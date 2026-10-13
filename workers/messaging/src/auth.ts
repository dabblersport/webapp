// D24 (RECOMMENDED, NOT YET CEO-APPROVED): bearer pass-through authorisation.
//
// The Worker forwards the caller's Authorization header UNCHANGED to rpc/msg_authorize. PostgREST verifies the
// token with the project's own key and auth.uid() comes from that verified token. The Worker trusts ONLY the
// user_id the RPC returns. It never inspects the token's contents, never compares identities taken from it and
// keeps no authorisation state between requests: exactly one RPC call per authorised request.

import { Reason, deniedWithoutReason, isReason, reasonError, unauthenticated, upstreamError } from "./errors";

export interface Env {
  DB: D1Database;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SKELETON_PROBE?: string;
}

export type AuthAction = "read" | "send";

export type AuthOutcome =
  | { ok: true; userId: string }
  | { ok: false; response: Response };

// Opaque shape check only: "Bearer <non-empty, no whitespace>". The token itself is never parsed.
const BEARER = /^Bearer [^\s]+$/;

/**
 * ASSUMED msg_authorize contract (T8 owns the real function; not yet in supabase/migrations at Alpha b6ccff1a):
 *   request body : { "p_conversation_id": <uuid>, "p_action": "read" | "send" }
 *   response     : { "user_id": <uuid>, "allowed": boolean, "reason"?: <T7 Reason> }  (or a one-element array of it)
 * Kept in this one function so T8 can change it in one place.
 */
export async function authorize(
  request: Request,
  env: Env,
  conversationId: string,
  action: AuthAction,
): Promise<AuthOutcome> {
  const authorization = request.headers.get("Authorization");
  if (authorization === null || !BEARER.test(authorization)) {
    return { ok: false, response: unauthenticated() };
  }
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) {
    return { ok: false, response: upstreamError(500, "authorisation not configured") };
  }

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_authorize`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_conversation_id: conversationId, p_action: action }),
    });
  } catch {
    return { ok: false, response: upstreamError(502, "authorisation unavailable") };
  }

  if (res.status === 401 || res.status === 403) {
    return { ok: false, response: unauthenticated("token rejected") };
  }
  if (!res.ok) {
    return { ok: false, response: upstreamError(502, "authorisation failed") };
  }

  let parsed: unknown;
  try {
    parsed = await res.json();
  } catch {
    return { ok: false, response: upstreamError(502, "authorisation result malformed") };
  }
  const result = Array.isArray(parsed) ? (parsed.length === 1 ? parsed[0] : undefined) : parsed;
  if (result === null || typeof result !== "object") {
    return { ok: false, response: upstreamError(502, "authorisation result malformed") };
  }
  const r = result as { user_id?: unknown; allowed?: unknown; reason?: unknown };

  if (r.allowed !== true) {
    if (r.allowed === false) {
      if (isReason(r.reason)) return { ok: false, response: reasonError(r.reason as Reason) };
      return { ok: false, response: deniedWithoutReason() };
    }
    return { ok: false, response: upstreamError(502, "authorisation result malformed") };
  }
  if (typeof r.user_id !== "string" || r.user_id.length === 0) {
    return { ok: false, response: upstreamError(502, "authorisation result malformed") };
  }
  return { ok: true, userId: r.user_id };
}
