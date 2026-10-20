// KAN-580 (UI half): the two sender-only READ routes behind the receipt count and the Message info drawer.
// AUTHORED, NOT DEPLOYED.
//
//   GET /v1/conversations/{id}/receipts?seqs=4,7,9   -> {"summaries":[{"seq","recipients","delivered_count","seen_count"}]}
//   GET /v1/conversations/{id}/receipts/{seq}        -> {"recipients":[{"user_id","state","updated_at"}]}
//
// Both are for the SENDER of the message only (MESSAGING_DS_ADDITIONS.md section 15). The caller must be a current
// member (msg_authorize with their own bearer) AND the author of the seq (D1 messages.sender_id). Any failure of either
// check answers 404 not_found, never 403, so a non-sender cannot learn that a seq exists or who else is in the room.
// A missing or rejected token is still the usual 401.
//
// Summary calls msg_receipt_summary with the caller's own bearer (authenticated grant; it re-checks membership), only
// for seqs D1 says the caller sent. Recipients calls msg_receipt_recipients, which is granted to the elevated database role ONLY
// (migration 20261020160000): it has no caller identity, so it receives the member list that msg_authorize returned
// for this caller. SUPABASE_SERVICE_KEY is read in this file alone (static_guard.test.ts enforces that).
// Nothing is written anywhere. No message body is read or sent; nothing is logged (KAN-513 guard).

import { DEFAULT_ACCESS_MODE, Env, authorize } from "./auth";
import { ok, reasonError, upstreamError } from "./errors";

export const RECEIPTS_PATH_GET = /^\/v1\/conversations\/([^/]+)\/receipts$/;
export const RECEIPT_SEQ_PATH = /^\/v1\/conversations\/([^/]+)\/receipts\/(\d+)$/;
const TIMEOUT_MS = 5000;
const MAX_SEQS = 100;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const notFound = () => reasonError("not_found");

/** The subset of `seqs` that `userId` sent in this conversation, from D1. */
async function authored(env: Env, conversationId: string, userId: string, seqs: number[]): Promise<number[]> {
  if (seqs.length === 0) return [];
  const marks = seqs.map((_, i) => `?${i + 3}`).join(",");
  const res = await env.DB.prepare(
    `SELECT seq FROM messages WHERE conversation_id = ?1 AND sender_id = ?2 AND seq IN (${marks})`,
  )
    .bind(conversationId, userId, ...seqs)
    .all<{ seq: number }>();
  return res.results.map((r) => r.seq);
}

async function rpc(env: Env, name: string, key: string, bearer: string, body: unknown): Promise<unknown | null> {
  try {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: { apikey: key, Authorization: bearer, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

export async function handleReceiptSummary(request: Request, env: Env, url: URL, conversationId: string): Promise<Response> {
  if (!UUID.test(conversationId)) return notFound();
  const raw = url.searchParams.get("seqs") ?? "";
  const seqs = [...new Set(raw.split(",").filter((x) => x !== "").map(Number))];
  if (seqs.length === 0 || seqs.length > MAX_SEQS || !seqs.every((s) => Number.isSafeInteger(s) && s >= 1)) {
    return reasonError("invalid_request", "seqs");
  }

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response.status === 401 ? auth.response : notFound();

  const mine = await authored(env, conversationId, auth.grant.userId, seqs);
  if (mine.length === 0) return notFound();

  const authorization = request.headers.get("Authorization");
  if (authorization === null || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(503, "receipts unavailable");
  const rows = await rpc(env, "msg_receipt_summary", env.SUPABASE_ANON_KEY, authorization, {
    p_conversation_id: conversationId,
    p_seqs: mine,
    p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE,
  });
  if (!Array.isArray(rows)) return upstreamError(502, "receipts unavailable");
  const summaries = rows
    .filter((r) => r && [r.seq, r.recipients, r.delivered_count, r.seen_count].every((n) => typeof n === "number"))
    .map((r) => ({ seq: r.seq, recipients: r.recipients, delivered_count: r.delivered_count, seen_count: r.seen_count }));
  return ok({ summaries });
}

export async function handleReceiptRecipients(request: Request, env: Env, conversationId: string, seqText: string): Promise<Response> {
  const seq = Number(seqText);
  if (!UUID.test(conversationId) || !Number.isSafeInteger(seq) || seq < 1) return notFound();

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response.status === 401 ? auth.response : notFound();

  if ((await authored(env, conversationId, auth.grant.userId, [seq])).length !== 1) return notFound();

  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) return upstreamError(503, "receipts unavailable");
  const rows = await rpc(env, "msg_receipt_recipients", env.SUPABASE_SERVICE_KEY, `Bearer ${env.SUPABASE_SERVICE_KEY}`, {
    p_conversation_id: conversationId,
    p_seq: seq,
    p_caller_id: auth.grant.userId,
    p_member_ids: auth.grant.memberUserIds,
  });
  if (!Array.isArray(rows)) return upstreamError(502, "receipts unavailable");
  const recipients = rows
    .filter((r) => r && typeof r.user_id === "string" && (r.state === "seen" || r.state === "delivered" || r.state === "sent"))
    .map((r) => ({ user_id: r.user_id, state: r.state, updated_at: typeof r.updated_at === "string" ? r.updated_at : null }));
  return ok({ recipients });
}
