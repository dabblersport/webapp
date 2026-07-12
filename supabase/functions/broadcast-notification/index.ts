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

/**
 * Verifies the caller is an authenticated admin.
 * Returns an error Response if not authorized, otherwise null.
 */
async function requireAdmin(req: Request): Promise<Response | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Evaluate the request in the caller's auth context (RLS + auth.uid()).
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  const { data: isAdmin, error: adminError } = await supabase.rpc("is_admin");
  if (adminError || isAdmin !== true) {
    return new Response(
      JSON.stringify({ error: "Forbidden" }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  return null;
}

interface BroadcastPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  topic?: string; // Default: 'announcements'
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

    // Require an authenticated admin caller — broadcasts reach all users.
    const authError = await requireAdmin(req);
    if (authError) return authError;

    // Parse request body
    const payload: BroadcastPayload = await req.json();
    const { title, body, data, topic = "announcements" } = payload;

    // Validate required fields
    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Send notification to topic
    await sendTopicNotification(topic, title, body, data);

    // Persist the broadcast into the in-app feed (one row per active user).
    // Uses the 'system.announcement' kind, which is inapp-only — the push
    // already went out via the FCM topic, so the per-notification push
    // trigger deliberately does not fire for these rows.
    let inAppCount = 0;
    try {
      const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const { data: inserted, error: rpcError } = await admin.rpc(
        "rpc_broadcast_inapp_notification",
        { p_title: title, p_body: body, p_route: data?.action_route ?? null }
      );
      if (rpcError) {
        console.error("broadcast in-app persistence failed:", rpcError);
      } else {
        inAppCount = inserted ?? 0;
      }
    } catch (persistError) {
      // Push already went out — don't fail the request over feed persistence.
      console.error("broadcast in-app persistence error:", persistError);
    }

    return new Response(
      JSON.stringify({
        message: `Broadcast notification sent to topic: ${topic}`,
        topic: topic,
        in_app_rows: inAppCount,
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
    // Log details server-side only; do not leak internals to the caller.
    console.error("Error in broadcast-notification:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

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
 * Send push notification to a topic via FCM HTTP v1 API
 */
async function sendTopicNotification(
  topic: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  const accessToken = await getAccessToken();

  const fcmPayload = {
    message: {
      topic: topic,
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
