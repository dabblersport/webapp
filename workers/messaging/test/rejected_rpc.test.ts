// (c) a rejected msg_authorize result gives a typed error and ZERO D1 access. LOCAL, mocked RPC only.
// Mocks use the real msg_authorize shape (KAN-505): { user_id, allowed_action, reason, left_at_seq, ... }.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, authRow, env, mockFetch, rpcJson, spyDb, type RpcReply } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

type Route = "whoami" | "probe" | "list" | "send";
const ALL: Route[] = ["whoami", "probe", "list", "send"];
const SENDS: Route[] = ["probe", "send"];
const deny = (reason: string) => rpcJson([authRow({ allowed_action: null, reason })]);

const cases: { name: string; reply: RpcReply; status: number; reason?: string; routes?: Route[] }[] = [
  { name: "401 from PostgREST", reply: rpcJson({ message: "JWT invalid" }, 401), status: 401 },
  { name: "403 from PostgREST", reply: rpcJson({ message: "permission denied" }, 403), status: 401 },
  { name: "500 from PostgREST", reply: rpcJson({ message: "boom" }, 500), status: 502 },
  { name: "denied not_a_member", reply: deny("not_member"), status: 403, reason: "not_a_member" },
  // read_only is an allowed READ in the real function, so it denies only a send (reads: closed_game.test.ts).
  { name: "denied game_ended", reply: rpcJson([authRow({ allowed_action: "read", reason: "read_only" })]), status: 409, reason: "game_ended", routes: SENDS },
  { name: "denied not_in_pilot", reply: deny("not_in_pilot"), status: 403, reason: "not_in_pilot" },
  { name: "denied not_authenticated", reply: rpcJson([authRow({ user_id: null, allowed_action: null, reason: "not_authenticated" })]), status: 401 },
  { name: "denied with unknown reason", reply: deny("made_up"), status: 403 },
  { name: "allowed missing user_id", reply: rpcJson([authRow({ user_id: undefined })]), status: 502 },
  { name: "empty array", reply: rpcJson([]), status: 502 },
  { name: "null body", reply: rpcJson(null), status: 502 },
  { name: "malformed JSON", reply: () => new Response("not json{", { status: 200 }), status: 502 },
  { name: "allowed_action is an unknown string", reply: rpcJson([authRow({ allowed_action: "true" })]), status: 502 },
  { name: "denial with no reason", reply: rpcJson([authRow({ allowed_action: null, reason: null })]), status: 502 },
  { name: "read with a denial reason", reply: rpcJson([authRow({ allowed_action: "read", reason: "removed" })]), status: 502 },
  { name: "left without left_at_seq", reply: rpcJson([authRow({ allowed_action: "read", reason: "left", left_at_seq: null })]), status: 502 },
  { name: "network error", reply: new Error("ECONNRESET"), status: 502 },
];

function request(route: Route): Request {
  const headers = { Authorization: "Bearer any.token.here", "content-type": "application/json" };
  switch (route) {
    case "whoami":
      return new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers });
    case "probe":
      return new Request("https://worker.local/v1/_probe", {
        method: "POST",
        headers,
        body: JSON.stringify({ conversation_id: CONV_A, body: "hi", client_key: "k1" }),
      });
    case "list":
      return new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, { headers });
    case "send":
      return new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, {
        method: "POST",
        headers: { ...headers, "Idempotency-Key": "9b2f7c1e-0000-4000-8000-000000000001" },
        body: JSON.stringify({ body: "hi" }),
      });
  }
}

describe("(c) rejected RPC", () => {
  for (const c of cases) {
    for (const route of c.routes ?? ALL) {
      it(`${c.name} on ${route}: ${c.status}${c.reason ? " " + c.reason : " no reason"}, zero DB access`, async () => {
        const { calls, unmocked } = mockFetch(c.reply);
        const { db, touched } = spyDb();
        const res = await worker.fetch(request(route), env(db, { SKELETON_PROBE: "1" }));
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
