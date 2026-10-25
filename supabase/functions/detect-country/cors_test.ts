// Run: `deno test supabase/functions/detect-country/cors_test.ts`, or with Node
// (a copy of cors.ts + this file in a folder whose package.json has
// {"type":"module"}): `node --test cors_test.ts`.
import assert from "node:assert/strict";
import { test } from "node:test";
import { corsHeaders, isAllowedOrigin } from "./cors.ts";

const req = (origin?: string) =>
  new Request("https://x.supabase.co/functions/v1/detect-country", {
    headers: origin ? { Origin: origin } : {},
  });

test("the app origins, previews and localhost are allowed", () => {
  for (
    const o of [
      "https://app.dabbler.pro",
      "https://canary.dabbler.pro",
      "https://alpha.dabbler.pro",
      "https://webapp.pages.dev",
      "https://abc123.webapp.pages.dev",
      "https://alpha-x.webapp.pages.dev",
      "http://localhost:8640",
      "http://localhost",
    ]
  ) {
    assert.equal(corsHeaders(req(o))["Access-Control-Allow-Origin"], o, o);
  }
});

test("other origins get no allow-origin header", () => {
  for (
    const o of [
      "https://evil.example",
      "https://app.dabbler.pro.evil.example",
      "http://app.dabbler.pro",
      "https://webapp.pages.dev.evil.example",
      "http://localhost.evil.example",
      "http://localhost:80@evil.example",
    ]
  ) {
    assert.equal(isAllowedOrigin(o), false, o);
    assert.equal(corsHeaders(req(o))["Access-Control-Allow-Origin"], undefined);
  }
  assert.equal(
    corsHeaders(req())["Access-Control-Allow-Origin"],
    undefined,
  );
});

test("the allow-headers carry every header the app sends", () => {
  const h = corsHeaders(req("http://localhost:8640"))[
    "Access-Control-Allow-Headers"
  ].toLowerCase();
  for (const n of ["authorization", "apikey", "content-type", "x-client-info"]) {
    assert.ok(h.includes(n), n);
  }
  assert.equal(
    corsHeaders(req("http://localhost:8640"))["Access-Control-Allow-Methods"],
    "GET, OPTIONS",
  );
});
