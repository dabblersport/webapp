// CORS for `detect-country` (KAN-640 R7). Kept free of Deno globals so it can be
// unit-tested without the edge runtime (see cors_test.ts).
//
// Native app requests carry no Origin header and are unaffected either way:
// CORS only gates browsers.

const ALLOWED_ORIGINS = new Set([
  "https://app.dabbler.pro",
  "https://canary.dabbler.pro",
  "https://alpha.dabbler.pro",
]);

// Cloudflare Pages previews of the webapp project
// (`https://<hash-or-branch>.webapp.pages.dev`, and the project host itself)
// and local builds (`http://localhost:<any port>`).
const ALLOWED_ORIGIN_PATTERNS = [
  /^https:\/\/([a-z0-9-]+\.)*webapp\.pages\.dev$/,
  /^http:\/\/localhost(:\d+)?$/,
];

export function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  return ALLOWED_ORIGINS.has(origin) ||
    ALLOWED_ORIGIN_PATTERNS.some((p) => p.test(origin));
}

/** Sent on EVERY response (success, error, 429 and the OPTIONS preflight). */
export function corsHeaders(req: Request): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  const origin = req.headers.get("Origin");
  if (origin && isAllowedOrigin(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}
