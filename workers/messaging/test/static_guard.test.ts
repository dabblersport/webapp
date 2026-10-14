// (g) static guard: forbidden patterns must not appear anywhere under src/ (code or comments).
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const SRC = fileURLToPath(new URL("../src", import.meta.url));
const files = readdirSync(SRC, { recursive: true })
  .map(String)
  .filter((f) => f.endsWith(".ts"))
  .map((f) => ({ f, text: readFileSync(join(SRC, f), "utf8") }));

const FORBIDDEN: [string, RegExp][] = [
  ["jwt-decode", /jwt-decode/i],
  ["jose / jsonwebtoken", /\b(jose|jsonwebtoken)\b/],
  ["JWT_SECRET", /JWT_SECRET/i],
  ["SERVICE_ROLE", /SERVICE_ROLE/i],
  ["atob(", /\batob\s*\(/],
  ["btoa(", /\bbtoa\s*\(/],
  ["Buffer.from", /Buffer\.from/],
  ["base64 decoding", /base64/i],
  ["crypto.subtle", /crypto\.subtle/],
  ["caches.default / Cache API", /\bcaches\b/],
  ["KV namespace", /KVNamespace|\bKV\b/],
  ["R2", /\bR2(Bucket)?\b/],
  ["module-level Map/WeakMap cache", /^(const|let|var)\s+\w+\s*=\s*new\s+(Weak)?Map\b/m],
  ["claim access", /\.(sub|claims?)\b|\["(sub|role)"\]/],
];

describe("(g) static guard over src/", () => {
  it("found source files", () => expect(files.length).toBeGreaterThan(0));
  for (const [name, re] of FORBIDDEN) {
    it(`no ${name}`, () => {
      // KAN-510: the HMAC check of the signed internal endpoint is the one legitimate crypto.subtle user.
      // It never touches a bearer token; every other file stays under the ban.
      const exempt = name === "crypto.subtle" ? "system_line.ts" : null;
      const hits = files.filter(({ f, text }) => f !== exempt && re.test(text)).map(({ f }) => f);
      expect(hits).toEqual([]);
    });
  }
});
