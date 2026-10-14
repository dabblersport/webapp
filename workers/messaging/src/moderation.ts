// KAN-513 (T18): audited moderator read of ONE reported message.
//
//   GET /v1/moderation/reports/{reportId}/message
//
// Moderator identity is decided by the project's EXISTING admin check, not by the Worker: public.is_admin()
// (role_grants admin / super_admin), the same predicate admin_resolve_report and v_mod_queue_open use. The
// caller's bearer token is forwarded UNCHANGED (D24); PostgREST verifies it. The Worker trusts only what these
// calls return and never reads the token. Three Supabase calls, in this order, and nothing is read before the
// first one says yes:
//   1. rpc/is_admin     -> true | false. false => typed refusal not_a_moderator, no text, no audit row.
//   2. rpc/admin_actor  -> the verified user id of the moderator (what the audit row records).
//   3. v_mod_queue_open -> the report's target (an admin-only view). No row => not_found.
// Then ONE D1 batch writes the audit row and reads the text, so a read that returns text always has exactly one
// audit row and a read that returns none has none.
//
// There is no list, search or batch variant and no timer-driven caller: one report id in, one message out.
// Message text is never logged and never put in a notification; this file has no logging at all.

import { Env } from "./auth";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";

export const MODERATION_PATH = /^\/v1\/moderation\/reports\/([^/]+)\/message$/;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BEARER = /^Bearer [^\s]+$/;

type Step<T> = { ok: true; value: T } | { ok: false; response: Response };

function headers(authorization: string, anonKey: string): Record<string, string> {
  return { apikey: anonKey, Authorization: authorization, "Content-Type": "application/json", Accept: "application/json" };
}

/** One call to Supabase with the caller's bearer. Maps transport and auth failures to the Worker's errors. */
async function supabase(url: string, init: RequestInit): Promise<Step<unknown>> {
  let res: Response;
  try {
    res = await fetch(url, init);
  } catch {
    return { ok: false, response: upstreamError(502, "moderation check unavailable") };
  }
  if (res.status === 401 || res.status === 403) return { ok: false, response: unauthenticated("token rejected") };
  if (!res.ok) return { ok: false, response: upstreamError(502, "moderation check failed") };
  try {
    return { ok: true, value: await res.json() };
  } catch {
    return { ok: false, response: upstreamError(502, "moderation check malformed") };
  }
}

const malformed = () => upstreamError(502, "moderation check malformed");

export interface ModeratorRead {
  id: string;
  conversation_id: string;
  seq: number;
  sender_id: string;
  body: string;
  created_at: string;
}

export async function readReportedMessage(request: Request, env: Env, reportId: string): Promise<Response> {
  if (!UUID.test(reportId)) return reasonError("invalid_request", "reportId");

  const authorization = request.headers.get("Authorization");
  if (authorization === null || !BEARER.test(authorization)) return unauthenticated();
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(500, "authorisation not configured");
  const h = headers(authorization, env.SUPABASE_ANON_KEY);

  // 1. Is the caller a moderator? The existing admin predicate answers; the Worker does not.
  const admin = await supabase(`${env.SUPABASE_URL}/rest/v1/rpc/is_admin`, { method: "POST", headers: h, body: "{}" });
  if (!admin.ok) return admin.response;
  if (typeof admin.value !== "boolean") return malformed();
  if (!admin.value) return reasonError("not_a_moderator"); // no further call, no D1 access, no text

  // 2. Who is the moderator? The verified id the database returns (what the audit row records).
  const actor = await supabase(`${env.SUPABASE_URL}/rest/v1/rpc/admin_actor`, { method: "POST", headers: h, body: "{}" });
  if (!actor.ok) return actor.response;
  if (typeof actor.value !== "string" || actor.value.length === 0) return malformed();
  const moderatorId = actor.value;

  // 3. What did the report point at? v_mod_queue_open is gated by is_admin(auth.uid()); open/triage/escalated only.
  const query = `report_id=eq.${reportId}&select=report_id,target_type,target_id`;
  const target = await supabase(`${env.SUPABASE_URL}/rest/v1/v_mod_queue_open?${query}`, { method: "GET", headers: h });
  if (!target.ok) return target.response;
  if (!Array.isArray(target.value)) return malformed();
  if (target.value.length === 0) return reasonError("not_found");
  if (target.value.length !== 1) return malformed();
  const row = target.value[0] as { report_id?: unknown; target_type?: unknown; target_id?: unknown };
  if (row === null || typeof row !== "object" || row.report_id !== reportId.toLowerCase()) return malformed();
  if (row.target_type !== "message") return reasonError("invalid_request", "target_type"); // not a message report
  if (typeof row.target_id !== "string" || !UUID.test(row.target_id)) return malformed();
  const messageId = row.target_id;

  // 4. One atomic D1 batch: the audit row (ids and a timestamp, no text) is written only if the message exists,
  //    and the text is read in the same transaction.
  const readAt = new Date().toISOString();
  const audit = env.DB.prepare(
    `INSERT INTO moderator_reads (id, moderator_id, report_id, message_id, read_at)
       SELECT ?1, ?2, ?3, ?4, ?5 WHERE EXISTS (SELECT 1 FROM messages WHERE id = ?4)`,
  ).bind(crypto.randomUUID(), moderatorId, reportId.toLowerCase(), messageId, readAt);
  const read = env.DB.prepare(
    "SELECT id, conversation_id, seq, sender_id, body, created_at FROM messages WHERE id = ?1",
  ).bind(messageId);
  const results = await env.DB.batch([audit, read]);
  const message = (results[1].results as ModeratorRead[])[0];
  if (!message) return reasonError("not_found");

  const res = ok({
    report_id: reportId.toLowerCase(),
    message: {
      id: message.id,
      conversation_id: message.conversation_id,
      seq: message.seq,
      sender_user_id: message.sender_id,
      kind: "text",
      body: message.body,
      created_at: message.created_at,
    },
  });
  res.headers.set("Cache-Control", "no-store");
  return res;
}
