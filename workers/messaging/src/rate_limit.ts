// KAN-548: per-user fixed-window rate limits on send and report, kept in D1 (migrations/0004_rate_limits.sql).
//
// Why D1 and not isolate memory: a Worker runs as many isolates at once and recycles them at will, so an in-memory
// counter would be per isolate, resettable by the platform, and bypassable by landing requests on different isolates.
// D1 serialises writes per database, so one table is the single shared counter.
//
// ONE written row per admitted request. A send has two limits (per conversation per minute, per user per hour); both
// live in the user's single 'send' row: the hour window in window_start/count, and the minute window in
// sub_window_start/sub_counts, a small JSON object of per-conversation counts for the current minute. The check and the
// increment of BOTH limits are one upsert statement whose DO UPDATE has a WHERE that is false once either window is
// full. A request is admitted only if that statement returns a row, so two parallel requests at the limit cannot both
// pass, an admitted request counts against both windows together, and a refused request writes nothing.
// The key is the verified user id the Worker derives from msg_authorize, never a client-supplied value. No logging.

import { reasonError } from "./errors";

export const SEND_PER_USER_PER_CONVERSATION_PER_MINUTE = 20;
export const SEND_PER_USER_PER_HOUR = 120;
export const REPORT_PER_USER_PER_HOUR = 10;
/** KAN-561: start-DM requests per user per hour; the second line behind the database's 20 new DMs per rolling day. */
export const NEW_DM_PER_USER_PER_HOUR = 10;

export const MINUTE_SECONDS = 60;
export const HOUR_SECONDS = 3600;

export type RateOutcome = { ok: true } | { ok: false; retryAfterSeconds: number };

const windowStart = (nowSeconds: number, windowSeconds: number) => Math.floor(nowSeconds / windowSeconds) * windowSeconds;

// ?1 subject, ?2 hour window start, ?3 hour limit, ?4 minute window start, ?5 conversation id (the JSON key),
// ?6 its JSON path, ?7 per-conversation minute limit. RETURNING yields a row only when the request was admitted.
// In DO UPDATE SET every right-hand side reads the OLD row.
const ADMIT_SEND = `INSERT INTO rate_limits (subject, scope, window_start, count, sub_window_start, sub_counts)
  VALUES (?1, 'send', ?2, 1, ?4, json_object(?5, 1))
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start),
    sub_counts = CASE
      WHEN rate_limits.sub_window_start < excluded.sub_window_start THEN json_object(?5, 1)
      ELSE json_set(rate_limits.sub_counts, ?6, COALESCE(json_extract(rate_limits.sub_counts, ?6), 0) + 1) END,
    sub_window_start = MAX(rate_limits.sub_window_start, excluded.sub_window_start)
  WHERE (rate_limits.window_start < excluded.window_start OR rate_limits.count < ?3)
    AND (rate_limits.sub_window_start < excluded.sub_window_start
         OR COALESCE(json_extract(rate_limits.sub_counts, ?6), 0) < ?7)
  RETURNING count`;

// Read only on a refusal, to tell which window is full (a read is not a written row).
const READ_SEND = `SELECT window_start, count, sub_window_start, COALESCE(json_extract(sub_counts, ?2), 0) AS sub_count
  FROM rate_limits WHERE subject = ?1 AND scope = 'send'`;

/** One send: at most 20 a minute in this conversation AND at most 120 an hour across conversations. */
export async function checkSend(db: D1Database, userId: string, conversationId: string): Promise<RateOutcome> {
  const now = Math.floor(Date.now() / 1000);
  const hourStart = windowStart(now, HOUR_SECONDS);
  const minuteStart = windowStart(now, MINUTE_SECONDS);
  const conv = conversationId.toLowerCase(); // a validated UUID: hex digits and hyphens only
  const path = `$."${conv}"`;
  const admitted = await db
    .prepare(ADMIT_SEND)
    .bind(userId, hourStart, SEND_PER_USER_PER_HOUR, minuteStart, conv, path, SEND_PER_USER_PER_CONVERSATION_PER_MINUTE)
    .all();
  if (admitted.results.length > 0) return { ok: true };

  const row = await db
    .prepare(READ_SEND)
    .bind(userId, path)
    .first<{ window_start: number; count: number; sub_window_start: number; sub_count: number }>();
  const hourFull = row !== null && row.window_start >= hourStart && row.count >= SEND_PER_USER_PER_HOUR;
  const minuteFull =
    row !== null && row.sub_window_start >= minuteStart && row.sub_count >= SEND_PER_USER_PER_CONVERSATION_PER_MINUTE;
  // The longest full window wins; if a concurrent request moved the window since, fall back to the shortest wait.
  const waits: number[] = [];
  if (hourFull) waits.push(hourStart + HOUR_SECONDS - now);
  if (minuteFull) waits.push(minuteStart + MINUTE_SECONDS - now);
  return { ok: false, retryAfterSeconds: waits.length > 0 ? Math.max(...waits) : minuteStart + MINUTE_SECONDS - now };
}

const ADMIT_REPORT = `INSERT INTO rate_limits (subject, scope, window_start, count) VALUES (?1, 'report_hour', ?2, 1)
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start)
  WHERE rate_limits.window_start < excluded.window_start OR rate_limits.count < ?3
  RETURNING count`;

/** One report: at most 10 an hour per user. */
export async function checkReport(db: D1Database, userId: string): Promise<RateOutcome> {
  const now = Math.floor(Date.now() / 1000);
  const start = windowStart(now, HOUR_SECONDS);
  const admitted = await db.prepare(ADMIT_REPORT).bind(userId, start, REPORT_PER_USER_PER_HOUR).all();
  return admitted.results.length > 0 ? { ok: true } : { ok: false, retryAfterSeconds: start + HOUR_SECONDS - now };
}

/** 429, the typed reason rate_limited, and Retry-After in whole seconds. */
export function rateLimited(retryAfterSeconds: number): Response {
  const res = reasonError("rate_limited");
  res.headers.set("Retry-After", String(Math.max(1, Math.ceil(retryAfterSeconds))));
  return res;
}

/** The call sites' one-liner: null to go on, or the 429 to return. */
export async function enforceSend(db: D1Database, userId: string, conversationId: string): Promise<Response | null> {
  const outcome = await checkSend(db, userId, conversationId);
  return outcome.ok ? null : rateLimited(outcome.retryAfterSeconds);
}

export async function enforceReport(db: D1Database, userId: string): Promise<Response | null> {
  const outcome = await checkReport(db, userId);
  return outcome.ok ? null : rateLimited(outcome.retryAfterSeconds);
}

// KAN-561: start-DM, scope 'new_dm_hour', the same one-row upsert as the report limit (no migration: scope is free text).
// The Worker cannot tell a new pair from an existing one before the database call, so it counts start requests; the
// database's own cap (20 new DMs per rolling day) counts only new conversations.
const ADMIT_NEW_DM = `INSERT INTO rate_limits (subject, scope, window_start, count) VALUES (?1, 'new_dm_hour', ?2, 1)
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start)
  WHERE rate_limits.window_start < excluded.window_start OR rate_limits.count < ?3
  RETURNING count`;

/** One start-DM: at most 10 an hour per user. */
export async function checkNewDm(db: D1Database, userId: string): Promise<RateOutcome> {
  const now = Math.floor(Date.now() / 1000);
  const start = windowStart(now, HOUR_SECONDS);
  const admitted = await db.prepare(ADMIT_NEW_DM).bind(userId, start, NEW_DM_PER_USER_PER_HOUR).all();
  return admitted.results.length > 0 ? { ok: true } : { ok: false, retryAfterSeconds: start + HOUR_SECONDS - now };
}

export async function enforceNewDm(db: D1Database, userId: string): Promise<Response | null> {
  const outcome = await checkNewDm(db, userId);
  return outcome.ok ? null : rateLimited(outcome.retryAfterSeconds);
}

// KAN-563: get the game conversation, mute and unmute share one per-user window, scope 'conv_ops_minute' (no D1
// migration: scope is free text). Same one-row upsert as the report limit. These operations are idempotent, so the
// check runs AFTER the database call (the verified id comes from it): an over-limit call changes nothing a normal call
// would not, and the caller still gets 429 + Retry-After.
export const CONVERSATION_OPS_PER_USER_PER_MINUTE = 60;

const ADMIT_CONV_OPS = `INSERT INTO rate_limits (subject, scope, window_start, count) VALUES (?1, 'conv_ops_minute', ?2, 1)
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start)
  WHERE rate_limits.window_start < excluded.window_start OR rate_limits.count < ?3
  RETURNING count`;

export async function checkConversationOps(db: D1Database, userId: string): Promise<RateOutcome> {
  const now = Math.floor(Date.now() / 1000);
  const start = windowStart(now, MINUTE_SECONDS);
  const admitted = await db.prepare(ADMIT_CONV_OPS).bind(userId, start, CONVERSATION_OPS_PER_USER_PER_MINUTE).all();
  return admitted.results.length > 0 ? { ok: true } : { ok: false, retryAfterSeconds: start + MINUTE_SECONDS - now };
}

export async function enforceConversationOps(db: D1Database, userId: string): Promise<Response | null> {
  const outcome = await checkConversationOps(db, userId);
  return outcome.ok ? null : rateLimited(outcome.retryAfterSeconds);
}
