// KAN-563: GET /v1/games/{gameId}/conversation (docs/messaging/openapi.yaml getGameConversation).
//
// ONE database call: msg_game_conversation (supabase/migrations/20261017120000_kan563_msg_game_conversation.sql) with
// the caller's bearer UNCHANGED. It derives the user from the verified token, resolves the game's conversation
// (creating the registry row only for a caller with a roster row), and returns msg_evaluate's verdict unchanged. The
// Worker re-implements no authorisation: it maps the reason and builds the contract's Conversation. The only other
// reads are D1: the conversation's newest seq (conversation_seq, one primary-key row; no message is read) and the
// per-user limit row. No message text is read. No logging.

import { Env, accessMode, hasBearer } from "./auth";
import { Reason, deniedWithoutReason, ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { enforceConversationOps } from "./rate_limit";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Denials (allowed_action null) as the contract's typed reasons. Anything else: 403 with no reason. */
const DENY: Record<string, Reason> = {
  not_in_pilot: "not_in_pilot",
  not_member: "not_a_member",
  removed: "removed",
  suspended: "suspended",
  not_found: "not_found",
};

/** Read-only verdicts (allowed_action 'read') as the contract's read_only_reason. */
const READ_ONLY: Record<string, "left_read_only" | "game_ended" | "game_cancelled"> = {
  left: "left_read_only",
  game_ended: "game_ended",
  game_cancelled: "game_cancelled",
};

const malformed = () => upstreamError(502, "result malformed");

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
      body: JSON.stringify({ p_game_id: gameId.toLowerCase(), p_access_mode: accessMode(env) }),
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
    if (r.reason === "not_authenticated") return unauthenticated();
    if (typeof r.reason !== "string") return malformed();
    const reason = Object.prototype.hasOwnProperty.call(DENY, r.reason) ? DENY[r.reason] : null;
    return reason === null ? deniedWithoutReason() : reasonError(reason);
  }

  if (typeof r.user_id !== "string" || r.user_id.length === 0) return malformed();
  if (typeof r.conversation_id !== "string" || !UUID.test(r.conversation_id)) return malformed();
  if (typeof r.muted !== "boolean") return malformed();

  let writable: boolean;
  let readOnlyReason: "left_read_only" | "game_ended" | "game_cancelled" | null = null;
  let leftAtSeq: number | null = null;
  if (r.allowed_action === "send") {
    if (r.reason !== null && r.reason !== undefined) return malformed();
    writable = true;
  } else if (r.allowed_action === "read") {
    if (typeof r.reason !== "string" || !Object.prototype.hasOwnProperty.call(READ_ONLY, r.reason)) return malformed();
    readOnlyReason = READ_ONLY[r.reason];
    writable = false;
    if (readOnlyReason === "left_read_only") {
      if (typeof r.left_at_seq !== "number" || !Number.isInteger(r.left_at_seq) || r.left_at_seq < 0) return malformed();
      leftAtSeq = r.left_at_seq;
    }
  } else {
    return malformed();
  }

  // Idempotent read-or-create: the limit runs after the database call, keyed by the verified id it returned.
  const limited = await enforceConversationOps(env.DB, r.user_id);
  if (limited !== null) return limited;

  const conversationId = r.conversation_id.toLowerCase();
  const seqRow = await env.DB.prepare("SELECT last_seq FROM conversation_seq WHERE conversation_id = ?1")
    .bind(conversationId)
    .first<{ last_seq: number }>();
  const newest = seqRow?.last_seq ?? 0;

  return ok({
    id: conversationId,
    kind: "game",
    game_id: gameId.toLowerCase(),
    writable,
    read_only_reason: readOnlyReason,
    boundary: leftAtSeq === null ? null : { kind: "left_at_seq", seq: leftAtSeq },
    muted: r.muted,
    last_seq: leftAtSeq === null ? newest : Math.min(newest, leftAtSeq),
  });
}
