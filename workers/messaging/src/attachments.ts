// KAN-581: private image attachments. The flow, every step re-checked against the database of record:
//
//   1. UPLOAD   POST /v1/conversations/{id}/attachments   raw image bytes, Idempotency-Key, Authorization
//        msg_authorize (member who may SEND) -> per-user upload limit -> real type and size from the BYTES ->
//        put the object in the PRIVATE R2 bucket (binding MEDIA) -> insert the D1 record (unbound).
//   2. BIND     POST /v1/conversations/{id}/messages     { body?, attachment_ids: [...] }   (src/index.ts)
//        only the uploader's own, still-unbound attachments of THIS conversation can be attached; the bind happens in the
//        same request that creates the message.
//   3. READ     GET /v1/attachments/{id}
//        msg_authorize for the attachment's conversation on EVERY read (a removed or non-member user, or a signed-out
//        caller, gets nothing), the left-member history boundary and the viewer's own blocks apply as they do to text,
//        then the bytes stream from R2. The client holds only the attachment id; there is no public bucket, no permanent
//        signed URL and no provider secret in the app.
//
// Without the MEDIA binding (R2 not provisioned) every route here answers 503 and writes nothing.

import { authorize, Env, Grant } from "./auth";
import { reasonError, unauthenticated, upstreamError } from "./errors";
import {
  MAX_IMAGE_BYTES,
  MAX_IMAGES_PER_MESSAGE,
  UPLOADS_PER_USER_PER_HOUR,
  declaredMatches,
  sniffImage,
} from "./media_policy";
import { rateLimited } from "./rate_limit";

export const UPLOAD_PATH = /^\/v1\/conversations\/([^/]+)\/attachments$/;
export const READ_PATH = /^\/v1\/attachments\/([^/]+)$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HOUR_SECONDS = 3600;

export interface ApiAttachment {
  id: string;
  mime_type: string;
  byte_size: number;
  width: number | null;
  height: number | null;
}

interface AttachmentRow {
  id: string;
  conversation_id: string;
  uploader_id: string;
  upload_key: string;
  object_key: string;
  mime_type: string;
  byte_size: number;
  width: number | null;
  height: number | null;
  message_id: string | null;
  position: number | null;
}

const COLS = "id, conversation_id, uploader_id, upload_key, object_key, mime_type, byte_size, width, height, message_id, position";

export function toApiAttachment(r: AttachmentRow): ApiAttachment {
  return { id: r.id, mime_type: r.mime_type, byte_size: r.byte_size, width: r.width, height: r.height };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

const mediaUnavailable = () => upstreamError(503, "media unavailable");

// ---- upload limit: scope 'upload_hour' in rate_limits (scope is free text, no migration), same one-row upsert as the
// ---- report limit. A refused upload writes nothing and stores nothing.
const ADMIT_UPLOAD = `INSERT INTO rate_limits (subject, scope, window_start, count) VALUES (?1, 'upload_hour', ?2, 1)
  ON CONFLICT (subject, scope) DO UPDATE SET
    count = CASE WHEN rate_limits.window_start < excluded.window_start THEN 1 ELSE rate_limits.count + 1 END,
    window_start = MAX(rate_limits.window_start, excluded.window_start)
  WHERE rate_limits.window_start < excluded.window_start OR rate_limits.count < ?3
  RETURNING count`;

async function enforceUpload(db: D1Database, userId: string): Promise<Response | null> {
  const now = Math.floor(Date.now() / 1000);
  const start = Math.floor(now / HOUR_SECONDS) * HOUR_SECONDS;
  const admitted = await db.prepare(ADMIT_UPLOAD).bind(userId, start, UPLOADS_PER_USER_PER_HOUR).all();
  return admitted.results.length > 0 ? null : rateLimited(start + HOUR_SECONDS - now);
}

async function findByKey(db: D1Database, conversationId: string, uploaderId: string, uploadKey: string) {
  return db
    .prepare(`SELECT ${COLS} FROM message_attachments WHERE conversation_id = ?1 AND uploader_id = ?2 AND upload_key = ?3`)
    .bind(conversationId, uploaderId, uploadKey)
    .first<AttachmentRow>();
}

/** POST /v1/conversations/{id}/attachments */
export async function uploadAttachment(request: Request, env: Env, conversationId: string): Promise<Response> {
  if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversationId");
  const key = (request.headers.get("Idempotency-Key") ?? "").toLowerCase();
  if (!UUID.test(key)) return reasonError("invalid_request", "Idempotency-Key");
  const conv = conversationId.toLowerCase();

  // Cheap refusals first, from the headers alone: no authorisation round trip and no bytes read for a body that is
  // already too large. The real size is checked again on the bytes below (a header can lie).
  const declaredLength = request.headers.get("Content-Length");
  if (declaredLength === null || !/^[0-9]{1,12}$/.test(declaredLength)) return reasonError("invalid_request", "Content-Length");
  if (Number(declaredLength) > MAX_IMAGE_BYTES) return reasonError("payload_too_large");

  const auth = await authorize(request, env, conv);
  if (!auth.ok) return auth.response; // no DB and no R2 before an allowed result
  if (auth.grant.action !== "send") return reasonError(auth.grant.readOnlyReason ?? "invalid_request");
  if (!env.MEDIA) return mediaUnavailable();
  const userId = auth.grant.userId;

  // A retry of an upload that already finished returns the same attachment: no second object, no second quota unit.
  const existing = await findByKey(env.DB, conv, userId, key);
  if (existing) return json(200, { attachment: toApiAttachment(existing) });

  const limited = await enforceUpload(env.DB, userId);
  if (limited !== null) return limited;

  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length > MAX_IMAGE_BYTES) return reasonError("payload_too_large");
  const sniffed = sniffImage(bytes);
  if (sniffed === null) return reasonError("unsupported_media_type");
  // The declared type is never trusted, and a declared type that disagrees with the bytes is refused outright.
  if (!declaredMatches(request.headers.get("Content-Type"), sniffed.mime)) return reasonError("unsupported_media_type");

  const id = crypto.randomUUID();
  const objectKey = `m/${conv}/${id}`;
  await env.MEDIA.put(objectKey, bytes, {
    httpMetadata: { contentType: sniffed.mime },
    customMetadata: { conversation_id: conv, uploader_id: userId },
  });
  const created = await env.DB.prepare(
    `INSERT INTO message_attachments (id, conversation_id, uploader_id, upload_key, object_key, mime_type, byte_size, width, height, message_id, position, created_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, NULL, NULL, ?10)
       ON CONFLICT (conversation_id, uploader_id, upload_key) DO NOTHING`,
  )
    .bind(id, conv, userId, key, objectKey, sniffed.mime, bytes.length, sniffed.width, sniffed.height, new Date().toISOString())
    .run();
  if ((created.meta?.changes ?? 0) !== 1) {
    // Two parallel uploads with the same key: the other won. Drop the object this one wrote and return the winner.
    await env.MEDIA.delete(objectKey);
    const winner = await findByKey(env.DB, conv, userId, key);
    if (winner) return json(200, { attachment: toApiAttachment(winner) });
    return upstreamError(502, "upload failed");
  }
  return json(201, {
    attachment: { id, mime_type: sniffed.mime, byte_size: bytes.length, width: sniffed.width, height: sniffed.height },
  });
}

export type BindCheck = { ok: true; ids: string[] } | { ok: false; response: Response };

/**
 * Validates the ids of a send BEFORE the message is written: a list of 1..MAX_IMAGES_PER_MESSAGE distinct UUIDs, every one
 * the caller's own upload in THIS conversation and either still unbound or already bound to the message this very
 * Idempotency-Key created (a retry). Anything else is an invalid_request that names only the field.
 */
export async function checkAttachmentIds(
  db: D1Database,
  grant: Grant,
  conversationId: string,
  raw: unknown,
  existingMessageId: string | null,
): Promise<BindCheck> {
  const bad = (): BindCheck => ({ ok: false, response: reasonError("invalid_request", "attachment_ids") });
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > MAX_IMAGES_PER_MESSAGE) return bad();
  const ids: string[] = [];
  for (const v of raw) {
    if (typeof v !== "string" || !UUID.test(v)) return bad();
    ids.push(v.toLowerCase());
  }
  if (new Set(ids).size !== ids.length) return bad();
  const rows = await db
    .prepare(
      `SELECT id FROM message_attachments
         WHERE conversation_id = ?1 AND uploader_id = ?2 AND (message_id IS NULL OR message_id = ?3)
           AND id IN (SELECT value FROM json_each(?4))`,
    )
    .bind(conversationId, grant.userId, existingMessageId ?? "", JSON.stringify(ids))
    .all<{ id: string }>();
  return rows.results.length === ids.length ? { ok: true, ids } : bad();
}

/** Binds the validated ids to a NEW message, in order, in one D1 batch. A repeat of a send binds nothing. */
export async function bindAttachments(db: D1Database, conversationId: string, userId: string, messageId: string, ids: string[]) {
  await db.batch(
    ids.map((id, position) =>
      db
        .prepare(
          `UPDATE message_attachments SET message_id = ?1, position = ?2
             WHERE id = ?3 AND conversation_id = ?4 AND uploader_id = ?5 AND message_id IS NULL`,
        )
        .bind(messageId, position, id, conversationId, userId),
    ),
  );
}

/** Adds `attachments` to each message that has some (the key is omitted when there are none). */
export async function withAttachments<T extends { id: string }>(
  db: D1Database,
  messages: T[],
): Promise<Array<T & { attachments?: ApiAttachment[] }>> {
  if (messages.length === 0) return messages;
  const rows = await db
    .prepare(`SELECT ${COLS} FROM message_attachments WHERE message_id IN (SELECT value FROM json_each(?1)) ORDER BY position`)
    .bind(JSON.stringify(messages.map((m) => m.id)))
    .all<AttachmentRow>();
  if (rows.results.length === 0) return messages;
  const by = new Map<string, ApiAttachment[]>();
  for (const r of rows.results) {
    const list = by.get(r.message_id as string) ?? [];
    list.push(toApiAttachment(r));
    by.set(r.message_id as string, list);
  }
  return messages.map((m) => (by.has(m.id) ? { ...m, attachments: by.get(m.id) } : m));
}

/** GET /v1/attachments/{id}: authorised bytes. Anything the caller may not see is 404, never a hint that it exists. */
export async function readAttachment(request: Request, env: Env, attachmentId: string): Promise<Response> {
  if (!UUID.test(attachmentId)) return reasonError("not_found");
  if (!request.headers.get("Authorization")) return unauthenticated();
  const row = await env.DB.prepare(`SELECT ${COLS} FROM message_attachments WHERE id = ?1`)
    .bind(attachmentId.toLowerCase())
    .first<AttachmentRow>();
  if (!row) return reasonError("not_found");

  const auth = await authorize(request, env, row.conversation_id);
  if (!auth.ok) {
    // Keep 401 (no/bad token); every other denial (not a member, removed, not in the pilot, messaging off) is a plain 404.
    return auth.response.status === 401 ? auth.response : reasonError("not_found");
  }
  const g = auth.grant;
  if (row.message_id === null) {
    // Not sent yet: only the uploader sees it (their own preview after a reload).
    if (row.uploader_id !== g.userId) return reasonError("not_found");
  } else {
    const msg = await env.DB.prepare("SELECT seq, sender_id FROM messages WHERE id = ?1")
      .bind(row.message_id)
      .first<{ seq: number; sender_id: string }>();
    if (!msg) return reasonError("not_found");
    if (g.leftAtSeq !== null && msg.seq > g.leftAtSeq) return reasonError("not_found");
    if (g.hiddenSenderIds.includes(msg.sender_id)) return reasonError("not_found");
  }
  if (!env.MEDIA) return mediaUnavailable();
  const object = await env.MEDIA.get(row.object_key);
  if (!object) return reasonError("not_found");

  return new Response(object.body, {
    status: 200,
    headers: {
      "content-type": row.mime_type,
      "content-length": String(row.byte_size),
      // Private and short: the app may reuse it briefly, a shared cache never may; every fresh read re-authorises.
      "cache-control": "private, max-age=300",
      "x-content-type-options": "nosniff",
      "content-disposition": "inline",
      "content-security-policy": "default-src 'none'; sandbox",
    },
  });
}

