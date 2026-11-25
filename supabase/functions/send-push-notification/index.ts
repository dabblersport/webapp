import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// v14 (KAN-979, 2026-11-17): quiet-hours silent delivery, iOS interruption levels, Android
// channels, thread/collapse ids, badge, device_platform, one notification_deliveries row per device.
// v19 (KAN-1045, 2026-11-25): channel_key (Android channel behind PUSH_CHANNEL_KEY_MIN_BUILD, legacy
// category channel otherwise), thread-id = channel_key, per-channel iOS interruption level.
// v15 (KAN-1016, 2026-11-18): on Android, the actionable categories (RSVP, waitlist, message) go out
// as data-only messages so the app draws them with their action buttons (KAN-992). Only to an
// installation whose app build is at least PUSH_DATA_ONLY_MIN_BUILD (secret); unset = off, and every
// push is the v14 notification message. iOS, the web and the other categories are unchanged.
//
// NOTE: You need to set these secrets in Supabase Dashboard:
// - FIREBASE_SERVICE_ACCOUNT: Your Firebase service account JSON (as string)
// - FIREBASE_PROJECT_ID: Your Firebase project ID

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "dabblersportapp";

// Cached shared secret used to recognise trusted calls from the DB push
// trigger. Fetched once per warm instance via the service_role-only RPC.
let cachedTriggerSecret: string | null = null;

// v14 (KAN-979): how the device should present this push. Built by
// trg_push_on_notification_insert and honoured only on the trusted lane.
interface DeliveryOptions {
  mode: "alert" | "silent";        // silent = quiet hours (I-2): no sound, iOS passive
  time_sensitive: boolean;          // breaks_quiet / security kinds (I-3): iOS time-sensitive
  android_channel_id: string;       // one channel per category, plus dabbler_quiet
  ios_category: string;             // UNNotificationCategory id (actions), also data.category
  thread_id?: string | null;        // v19: channel_key (was group_key)
  channel_key?: string | null;      // v19 (KAN-1045): notification_kinds.channel_key, e.g. games.invites
  interruption_level?: string | null; // v19: per-channel iOS level from notification_push_dispatch
  collapse_id?: string | null;      // from group_key, <= 64 bytes
  badge?: number | null;            // recipient's unread count
}

interface NotificationPayload {
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  // Optional: specific platforms to send to (matches fcm_tokens.device_platform)
  platforms?: string[];
  // v14, trusted lane only
  notification_id?: string;
  delivery?: DeliveryOptions;
}

interface TokenRow {
  id: string;
  token: string;
  device_platform: string;
  app_version: string | null;
}

/** v15: the categories whose Android push the app draws itself, with actions (push_contract.dart). */
const DATA_ONLY_CATEGORIES = new Set(["DABBLER_RSVP", "DABBLER_WAITLIST", "DABBLER_MESSAGE"]);

/**
 * v15: the lowest app build (the number after "+" in fcm_tokens.app_version) whose background
 * handler draws a data-only push. Unset or not a number = data-only is off for every device.
 */
const DATA_ONLY_MIN_BUILD = (() => {
  const n = Number(Deno.env.get("PUSH_DATA_ONLY_MIN_BUILD") ?? "");
  return Number.isInteger(n) && n > 0 ? n : Infinity;
})();

/**
 * v19 (KAN-1045): the lowest app build that creates the channel_key Android channels. Below it (and while
 * unset) Android keeps the legacy category channel, which every installed build has.
 */
const CHANNEL_KEY_MIN_BUILD = (() => {
  const n = Number(Deno.env.get("PUSH_CHANNEL_KEY_MIN_BUILD") ?? "");
  return Number.isInteger(n) && n > 0 ? n : Infinity;
})();

/** v19: the Android channel for this device: channel_key on a build that has it, else the legacy id. */
function androidChannelFor(row: TokenRow, delivery: DeliveryOptions): string {
  if (delivery.mode !== "alert" || !delivery.channel_key) return delivery.android_channel_id;
  const build = appBuild(row.app_version);
  return build !== null && build >= CHANNEL_KEY_MIN_BUILD ? delivery.channel_key : delivery.android_channel_id;
}

const IOS_LEVELS = new Set(["time-sensitive", "active", "passive"]);

/** "1.7.10+181" -> 181; null when there is no build number. */
function appBuild(appVersion: string | null | undefined): number | null {
  const m = /\+(\d+)\s*$/.exec(appVersion ?? "");
  return m ? Number(m[1]) : null;
}

/** v15: whether this device gets a data-only message for this push. */
function sendsDataOnly(row: TokenRow, delivery: DeliveryOptions, trusted: boolean): boolean {
  if (!trusted || row.device_platform !== "android") return false;
  if (!DATA_ONLY_CATEGORIES.has(delivery.ios_category)) return false;
  const build = appBuild(row.app_version);
  return build !== null && build >= DATA_ONLY_MIN_BUILD;
}

/** Default presentation for the direct lane and for callers that send no delivery block (v13 behaviour). */
const DEFAULT_DELIVERY: DeliveryOptions = {
  mode: "alert",
  time_sensitive: false,
  android_channel_id: "dabbler_default",
  ios_category: "DABBLER_DEFAULT",
};

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

    // KAN-1037: the only caller is the notifications push trigger
    // (trg_push_on_notification_insert via pg_net), which sends a shared
    // secret in x-trigger-secret. There is no user-JWT lane: without a
    // valid secret the request is rejected.
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const triggerSecret = req.headers.get("x-trigger-secret");
    let trusted = false;
    if (triggerSecret) {
      const expected = await getTriggerSecret(supabase);
      if (expected && constantTimeEqual(triggerSecret, expected)) {
        trusted = true;
      }
    }
    if (!trusted) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // v14: the delivery block and the delivery records are accepted only from
    // the trusted trigger lane; a direct caller cannot ask for time-sensitive
    // delivery or write notification_deliveries rows.
    const delivery: DeliveryOptions = trusted && payload.delivery
      ? { ...DEFAULT_DELIVERY, ...payload.delivery }
      : DEFAULT_DELIVERY;
    const notificationId = trusted && payload.notification_id ? payload.notification_id : null;

    // Get FCM tokens for the user. KAN-977: device_platform is the OS on every
    // row (platform is the legacy slot and NULL on installation rows).
    let query = supabase
      .from("fcm_tokens")
      .select("id, token, device_platform, app_version")
      .eq("user_id", user_id);

    // Filter by platforms if specified
    if (platforms && platforms.length > 0) {
      query = query.in("device_platform", platforms);
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
      (tokens as TokenRow[]).map(async (row) => {
        const { id, token, device_platform } = row;
        try {
          const providerId = await sendFCMNotification(
            accessToken, token, title, effectiveBody, data,
            { ...delivery, android_channel_id: androidChannelFor(row, delivery) },
            sendsDataOnly(row, delivery, trusted));
          return { id, device_platform, ok: true, invalid: false, providerId, errorClass: null as string | null };
        } catch (e) {
          // Surface FCM's real response in the logs — essential for
          // diagnosing platform-specific failures (e.g. APNs auth).
          console.error(`FCM send failed (platform=${device_platform}):`, String(e));
          return {
            id,
            device_platform,
            ok: false,
            invalid: isInvalidTokenError(e),
            providerId: null as string | null,
            errorClass: classifyFcmError(e) as string | null,
            errorCode: extractFcmErrorStatus(e, device_platform),
          };
        }
      })
    );

    // v14 (KAN-979): one notification_deliveries row per device, with the
    // provider result. Never the token and never the text.
    if (notificationId) {
      const attemptedAt = new Date().toISOString();
      const { error: deliveryError } = await supabase
        .from("notification_deliveries")
        .insert(outcomes.map((o) => ({
          notification_id: notificationId,
          channel: "push",
          status: o.ok ? "accepted" : "failed",
          provider_id: o.providerId,
          error_class: o.errorClass,
          token_id: o.id,
          device_platform: o.device_platform,
          delivery_mode: delivery.mode,
          time_sensitive: delivery.time_sensitive,
          attempted_at: attemptedAt,
        })));
      if (deliveryError) {
        console.error("Failed to record notification deliveries:", deliveryError);
      }
    }

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
    const invalidTokens = outcomes.filter(o => o.invalid).map(o => o.id);
    if (invalidTokens.length > 0) {
      const { error: cleanupError } = await supabase
        .from("fcm_tokens")
        .delete()
        .in("id", invalidTokens);
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
  // v14: INVALID_ARGUMENT alone is no longer enough. It is also what FCM says
  // about a malformed payload, and pruning on it would delete every token after
  // one payload bug. Only a token-specific answer prunes.
  const cls = classifyFcmError(e);
  return cls === "unregistered" || cls === "invalid_token";
}

/**
 * v14: a short error class for notification_deliveries.error_class. No
 * message text, token or internals.
 */
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
  data: Record<string, string> | undefined,
  delivery: DeliveryOptions,
  dataOnly = false
): Promise<string | null> {
  const alert = delivery.mode === "alert";
  const badge = typeof delivery.badge === "number" ? delivery.badge : undefined;

  if (dataOnly) {
    // v15 (KAN-1016): Android, actionable category. No `notification` block, so Android hands the
    // message to the app, which draws it on `android_channel_id` (dabbler_quiet in quiet hours, so
    // a silent push stays silent) with the category's actions. FCM data values are strings only.
    const d: Record<string, string> = {
      ...(data || {}),
      title,
      body,
      category: delivery.ios_category,
      delivery_mode: delivery.mode,
      android_channel_id: delivery.android_channel_id,
      time_sensitive: delivery.time_sensitive ? "true" : "false",
    };
    if (delivery.collapse_id) d.collapse_id = delivery.collapse_id;
    if (delivery.thread_id) d.thread_id = delivery.thread_id;
    if (badge !== undefined) d.badge = String(badge);
    const et = d.entity_type, eid = d.entity_id;
    if (eid && et === "game" && !d.game_id) d.game_id = eid;
    if (eid && et === "meetup" && !d.meetup_id) d.meetup_id = eid;
    if (eid && et === "conversation" && !d.conversation_id) d.conversation_id = eid;
    const android: Record<string, unknown> = { priority: alert ? "high" : "normal" };
    if (delivery.collapse_id) android.collapse_key = delivery.collapse_id;
    return await postFcm(accessToken, { message: { token, data: d, android } });
  }
  // iOS: passive in quiet hours (no sound, no screen wake), time-sensitive for
  // breaks_quiet and security kinds, active otherwise. Without a sound the iOS
  // banner arrives silently, so only an alerting push carries one.
  // v19: the dispatcher's per-channel level when it sent a valid one; never louder than the mode allows.
  const interruptionLevel = delivery.time_sensitive ? "time-sensitive" : !alert ? "passive"
    : (delivery.interruption_level && IOS_LEVELS.has(delivery.interruption_level)) ? delivery.interruption_level
    : "active";

  const aps: Record<string, unknown> = {
    "interruption-level": interruptionLevel,
    category: delivery.ios_category,
  };
  if (alert) aps.sound = "default";
  if (badge !== undefined) aps.badge = badge;
  if (delivery.thread_id) aps["thread-id"] = delivery.thread_id;

  const apnsHeaders: Record<string, string> = { "apns-priority": alert ? "10" : "5" };
  if (delivery.collapse_id) apnsHeaders["apns-collapse-id"] = delivery.collapse_id;

  const androidNotification: Record<string, unknown> = {
    channel_id: delivery.android_channel_id,
    notification_priority: alert ? "PRIORITY_HIGH" : "PRIORITY_LOW",
    default_sound: alert,
  };
  if (badge !== undefined) androidNotification.notification_count = badge;
  if (delivery.collapse_id) androidNotification.tag = delivery.collapse_id;

  const android: Record<string, unknown> = {
    priority: alert ? "high" : "normal",
    notification: androidNotification,
  };
  if (delivery.collapse_id) android.collapse_key = delivery.collapse_id;

  const webNotification: Record<string, unknown> = {};
  if (!alert) webNotification.silent = true;
  if (delivery.collapse_id) webNotification.tag = delivery.collapse_id;

  const fcmPayload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...(data || {}),
        category: delivery.ios_category,
        delivery_mode: delivery.mode,
      },
      android,
      apns: {
        headers: apnsHeaders,
        payload: { aps },
      },
      ...(Object.keys(webNotification).length > 0 ? { webpush: { notification: webNotification } } : {}),
    },
  };

  return await postFcm(accessToken, fcmPayload);
}

/** POST one FCM v1 message; returns the provider id, throws with FCM's answer on failure. */
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
  // FCM answers {"name": "projects/<p>/messages/<id>"}: the provider id.
  const ok = await response.json().catch(() => ({}));
  return typeof ok?.name === "string" ? ok.name : null;
}
