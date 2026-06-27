import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// NOTE: You need to set these secrets in Supabase Dashboard:
// - FIREBASE_SERVICE_ACCOUNT: Your Firebase service account JSON (as string)
// - FIREBASE_PROJECT_ID: Your Firebase project ID

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "dabblersportapp";

// Cached shared secret used to recognise trusted calls from the DB push
// trigger. Fetched once per warm instance via the service_role-only RPC.
let cachedTriggerSecret: string | null = null;

interface NotificationPayload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  // Optional: specific platforms to send to
  platforms?: string[];
}

Deno.serve(async (req: Request) => {
  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const payload: NotificationPayload = await req.json();
    const { user_id, title, body, data, platforms } = payload;

    // Validate required fields (body is optional — falls back to title)
    if (!user_id || !title) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: user_id, title" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    const effectiveBody = body || title;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Service-role client: used for the trusted-call check, token lookup, and
    // (further down) invalid-token cleanup.
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Trusted server call? The notifications push trigger
    // (trg_push_on_notification_insert) sends a shared secret in
    // x-trigger-secret. When it matches, this is a fan-out from a notification
    // row that already targeted the correct recipient, so we skip the per-user
    // auth + block checks. The anon-key bearer it also sends only exists to
    // satisfy the platform's verify_jwt gate.
    const triggerSecret = req.headers.get("x-trigger-secret");
    let trusted = false;
    if (triggerSecret) {
      const expected = await getTriggerSecret(supabase);
      if (expected && constantTimeEqual(triggerSecret, expected)) {
        trusted = true;
      }
    }

    if (!trusted) {
      // Per-user path: require an authenticated caller (defense in depth on top
      // of verify_jwt) and enforce blocking.
      const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: { user: caller }, error: callerError } =
        await callerClient.auth.getUser();
      if (callerError || !caller) {
        return new Response(
          JSON.stringify({ error: "Unauthorized" }),
          { status: 401, headers: { "Content-Type": "application/json" } }
        );
      }

      // A caller may not notify a user who has blocked them (or whom they have
      // blocked). Self-notifications are exempt.
      if (caller.id !== user_id) {
        const { data: block } = await supabase
          .from("user_blocks")
          .select("id")
          .or(
            `and(blocker_user_id.eq.${caller.id},blocked_user_id.eq.${user_id}),` +
            `and(blocker_user_id.eq.${user_id},blocked_user_id.eq.${caller.id})`
          )
          .maybeSingle();
        if (block) {
          return new Response(
            JSON.stringify({ message: "Notification skipped (blocked)", sent: 0 }),
            { status: 200, headers: { "Content-Type": "application/json" } }
          );
        }
      }
    }

    // Get FCM tokens for the user
    let query = supabase
      .from("fcm_tokens")
      .select("token, platform")
      .eq("user_id", user_id);

    // Filter by platforms if specified
    if (platforms && platforms.length > 0) {
      query = query.in("platform", platforms);
    }

    const { data: tokens, error: tokensError } = await query;

    if (tokensError) {
      console.error("Error fetching tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch FCM tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: "No FCM tokens found for user",
          sent: 0 
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Send notification to each token. Each send resolves to a per-token
    // outcome so we can prune tokens FCM reports as permanently invalid.
    const outcomes = await Promise.all(
      tokens.map(async ({ token }) => {
        try {
          await sendFCMNotification(token, title, effectiveBody, data);
          return { token, ok: true, invalid: false };
        } catch (e) {
          return { token, ok: false, invalid: isInvalidTokenError(e) };
        }
      })
    );

    const successful = outcomes.filter(o => o.ok).length;
    const failed = outcomes.filter(o => !o.ok).length;

    // Prune tokens FCM rejected as unregistered / malformed so they don't
    // accumulate and waste sends on every future notification.
    const invalidTokens = outcomes.filter(o => o.invalid).map(o => o.token);
    if (invalidTokens.length > 0) {
      const { error: cleanupError } = await supabase
        .from("fcm_tokens")
        .delete()
        .in("token", invalidTokens);
      if (cleanupError) {
        console.error("Failed to prune invalid FCM tokens:", cleanupError);
      } else {
        console.log(`Pruned ${invalidTokens.length} invalid FCM token(s)`);
      }
    }

    return new Response(
      JSON.stringify({
        message: "Notifications sent",
        sent: successful,
        failed: failed,
        total: tokens.length,
      }),
      { 
        status: 200,
        headers: { 
          "Content-Type": "application/json",
          "Connection": "keep-alive"
        } 
      }
    );

  } catch (error) {
    console.error("Error in send-push-notification:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

/**
 * Fetch the push-trigger shared secret via the service_role-only RPC.
 * Cached per warm instance to avoid a DB round-trip on every push.
 */
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

/** Constant-time string comparison to avoid leaking the secret via timing. */
function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

/**
 * Whether an FCM send error indicates a permanently invalid token that should
 * be pruned (unregistered device, malformed token). Transient errors (5xx,
 * quota) are NOT treated as invalid so we don't delete healthy tokens.
 */
function isInvalidTokenError(e: unknown): boolean {
  const msg = String(e instanceof Error ? e.message : e);
  return (
    msg.includes(" 404 ") ||
    msg.includes("UNREGISTERED") ||
    msg.includes("registration-token-not-registered") ||
    msg.includes("INVALID_ARGUMENT") ||
    msg.includes("invalid-argument")
  );
}

/**
 * Get OAuth2 access token for FCM HTTP v1 API
 */
async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  
  // Create JWT for Google OAuth2
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  // Encode header and payload
  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Sign with private key
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
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

  // Exchange JWT for access token
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

/**
 * Convert PEM private key to ArrayBuffer
 */
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

/**
 * Send push notification via FCM HTTP v1 API
 */
async function sendFCMNotification(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  const accessToken = await getAccessToken();

  const fcmPayload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    },
  };

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
}
