// KAN-538: exact-match CORS origin allowlist for the public /v1/ routes, so the web app can call the Worker.
// Not secret; this constant is the one place the list lives. Exact string match only: no wildcard, no pattern, no
// subdomain rule. No credentials header (the app sends a bearer token, not cookies). /health and /internal/* never
// get CORS handling: /internal/system-line is called by the database, not by a browser.

export const CORS_ALLOWED_ORIGINS: readonly string[] = ["https://canary.dabbler.pro", "https://alpha.dabbler.pro"];

export const CORS_ALLOWED_METHODS = "GET, POST, OPTIONS";
export const CORS_ALLOWED_HEADERS = "Authorization, Content-Type, Idempotency-Key";
const PREFLIGHT_MAX_AGE_SECONDS = "86400";

/** True only for the public API: /v1 and everything below it. */
export function isPublicApiPath(pathname: string): boolean {
  return pathname === "/v1" || pathname.startsWith("/v1/");
}

/** The request's Origin when it is exactly one of the allowed origins, otherwise null. */
export function allowedOrigin(request: Request): string | null {
  const origin = request.headers.get("Origin");
  return origin !== null && CORS_ALLOWED_ORIGINS.includes(origin) ? origin : null;
}

/**
 * The answer to a preflight (OPTIONS) from an allowed origin on a /v1/ route; null for anything else, so an
 * unlisted origin, a non-/v1 path or a non-OPTIONS request falls through to the normal routing and gets no CORS
 * headers.
 */
export function preflightResponse(request: Request, pathname: string): Response | null {
  if (request.method !== "OPTIONS" || !isPublicApiPath(pathname)) return null;
  const origin = allowedOrigin(request);
  if (origin === null) return null;
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": CORS_ALLOWED_METHODS,
      "Access-Control-Allow-Headers": CORS_ALLOWED_HEADERS,
      "Access-Control-Max-Age": PREFLIGHT_MAX_AGE_SECONDS,
      Vary: "Origin",
    },
  });
}

/**
 * Adds the allow-origin header to a /v1/ response for an allowed origin. Every /v1/ response carries
 * `Vary: Origin` so a cache never serves one origin's answer to another. Other paths are returned untouched.
 */
export function withCors(request: Request, pathname: string, response: Response): Response {
  if (!isPublicApiPath(pathname)) return response;
  const out = new Response(response.body, response);
  out.headers.append("Vary", "Origin");
  const origin = allowedOrigin(request);
  if (origin !== null) out.headers.set("Access-Control-Allow-Origin", origin);
  return out;
}
