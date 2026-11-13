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
  /** KAN-580: used ONLY by the sender-only receipt recipients route (src/receipt_reads.ts). Binding name only; the value
   *  is set by operations as a Worker secret, never in the repo. Absent = that route answers 503. */
  SUPABASE_SERVICE_KEY?: string;
  SKELETON_PROBE?: string;
  /** KAN-510: shared HMAC key for POST /internal/system-line. Binding name only; no value in the repo. */
  MSG_SYSTEM_HMAC_SECRET?: string;
  /** off | allowlist | all. Dashboard-only. Absent, empty or any other value = 'off' (accessMode(), fails closed). */
  MESSAGING_ACCESS_MODE?: string;
  /** KAN-581: the PRIVATE R2 bucket for message images (binding MEDIA). Absent until operations provision it; every
   *  attachment route then answers 503. See docs/messaging/images-kan581.md. */
  MEDIA?: R2Bucket;
  /** KAN-581: upload kill switch (the control the architecture draft names). 'off' refuses NEW uploads with 503; reads and
   *  everything else keep working. Absent or any other value = on. Edited in the dashboard like MESSAGING_ACCESS_MODE. */
  MESSAGING_UPLOADS?: string;
}

export type AccessMode = "off" | "allowlist" | "all";

/**
 * KAN-625: the ONE place the access mode is derived. MESSAGING_ACCESS_MODE is changed only by an admin in the Cloudflare
 * dashboard (Worker variable); nothing in this Worker or the app writes it. Fail closed: a value that is absent, empty or
 * not exactly off|allowlist|all (case-sensitive) is treated as 'off'.
 */
export function accessMode(env: Env): AccessMode {
  const v = env.MESSAGING_ACCESS_MODE;
  return v === "off" || v === "allowlist" || v === "all" ? v : "off";
}

/** What the caller may do, exactly as msg_authorize said. */
export interface Grant {
  userId: string;
  action: "send" | "read";
  /** Set when action is 'read': the typed reason a send is refused with. */
  readOnlyReason: "left_read_only" | "game_ended" | "game_cancelled" | "blocked" | "suspended" | null;
  /** Set when the caller left: history is visible up to and including this seq only. */
  leftAtSeq: number | null;
  /** D4 group rule (KAN-512): senders the CALLER blocked (user_blocks only). Their messages are omitted from the
   *  caller's own list. Empty when the caller blocked nobody. Never another user's blocks. */
  hiddenSenderIds: string[];
  /** KAN-580: the conversation's current members exactly as msg_authorize returned them (may include the caller).
   *  Empty when the RPC sent none. Used only by the sender-only receipts route. */
  memberUserIds: string[];
}

export type AuthOutcome = { ok: true; grant: Grant } | { ok: false; response: Response };

/**
 * The ONE place an msg_authorize reason becomes an API outcome. A follow-up changes one row.
 *   deny + reason      -> typed error, status from the contract table
 *   deny + status only -> that status with NO reason (client maps to unknown)
 *   readOnly           -> the RPC ALLOWED a read; a send is refused with this typed reason
 *
 * msg_authorize now distinguishes an ended game (game_ended) from a cancelled one (game_cancelled), so both pass through unchanged.
 */
export type ReasonMapping =
  | { kind: "deny"; reason: Reason }
  | { kind: "deny"; status: 401 | 403 }
  | { kind: "readOnly"; reason: "left_read_only" | "game_ended" | "game_cancelled" | "blocked" | "suspended" };

const RPC_REASONS: Record<string, ReasonMapping> = {
  not_authenticated: { kind: "deny", status: 401 },
  messaging_off: { kind: "deny", status: 403 },
  not_in_pilot: { kind: "deny", reason: "not_in_pilot" },
  not_member: { kind: "deny", reason: "not_a_member" },
  removed: { kind: "deny", reason: "removed" },
  left: { kind: "readOnly", reason: "left_read_only" },
  game_ended: { kind: "readOnly", reason: "game_ended" },
  game_cancelled: { kind: "readOnly", reason: "game_cancelled" },
  // KAN-561: a DM is read-only for BOTH users when either blocked the other (blocked) or the counterpart is deleted or
  // banned (suspended). Game chats never return these.
  blocked: { kind: "readOnly", reason: "blocked" },
  suspended: { kind: "readOnly", reason: "suspended" },
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

/** Opaque shape check only, for routes that must reject an unauthenticated call before touching D1. */
export function hasBearer(request: Request): boolean {
  const a = request.headers.get("Authorization");
  return a !== null && BEARER.test(a);
}

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
        p_access_mode: accessMode(env),
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
  const r = result as {
    user_id?: unknown;
    allowed_action?: unknown;
    reason?: unknown;
    left_at_seq?: unknown;
    hidden_sender_ids?: unknown;
    member_user_ids?: unknown;
  };

  if (r.allowed_action === null || r.allowed_action === undefined) {
    if (typeof r.reason !== "string") return malformed();
    const m = mapAuthorizeReason(r.reason);
    if (m.kind === "readOnly") return malformed(); // a read-only reason without an allowed read is incoherent
    return { ok: false, response: denial(m) };
  }

  if (typeof r.user_id !== "string" || r.user_id.length === 0) return malformed();
  // null/absent means "blocked nobody"; anything else that is not a string array is incoherent (fails closed).
  let hiddenSenderIds: string[] = [];
  if (r.hidden_sender_ids !== null && r.hidden_sender_ids !== undefined) {
    if (!Array.isArray(r.hidden_sender_ids) || !r.hidden_sender_ids.every((x) => typeof x === "string")) return malformed();
    hiddenSenderIds = r.hidden_sender_ids as string[];
  }

  let memberUserIds: string[] = [];
  if (Array.isArray(r.member_user_ids) && r.member_user_ids.every((x) => typeof x === "string")) {
    memberUserIds = r.member_user_ids as string[];
  }

  if (r.allowed_action === "send") {
    if (r.reason !== null && r.reason !== undefined) return malformed();
    return { ok: true, grant: { userId: r.user_id, action: "send", readOnlyReason: null, leftAtSeq: null, hiddenSenderIds, memberUserIds } };
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
    return { ok: true, grant: { userId: r.user_id, action: "read", readOnlyReason: m.reason, leftAtSeq, hiddenSenderIds, memberUserIds } };
  }

  return malformed();
}


/** A conversation id no row can have: msg_authorize answers it with the caller's verified id and not_member. */
const NIL_CONVERSATION = "00000000-0000-0000-0000-000000000000";

export type CallerOutcome = { ok: true; userId: string } | { ok: false; response: Response };

/**
 * KAN-561: the verified user id of the caller, for routes that have no conversation yet (start a DM). Same pass-through
 * as authorize(): the bearer goes unchanged to msg_authorize, which derives the id from the verified token. The nil
 * conversation yields the id with reason not_member; messaging_off and not_in_pilot are refused exactly as they are
 * everywhere else. Nothing about the token is read here.
 */
export async function resolveCaller(request: Request, env: Env): Promise<CallerOutcome> {
  const authorization = request.headers.get("Authorization");
  if (authorization === null || !BEARER.test(authorization)) return { ok: false, response: unauthenticated() };
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
        p_conversation_id: NIL_CONVERSATION,
        p_access_mode: accessMode(env),
      }),
    });
  } catch {
    return { ok: false, response: upstreamError(502, "authorisation unavailable") };
  }
  if (res.status === 401 || res.status === 403) return { ok: false, response: unauthenticated("token rejected") };
  if (!res.ok) return { ok: false, response: upstreamError(502, "authorisation failed") };
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
  const r = result as { user_id?: unknown; reason?: unknown };
  if (r.reason === "messaging_off" || r.reason === "not_in_pilot" || r.reason === "not_authenticated") {
    return { ok: false, response: denial(mapAuthorizeReason(r.reason)) };
  }
  if (typeof r.user_id !== "string" || r.user_id.length === 0) return { ok: false, response: unauthenticated() };
  return { ok: true, userId: r.user_id };
}
