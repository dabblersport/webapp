// KAN-506 (T10) messaging Worker SKELETON. Nothing deployed.
// Routes:
//   GET  /health     no auth, no DB.
//   GET  /v1/whoami  skeleton-only probe of the auth pipeline; returns only the user_id msg_authorize returned.
//   POST /v1/_probe  skeleton-only, OFF unless SKELETON_PROBE = "1"; writes one row via src/db.ts as the RPC's user_id.
// Real endpoints (send/list/paginate, system lines) belong to T14/T15 and are NOT built here.
// Per request: at most 1 subrequest (msg_authorize) + 1 D1 batch.

import { Env, authorize } from "./auth";
import { insertMessage } from "./db";
import { ok, reasonError } from "./errors";

export const VERSION = "messaging-skeleton/0.0.1";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CLIENT_KEY = /^[A-Za-z0-9_-]{1,64}$/;
const MAX_BODY = 2000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return ok({ ok: true, version: VERSION });
    }

    if (request.method === "GET" && url.pathname === "/v1/whoami") {
      const conversationId = url.searchParams.get("conversation_id") ?? "";
      if (!UUID.test(conversationId)) return reasonError("invalid_request", "conversation_id");
      const auth = await authorize(request, env, conversationId, "read");
      if (!auth.ok) return auth.response;
      return ok({ user_id: auth.userId });
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
      const auth = await authorize(request, env, conversationId, "send");
      if (!auth.ok) return auth.response; // no DB access before an allowed result
      const { row, created } = await insertMessage(env.DB, {
        conversationId,
        senderId: auth.userId, // the ONLY identity the Worker uses
        body,
        clientKey,
      });
      return ok({ created, message: row });
    }

    return reasonError("not_found");
  },
};
