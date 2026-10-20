// KAN-580 (backend half): POST /v1/conversations/{id}/receipts  {"state":"delivered"|"seen","through_seq":<int>}.
// AUTHORED, NOT DEPLOYED. Answers 200 {"delivered_seq","seen_seq","advanced"}.
//
// The recipient acknowledges the highest seq their device has received ("delivered") or seen ("seen"). The state is a
// per-user watermark that only grows (public.msg_ack_receipt, migration 20261020150000_kan580_msg_receipts.sql), so a
// retry, a second device or an out-of-order ack is a harmless no-op: `advanced` is false and the current watermarks
// come back. The Worker authorises first (msg_authorize, so a removed or non-member caller gets its typed reason),
// checks `through_seq` against the conversation's highest assigned seq in D1 (read only; a seq that does not exist
// yet is invalid_request, so nobody can pre-acknowledge future messages), then forwards the caller's own bearer to
// the RPC, which re-checks current membership and caps a leaver at left_at_seq. Nothing is written to D1 and the
// Worker holds no elevated key. No message body, name or id other than the conversation id is read or sent; nothing
// is logged (KAN-513 guard).

import { DEFAULT_ACCESS_MODE, Env, authorize } from "./auth";
import { reasonError, ok, upstreamError } from "./errors";

export const RECEIPTS_PATH = /^\/v1\/conversations\/([^/]+)\/receipts$/;
const RECEIPT_TIMEOUT_MS = 5000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleReceipt(request: Request, env: Env, conversationId: string): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  let input: { state?: unknown; through_seq?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  if (input === null || typeof input !== "object") return reasonError("invalid_request", "body");
  if (input.state !== "delivered" && input.state !== "seen") return reasonError("invalid_request", "state");
  const seq = input.through_seq;
  if (typeof seq !== "number" || !Number.isSafeInteger(seq) || seq < 1) return reasonError("invalid_request", "through_seq");

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response; // a non-member or removed caller is refused here with its typed reason
  // Read-only members (finished game, left, blocked) may still acknowledge what they can read: no action check.

  const row = await env.DB.prepare("SELECT last_seq FROM conversation_seq WHERE conversation_id = ?1")
    .bind(conversationId)
    .first<{ last_seq: number }>();
  if (!row || seq > row.last_seq) return reasonError("invalid_request", "through_seq");

  const authorization = request.headers.get("Authorization");
  if (authorization === null || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return upstreamError(503, "receipts unavailable");
  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_ack_receipt`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: authorization,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        p_conversation_id: conversationId,
        p_state: input.state,
        p_through_seq: seq,
        p_access_mode: env.MESSAGING_ACCESS_MODE || DEFAULT_ACCESS_MODE,
      }),
      signal: AbortSignal.timeout(RECEIPT_TIMEOUT_MS),
    });
  } catch {
    return upstreamError(502, "receipts unavailable");
  }
  if (!res.ok) return upstreamError(502, "receipts unavailable");
  let rows: unknown;
  try {
    rows = await res.json();
  } catch {
    return upstreamError(502, "receipts unavailable");
  }
  const r = Array.isArray(rows) ? rows[0] : null;
  // An empty result means the RPC refused (membership changed between the two calls): treat as not a member.
  if (!r || typeof r.delivered_seq !== "number" || typeof r.seen_seq !== "number") return reasonError("not_a_member");
  return ok({ delivered_seq: r.delivered_seq, seen_seq: r.seen_seq, advanced: r.advanced === true });
}
