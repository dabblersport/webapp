// Message insert with a gap-free per-conversation seq.
//
// One D1 batch (D1 runs a batch as a single SQL transaction, and D1 serialises writes per database):
//   1. advance conversation_seq.last_seq by 1 -- only if this (conversation, sender, client_key) is new;
//   2. insert the message with seq = the advanced last_seq -- under the same "is new" predicate;
//   3. read back the row for (conversation, sender, client_key).
// A repeated client_key advances nothing and inserts nothing, so it consumes no seq (no gap) and returns the
// existing row. A UNIQUE violation aborts the whole batch, so the counter never advances without a row.

export interface NewMessage {
  conversationId: string;
  senderId: string;
  body: string;
  clientKey: string;
}

export interface MessageRow {
  id: string;
  conversation_id: string;
  seq: number;
  sender_id: string;
  body: string;
  created_at: string;
  client_key: string;
  legal_hold: number;
}

const IS_NEW =
  "NOT EXISTS (SELECT 1 FROM messages WHERE conversation_id = ?1 AND sender_id = ?2 AND client_key = ?3)";

export async function insertMessage(
  db: D1Database,
  m: NewMessage,
): Promise<{ row: MessageRow; created: boolean }> {
  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();

  const advance = db
    .prepare(
      `INSERT INTO conversation_seq (conversation_id, last_seq)
         SELECT ?1, 1 WHERE ${IS_NEW}
       ON CONFLICT (conversation_id) DO UPDATE SET last_seq = last_seq + 1`,
    )
    .bind(m.conversationId, m.senderId, m.clientKey);

  const insert = db
    .prepare(
      `INSERT INTO messages (id, conversation_id, seq, sender_id, body, created_at, client_key, legal_hold)
         SELECT ?4, ?1, (SELECT last_seq FROM conversation_seq WHERE conversation_id = ?1), ?2, ?5, ?6, ?3, 0
         WHERE ${IS_NEW}`,
    )
    .bind(m.conversationId, m.senderId, m.clientKey, id, m.body, createdAt);

  const read = db
    .prepare(
      `SELECT id, conversation_id, seq, sender_id, body, created_at, client_key, legal_hold
         FROM messages WHERE conversation_id = ?1 AND sender_id = ?2 AND client_key = ?3`,
    )
    .bind(m.conversationId, m.senderId, m.clientKey);

  const results = await db.batch([advance, insert, read]);
  const created = (results[1].meta?.changes ?? 0) === 1;
  const row = (results[2].results as MessageRow[])[0];
  if (!row) throw new Error("insertMessage: row not found after batch");
  return { row, created };
}
