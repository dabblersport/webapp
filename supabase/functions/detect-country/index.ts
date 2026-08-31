// @ts-ignore: Deno types
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
// @ts-ignore: Deno types
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * Supabase Edge Function to detect user's country and city from IP address.
 *
 * This function uses Cloudflare's IP geolocation headers which are
 * automatically added to requests by Cloudflare's CDN.
 *
 * Deliberately unauthenticated (KAN-59): it is called during onboarding
 * before a session exists (`ip_country_detection_service.dart` sends the
 * anon key as bearer, not a user JWT) -- there is no user to require auth
 * from. The two gaps this closes are the ones that don't require a session:
 * a per-caller rate limit, and no longer logging or trusting client-supplied
 * IP values.
 *
 * Returns: { country: string, city: string, countryCode: string }
 * - country: Full country name (e.g., "United Arab Emirates", "United States")
 * - city: City name from IP (e.g., "Dubai", "New York")
 * - countryCode: ISO country code (e.g., "AE", "US") or "XX" if unknown
 */

// Origins allowed to call this from a browser. Native app requests carry no
// Origin header and are unaffected either way -- CORS only gates browsers.
const ALLOWED_ORIGINS = new Set([
  "https://app.dabbler.pro",
  "https://canary.dabbler.pro",
]);

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

// @ts-ignore: Deno global is available in Supabase edge runtime
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// @ts-ignore: Deno global is available in Supabase edge runtime
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const RATE_LIMIT_MAX_CALLS = 30; // per hashed IP, per rolling hour
const RATE_LIMIT_WINDOW_HOURS = 1;

/** SHA-256 hex digest -- used to key rate limiting without storing raw IPs. */
async function hashIp(ip: string): Promise<string> {
  // @ts-ignore: crypto is available in the Supabase edge runtime
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(ip),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Fails closed: an error counting or recording a call rejects the request,
 * matching the posture already adopted for send-push-notification (KAN-59).
 * Onboarding degrades gracefully client-side (falls back to "Global"), so
 * failing closed here does not block signup, only this one lookup.
 */
async function isRateLimited(
  supabase: ReturnType<typeof createClient>,
  ipHash: string,
): Promise<boolean> {
  const since = new Date(
    Date.now() - RATE_LIMIT_WINDOW_HOURS * 60 * 60 * 1000,
  ).toISOString();

  const { count, error: countError } = await supabase
    .from("audit_events")
    .select("id", { count: "exact", head: true })
    .eq("action", "detect_country.call")
    .eq("meta->>ip_hash", ipHash)
    .gte("created_at", since);

  if (countError) {
    console.error("Rate limit check failed:", countError.message);
    return true;
  }
  if ((count ?? 0) >= RATE_LIMIT_MAX_CALLS) {
    return true;
  }

  const { error: insertError } = await supabase.from("audit_events").insert({
    actor_user_id: null,
    action: "detect_country.call",
    meta: { ip_hash: ipHash },
  });
  if (insertError) {
    console.error("Failed to record rate-limit event:", insertError.message);
    return true;
  }

  return false;
}

// @ts-expect-error: Deno global is available in Supabase edge runtime
Deno.serve(async (req: Request) => {
  const cors = corsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  try {
    // Cloudflare sets CF-Connecting-IP to the real connecting IP and
    // overwrites any client-supplied value -- unlike X-Forwarded-For /
    // X-Real-IP, which the caller controls and which previously let anyone
    // use this function as a free geolocation lookup for an arbitrary IP by
    // spoofing the header. Only CF-Connecting-IP is trusted for the ipapi.co
    // lookup; X-Forwarded-For/X-Real-IP are used only as a last-resort
    // rate-limit key when Cloudflare's header is absent (e.g. local dev).
    const trustedIp = req.headers.get("CF-Connecting-IP");
    const forwardedFor = req.headers.get("X-Forwarded-For");
    const realIp = req.headers.get("X-Real-IP");
    const rateLimitKeyIp =
      trustedIp || forwardedFor?.split(",")[0].trim() || realIp;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (rateLimitKeyIp) {
      const ipHash = await hashIp(rateLimitKeyIp);
      if (await isRateLimited(supabase, ipHash)) {
        return new Response(
          JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
          {
            status: 429,
            headers: { "Content-Type": "application/json", ...cors },
          },
        );
      }
    }

    // 1. Cloudflare's CF-IPCountry header (most reliable when available;
    // Cloudflare-set, not client-controlled).
    let countryCode = req.headers.get("CF-IPCountry");
    let city: string | null = null;

    // Filter out localhost and private IPs
    const isPrivateIp = trustedIp === "127.0.0.1" ||
      trustedIp === "::1" ||
      trustedIp?.startsWith("192.168.") ||
      trustedIp?.startsWith("10.") ||
      trustedIp?.startsWith("172.16.") ||
      trustedIp?.startsWith("172.17.") ||
      trustedIp?.startsWith("172.18.") ||
      trustedIp?.startsWith("172.19.") ||
      trustedIp?.startsWith("172.20.") ||
      trustedIp?.startsWith("172.21.") ||
      trustedIp?.startsWith("172.22.") ||
      trustedIp?.startsWith("172.23.") ||
      trustedIp?.startsWith("172.24.") ||
      trustedIp?.startsWith("172.25.") ||
      trustedIp?.startsWith("172.26.") ||
      trustedIp?.startsWith("172.27.") ||
      trustedIp?.startsWith("172.28.") ||
      trustedIp?.startsWith("172.29.") ||
      trustedIp?.startsWith("172.30.") ||
      trustedIp?.startsWith("172.31.");

    // Only ever look up a Cloudflare-verified IP -- never a client-supplied
    // X-Forwarded-For/X-Real-IP value, which would restore the spoofable
    // geolocation-oracle behaviour this migration closes.
    if (trustedIp && !isPrivateIp) {
      try {
        const ipApiResponse = await fetch(
          `https://ipapi.co/${trustedIp}/json/`,
          { headers: { "User-Agent": "Dabbler-App/1.0" } },
        );

        if (ipApiResponse.ok) {
          const ipData = await ipApiResponse.json();
          city = ipData.city || null;
          if (!countryCode || countryCode === "XX") {
            countryCode = ipData.country_code;
          }
        } else {
          console.error("ipapi.co response not ok:", ipApiResponse.status);
        }
      } catch (e) {
        console.error(
          "ipapi.co lookup failed:",
          e instanceof Error ? e.message : String(e),
        );
      }
    }

    // Map country code to full country name
    const countryName = mapCountryCodeToName(countryCode);

    return new Response(
      JSON.stringify({
        country: countryName,
        city: city || null,
        countryCode: countryCode || "XX",
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          ...cors,
        },
      },
    );
  } catch (error: unknown) {
    console.error(
      "Error detecting country:",
      error instanceof Error ? error.message : String(error),
    );
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({
        country: "Global",
        city: null,
        countryCode: "XX",
        error: errorMessage,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...cors },
      },
    );
  }
});

/**
 * Maps ISO 3166-1 alpha-2 country codes to full country names.
 * Matches the format used in the app's country list.
 */
function mapCountryCodeToName(code: string | null): string {
  if (!code || code === "XX") return "Global";

  const countryMap: Record<string, string> = {
    "AE": "United Arab Emirates",
    "SA": "Saudi Arabia",
    "QA": "Qatar",
    "KW": "Kuwait",
    "BH": "Bahrain",
    "OM": "Oman",
    "EG": "Egypt",
    "JO": "Jordan",
    "LB": "Lebanon",
    "US": "United States",
    "GB": "United Kingdom",
    "CA": "Canada",
    "AU": "Australia",
    "FR": "France",
    "DE": "Germany",
    "ES": "Spain",
    "IT": "Italy",
    "NL": "Netherlands",
    "BE": "Belgium",
    "CH": "Switzerland",
    "AT": "Austria",
    "SE": "Sweden",
    "NO": "Norway",
    "DK": "Denmark",
    "FI": "Finland",
    "PL": "Poland",
    "CZ": "Czech Republic",
    "PT": "Portugal",
    "GR": "Greece",
    "IE": "Ireland",
    "IN": "India",
    "PK": "Pakistan",
    "BD": "Bangladesh",
    "JP": "Japan",
    "CN": "China",
    "KR": "South Korea",
    "SG": "Singapore",
    "MY": "Malaysia",
    "TH": "Thailand",
    "ID": "Indonesia",
    "PH": "Philippines",
    "VN": "Vietnam",
    "BR": "Brazil",
    "MX": "Mexico",
    "AR": "Argentina",
    "CL": "Chile",
    "CO": "Colombia",
    "PE": "Peru",
    "ZA": "South Africa",
    "NG": "Nigeria",
    "KE": "Kenya",
    "MA": "Morocco",
    "DZ": "Algeria",
    "TN": "Tunisia",
    "TR": "Turkey",
    "IL": "Israel",
  };

  return countryMap[code.toUpperCase()] || "Global";
}
