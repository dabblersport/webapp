// KAN-538: exact-match CORS allowlist for the public /v1/ routes. No network: fetch is stubbed, D1 is spied.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CORS_ALLOWED_ORIGINS } from "../src/cors";
import { CONV_A, authRow, env, mockFetch, rpcJson, spyDb } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
});

const ALLOWED = ["https://canary.dabbler.pro", "https://alpha.dabbler.pro"];
const MESSAGES = `https://worker.local/v1/conversations/${CONV_A}/messages`;

const preflight = (url: string, origin?: string) =>
  new Request(url, {
    method: "OPTIONS",
    headers: {
      ...(origin ? { Origin: origin } : {}),
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "authorization, content-type, idempotency-key",
    },
  });

const corsHeaders = (res: Response) => [...res.headers.keys()].filter((k) => k.startsWith("access-control-"));

describe("allowlist", () => {
  it("is exactly the two origins: no wildcard, no pattern", () => {
    expect([...CORS_ALLOWED_ORIGINS]).toEqual(ALLOWED);
    expect(CORS_ALLOWED_ORIGINS.some((o) => o.includes("*"))).toBe(false);
  });
});

describe("preflight on /v1/ routes", () => {
  for (const origin of ALLOWED) {
    it(`${origin}: 204 with the exact headers, no credentials header`, async () => {
      const { calls } = mockFetch(rpcJson({}));
      const { db, touched } = spyDb();
      for (const url of [MESSAGES, `https://worker.local/v1/messages/${CONV_A}/report`, "https://worker.local/v1/whoami"]) {
        const res = await worker.fetch(preflight(url, origin), env(db));
        expect(res.status).toBe(204);
        expect(res.headers.get("Access-Control-Allow-Origin")).toBe(origin);
        expect(res.headers.get("Access-Control-Allow-Methods")).toBe("GET, POST, OPTIONS");
        expect(res.headers.get("Access-Control-Allow-Headers")).toBe("Authorization, Content-Type, Idempotency-Key");
        expect(res.headers.get("Access-Control-Max-Age")).toBe("86400");
        expect(res.headers.get("Vary")).toBe("Origin");
        expect(res.headers.get("Access-Control-Allow-Credentials")).toBeNull();
        expect(res.headers.get("Access-Control-Allow-Origin")).not.toBe("*");
        expect(await res.text()).toBe("");
      }
      // a preflight authorises nothing: no RPC, no DB
      expect(calls.length).toBe(0);
      expect(touched).toEqual([]);
    });
  }

  for (const [name, origin] of [
    ["an unlisted origin", "https://evil.example"],
    ["the right host over http", "http://canary.dabbler.pro"],
    ["a look-alike subdomain", "https://canary.dabbler.pro.evil.example"],
    ["a different subdomain", "https://www.dabbler.pro"],
    ["the same origin with a trailing slash", "https://canary.dabbler.pro/"],
    ["a different case", "https://Canary.dabbler.pro"],
    ["null", "null"],
    ["no Origin header", undefined],
  ] as const) {
    it(`${name}: no CORS headers`, async () => {
      mockFetch(rpcJson({}));
      const { db } = spyDb();
      const res = await worker.fetch(preflight(MESSAGES, origin), env(db));
      expect(corsHeaders(res)).toEqual([]);
      expect(res.status).not.toBe(204);
    });
  }
});

describe("actual responses on /v1/ routes", () => {
  it("an allowed origin gets Allow-Origin and Vary; the body and status are untouched", async () => {
    mockFetch(rpcJson([authRow({ user_id: "u1" })]));
    const { db } = spyDb();
    const res = await worker.fetch(
      new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, {
        headers: { Origin: ALLOWED[0], Authorization: "Bearer t" },
      }),
      env(db),
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ user_id: "u1" });
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe(ALLOWED[0]);
    expect(res.headers.get("Vary")).toContain("Origin");
    expect(res.headers.get("Access-Control-Allow-Credentials")).toBeNull();
  });

  it("an error response (401) carries it too, so the browser can read the typed error", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(
      new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers: { Origin: ALLOWED[1] } }),
      env(db),
    );
    expect(res.status).toBe(401);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe(ALLOWED[1]);
  });

  it("an unlisted origin gets no CORS headers (Vary only)", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(
      new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers: { Origin: "https://evil.example" } }),
      env(db),
    );
    expect(corsHeaders(res)).toEqual([]);
    expect(res.headers.get("Vary")).toContain("Origin");
  });

  it("no Origin header (the database, curl): no CORS headers", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`), env(db));
    expect(corsHeaders(res)).toEqual([]);
  });
});

describe("/health and /internal/system-line are excluded", () => {
  it("/health never gets CORS headers, even from an allowed origin", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(new Request("https://worker.local/health", { headers: { Origin: ALLOWED[0] } }), env(db));
    expect(res.status).toBe(200);
    expect(corsHeaders(res)).toEqual([]);
    expect(res.headers.get("Vary")).toBeNull();
  });

  it("OPTIONS /health from an allowed origin is not a preflight", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(preflight("https://worker.local/health", ALLOWED[0]), env(db));
    expect(corsHeaders(res)).toEqual([]);
    expect(res.status).not.toBe(204);
  });

  it("/internal/system-line never gets CORS headers: POST (signed or not) and OPTIONS", async () => {
    const { db } = spyDb();
    const post = await worker.fetch(
      new Request("https://worker.local/internal/system-line", { method: "POST", headers: { Origin: ALLOWED[0] }, body: "{}" }),
      env(db),
    );
    expect(corsHeaders(post)).toEqual([]);
    expect(post.headers.get("Vary")).toBeNull();
    for (const origin of ALLOWED) {
      const opt = await worker.fetch(preflight("https://worker.local/internal/system-line", origin), env(db));
      expect(corsHeaders(opt)).toEqual([]);
      expect(opt.status).not.toBe(204);
    }
  });

  it("a path that only starts with /v1 is not a /v1/ route", async () => {
    const { db } = spyDb();
    const res = await worker.fetch(preflight("https://worker.local/v1evil", ALLOWED[0]), env(db));
    expect(corsHeaders(res)).toEqual([]);
  });
});
