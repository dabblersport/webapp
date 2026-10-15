// KAN-561: GET /v1/conversations/summary?ids=<up to 50 ids>: the time of the last message per conversation, for the
// Messages list. Per id it returns conversation_id, last_message_at and last_message_from_me and NOTHING else: no
// text, no sender id, no counts.
//
// Which ids the caller may read: the database's own list (msg_my_conversations, one call, the caller's bearer passed
// through unchanged). An id that is not in that list is omitted silently, as is a conversation the caller has left
// (what they may still read there depends on a cut-off the list does not carry, so nothing is said about it).
// last_message_at / last_message_from_me come from ONE bounded D1 read of the newest user message per conversation
// (system lines are not messages). last_message_from_me compares the stored sender with the caller's verified id.
// Subrequests: msg_authorize (the verified id) + msg_my_conversations. D1 writes: none. No logging.

import { Env, resolveCaller } from "./auth";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { SYSTEM_SENDER } from "./system_line";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const MAX_SUMMARY_IDS = 50;
const LIST_LIMIT = 100; // the database's own cap on the list

export async function conversationSummary(request: Request, env: Env, url: URL): Promise<Response> {
  const raw = url.searchParams.get("ids") ?? "";
  const ids = [...new Set(raw.split(",").map((s) => s.trim().toLowerCase()).filter((s) => s.length > 0))];
  if (ids.length === 0 || ids.length > MAX_SUMMARY_IDS || !ids.every((id) => UUID.test(id))) {
    return reasonError("invalid_request", "ids");
  }

  const caller = await resolveCaller(request, env);
  if (!caller.ok) return caller.response;

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_my_conversations`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: request.headers.get("Authorization") as string,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ p_limit: LIST_LIMIT }),
    });
  } catch {
    return upstreamError(502, "list unavailable");
  }
  if (res.status === 401) return unauthenticated("token rejected");
  if (!res.ok) return upstreamError(502, "list failed");
  let rows: unknown;
  try {
    rows = await res.json();
  } catch {
    return upstreamError(502, "list malformed");
  }
  if (!Array.isArray(rows)) return upstreamError(502, "list malformed");

  const wanted = new Set(ids);
  const readable: string[] = [];
  for (const row of rows) {
    if (row === null || typeof row !== "object") continue;
    const r = row as { conversation_id?: unknown; state?: unknown };
    if (typeof r.conversation_id !== "string" || r.state === "left") continue;
    const id = r.conversation_id.toLowerCase();
    if (wanted.has(id) && !readable.includes(id)) readable.push(id);
  }
  if (readable.length === 0) return ok({ summaries: [] });

  // The newest user message of each readable conversation: one statement, at most 50 bound ids.
  const marks = readable.map((_, i) => `?${i + 2}`).join(", ");
  const result = await env.DB.prepare(
    `SELECT m.conversation_id, m.created_at, m.sender_id
       FROM messages m
       JOIN (SELECT conversation_id, MAX(seq) AS top FROM messages
              WHERE sender_id <> ?1 AND conversation_id IN (${marks}) GROUP BY conversation_id) x
         ON x.conversation_id = m.conversation_id AND x.top = m.seq`,
  )
    .bind(SYSTEM_SENDER, ...readable)
    .all<{ conversation_id: string; created_at: string; sender_id: string }>();

  const last = new Map<string, { at: string; mine: boolean }>();
  for (const row of result.results) {
    last.set(row.conversation_id.toLowerCase(), {
      at: row.created_at,
      mine: row.sender_id.toLowerCase() === caller.userId.toLowerCase(),
    });
  }
  return ok({
    summaries: readable.map((id) => ({
      conversation_id: id,
      last_message_at: last.get(id)?.at ?? null,
      last_message_from_me: last.get(id)?.mine ?? false,
    })),
  });
}
