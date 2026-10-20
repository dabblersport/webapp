// KAN-579: ephemeral typing presence. POST /v1/conversations/{id}/typing  {"typing": true|false}  ->  204.
//
// NOTHING IS STORED. No D1 write, no message row, no push notification: the Worker checks that the caller may send in
// the conversation now (msg_authorize, so a removed, left or blocked member is refused with its typed reason), then asks
// Supabase to fan the signal out (public.msg_typing, which re-checks membership and picks the recipients from the
// caller's own identity). The Worker holds no elevated key: the caller's Authorization is forwarded UNCHANGED, with the
// anon key as `apikey`, exactly as notify.ts does.
//
// PRIVACY. The only data that moves are ids and one boolean. The request body is read for that boolean and dropped.
// Nothing here logs: the KAN-513 guard (t18) forbids any console call in src, and no token, header or body is kept.
//
// THROTTLE. The app sends at most one "typing" every few seconds per conversation (lib/features/messaging, KAN-579).
// This route keeps no counter of its own: the KAN-548 limiter writes a D1 row per call, which a signal every few seconds
// would turn into most of the free-tier write budget, and the static guard (test/static_guard.test.ts) forbids an
// in-isolate cache. A client that ignores its throttle is bounded by the authorisation call each request costs and by
// Supabase Realtime's own per-project message rate; that residual risk is stated in the README.

import { DEFAULT_ACCESS_MODE, Env, authorize } from "./auth";
import { reasonError } from "./errors";
import type { WaitUntilContext } from "./notify";

export const TYPING_PATH = /^\/v1\/conversations\/([^/]+)\/typing$/;
const TYPING_TIMEOUT_MS = 5000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Asks Supabase to fan the signal out. Returns the status, or null when the call could not be made. Never throws. */
export async function sendTyping(env: Env, authorization: string, conversationId: string, typing: boolean): Promise<number | null> {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  try {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_typing`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        p_conversation_id: conversationId,
        p_typing: typing,
        p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE,
      }),
      signal: AbortSignal.timeout(TYPING_TIMEOUT_MS),
    });
    return res.status;
  } catch {
    return null; // network error or timeout: swallowed, the signal is a hint
  }
}

export async function handleTyping(
  request: Request,
  env: Env,
  conversationId: string,
  ctx?: WaitUntilContext,
): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  let input: { typing?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  if (input === null || typeof input !== "object" || typeof input.typing !== "boolean") {
    return reasonError("invalid_request", "typing");
  }
  const typing = input.typing;

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response; // membership is checked here; nothing is sent for a non-member
  // A closed game, a left member, a blocked DM: the RPC allowed only a read, so nobody is told they are typing.
  if (auth.grant.action !== "send") return reasonError(auth.grant.readOnlyReason ?? "invalid_request");

  const authorization = request.headers.get("Authorization");
  if (ctx && authorization !== null) {
    ctx.waitUntil(sendTyping(env, authorization, conversationId, typing));
  }
  return new Response(null, { status: 204 });
}
