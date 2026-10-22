// KAN-506 (T10) messaging Worker skeleton + KAN-509 (T14) send/list. Nothing deployed.
// Routes:
//   GET  /health     no auth, no DB.
//   GET  /v1/whoami  skeleton-only probe of the auth pipeline; returns only the user_id msg_authorize returned.
//   POST /v1/_probe  skeleton-only, OFF unless SKELETON_PROBE = "1"; writes one row via src/db.ts as the RPC's user_id.
//   GET  /v1/conversations/{id}/messages  list, seq cursor both directions, cut at left_at_seq (T14).
//   POST /v1/conversations/{id}/messages  send text, idempotent on (sender, conversation, Idempotency-Key) (T14).
//   POST /internal/system-line  signed (HMAC) roster/cancel event from the database trigger; stores one system line (T15).
//   GET  /v1/moderation/reports/{reportId}/message  audited moderator read of one reported message (T18, src/moderation.ts).
//   POST /v1/dm  GET /v1/conversations/summary  POST /v1/conversations/{id}/mute  DMs (KAN-561, src/dm.ts, src/conversations.ts)
//   GET /v1/games/{gameId}/conversation  PUT|DELETE /v1/conversations/{id}/mute  (KAN-563, src/games.ts, src/dm.ts)
//   POST /v1/conversations/{id}/attachments  GET /v1/attachments/{id}  private image upload and authorised read (KAN-581, src/attachments.ts)
//   POST /v1/messages/{id}/report  report a message (T17, KAN-512): ids + reason relayed, legal hold set.
// List applies the D4 group block filter from msg_authorize's hidden_sender_ids (T17).
// Realtime, reactions: NOT built here. Images (KAN-581) are private objects behind this Worker (src/attachments.ts).
// Per request: at most 1 subrequest (msg_authorize) + 1 D1 batch, except report: msg_authorize + msg_report_message
// and two single-statement D1 calls (seq lookup, hold).

import { Env, authorize, hasBearer } from "./auth";
import { insertMessage } from "./db";
import { ok, reasonError, unauthenticated, upstreamError } from "./errors";
import { setLegalHold } from "./retention";
import { listPage, toApiMessage } from "./messages";
import { preflightResponse, withCors } from "./cors";
import { conversationSummary } from "./conversations";
import { putMuted, setMuted, startDm } from "./dm";
import { getGameConversation } from "./games";
import { WaitUntilContext, scheduleNotify } from "./notify";
import { handleSystemLine } from "./system_line";
import { MODERATION_PATH, readReportedMessage } from "./moderation";
import { enforceReport, enforceSend } from "./rate_limit";
import { RECEIPTS_PATH, handleReceipt } from "./receipts";
import { RECEIPTS_PATH_GET, RECEIPT_SEQ_PATH, handleReceiptRecipients, handleReceiptSummary } from "./receipt_reads";
import { TYPING_PATH, handleTyping } from "./typing";
import { READ_PATH, UPLOAD_PATH, bindAttachments, checkAttachmentIds, readAttachment, uploadAttachment, withAttachments } from "./attachments";

export const VERSION = "messaging-skeleton/0.0.1";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CLIENT_KEY = /^[A-Za-z0-9_-]{1,64}$/;
const MAX_BODY = 2000;
const MESSAGES_PATH = /^\/v1\/conversations\/([^/]+)\/messages$/;
const MUTE_PATH = /^\/v1\/conversations\/([^/]+)\/mute$/;
const GAME_CONVERSATION_PATH = /^\/v1\/games\/([^/]+)\/conversation$/;
const REPORT_PATH = /^\/v1\/messages\/([^/]+)\/report$/;
// The existing ten-value public.report_reason enum (docs/messaging/openapi.yaml ReportRequest). No new values.
export const REPORT_REASONS = ["spam", "abuse", "hate", "harassment", "nudity", "illegal", "danger", "scam", "impersonation", "other"] as const;
const POS_INT = /^[1-9][0-9]{0,15}$/;
const DEFAULT_LIMIT = 30;
const MAX_LIMIT = 50;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

const router = {
  async fetch(request: Request, env: Env, ctx?: WaitUntilContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return ok({ ok: true, version: VERSION });
    }

    if (request.method === "GET" && url.pathname === "/v1/whoami") {
      const conversationId = url.searchParams.get("conversation_id") ?? "";
      if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversation_id");
      const auth = await authorize(request, env, conversationId);
      if (!auth.ok) return auth.response;
      return ok({ user_id: auth.grant.userId });
    }

    if (request.method === "POST" && url.pathname === "/v1/_probe" && env.SKELETON_PROBE === "1") {
      let input: { conversation_id?: unknown; body?: unknown; client_key?: unknown };
      try {
        input = await request.json();
      } catch {
        return reasonError("invalid_request", "body");
      }
      const conversationId = typeof input.conversation_id === "string" ? input.conversation_id : "";
      const body = typeof input.body === "string" ? input.body : "";
      const clientKey = typeof input.client_key === "string" ? input.client_key : "";
      if (!UUID.test(conversationId) || body.length === 0 || body.length > MAX_BODY || !CLIENT_KEY.test(clientKey)) {
        return reasonError("invalid_request");
      }
      const auth = await authorize(request, env, conversationId);
      if (!auth.ok) return auth.response; // no DB access before an allowed result
      if (auth.grant.action !== "send") return reasonError(auth.grant.readOnlyReason ?? "invalid_request");
      const { row, created } = await insertMessage(env.DB, {
        conversationId,
        senderId: auth.grant.userId, // the ONLY identity the Worker uses
        body,
        clientKey,
      });
      return ok({ created, message: row });
    }

    if (request.method === "POST" && url.pathname === "/internal/system-line") return handleSystemLine(request, env);
    // KAN-513 (T18): the single moderator read of one reported message. GET only; no list variant exists.
    const mod = MODERATION_PATH.exec(url.pathname);
    if (mod && request.method === "GET") return readReportedMessage(request, env, mod[1]);

    // KAN-561: DMs. Start a DM, the Messages list summary, mute a conversation.
    if (request.method === "POST" && url.pathname === "/v1/dm") return startDm(request, env);
    if (request.method === "GET" && url.pathname === "/v1/conversations/summary") {
      return conversationSummary(request, env, url);
    }
    const mute = MUTE_PATH.exec(url.pathname);
    if (mute && request.method === "POST") return setMuted(request, env, mute[1]);
    // KAN-563: the contract's mute / unmute (204, idempotent) and get-the-game-conversation.
    if (mute && request.method === "PUT") return putMuted(request, env, mute[1], true);
    if (mute && request.method === "DELETE") return putMuted(request, env, mute[1], false);
    const game = GAME_CONVERSATION_PATH.exec(url.pathname);
    if (game && request.method === "GET") return getGameConversation(request, env, game[1]);

    // KAN-579: ephemeral typing presence. No D1, no stored row; see src/typing.ts.
    const typing = TYPING_PATH.exec(url.pathname);
    if (typing && request.method === "POST") return handleTyping(request, env, typing[1], ctx);

    // KAN-580: recipient acknowledgement (delivered / seen watermark). Authored on the branch, not deployed.
    const receipt = RECEIPTS_PATH.exec(url.pathname);
    if (receipt && request.method === "POST") return handleReceipt(request, env, receipt[1]);
    // KAN-580: sender-only reads (count + Message info drawer). 404, never 403, for a non-sender.
    const receiptGet = RECEIPTS_PATH_GET.exec(url.pathname);
    if (receiptGet && request.method === "GET") return handleReceiptSummary(request, env, url, receiptGet[1]);
    const receiptSeq = RECEIPT_SEQ_PATH.exec(url.pathname);
    if (receiptSeq && request.method === "GET") return handleReceiptRecipients(request, env, receiptSeq[1], receiptSeq[2]);

    // KAN-581: private images. Upload bytes to private object storage behind the membership check; read them back through the same check.
    const up = UPLOAD_PATH.exec(url.pathname);
    if (up && request.method === "POST") return uploadAttachment(request, env, up[1]);
    const rd = READ_PATH.exec(url.pathname);
    if (rd && request.method === "GET") return readAttachment(request, env, rd[1]);

    const m = MESSAGES_PATH.exec(url.pathname);
    if (m && request.method === "GET") return listMessages(request, env, url, m[1]);
    if (m && request.method === "POST") return sendMessage(request, env, m[1], ctx);

    const rp = REPORT_PATH.exec(url.pathname);
    if (rp && request.method === "POST") return reportMessage(request, env, rp[1]);

    return reasonError("not_found");
  },
};

// KAN-538: CORS wraps the router for the public /v1/ routes only (src/cors.ts); /health and /internal/* are untouched.
export default {
  async fetch(request: Request, env: Env, ctx?: WaitUntilContext): Promise<Response> {
    const pathname = new URL(request.url).pathname;
    const preflight = preflightResponse(request, pathname);
    if (preflight !== null) return preflight;
    return withCors(request, pathname, await router.fetch(request, env, ctx));
  },
};

async function listMessages(request: Request, env: Env, url: URL, conversationId: string): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  const p = url.searchParams;
  const cursorRaw = p.get("cursor");
  const directionRaw = p.get("direction") ?? "older";
  const limitRaw = p.get("limit");
  if (cursorRaw !== null && !POS_INT.test(cursorRaw)) return reasonError("invalid_request", "cursor");
  if (directionRaw !== "older" && directionRaw !== "newer") return reasonError("invalid_request", "direction");
  const limit = limitRaw === null ? DEFAULT_LIMIT : POS_INT.test(limitRaw) ? Number(limitRaw) : 0;
  if (limit < 1 || limit > MAX_LIMIT) return reasonError("invalid_request", "limit");

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response; // no DB access before an allowed result
  const page = await listPage(env.DB, {
    conversationId,
    viewerId: auth.grant.userId,
    cursor: cursorRaw === null ? null : Number(cursorRaw),
    direction: directionRaw,
    limit,
    cap: auth.grant.leftAtSeq, // set only for a member who left; the RPC computed it
    hidden: auth.grant.hiddenSenderIds, // the caller's own blocks (user_blocks); nobody else's view changes
  });
  return ok({ ...page, messages: await withAttachments(env.DB, page.messages) });
}

async function sendMessage(request: Request, env: Env, conversationId: string, ctx?: WaitUntilContext): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  const key = request.headers.get("Idempotency-Key") ?? "";
  if (!UUID.test(key)) return reasonError("invalid_request", "Idempotency-Key");
  let input: { body?: unknown; attachment_ids?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  const hasIds = input !== null && typeof input === "object" && input.attachment_ids !== undefined;
  const body = input !== null && typeof input === "object" && typeof input.body === "string" ? input.body : "";
  // KAN-581: a message with images may have an empty caption; a text-only message still needs text.
  if (body.length > MAX_BODY || (body.length === 0 && !hasIds)) return reasonError("invalid_request", "body");

  const auth = await authorize(request, env, conversationId);
  if (!auth.ok) return auth.response; // no DB access before an allowed result
  // Closed game or a member who left: the RPC allowed only a read. Refuse with its typed reason.
  if (auth.grant.action !== "send") return reasonError(auth.grant.readOnlyReason ?? "invalid_request");
  // KAN-548: per verified user, before anything is written. A refused send inserts nothing.
  const limited = await enforceSend(env.DB, auth.grant.userId, conversationId);
  if (limited !== null) return limited;

  // KAN-581: validate the images BEFORE anything is written, so a bad id stores no message.
  let imageIds: string[] = [];
  if (hasIds) {
    const prior = await env.DB.prepare("SELECT id FROM messages WHERE conversation_id = ?1 AND sender_id = ?2 AND client_key = ?3")
      .bind(conversationId.toLowerCase(), auth.grant.userId, key.toLowerCase())
      .first<{ id: string }>();
    const checked = await checkAttachmentIds(env.DB, auth.grant, conversationId.toLowerCase(), input.attachment_ids, prior?.id ?? null);
    if (!checked.ok) return checked.response;
    imageIds = checked.ids;
  }
  const { row, created } = await insertMessage(env.DB, {
    conversationId,
    senderId: auth.grant.userId,
    body,
    clientKey: key.toLowerCase(),
  });
  if (created && imageIds.length > 0) {
    await bindAttachments(env.DB, conversationId.toLowerCase(), auth.grant.userId, row.id, imageIds);
  }
  // KAN-543: wake the members only for a NEW message (201), never for an idempotent repeat (200). Scheduled after the
  // response with ctx.waitUntil; it never delays or changes the send result.
  if (created) scheduleNotify(ctx, env, request.headers.get("Authorization"), conversationId, row.seq);
  const [withImages] = await withAttachments(env.DB, [toApiMessage(row, auth.grant.userId)]);
  return json(created ? 201 : 200, withImages);
}

/**
 * Report a message (T17). The ONLY data relayed to Supabase is ids + reason: the D1 lookup reads conversation_id and
 * seq, never the body. Order: bearer shape -> request -> seq lookup -> msg_authorize -> visibility (left_at_seq) ->
 * msg_report_message (same bearer; it re-checks membership and is idempotent per reporter+message) -> legal hold.
 */
async function reportMessage(request: Request, env: Env, messageId: string): Promise<Response> {
  if (!UUID.test(messageId)) return reasonError("invalid_request", "messageId");
  if (!hasBearer(request)) return unauthenticated();
  let input: { reason?: unknown };
  try {
    input = await request.json();
  } catch {
    return reasonError("invalid_request", "body");
  }
  const reason = input !== null && typeof input === "object" ? input.reason : undefined;
  if (typeof reason !== "string" || !(REPORT_REASONS as readonly string[]).includes(reason)) {
    return reasonError("invalid_request", "reason");
  }

  const target = await env.DB.prepare("SELECT conversation_id, seq FROM messages WHERE id = ?1")
    .bind(messageId.toLowerCase())
    .first<{ conversation_id: string; seq: number }>();
  if (!target) return reasonError("not_found");

  const auth = await authorize(request, env, target.conversation_id);
  if (!auth.ok) return auth.response;
  // A member who left may report only what they can still read.
  if (auth.grant.leftAtSeq !== null && target.seq > auth.grant.leftAtSeq) return reasonError("not_a_member");
  // KAN-548: per verified user, before the report is relayed or the hold is set. A refused report writes nothing.
  const limited = await enforceReport(env.DB, auth.grant.userId);
  if (limited !== null) return limited;

  let res: Response;
  try {
    res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/msg_report_message`, {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: request.headers.get("Authorization") as string,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        p_conversation_id: target.conversation_id,
        p_message_id: messageId.toLowerCase(),
        p_message_seq: target.seq,
        p_reason: reason,
        p_access_mode: env.MESSAGING_ACCESS_MODE || "allowlist",
      }),
    });
  } catch {
    return upstreamError(502, "report unavailable");
  }
  if (res.status === 401) return unauthenticated("token rejected");
  if (res.status === 403) return reasonError("not_a_member");
  if (!res.ok) return upstreamError(502, "report failed");

  await setLegalHold(env.DB, messageId.toLowerCase());
  return new Response(null, { status: 202 });
}
