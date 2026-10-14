// KAN-512 (T17): legal hold. The ONE place in the Worker that may remove message rows.
//
// There is no deletion or expiry feature in the product today (D5: nothing deleted). These helpers exist so any
// future path has a single guarded entry: every removal statement carries `legal_hold = 0`, and the D1 triggers in
// migrations/0003_legal_hold_guard.sql abort a removal of a held row even if a statement forgot the predicate.
// test/t17_report.test.ts asserts no other file in src/ removes message rows.

/** Mark a message as held. Idempotent. A hold is never released (the D1 trigger refuses it). */
export async function setLegalHold(db: D1Database, messageId: string): Promise<void> {
  await db.prepare("UPDATE messages SET legal_hold = 1 WHERE id = ?1").bind(messageId).run();
}

/** Remove the given messages, skipping held ones. Returns how many rows were removed. */
export async function deleteMessagesIfNotHeld(db: D1Database, ids: string[]): Promise<number> {
  if (ids.length === 0) return 0;
  const res = await db
    .prepare("DELETE FROM messages WHERE legal_hold = 0 AND id IN (SELECT value FROM json_each(?1))")
    .bind(JSON.stringify(ids))
    .run();
  return res.meta?.changes ?? 0;
}

/** Expire messages created before an ISO timestamp, skipping held ones. Returns how many rows were removed. */
export async function expireMessagesBefore(db: D1Database, isoTimestamp: string): Promise<number> {
  const res = await db
    .prepare("DELETE FROM messages WHERE legal_hold = 0 AND created_at < ?1")
    .bind(isoTimestamp)
    .run();
  return res.meta?.changes ?? 0;
}
