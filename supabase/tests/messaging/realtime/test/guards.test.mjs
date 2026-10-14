import test from "node:test";
import assert from "node:assert/strict";
import {
  ALLOWED_WAKE_KEYS,
  FIXTURE_GAME_ID,
  GuardError,
  assertOnlyFixtureGame,
  assertProjectUrl,
  assertTestProfiles,
  decodeExpMinusIat,
  keysAllowed,
  runGuards,
} from "../lib/guards.mjs";

const jwt = (claims) =>
  ["x", Buffer.from(JSON.stringify(claims)).toString("base64url"), "sig"].join(".");

test("allowed wake keys include the platform id", () => {
  assert.deepEqual([...ALLOWED_WAKE_KEYS].sort(), ["conversation_id", "id", "seq", "type"]);
});

test("key subset check", () => {
  assert.equal(keysAllowed(["conversation_id", "id", "seq", "type"]), true);
  assert.equal(keysAllowed(["conversation_id", "type"]), true);
  assert.equal(keysAllowed(["conversation_id", "id", "type"]), true);
  assert.equal(keysAllowed([]), true);
  assert.equal(keysAllowed(["type", "text"]), false);
  assert.equal(keysAllowed(["conversation_id", "event"]), false);
  assert.equal(keysAllowed(["sender"]), false);
  assert.equal(keysAllowed(undefined), false);
});

test("exp - iat decoder returns only a number", () => {
  assert.equal(decodeExpMinusIat(jwt({ iat: 1000, exp: 4600, sub: "secret-subject" })), 3600);
  assert.equal(decodeExpMinusIat(jwt({ iat: 10, exp: 70 })), 60);
  assert.throws(() => decodeExpMinusIat("not-a-jwt"), TypeError);
  assert.throws(() => decodeExpMinusIat(jwt({ iat: 1 })), TypeError);
  assert.throws(() => decodeExpMinusIat(123), TypeError);
});

test("guard refuses the wrong project", () => {
  assert.doesNotThrow(() => assertProjectUrl("https://wtncuzcskpigqpmnxwws.supabase.co"));
  for (const bad of [
    "https://other-project.supabase.co",
    "http://wtncuzcskpigqpmnxwws.supabase.co",
    "https://wtncuzcskpigqpmnxwws.supabase.co.evil.com",
    "https://evil.com/wtncuzcskpigqpmnxwws.supabase.co",
    "",
    undefined,
  ]) {
    assert.throws(() => assertProjectUrl(bad), (e) => e instanceof GuardError && e.code === "wrong-project");
  }
});

test("guard refuses a non-test profile", () => {
  assert.doesNotThrow(() => assertTestProfiles("A", [{ username: "dabbler_test_user", display_name: "X" }]));
  assert.doesNotThrow(() => assertTestProfiles("A", [{ username: "zed", display_name: "A Test User" }]));
  assert.throws(
    () => assertTestProfiles("A", [{ username: "real_person", display_name: "Real Person" }]),
    (e) => e.code === "not-a-test-profile",
  );
  assert.throws(
    () => assertTestProfiles("A", [{ username: "a_test", display_name: "x" }, { username: "real", display_name: "Real" }]),
    (e) => e.code === "not-a-test-profile",
    "every profile must be a test profile",
  );
  assert.throws(() => assertTestProfiles("A", []), (e) => e.code === "no-profile");
});

test("guard refuses an account active on a foreign game, ignores history", () => {
  assert.doesNotThrow(() =>
    assertOnlyFixtureGame("A", [
      { game_id: FIXTURE_GAME_ID, status: "active" },
      { game_id: "11111111-1111-4111-8111-111111111111", status: "left" },
      { game_id: "22222222-2222-4222-8222-222222222222", status: "kicked" },
    ]),
  );
  assert.throws(
    () => assertOnlyFixtureGame("B", [{ game_id: "11111111-1111-4111-8111-111111111111", status: "active" }]),
    (e) => e.code === "foreign-game",
  );
});

test("runGuards requires both accounts on the fixture game", () => {
  const ok = { profiles: [{ username: "t_test", display_name: "T" }], roster: [{ game_id: FIXTURE_GAME_ID, status: "active" }] };
  const url = "https://wtncuzcskpigqpmnxwws.supabase.co";
  assert.doesNotThrow(() => runGuards({ supabaseUrl: url, facts: { A: ok, B: ok } }));
  assert.throws(
    () => runGuards({ supabaseUrl: url, facts: { A: ok, B: { ...ok, roster: [] } } }),
    (e) => e.code === "not-on-fixture",
  );
});
