// (b) C4 / AC1: a token with forged claims still makes the Worker act ONLY on the msg_authorize result.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, RPC_URL, authRow, env, localD1, mockFetch, rpcJson } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

// Built in the test: unsigned-looking JWT with a garbage signature, claiming another user and a stolen role.
function forgedToken(): string {
  const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
  return [
    b64({ alg: "HS256", typ: "JWT" }),
    b64({ sub: "victim-user", user_id: "victim-user", role: "service_role", exp: 9999999999 }),
    "garbage-signature",
  ].join(".");
}

describe("(b) forged claims", () => {
  it("whoami returns only the RPC's user_id and forwards the header byte-identically", async () => {
    const authorization = `Bearer ${forgedToken()}`;
    const { calls, unmocked } = mockFetch(rpcJson([authRow()]));
    const { mf, db } = await localD1();
    try {
      const res = await worker.fetch(
        new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers: { Authorization: authorization } }),
        env(db),
      );
      const text = await res.text();
      expect(res.status).toBe(200);
      expect(JSON.parse(text)).toEqual({ user_id: "real-user" });
      expect(text).not.toContain("victim-user");
      expect(text).not.toContain("service_role");
      expect(calls.length).toBe(1);
      expect(calls[0].url).toBe(RPC_URL);
      const fwd = (calls[0].init.headers as Record<string, string>).Authorization;
      expect(Buffer.from(fwd).equals(Buffer.from(authorization))).toBe(true);
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("the DB row written through the probe uses real-user; victim-user appears nowhere in D1", async () => {
    const authorization = `Bearer ${forgedToken()}`;
    const { calls, unmocked } = mockFetch(rpcJson([authRow()]));
    const { mf, db } = await localD1();
    try {
      const res = await worker.fetch(
        new Request("https://worker.local/v1/_probe", {
          method: "POST",
          headers: { Authorization: authorization, "content-type": "application/json" },
          body: JSON.stringify({ conversation_id: CONV_A, body: "hello", client_key: "k1" }),
        }),
        env(db, { SKELETON_PROBE: "1" }),
      );
      const text = await res.text();
      expect(res.status).toBe(200);
      expect(text).not.toContain("victim-user");
      const out = JSON.parse(text);
      expect(out.message.sender_id).toBe("real-user");
      expect(out.message.seq).toBe(1);
      const all = await db.prepare("SELECT * FROM messages").all();
      expect(JSON.stringify(all.results)).not.toContain("victim-user");
      expect(all.results.length).toBe(1);
      expect(calls.length).toBe(1);
      expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(authorization);
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });
});
