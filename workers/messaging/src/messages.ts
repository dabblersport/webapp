// KAN-509 (T14): API shapes and seq-cursor pagination over the local D1 messages table.
// Text only. No system lines (T15), no group block filtering (T17), no read state.

import { MessageRow } from "./db";

export interface ApiMessage {
  id: string;
  conversation_id: string;
  seq: number;
  sender_user_id: string;
  kind: "text";
  body: string;
  client_key: string | null;
  created_at: string;
}

/** client_key is shown only to its own sender (contract: null for other senders' messages). */
export function toApiMessage(row: MessageRow, viewerId: string): ApiMessage {
  return {
    id: row.id,
    conversation_id: row.conversation_id,
    seq: row.seq,
    sender_user_id: row.sender_id,
    kind: "text",
    body: row.body,
    client_key: row.sender_id === viewerId ? row.client_key : null,
    created_at: row.created_at,
  };
}

export interface PageQuery {
  conversationId: string;
  viewerId: string;
  cursor: number | null;
  direction: "older" | "newer";
  limit: number;
  /** Highest seq the viewer may see (left_at_seq), or null for no boundary. */
  cap: number | null;
}

const COLS = "id, conversation_id, seq, sender_id, body, created_at, client_key, legal_hold";
// Effective cap: a very large integer stands for "no boundary".
const NO_CAP = Number.MAX_SAFE_INTEGER;

export async function listPage(db: D1Database, q: PageQuery) {
  const cap = q.cap ?? NO_CAP;
  const take = q.limit + 1;
  let page: D1PreparedStatement;
  let other: D1PreparedStatement;

  if (q.cursor === null) {
    page = db
      .prepare(`SELECT ${COLS} FROM messages WHERE conversation_id = ?1 AND seq <= ?2 ORDER BY seq DESC LIMIT ?3`)
      .bind(q.conversationId, cap, take);
    other = db.prepare("SELECT 0 AS x").bind(); // newest page: nothing newer by definition
  } else if (q.direction === "older") {
    page = db
      .prepare(`SELECT ${COLS} FROM messages WHERE conversation_id = ?1 AND seq < ?2 AND seq <= ?3 ORDER BY seq DESC LIMIT ?4`)
      .bind(q.conversationId, q.cursor, cap, take);
    other = db
      .prepare("SELECT EXISTS (SELECT 1 FROM messages WHERE conversation_id = ?1 AND seq >= ?2 AND seq <= ?3) AS x")
      .bind(q.conversationId, q.cursor, cap);
  } else {
    page = db
      .prepare(`SELECT ${COLS} FROM messages WHERE conversation_id = ?1 AND seq > ?2 AND seq <= ?3 ORDER BY seq ASC LIMIT ?4`)
      .bind(q.conversationId, q.cursor, cap, take);
    other = db
      .prepare("SELECT EXISTS (SELECT 1 FROM messages WHERE conversation_id = ?1 AND seq <= ?2 AND seq <= ?3) AS x")
      .bind(q.conversationId, q.cursor, cap);
  }

  const [pageRes, otherRes] = await db.batch([page, other]);
  let rows = pageRes.results as MessageRow[];
  const more = rows.length > q.limit;
  if (more) rows = rows.slice(0, q.limit);
  const otherSide = ((otherRes.results[0] as { x?: number } | undefined)?.x ?? 0) === 1;

  const newerPaging = q.cursor !== null && q.direction === "newer";
  if (!newerPaging) rows.reverse(); // always ascending by seq
  const olderExists = newerPaging ? otherSide : more;
  const newerExists = newerPaging ? more : otherSide;

  const minSeq = rows.length ? rows[0].seq : null;
  const maxSeq = rows.length ? rows[rows.length - 1].seq : null;
  // Empty page: the cursor itself is the edge to continue from.
  const olderCursor = olderExists ? (minSeq ?? (q.cursor as number) + 1) : null;
  // An empty older page at cursor=1 means the client already holds seq 1; there is no valid newer
  // cursor (contract minimum is 1), so nothing is reported above the page.
  const edge = (q.cursor as number) - 1;
  const newerCursor = newerExists ? (maxSeq ?? (edge >= 1 ? edge : null)) : null;

  // Contract rule (MessagePage): has_X === (X_cursor !== null), always. Flags are derived from cursors.
  return {
    messages: rows.map((r) => toApiMessage(r, q.viewerId)),
    older_cursor: olderCursor,
    newer_cursor: newerCursor,
    has_older: olderCursor !== null,
    has_newer: newerCursor !== null,
    page_size: q.limit,
    boundary: q.cap === null ? null : { kind: "left_at_seq" as const, seq: q.cap },
  };
}
