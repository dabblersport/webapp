// (c) a rejected msg_authorize result gives a typed error and ZERO D1 access.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, env, mockFetch, rpcJson, spyDb, type RpcReply } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const cases: { name: string; reply: RpcReply; status: number; reason?: string }[] = [
  { name: "401 from PostgREST", reply: rpcJson({ message: "JWT invalid" }, 401), status: 401 },
  { name: "403 from PostgREST", reply: rpcJson({ message: "permission denied" }, 403), status: 401 },
  { name: "500 from PostgREST", reply: rpcJson({ message: "boom" }, 500), status: 502 },
  { name: "denied not_a_member", reply: rpcJson({ user_id: "real-user", allowed: false, reason: "not_a_member" }), status: 403, reason: "not_a_member" },
  { name: "denied game_ended", reply: rpcJson({ user_id: "real-user", allowed: false, reason: "game_ended" }), status: 409, reason: "game_ended" },
  { name: "denied not_in_pilot", reply: rpcJson({ user_id: "real-user", allowed: false, reason: "not_in_pilot" }), status: 403, reason: "not_in_pilot" },
  { name: "denied with unknown reason", reply: rpcJson({ user_id: "real-user", allowed: false, reason: "made_up" }), status: 403 },
  { name: "allowed missing user_id", reply: rpcJson({ allowed: true }), status: 502 },
  { name: "empty array", reply: rpcJson([]), status: 502 },
  { name: "null body", reply: rpcJson(null), status: 502 },
  { name: "malformed JSON", reply: () => new Response("not json{", { status: 200 }), status: 502 },
  { name: "allowed is a string", reply: rpcJson({ user_id: "real-user", allowed: "true" }), status: 502 },
  { name: "network error", reply: new Error("ECONNRESET"), status: 502 },
];

describe("(c) rejected RPC", () => {
  for (const c of cases) {
    for (const route of ["whoami", "probe"] as const) {
      it(`${c.name} on ${route}: ${c.status}${c.reason ? " " + c.reason : " no reason"}, zero DB access`, async () => {
        const { calls, unmocked } = mockFetch(c.reply);
        const { db, touched } = spyDb();
        const headers = { Authorization: "Bearer any.token.here", "content-type": "application/json" };
        const req =
          route === "whoami"
            ? new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers })
            : new Request("https://worker.local/v1/_probe", {
                method: "POST",
                headers,
                body: JSON.stringify({ conversation_id: CONV_A, body: "hi", client_key: "k1" }),
              });
        const res = await worker.fetch(req, env(db, { SKELETON_PROBE: "1" }));
        expect(res.status).toBe(c.status);
        const body = (await res.json()) as { error: Record<string, unknown> };
        expect(body.error.reason).toBe(c.reason);
        expect(calls.length).toBe(1);
        expect(unmocked).toEqual([]);
        expect(touched).toEqual([]); // no prepare / exec / batch / anything
      });
    }
  }
});
