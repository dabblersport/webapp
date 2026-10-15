// KAN-548: per-user fixed-window rate limits on send and report, kept in D1 (migrations/0004_rate_limits.sql).
//
// Why D1 and not isolate memory: a Worker runs as many isolates at once and recycles them at will, so an in-memory
// counter would be per isolate, resettable by the platform, and bypassable by landing requests on different isolates.
// D1 serialises writes per database, so one table is the single shared counter.
//
// Check and increment are ONE statement per limit: an upsert whose DO UPDATE has a WHERE that is false once the
// window is full. A request is admitted only if that statement returns a row. So two parallel requests at the limit
// cannot both pass, and a refused request writes nothing (a false WHERE performs no update). The key is the verified
// user id the Worker derives from msg_authorize, never a client-supplied value. No logging in this module.

import { reasonError } from "./errors";

export const SEND_PER_USER_PER_CONVERSATION_PER_MINUTE = 20;
export const SEND_PER_USER_PER_HOUR = 120;
export const REPORT_PER_USER_PER_HOUR = 10;

export const MINUTE_SECONDS = 60;
export const HOUR_SECONDS = 3600;

export interface RateRule {
  scope: string;
  windowSeconds: number;
  limit: number;
}

/** One send: at most 20 a minute in this conversation AND at most 120 an hour across conversations. */
export function sendRules(conversationId: string): RateRule[] {
  return [
    {
      scope: `send_conv_min:${conversationId.toLowerCase()}`,
      windowSeconds: MINUTE_SECONDS,
      limit: SEND_PER_USER_PER_CONVERSATION_PER_MINUTE,
    },
    { scope: "send_hour", windowSeconds: HOUR_SECONDS, limit: SEND_PER_USER_PER_HOUR },
  ];
}

/** One report: at most 10 an hour per user. */
export function reportRules(): RateRule[] {
  return [{ scope: "report_hour", windowSeconds: HOUR_SECONDS, limit: REPORT_PER_USER_PER_HOUR }];
}

export type RateOutcome = { ok: true } | { ok: false; retryAfterSeconds: number };

// ?1 subject, ?2 scope, ?3 this window's start, ?4 the limit. RETURNING yields a row only when the request was
// admitted: a new row, a new window (count reset to 1) or a count below the limit (count + 1).
const ADMIT = `INSERT INTO rate_limits (subject, scope, window_start, count) VALUES (?1, ?2, ?3, 1)
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start)
  WHERE rate_limits.window_start < excluded.window_start OR rate_limits.count < ?4
  RETURNING count`;

/**
 * Admit or refuse one request for [subject] against every rule, in one D1 batch. A refusal carries the whole seconds
 * until the longest refused window ends. The caller must run this BEFORE it writes anything.
 */
export async function checkRate(db: D1Database, subject: string, rules: RateRule[]): Promise<RateOutcome> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const starts = rules.map((r) => Math.floor(nowSeconds / r.windowSeconds) * r.windowSeconds);
  const results = await db.batch(
    rules.map((r, i) => db.prepare(ADMIT).bind(subject, r.scope, starts[i], r.limit)),
  );
  let retryAfter = 0;
  results.forEach((res, i) => {
    if (res.results.length === 0) retryAfter = Math.max(retryAfter, starts[i] + rules[i].windowSeconds - nowSeconds);
  });
  return retryAfter === 0 ? { ok: true } : { ok: false, retryAfterSeconds: retryAfter };
}

/** 429, the typed reason rate_limited, and Retry-After in whole seconds. */
export function rateLimited(retryAfterSeconds: number): Response {
  const res = reasonError("rate_limited");
  res.headers.set("Retry-After", String(Math.max(1, Math.ceil(retryAfterSeconds))));
  return res;
}

/** The call sites' one-liner: null to go on, or the 429 to return. */
export async function enforceRate(db: D1Database, subject: string, rules: RateRule[]): Promise<Response | null> {
  const outcome = await checkRate(db, subject, rules);
  return outcome.ok ? null : rateLimited(outcome.retryAfterSeconds);
}
