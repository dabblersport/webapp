import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// NOTE: You need to set these secrets in Supabase Dashboard:
// - FIREBASE_SERVICE_ACCOUNT: Your Firebase service account JSON (as string)
// - FIREBASE_PROJECT_ID: Your Firebase project ID

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "dabblersportapp";

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

    // Create Supabase client with service role key
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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

    // Send notification to each token
    const results = await Promise.allSettled(
      tokens.map(({ token }) => sendFCMNotification(token, title, effectiveBody, data))
    );

    // Count successes and failures
    const successful = results.filter(r => r.status === "fulfilled").length;
    const failed = results.filter(r => r.status === "rejected").length;

    // Log failed tokens (could be used to clean up invalid tokens)
    const failedTokens = results
      .map((r, idx) => ({ result: r, token: tokens[idx].token }))
      .filter(({ result }) => result.status === "rejected")
      .map(({ token }) => token);

    if (failedTokens.length > 0) {
      console.log("Failed to send to tokens:", failedTokens);
      // TODO: Clean up invalid tokens from database
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
