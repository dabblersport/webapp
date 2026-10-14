import test from "node:test";
import assert from "node:assert/strict";
import { FIXTURE_GAME_ID } from "../lib/guards.mjs";
import { makeReporter } from "../lib/report.mjs";
import { runLive } from "../lib/live.mjs";

const jwt = (claims) => ["x", Buffer.from(JSON.stringify(claims)).toString("base64url"), "sig"].join(".");
const URL_OK = "https://wtncuzcskpigqpmnxwws.supabase.co";
const CONV = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

// A fake client that records every write (rpc), channel and worker call. No network.
function fakeWorld({ profilesByUid, rosterByUid }) {
  const writes = [];
  const channels = [];
  const fetches = [];
  const uidOf = { "a@test": "uid-a", "b@test": "uid-b" };
  const createClient = () => {
    let uid = null;
    return {
      auth: {
        signInWithPassword: async ({ email }) => {
          uid = uidOf[email];
          return { data: { user: { id: uid }, session: { access_token: jwt({ iat: 1, exp: 3601 }) } }, error: null };
        },
        signOut: async () => ({}),
        refreshSession: async () => ({ error: null }),
      },
      from: (table) => ({
        select: () => ({
          eq: async () => ({
            data: table === "profiles" ? profilesByUid[uid] : rosterByUid[uid],
            error: null,
          }),
        }),
      }),
      rpc: async (name) => {
        writes.push(name);
        return { error: null };
      },
      channel: (t) => {
        channels.push(t);
        throw new Error("a channel must not be opened before the guards pass");
      },
      removeChannel: async () => {},
      removeAllChannels: () => {},
    };
  };
  return { createClient, writes, channels, fetches };
}

function deps(world, overrides = {}) {
  const lines = [];
  const reporter = makeReporter((l) => lines.push(l));
  return {
    lines,
    d: {
      env: {
        SUPABASE_URL: URL_OK,
        SUPABASE_ANON_KEY: "anon-key-placeholder",
        MESSAGING_WORKER_URL: "https://worker.example.workers.dev",
        MESSAGING_CONVERSATION_ID: CONV,
      },
      reporter,
      serviceA: "svc-a",
      serviceB: "svc-b",
      readCredential: async (svc) =>
        svc === "svc-a" ? { email: "a@test", password: "PASSWORD-A-SECRET" } : { email: "b@test", password: "PASSWORD-B-SECRET" },
      createClient: world.createClient,
      fetchFn: async (...args) => {
        world.fetches.push(args);
        return { status: 200, json: async () => ({}) };
      },
      sleep: async () => {},
      now: () => Date.now(),
      ...overrides,
    },
  };
}

const testProfile = [{ id: "p", username: "dabbler_test", display_name: "Test" }];
const onFixture = [{ game_id: FIXTURE_GAME_ID, status: "active" }];
const goodWorld = () =>
  fakeWorld({
    profilesByUid: { "uid-a": testProfile, "uid-b": testProfile },
    rosterByUid: { "uid-a": onFixture, "uid-b": onFixture },
  });

async function refused(world, overrides, code) {
  const { d, lines } = deps(world, overrides);
  await assert.rejects(runLive(d), (e) => e.code === code);
  assert.deepEqual(world.writes, [], "no write before the guards pass");
  assert.deepEqual(world.channels, [], "no channel before the guards pass");
  assert.deepEqual(world.fetches, [], "no Worker call before the guards pass");
  const out = lines.join("\n");
  assert.ok(!out.includes("PASSWORD"), "no credential printed");
  assert.ok(!out.includes("eyJ"), "no token printed");
}

test("refuses a wrong project URL before any credential is read", async () => {
  const w = goodWorld();
  let credentialReads = 0;
  await refused(
    w,
    {
      env: { SUPABASE_URL: "https://someother.supabase.co", SUPABASE_ANON_KEY: "k", MESSAGING_WORKER_URL: "https://w.workers.dev", MESSAGING_CONVERSATION_ID: CONV },
      readCredential: async () => {
        credentialReads++;
        return { email: "a@test", password: "x" };
      },
    },
    "wrong-project",
  );
  assert.equal(credentialReads, 0, "no credential is read for a wrong project");
});

test("refuses a non-test profile", async () => {
  const w = fakeWorld({
    profilesByUid: { "uid-a": testProfile, "uid-b": [{ id: "p", username: "real_user", display_name: "Real Person" }] },
    rosterByUid: { "uid-a": onFixture, "uid-b": onFixture },
  });
  await refused(w, {}, "not-a-test-profile");
});

test("refuses an account on a foreign game", async () => {
  const w = fakeWorld({
    profilesByUid: { "uid-a": testProfile, "uid-b": testProfile },
    rosterByUid: { "uid-a": onFixture, "uid-b": [...onFixture, { game_id: "99999999-9999-4999-8999-999999999999", status: "active" }] },
  });
  await refused(w, {}, "foreign-game");
});

test("refuses when the environment is incomplete or malformed", async () => {
  const w = goodWorld();
  const { d } = deps(w, { env: { SUPABASE_URL: URL_OK } });
  await assert.rejects(runLive(d), (e) => e.code === "missing-env");
  const { d: d2 } = deps(w, { env: { SUPABASE_URL: URL_OK, SUPABASE_ANON_KEY: "k", MESSAGING_WORKER_URL: "http://insecure", MESSAGING_CONVERSATION_ID: CONV } });
  await assert.rejects(runLive(d2), (e) => e.code === "bad-env");
});
