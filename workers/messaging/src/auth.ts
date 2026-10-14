// D24 (RECOMMENDED, NOT YET CEO-APPROVED): bearer pass-through authorisation.
//
// The Worker forwards the caller's Authorization header UNCHANGED to rpc/msg_authorize. PostgREST verifies the
// token with the project's own key and auth.uid() comes from that verified token. The Worker trusts ONLY what
// the RPC returns. It never inspects the token's contents, never compares identities taken from it, never
// computes game lifecycle itself and keeps no authorisation state between requests: exactly one RPC call per
// authorised request.

import { Reason, deniedWithoutReason, reasonError, unauthenticated, upstreamError } from "./errors";

export interface Env {
  DB: D1Database;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SKELETON_PROBE?: string;
  /** KAN-510: shared HMAC key for POST /internal/system-line. Binding name only; no value in the repo. */
  MSG_SYSTEM_HMAC_SECRET?: string;
  /** off | allowlist | all. Code default 'allowlist'; the RPC denies any other value (fails closed). */
  MESSAGING_ACCESS_MODE?: string;
}

export const DEFAULT_ACCESS_MODE = "allowlist";

/** What the caller may do, exactly as msg_authorize said. */
export interface Grant {
  userId: string;
  action: "send" | "read";
  /** Set when action is 'read': the typed reason a send is refused with. */
  readOnlyReason: "left_read_only" | "game_ended" | null;
  /** Set when the caller left: history is visible up to and including this seq only. */
  leftAtSeq: number | null;
}

export type AuthOutcome = { ok: true; grant: Grant } | { ok: false; response: Response };

/**
 * The ONE place an msg_authorize reason becomes an API outcome. A follow-up changes one row.
 *   deny + reason      -> typed error, status from the contract table
 *   deny + status only -> that status with NO reason (client maps to unknown)
 *   readOnly           -> the RPC ALLOWED a read; a send is refused with this typed reason
 *
 * GAP (KAN-509, decision c): msg_authorize returns 'read_only' for BOTH an ended and a cancelled game, so the
 * Worker cannot tell them apart and maps both to game_ended. game_cancelled stays in the API contract.
 * Pending KAN follow-up: msg_authorize distinguishes cancelled; then only the read_only row changes.
 */
export type ReasonMapping =
  | { kind: "deny"; reason: Reason }
  | { kind: "deny"; status: 401 | 403 }
  | { kind: "readOnly"; reason: "left_read_only" | "game_ended" };

const RPC_REASONS: Record<string, ReasonMapping> = {
  not_authenticated: { kind: "deny", status: 401 },
  messaging_off: { kind: "deny", status: 403 },
  not_in_pilot: { kind: "deny", reason: "not_in_pilot" },
  not_member: { kind: "deny", reason: "not_a_member" },
  removed: { kind: "deny", reason: "removed" },
  left: { kind: "readOnly", reason: "left_read_only" },
  read_only: { kind: "readOnly", reason: "game_ended" },
};

/** Unknown reason strings deny with 403 and no reason. */
export function mapAuthorizeReason(rpcReason: string): ReasonMapping {
  return Object.prototype.hasOwnProperty.call(RPC_REASONS, rpcReason)
    ? RPC_REASONS[rpcReason]
    : { kind: "deny", status: 403 };
}

function denial(m: ReasonMapping): Response {
  if (m.kind === "deny" && "reason" in m) return reasonError(m.reason);
  if (m.kind === "deny") return m.status === 401 ? unauthenticated() : deniedWithoutReason();
  return upstreamError(502, "authorisation result malformed");
}

// Opaque shape check only: "Bearer <non-empty, no whitespace>". The token itself is never parsed.
const BEARER = /^Bearer [^\s]+$/;

const malformed = (): AuthOutcome => ({ ok: false, response: upstreamError(502, "authorisation result malformed") });

/**
 * msg_authorize (supabase/migrations/20261013150200_kan505_msg_functions.sql):
 *   request body : { "p_conversation_id": <uuid>, "p_access_mode": "off" | "allowlist" | "all" }
 *   response     : one row (PostgREST array, or a bare object) of
 *                  { user_id, allowed_action: 'send'|'read'|null, reason, left_at_seq, member_user_ids, hidden_sender_ids }
 */
export async function authorize(request: Request, env: Env, conversationId: string): Promise<AuthOutcome> {
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
      body: JSON.stringify({
        p_conversation_id: conversationId,
        p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE,
      }),
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
    return malformed();
  }
  const result = Array.isArray(parsed) ? (parsed.length === 1 ? parsed[0] : undefined) : parsed;
  if (result === null || typeof result !== "object") return malformed();
  const r = result as { user_id?: unknown; allowed_action?: unknown; reason?: unknown; left_at_seq?: unknown };

  if (r.allowed_action === null || r.allowed_action === undefined) {
    if (typeof r.reason !== "string") return malformed();
    const m = mapAuthorizeReason(r.reason);
    if (m.kind === "readOnly") return malformed(); // a read-only reason without an allowed read is incoherent
    return { ok: false, response: denial(m) };
  }

  if (typeof r.user_id !== "string" || r.user_id.length === 0) return malformed();

  if (r.allowed_action === "send") {
    if (r.reason !== null && r.reason !== undefined) return malformed();
    return { ok: true, grant: { userId: r.user_id, action: "send", readOnlyReason: null, leftAtSeq: null } };
  }

  if (r.allowed_action === "read") {
    if (typeof r.reason !== "string") return malformed();
    const m = mapAuthorizeReason(r.reason);
    if (m.kind !== "readOnly") return malformed();
    let leftAtSeq: number | null = null;
    if (m.reason === "left_read_only") {
      if (typeof r.left_at_seq !== "number" || !Number.isInteger(r.left_at_seq) || r.left_at_seq < 0) return malformed();
      leftAtSeq = r.left_at_seq;
    }
    return { ok: true, grant: { userId: r.user_id, action: "read", readOnlyReason: m.reason, leftAtSeq } };
  }

  return malformed();
}
