// KAN-561: start a DM and mute a conversation. Authorisation is the database's: the caller's bearer goes UNCHANGED to
// msg_start_dm / msg_set_muted, which take the user from auth.uid() (KAN-560). The Worker adds only the pass-through,
// the typed-reason mapping and the start-DM rate limit. The only client-supplied user id is other_user_id. No logging.
//
//   POST /v1/dm                          { other_user_id }  -> 200 { conversation_id }   (the existing id for an existing pair)
//   POST /v1/conversations/{id}/mute     { muted }          -> 200 { muted }
//   PUT / DELETE /v1/conversations/{id}/mute                -> 204 (KAN-563, the contract's mute / unmute)

import { DEFAULT_ACCESS_MODE, Env, denial, mapAuthorizeReason, resolveCaller } from "./auth";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { enforceMute, enforceNewDm } from "./rate_limit";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The database's typed refusals (the exception message of msg_start_dm / msg_set_muted) as API responses. */
function databaseRefusal(message: string): Response | null {
  switch (message) {
    case "not_authenticated":
      return unauthenticated("token rejected");
    case "invalid_request":
      return reasonError("invalid_request");
    case "blocked":
      return reasonError("blocked"); // either direction; the database does not say which
    case "age_restricted":
      // No existing reason names an age rule; not_in_pilot is the "unavailable" screen and tells nothing about age.
      return reasonError("not_in_pilot");
    case "not_found":
      return reasonError("not_found"); // the other user is deleted or banned
    case "rate_limited":
      return reasonError("dm_cap_reached"); // the database's daily cap on NEW DMs
    case "not_member":
      return reasonError("not_a_member");
    default:
      return null;
  }
}

async function rpcFailure(res: Response): Promise<Response> {
  if (res.status === 401) return unauthenticated("token rejected");
  let message = "";
  try {
    const body = (await res.json()) as { message?: unknown };
    if (body !== null && typeof body === "object" && typeof body.message === "string") message = body.message;
  } catch {
    // not JSON: an upstream failure
  }
  return databaseRefusal(message) ?? upstreamError(502, "request failed");
}

/**
 * True when the caller and `other` already have a DM pair, asked of the database itself (msg_dm_exists, KAN-561: it
 * sees an EMPTY pair the other user started and a pair older than any list cap). Re-opening an existing pair must not
 * count toward the new-DM limit. Fails OPEN for this second-line limiter: when the database cannot answer (for example
 * the function is not applied yet) the start is not charged, and the database's own daily cap still decides.
 */
async function hasExistingDm(request: Request, env: Env, other: string): Promise<boolean> {
  try {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_dm_exists`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: request.headers.get("Authorization") as string,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_other_user: other.toLowerCase() }),
    });
    if (!res.ok) return true;
    return (await res.json()) !== false;
  } catch {
    return true;
  }
}

export async function startDm(request: Request, env: Env): Promise<Response> {
  let input: { other_user_id?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  const other = input !== null && typeof input === "object" ? input.other_user_id : undefined;
  if (typeof other !== "string" || !UUID.test(other)) return reasonError("invalid_request", "other_user_id");

  const caller = await resolveCaller(request, env); // the verified user id, from the database
  if (!caller.ok) return caller.response;
  if (other.toLowerCase() === caller.userId.toLowerCase()) return reasonError("invalid_request", "self");

  // Only a NEW pair counts: an existing one is re-opened freely (the database still applies every block/age rule).
  if (!(await hasExistingDm(request, env, other))) {
    const limited = await enforceNewDm(env.DB, caller.userId); // one small D1 write
    if (limited !== null) return limited;
  }

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_start_dm`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: request.headers.get("Authorization") as string,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_other_user: other.toLowerCase() }),
    });
  } catch {
    return upstreamError(502, "request unavailable");
  }
  if (!res.ok) return rpcFailure(res);
  let id: unknown;
  try {
    id = await res.json();
  } catch {
    return upstreamError(502, "result malformed");
  }
  if (typeof id !== "string" || !UUID.test(id)) return upstreamError(502, "result malformed");
  return ok({ conversation_id: id.toLowerCase() });
}

/** msg_set_muted with the caller's own bearer. null on success, otherwise the typed failure response. */
async function callSetMuted(authorization: string, env: Env, conversationId: string, muted: boolean): Promise<Response | null> {
  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_set_muted`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_conversation_id: conversationId.toLowerCase(), p_muted: muted }),
    });
  } catch {
    return upstreamError(502, "request unavailable");
  }
  return res.ok ? null : rpcFailure(res);
}

export async function setMuted(request: Request, env: Env, conversationId: string): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  let input: { muted?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  const muted = input !== null && typeof input === "object" ? input.muted : undefined;
  if (typeof muted !== "boolean") return reasonError("invalid_request", "muted");
  const authorization = request.headers.get("Authorization");
  if (authorization === null || !/^Bearer [^\s]+$/.test(authorization)) return unauthenticated();
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(500, "authorisation not configured");

  const failure = await callSetMuted(authorization, env, conversationId, muted);
  if (failure !== null) return failure;
  return ok({ muted });
}

/**
 * KAN-563: the contract's muteConversation (PUT) and unmuteConversation (DELETE): 204, no body, idempotent. ONE database
 * round trip: msg_mute_conversation (supabase/migrations/20261015130000_kan563_*.sql) takes the user from auth.uid() with
 * the caller's bearer, applies msg_evaluate's verdict (the pilot rule included) and writes the flag, returning the verified
 * user id or the typed reason. The rate limit (one D1 write) is keyed by that returned id and checked after the call; the
 * write is an idempotent flag, so a 429 that follows it leaves nothing harmful behind.
 */
export async function muteConversation(request: Request, env: Env, conversationId: string, muted: boolean): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  const authorization = request.headers.get("Authorization");
  if (authorization === null || !/^Bearer [^\s]+$/.test(authorization)) return unauthenticated();
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(500, "authorisation not configured");

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_mute_conversation`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        p_conversation_id: conversationId.toLowerCase(),
        p_muted: muted,
        p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE,
      }),
    });
  } catch {
    return upstreamError(502, "request unavailable");
  }
  if (res.status === 401 || res.status === 403) return unauthenticated("token rejected");
  if (!res.ok) return upstreamError(502, "request failed");

  let parsed: unknown;
  try {
    parsed = await res.json();
  } catch {
    return upstreamError(502, "result malformed");
  }
  const row = Array.isArray(parsed) ? (parsed.length === 1 ? parsed[0] : undefined) : parsed;
  if (row === null || typeof row !== "object") return upstreamError(502, "result malformed");
  const r = row as { user_id?: unknown; reason?: unknown };

  if (r.reason !== null && r.reason !== undefined) {
    if (typeof r.reason !== "string") return upstreamError(502, "result malformed");
    if (r.reason === "invalid_request" || r.reason === "not_found" || r.reason === "suspended") return reasonError(r.reason);
    const m = mapAuthorizeReason(r.reason);
    if (m.kind === "readOnly") return upstreamError(502, "result malformed");
    return denial(m);
  }
  if (typeof r.user_id !== "string" || r.user_id.length === 0) return upstreamError(502, "result malformed");

  const limited = await enforceMute(env.DB, r.user_id);
  if (limited !== null) return limited;
  return new Response(null, { status: 204 });
}
