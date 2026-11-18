import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// send-live-activity v2 (KAN-1004d, 2026-11-18): the real Android Live Activity sender.
// v2: rows are claimed atomically by live_activity_claim (queued -> sending, attempts + 1, at most 20, inactive
// sessions skipped); only claimed rows are sent. android message carries ttl 3600s + collapse_key la:<session>.
// Called only by the database (live_activity_post via pg_net) with x-trigger-secret, the same trusted lane
// trg_push_on_notification_insert uses for send-push-notification. There is no user lane: no secret, 401.
// Input: {"send_ids": [bigint, ...]} (at most MAX_BATCH), optional "validate_only": true (FCM validate_only:
// nothing reaches a device; outcomes are still recorded, so a test can prove the rejection path).
// android: FCM HTTP v1 data message {token, android.priority high, data: the stored payload's string keys} to the
//          installation's fcm_tokens token (server-side only, never logged or returned).
// iOS:     nothing is sent until an APNs key exists; the row is marked 'unsent: no credentials'.
// Outcomes: sent | token_rejected (UNREGISTERED / token INVALID_ARGUMENT -> session stale, via
//           live_activity_record_result) | failed (error_class) | transient -> live_activity_retry (3 attempts).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "dabblersportapp";
const MAX_BATCH = 20;
const TRANSIENT = new Set(["unavailable", "quota", "network"]);

let cachedTriggerSecret: string | null = null;
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
    if (!req.headers.get("Authorization")) return json({ error: "Unauthorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const triggerSecret = req.headers.get("x-trigger-secret");
    let trusted = false;
    if (triggerSecret) {
      const expected = await getTriggerSecret(supabase);
      if (expected && constantTimeEqual(triggerSecret, expected)) trusted = true;
    }
    if (!trusted) return json({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const ids: number[] = Array.isArray(body?.send_ids)
      ? body.send_ids.map(Number).filter((n: number) => Number.isInteger(n) && n > 0).slice(0, MAX_BATCH)
      : [];
    const validateOnly = body?.validate_only === true;
    if (ids.length === 0) return json({ error: "send_ids required" }, 400);

    const { data: sends, error } = await supabase.rpc("live_activity_claim", { p_ids: ids });
    if (error) throw new Error(`claim: ${error.code}`);

    const counts: Record<string, number> = {};
    const bump = (k: string) => (counts[k] = (counts[k] ?? 0) + 1);
    let accessToken: string | null = null;

    // deno-lint-ignore no-explicit-any
    for (const row of (sends ?? []) as any[]) {
      const s = row;
      if (s.platform !== "android") {
        // No APNs key yet: the database flag live_activity_config.ios_sender_enabled keeps iOS rows from
        // reaching here; one that does is left exactly as the stub left it.
        await supabase.from("live_activity_sends")
          .update({ status: "unsent: no credentials", result_at: new Date().toISOString() })
          .eq("id", row.id).eq("status", "sending");
        bump("unsent_no_credentials");
        continue;
      }
      const { data: tok } = await supabase.from("fcm_tokens").select("token")
        .eq("user_id", s.user_id).eq("installation_id", s.installation_id)
        .order("updated_at", { ascending: false }).limit(1).maybeSingle();
      if (!tok?.token) {
        await record(supabase, row.id, "failed", "no_token");
        bump("failed");
        continue;
      }
      const data: Record<string, string> = {};
      for (const [k, v] of Object.entries(row.payload?.data ?? {})) {
        data[k] = typeof v === "string" ? v : JSON.stringify(v);
      }
      const message = {
        validate_only: validateOnly || undefined,
        message: {
          token: tok.token,
          android: {
            priority: "high",
            ttl: row.payload?.android?.ttl ?? "3600s",
            collapse_key: row.payload?.android?.collapse_key ?? `la:${row.session_id}`,
          },
          data,
        },
      };
      try {
        accessToken ??= await getAccessToken();
        await postFcm(accessToken, message);
        await record(supabase, row.id, "sent", validateOnly ? "validate_only" : null);
        bump("sent");
      } catch (e) {
        const raw = String(e instanceof Error ? e.message : e);
        const cls = raw.startsWith("FCM request failed") ? classifyFcmError(e) : "network";
        if (cls === "unregistered" || cls === "invalid_token") {
          await record(supabase, row.id, "token_rejected", cls);
          bump("token_rejected");
        } else if (TRANSIENT.has(cls)) {
          await supabase.rpc("live_activity_retry", { p_send_id: row.id, p_error_class: cls });
          bump("retry");
        } else {
          await record(supabase, row.id, "failed", cls);
          bump("failed");
        }
        console.error("send-live-activity: send", row.id, "failed:", cls);
      }
    }
    return json({ received: ids.length, claimed: (sends ?? []).length, validate_only: validateOnly, ...counts });
  } catch (e) {
    console.error("send-live-activity error:", e instanceof Error ? e.message.slice(0, 200) : "unknown");
    return json({ error: "Internal error" }, 500);
  }
});

// deno-lint-ignore no-explicit-any
async function record(supabase: any, id: number, outcome: string, errorClass: string | null) {
  const { error } = await supabase.rpc("live_activity_record_result",
    { p_send_id: id, p_outcome: outcome, p_error_class: errorClass });
  if (error) console.error("live_activity_record_result failed for", id, error.code);
}

// --- helpers copied verbatim from send-push-notification ---

// deno-lint-ignore no-explicit-any
async function getTriggerSecret(supabase: any): Promise<string | null> {
  if (cachedTriggerSecret) return cachedTriggerSecret;
  const { data, error } = await supabase.rpc("get_push_trigger_secret");
  if (error || !data) {
    console.error("Failed to fetch push trigger secret:", error);
    return null;
  }
  cachedTriggerSecret = data as string;
  return cachedTriggerSecret;
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

function classifyFcmError(e: unknown): string {
  const msg = String(e instanceof Error ? e.message : e);
  const status = msg.match(/"status"\s*:\s*"([A-Z_]+)"/)?.[1] ?? "";
  const errorCode = msg.match(/"errorCode"\s*:\s*"([A-Z_]+)"/)?.[1] ?? "";
  const http = Number(msg.match(/FCM request failed: (\d{3})/)?.[1] ?? 0);
  if (errorCode === "UNREGISTERED" || status === "NOT_FOUND" || http === 404) return "unregistered";
  if (errorCode === "SENDER_ID_MISMATCH") return "sender_mismatch";
  if (errorCode === "THIRD_PARTY_AUTH_ERROR") return "apns_auth";
  if (errorCode === "QUOTA_EXCEEDED" || http === 429) return "quota";
  if (status === "INVALID_ARGUMENT" || errorCode === "INVALID_ARGUMENT") {
    return /registration token/i.test(msg) ? "invalid_token" : "invalid_payload";
  }
  if (status === "UNAUTHENTICATED" || status === "PERMISSION_DENIED" || http === 401 || http === 403) return "auth";
  if (http >= 500 || status === "UNAVAILABLE" || status === "INTERNAL") return "unavailable";
  return "unknown";
}

async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${unsignedToken}.${encodedSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!tokenResponse.ok) {
    throw new Error(`Failed to get access token: ${await tokenResponse.text()}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function postFcm(accessToken: string, fcmPayload: unknown): Promise<string | null> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmPayload),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`FCM request failed: ${response.status} - ${errorText}`);
  }
  const ok = await response.json().catch(() => ({}));
  return typeof ok?.name === "string" ? ok.name : null;
}
