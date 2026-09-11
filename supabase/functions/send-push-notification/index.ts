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

      // Per-caller rate limit on the direct (non-trusted) lane — applies
      // regardless of outcome below, so it also caps relationship-probing.
      const limited = await isRateLimited(supabase, caller.id, user_id);
      if (limited) {
        return new Response(
          JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
          { status: 429, headers: { "Content-Type": "application/json" } }
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

        // Authentication proved WHO is calling; this proves the caller has a
        // reason to reach this specific target. Without it, any registered
        // account could push arbitrary title/body to any other user (KAN-59).
        const authorized = await callerMayNotify(supabase, caller.id, user_id);
        if (!authorized) {
          return new Response(
            JSON.stringify({ error: "Not authorized to notify this user" }),
            { status: 403, headers: { "Content-Type": "application/json" } }
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

    // One OAuth token for the whole request (was fetched per device token).
    const accessToken = await getAccessToken();

    // Send notification to each token. Each send resolves to a per-token
    // outcome so we can prune tokens FCM reports as permanently invalid.
    const outcomes = await Promise.all(
      tokens.map(async ({ token, platform }) => {
        try {
          await sendFCMNotification(accessToken, token, title, effectiveBody, data);
          return { token, ok: true, invalid: false };
        } catch (e) {
          // Surface FCM's real response in the logs — essential for
          // diagnosing platform-specific failures (e.g. APNs auth).
          console.error(`FCM send failed (platform=${platform}):`, String(e));
          return {
            token,
            ok: false,
            invalid: isInvalidTokenError(e),
            errorCode: extractFcmErrorStatus(e, platform),
          };
        }
      })
    );

    const successful = outcomes.filter(o => o.ok).length;
    const failed = outcomes.filter(o => !o.ok).length;
    // FCM error STATUS codes only (e.g. "iOS:THIRD_PARTY_AUTH_ERROR") — safe
    // to return, and the only way trigger-initiated sends (whose response
    // lands in net._http_response) can report why a platform failed.
    const errorCodes = outcomes
      .filter(o => !o.ok)
      .map(o => (o as { errorCode?: string }).errorCode)
      .filter(Boolean);

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
        ...(errorCodes.length > 0 ? { error_codes: errorCodes } : {}),
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

/** Max direct (non-trusted) push calls a single caller may make per hour. */
const DIRECT_SEND_RATE_LIMIT_PER_HOUR = 20;

/**
 * Per-caller rate limit for the direct (non-trusted) lane, backed by
 * `audit_events` (actor_user_id, action='push.direct_send'). No new table:
 * this is an existing generic audit log, and service-role bypasses its RLS.
 * Counts+records every direct call regardless of downstream outcome, so it
 * also bounds relationship-probing via repeated 403s.
 */
// deno-lint-ignore no-explicit-any
async function isRateLimited(
  supabase: any,
  callerId: string,
  targetUserId: string
): Promise<boolean> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("audit_events")
    .select("id", { count: "exact", head: true })
    .eq("actor_user_id", callerId)
    .eq("action", "push.direct_send")
    .gte("created_at", oneHourAgo);

  if (error) {
    // Fail closed: an unreadable rate-limit ledger must not become an
    // unlimited-send bypass.
    console.error("Rate limit check failed:", error);
    return true;
  }
  if ((count ?? 0) >= DIRECT_SEND_RATE_LIMIT_PER_HOUR) {
    return true;
  }

  const { error: insertError } = await supabase.from("audit_events").insert({
    actor_user_id: callerId,
    action: "push.direct_send",
    target_user_id: targetUserId,
    meta: {},
  });
  if (insertError) {
    console.error("Failed to record rate-limit event:", insertError);
  }
  return false;
}

/**
 * Whether `callerId` has a legitimate relationship to `targetUserId` that
 * justifies sending them a direct push: a mutual follow, shared circle,
 * shared active squad, shared active game roster, or shared meetup
 * attendance. Mirrors the relationships that already drive the server-side
 * notify triggers (friend/circle/squad/game/meetup) — see
 * trg_*_notify in db-triggers-functions memory. Self-notifications bypass
 * this entirely (checked by the caller before invoking).
 */
// deno-lint-ignore no-explicit-any
async function callerMayNotify(
  supabase: any,
  callerId: string,
  targetUserId: string
): Promise<boolean> {
  // profile_follows/circle_members key off profile ids, not auth user ids —
  // resolve every profile (player and/or organiser) each user holds.
  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, user_id")
    .in("user_id", [callerId, targetUserId]);

  const callerProfileIds = (profiles ?? [])
    .filter((p: { user_id: string }) => p.user_id === callerId)
    .map((p: { id: string }) => p.id);
  const targetProfileIds = (profiles ?? [])
    .filter((p: { user_id: string }) => p.user_id === targetUserId)
    .map((p: { id: string }) => p.id);

  if (callerProfileIds.length > 0 && targetProfileIds.length > 0) {
    const { data: follow } = await supabase
      .from("profile_follows")
      .select("id")
      .or(
        `and(follower_profile_id.in.(${callerProfileIds.join(",")}),following_profile_id.in.(${targetProfileIds.join(",")})),` +
        `and(follower_profile_id.in.(${targetProfileIds.join(",")}),following_profile_id.in.(${callerProfileIds.join(",")}))`
      )
      .limit(1)
      .maybeSingle();
    if (follow) return true;

    const { data: callerCircles } = await supabase
      .from("circle_members")
      .select("circle_id")
      .in("member_profile_id", callerProfileIds);
    const circleIds = (callerCircles ?? []).map((c: { circle_id: string }) => c.circle_id);
    if (circleIds.length > 0) {
      const { data: sharedCircle } = await supabase
        .from("circle_members")
        .select("circle_id")
        .in("circle_id", circleIds)
        .in("member_profile_id", targetProfileIds)
        .limit(1)
        .maybeSingle();
      if (sharedCircle) return true;
    }
  }

  const { data: callerSquads } = await supabase
    .from("squad_members")
    .select("squad_id")
    .eq("user_id", callerId)
    .eq("status", "active");
  const squadIds = (callerSquads ?? []).map((s: { squad_id: string }) => s.squad_id);
  if (squadIds.length > 0) {
    const { data: sharedSquad } = await supabase
      .from("squad_members")
      .select("squad_id")
      .in("squad_id", squadIds)
      .eq("user_id", targetUserId)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();
    if (sharedSquad) return true;
  }

  const { data: callerGames } = await supabase
    .from("game_roster")
    .select("game_id")
    .eq("user_id", callerId)
    .eq("status", "active");
  const gameIds = (callerGames ?? []).map((g: { game_id: string }) => g.game_id);
  if (gameIds.length > 0) {
    const { data: sharedGame } = await supabase
      .from("game_roster")
      .select("game_id")
      .in("game_id", gameIds)
      .eq("user_id", targetUserId)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();
    if (sharedGame) return true;
  }

  const { data: callerMeetups } = await supabase
    .from("meetup_attendees")
    .select("meetup_id")
    .eq("user_id", callerId);
  const meetupIds = (callerMeetups ?? []).map((m: { meetup_id: string }) => m.meetup_id);
  if (meetupIds.length > 0) {
    const { data: sharedMeetup } = await supabase
      .from("meetup_attendees")
      .select("meetup_id")
      .in("meetup_id", meetupIds)
      .eq("user_id", targetUserId)
      .limit(1)
      .maybeSingle();
    if (sharedMeetup) return true;
  }

  return false;
}

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
 * Extract FCM's error STATUS (e.g. "UNREGISTERED", "THIRD_PARTY_AUTH_ERROR")
 * from a failed-send error, prefixed with the platform. Status codes only —
 * no message text, tokens, or internals.
 */
function extractFcmErrorStatus(e: unknown, platform: string): string {
  const msg = String(e instanceof Error ? e.message : e);
  const match = msg.match(/"status"\s*:\s*"([A-Z_]+)"/);
  const httpMatch = msg.match(/FCM request failed: (\d{3})/);
  const code = match?.[1] ?? (httpMatch ? `HTTP_${httpMatch[1]}` : "UNKNOWN");
  return `${platform}:${code}`;
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
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
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
        payload: {
          aps: {
            // Without a sound the iOS banner arrives silently.
            sound: "default",
          },
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
