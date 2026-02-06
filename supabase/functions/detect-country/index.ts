// @ts-ignore: Deno types
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Supabase Edge Function to detect user's country and city from IP address.
 * 
 * This function uses Cloudflare's IP geolocation headers which are
 * automatically added to requests by Cloudflare's CDN.
 * 
 * Returns: { country: string, city: string, countryCode: string }
 * - country: Full country name (e.g., "United Arab Emirates", "United States")
 * - city: City name from IP (e.g., "Dubai", "New York")
 * - countryCode: ISO country code (e.g., "AE", "US") or "XX" if unknown
 */

// @ts-expect-error: Deno global is available in Supabase edge runtime
Deno.serve(async (req: Request) => {
  try {
    // Try multiple sources for country detection
    // 1. Cloudflare's CF-IPCountry header (most reliable when available)
    let countryCode = req.headers.get("CF-IPCountry");
    let city: string | null = null;
    
    console.log("CF-IPCountry header:", countryCode);
    
    // 2. If CF header is not available, use X-Forwarded-For to get real IP
    // Also use ipapi.co to get city information
    const forwardedFor = req.headers.get("X-Forwarded-For");
    const realIp = req.headers.get("X-Real-IP");
    const clientIp = forwardedFor?.split(',')[0].trim() || realIp;
    
    console.log("Client IP from headers:", clientIp);
    console.log("X-Forwarded-For:", forwardedFor);
    console.log("X-Real-IP:", realIp);
    
    // Filter out localhost and private IPs
    const isPrivateIp = clientIp === "127.0.0.1" || 
                       clientIp === "::1" ||
                       clientIp?.startsWith("192.168.") ||
                       clientIp?.startsWith("10.") ||
                       clientIp?.startsWith("172.16.") ||
                       clientIp?.startsWith("172.17.") ||
                       clientIp?.startsWith("172.18.") ||
                       clientIp?.startsWith("172.19.") ||
                       clientIp?.startsWith("172.20.") ||
                       clientIp?.startsWith("172.21.") ||
                       clientIp?.startsWith("172.22.") ||
                       clientIp?.startsWith("172.23.") ||
                       clientIp?.startsWith("172.24.") ||
                       clientIp?.startsWith("172.25.") ||
                       clientIp?.startsWith("172.26.") ||
                       clientIp?.startsWith("172.27.") ||
                       clientIp?.startsWith("172.28.") ||
                       clientIp?.startsWith("172.29.") ||
                       clientIp?.startsWith("172.30.") ||
                       clientIp?.startsWith("172.31.");
    
    // Always try ipapi.co to get city (and country as fallback)
    if (clientIp && !isPrivateIp) {
      try {
        const ipApiResponse = await fetch(`https://ipapi.co/${clientIp}/json/`, {
          headers: { "User-Agent": "Dabbler-App/1.0" },
        });
        
        if (ipApiResponse.ok) {
          const ipData = await ipApiResponse.json();
          // Get city from ipapi.co
          city = ipData.city || null;
          // Use country from ipapi.co if CF header is not available
          if (!countryCode || countryCode === "XX") {
            countryCode = ipData.country_code;
          }
          console.log("Data from ipapi.co - Country:", countryCode, ipData.country_name, "City:", city);
        } else {
          console.error("ipapi.co response not ok:", ipApiResponse.status, await ipApiResponse.text());
        }
      } catch (e) {
        console.error("ipapi.co lookup failed:", e);
      }
    } else {
      console.log("Skipping IP lookup - private/local IP detected:", clientIp);
    }

    // Log all headers for debugging
    console.log("All headers:", Object.fromEntries(req.headers.entries()));

    // Map country code to full country name
    const countryName = mapCountryCodeToName(countryCode);

    return new Response(
      JSON.stringify({ 
        country: countryName,
        city: city || null,
        countryCode: countryCode || "XX",
        debug: {
          cfCountry: req.headers.get("CF-IPCountry"),
          xForwardedFor: req.headers.get("X-Forwarded-For"),
          xRealIp: req.headers.get("X-Real-IP"),
          detectedFrom: countryCode ? (req.headers.get("CF-IPCountry") ? "CF-IPCountry" : "ipapi.co") : "fallback",
        }
      }),
      { 
        status: 200, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        } 
      }
    );
  } catch (error: unknown) {
    console.error("Error detecting country:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ 
        country: "Global",
        city: null,
        countryCode: "XX",
        error: errorMessage 
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" } 
      }
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
