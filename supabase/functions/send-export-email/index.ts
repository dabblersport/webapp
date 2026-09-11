import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// NOTE: You need to set this secret in Supabase Dashboard
// (Project Settings -> Edge Functions -> Secrets) before delivery works:
// - RESEND_API_KEY: a Resend (https://resend.com) API key.
//
// This is a separate credential from the Resend SMTP config already wired
// into Supabase Auth's own emails (OTP, password reset) — that lives at the
// Dashboard's Auth SMTP level, not as an app secret this function can read.
// Without RESEND_API_KEY set, every call below fails at the Resend API call
// with a clear "not configured" error — it does not silently no-op.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RESEND_FROM_ADDRESS =
  Deno.env.get("RESEND_FROM_ADDRESS") || "Dabbler <noreply@dabbler.app>";

interface SendExportEmailPayload {
  to: string;
  subject: string;
  body: string;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      );
    }

    const payload: SendExportEmailPayload = await req.json();
    const { to, subject, body } = payload;

    if (!to || !subject || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, subject, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Evaluate the caller in their own auth context (defense in depth on top
    // of verify_jwt).
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

    // This function is a self-serve "email me my own GDPR/PDPL export"
    // primitive, not a general mailer. Without this check, any authenticated
    // account could use it as an open relay to send arbitrary subject/body
    // content to any address. Restricting `to` to the caller's own verified
    // auth email keeps the blast radius to "send myself something."
    const callerEmail = caller.email?.toLowerCase().trim();
    if (!callerEmail || callerEmail !== to.toLowerCase().trim()) {
      return new Response(
        JSON.stringify({
          error: "Recipient must match the authenticated caller's own email",
        }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!RESEND_API_KEY) {
      console.error(
        "send-export-email: RESEND_API_KEY is not set. Set it in " +
          "Project Settings -> Edge Functions -> Secrets before this " +
          "function can deliver mail."
      );
      return new Response(
        JSON.stringify({
          error:
            "Email delivery is not configured (RESEND_API_KEY missing). " +
            "The export was created but could not be emailed.",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: RESEND_FROM_ADDRESS,
        to: [to],
        subject,
        text: body,
      }),
    });

    if (!resendResponse.ok) {
      const errorText = await resendResponse.text();
      console.error("Resend API error:", resendResponse.status, errorText);
      return new Response(
        JSON.stringify({ error: "Failed to send email via Resend" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    const result = await resendResponse.json();

    return new Response(
      JSON.stringify({ message: "Email sent", id: result?.id ?? null }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", "Connection": "keep-alive" },
      }
    );
  } catch (error) {
    console.error("Error in send-export-email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
