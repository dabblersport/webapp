// KAN-561: GET /v1/conversations/summary?ids=<up to 50 ids>: the time of the last message per conversation, for the
// Messages list. Per id it returns conversation_id, last_message_at and last_message_from_me and NOTHING else: no
// text, no sender id, no counts.
//
// Which ids the caller may read: the database's own list (msg_my_conversations, one call, the caller's bearer passed
// through unchanged). An id that is not in that list is omitted silently, as is a conversation the caller has left
// (what they may still read there depends on a cut-off the list does not carry, so nothing is said about it).
//
// D4 (blocked counterpart): a DM whose list state is 'read_only' is a DM with a block in either direction or an
// unavailable counterpart. For each of those the Worker asks msg_authorize (the caller's bearer, same call as every
// other route) for the caller's hidden_sender_ids; a counterpart the CALLER blocked is excluded from that
// conversation's "last message", so the blocker's summary never shows the blocked person's activity. At most
// MAX_BLOCK_LOOKUPS such lookups are made per request (the subrequest budget); a read_only DM past the budget, or whose
// lookup fails, is omitted (fails closed).
//
// BOUNDED READ: one D1 statement. Per conversation it reads one conversation_seq row (primary key, the newest seq) and
// then an index range scan on UNIQUE (conversation_id, seq) over only the newest LOOKBACK_MESSAGES sequence numbers,
// keeping the newest message that is not a system line and not from a hidden sender. So a request reads at most about
// 50 x (LOOKBACK_MESSAGES + 1) rows whatever the history length (the window, not the history, is what is scanned).
// A conversation with nothing qualifying in that window has last_message_at null.
// Subrequests: msg_authorize (the verified id) + msg_my_conversations + at most MAX_BLOCK_LOOKUPS. D1 writes: none.

import { Env, authorize, resolveCaller } from "./auth";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { SYSTEM_SENDER } from "./system_line";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const MAX_SUMMARY_IDS = 50;
export const MAX_BLOCK_LOOKUPS = 30;
export const LOOKBACK_MESSAGES = 100;
const LIST_LIMIT = 100; // the database's own cap on the list

export interface SummaryItem {
  id: string;
  /** A sender whose messages do not count for this conversation (a counterpart the caller blocked), or null. */
  exclude: string | null;
}

/**
 * The one statement. The ids and the exclusions travel as two JSON parameters (D1 allows 100 bound parameters and a
 * compound SELECT of only a few terms, so neither one-parameter-per-id nor one-sub-select-per-id fits 50 ids).
 *   cs   : conversation_seq, the newest seq of each conversation, by primary key (one row each);
 *   m    : the messages of that conversation with seq above (newest seq - LOOKBACK_MESSAGES), an index range scan on
 *          UNIQUE (conversation_id, seq) whose lower bound comes from cs;
 *   rn=1 : the newest qualifying message of each conversation.
 */
export function summarySql(items: SummaryItem[]): { sql: string; binds: string[] } {
  const ids = items.map((i) => i.id);
  const excluded = items.filter((i) => i.exclude !== null).map((i) => `${i.id}|${i.exclude}`);
  const sql =
    `SELECT conversation_id, created_at, sender_id FROM (` +
    `SELECT m.conversation_id AS conversation_id, m.created_at AS created_at, m.sender_id AS sender_id,` +
    ` ROW_NUMBER() OVER (PARTITION BY m.conversation_id ORDER BY m.seq DESC) AS rn` +
    ` FROM conversation_seq cs` +
    ` JOIN messages m ON m.conversation_id = cs.conversation_id AND m.seq > cs.last_seq - ${LOOKBACK_MESSAGES}` +
    ` WHERE cs.conversation_id IN (SELECT value FROM json_each(?1))` +
    ` AND m.sender_id <> '${SYSTEM_SENDER}'` +
    ` AND (m.conversation_id || '|' || m.sender_id) NOT IN (SELECT value FROM json_each(?2))` +
    `) WHERE rn = 1`;
  return { sql, binds: [JSON.stringify(ids), JSON.stringify(excluded)] };
}

interface ListRow {
  conversation_id?: unknown;
  state?: unknown;
  kind?: unknown;
  counterpart_user_id?: unknown;
}

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
  const items: SummaryItem[] = [];
  let lookups = 0;
  for (const row of rows as ListRow[]) {
    if (row === null || typeof row !== "object") continue;
    if (typeof row.conversation_id !== "string" || row.state === "left") continue;
    const id = row.conversation_id.toLowerCase();
    if (!wanted.has(id) || items.some((i) => i.id === id)) continue;

    let exclude: string | null = null;
    if (row.kind === "dm" && row.state === "read_only") {
      // A block in either direction, or an unavailable counterpart: find out whether the CALLER blocked them.
      if (lookups >= MAX_BLOCK_LOOKUPS) continue; // over the subrequest budget: omit
      lookups++;
      const auth = await authorize(request, env, id);
      if (!auth.ok) continue; // fails closed
      const counterpart = typeof row.counterpart_user_id === "string" ? row.counterpart_user_id.toLowerCase() : null;
      if (counterpart !== null && auth.grant.hiddenSenderIds.some((h) => h.toLowerCase() === counterpart)) exclude = counterpart;
    }
    items.push({ id, exclude });
  }
  if (items.length === 0) return ok({ summaries: [] });

  const { sql, binds } = summarySql(items);
  const result = await env.DB.prepare(sql)
    .bind(...binds)
    .all<{ conversation_id: string; created_at: string; sender_id: string }>();

  const last = new Map<string, { at: string; mine: boolean }>();
  for (const row of result.results) {
    last.set(row.conversation_id.toLowerCase(), {
      at: row.created_at,
      mine: row.sender_id.toLowerCase() === caller.userId.toLowerCase(),
    });
  }
  return ok({
    summaries: items.map(({ id }) => ({
      conversation_id: id,
      last_message_at: last.get(id)?.at ?? null,
      last_message_from_me: last.get(id)?.mine ?? false,
    })),
  });
}
