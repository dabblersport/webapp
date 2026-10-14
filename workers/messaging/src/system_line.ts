// KAN-510 (T15): one signed internal endpoint, POST /internal/system-line.
// The database trigger (msg_system_notify) signs the exact body with HMAC-SHA256 and the Worker stores
// one system line per event_id. "Game finished" is NOT emitted here or anywhere server-side: no trigger
// fires on the passage of time, so the client renders it from the game's end time (T16).
// The shared key is read from the binding MSG_SYSTEM_HMAC_SECRET (named here, never valued).

import { Env } from "./auth";
import { insertMessage } from "./db";
import { reasonError, unauthenticated, upstreamError } from "./errors";

/** Fixed sender id of every system line. Not a user id, so it can never collide with a real sender. */
export const SYSTEM_SENDER = "system";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SIGNATURE = /^sha256=([0-9a-f]{64})$/;
const EVENTS = new Set(["joined", "left", "removed", "cancelled"]);
const MAX_BODY_BYTES = 2048;

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

/** Constant-time check (SubtleCrypto.verify) of 'sha256=<hex>' over the exact body text. */
export async function verifySignature(secret: string, bodyText: string, header: string | null): Promise<boolean> {
  const m = header === null ? null : SIGNATURE.exec(header);
  if (!m) return false;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "verify",
  ]);
  return crypto.subtle.verify("HMAC", key, hexToBytes(m[1]), enc.encode(bodyText));
}

export async function handleSystemLine(request: Request, env: Env): Promise<Response> {
  const secret = env.MSG_SYSTEM_HMAC_SECRET;
  if (!secret) return upstreamError(503, "system lines not configured"); // fail closed, no write

  const bodyText = await request.text();
  if (bodyText.length > MAX_BODY_BYTES) return reasonError("invalid_request", "body");
  if (!(await verifySignature(secret, bodyText, request.headers.get("X-Msg-Signature")))) {
    return unauthenticated("bad signature"); // missing, malformed or tampered: no write
  }

  let input: { event_id?: unknown; conversation_id?: unknown; event?: unknown; user_id?: unknown };
  try {
    input = JSON.parse(bodyText);
  } catch {
    return reasonError("invalid_request", "body");
  }
  if (input === null || typeof input !== "object") return reasonError("invalid_request", "body");
  const { event_id, conversation_id, event, user_id } = input;
  if (typeof event_id !== "string" || !UUID.test(event_id)) return reasonError("invalid_request", "event_id");
  if (typeof conversation_id !== "string" || !UUID.test(conversation_id)) {
    return reasonError("invalid_request", "conversation_id");
  }
  if (typeof event !== "string" || !EVENTS.has(event)) return reasonError("invalid_request", "event");
  const hasUser = user_id !== undefined;
  if (hasUser && (typeof user_id !== "string" || !UUID.test(user_id))) return reasonError("invalid_request", "user_id");
  if (event === "cancelled" ? hasUser : !hasUser) return reasonError("invalid_request", "user_id");

  // The client localises the line from this structured body (event code + subject), never from stored prose.
  const line = hasUser ? { event, user_id: (user_id as string).toLowerCase() } : { event };
  const { row, created } = await insertMessage(env.DB, {
    conversationId: conversation_id.toLowerCase(),
    senderId: SYSTEM_SENDER,
    body: JSON.stringify(line),
    clientKey: event_id.toLowerCase(), // the same event delivered twice stores one line
  });
  return new Response(JSON.stringify({ created, id: row.id, seq: row.seq }), {
    status: created ? 201 : 200,
    headers: { "content-type": "application/json" },
  });
}
