// KAN-563: GET /v1/games/{gameId}/conversation (docs/messaging/openapi.yaml getGameConversation).
// Authorisation is the database's: ONE round trip to msg_game_conversation (supabase/migrations/20261015130000_kan563_*.sql),
// with the caller's bearer unchanged. It resolves the game's conversation (creating the row on first use for an eligible
// member) and answers with msg_evaluate's verdict, the same evaluator msg_authorize uses. The Worker adds the typed-reason
// mapping, the per-user rate limit and last_seq from D1's conversation_seq. The user is auth.uid() inside the database;
// the only client value is the game id in the path. No message text is read. No logging.

import { Env, denial, hasBearer, mapAuthorizeReason } from "./auth";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { DEFAULT_ACCESS_MODE } from "./auth";
import { enforceGameConversation } from "./rate_limit";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const malformed = () => upstreamError(502, "conversation result malformed");

export async function getGameConversation(request: Request, env: Env, gameId: string): Promise<Response> {
  if (!UUID.test(gameId)) return reasonError("invalid_request", "gameId");
  if (!hasBearer(request)) return unauthenticated();
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(500, "authorisation not configured");

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_game_conversation`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: request.headers.get("Authorization") as string,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_game_id: gameId.toLowerCase(), p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE }),
    });
  } catch {
    return upstreamError(502, "conversation unavailable");
  }
  if (res.status === 401 || res.status === 403) return unauthenticated("token rejected");
  if (!res.ok) return upstreamError(502, "conversation failed");

  let parsed: unknown;
  try {
    parsed = await res.json();
  } catch {
    return malformed();
  }
  const row = Array.isArray(parsed) ? (parsed.length === 1 ? parsed[0] : undefined) : parsed;
  if (row === null || typeof row !== "object") return malformed();
  const r = row as {
    user_id?: unknown;
    conversation_id?: unknown;
    game_id?: unknown;
    allowed_action?: unknown;
    reason?: unknown;
    left_at_seq?: unknown;
    muted?: unknown;
  };

  if (r.allowed_action === null || r.allowed_action === undefined) {
    if (typeof r.reason !== "string") return malformed();
    if (r.reason === "not_found") return reasonError("not_found");
    if (r.reason === "suspended") return reasonError("suspended"); // the contract's account-level refusal; msg_evaluate has no such rule today
    const m = mapAuthorizeReason(r.reason);
    if (m.kind === "readOnly") return malformed();
    return denial(m);
  }

  if (typeof r.user_id !== "string" || r.user_id.length === 0) return malformed();
  if (typeof r.conversation_id !== "string" || !UUID.test(r.conversation_id)) return malformed();
  if (typeof r.game_id !== "string" || !UUID.test(r.game_id)) return malformed();
  if (typeof r.muted !== "boolean") return malformed();

  let writable = false;
  let readOnlyReason: "left_read_only" | "game_ended" | "game_cancelled" | null = null;
  let boundary: { kind: "left_at_seq"; seq: number } | null = null;
  let leftAtSeq: number | null = null;
  if (r.allowed_action === "send") {
    if (r.reason !== null && r.reason !== undefined) return malformed();
    writable = true;
  } else if (r.allowed_action === "read") {
    if (typeof r.reason !== "string") return malformed();
    const m = mapAuthorizeReason(r.reason);
    if (m.kind !== "readOnly" || (m.reason !== "left_read_only" && m.reason !== "game_ended" && m.reason !== "game_cancelled")) {
      return malformed();
    }
    readOnlyReason = m.reason;
    if (m.reason === "left_read_only") {
      if (typeof r.left_at_seq !== "number" || !Number.isInteger(r.left_at_seq) || r.left_at_seq < 0) return malformed();
      leftAtSeq = r.left_at_seq;
      boundary = { kind: "left_at_seq", seq: leftAtSeq };
    }
  } else {
    return malformed();
  }

  const limited = await enforceGameConversation(env.DB, r.user_id);
  if (limited !== null) return limited;

  // The highest seq the caller may view: the conversation's last seq, cut at the leave point for a member who left.
  const seqRow = await env.DB.prepare("SELECT last_seq FROM conversation_seq WHERE conversation_id = ?1")
    .bind(r.conversation_id.toLowerCase())
    .first<{ last_seq: number }>();
  const top = seqRow?.last_seq ?? 0;

  return ok({
    id: r.conversation_id.toLowerCase(),
    kind: "game",
    game_id: r.game_id.toLowerCase(),
    writable,
    read_only_reason: readOnlyReason,
    boundary,
    muted: r.muted,
    last_seq: leftAtSeq === null ? top : Math.min(top, leftAtSeq),
  });
}
