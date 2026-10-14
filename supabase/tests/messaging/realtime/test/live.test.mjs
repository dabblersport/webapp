import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { FIXTURE_GAME_ID } from "../lib/guards.mjs";
import { makeReporter } from "../lib/report.mjs";
import { runLive } from "../lib/live.mjs";

const jwt = (claims) => ["x", Buffer.from(JSON.stringify(claims)).toString("base64url"), "sig"].join(".");
const URL_OK = "https://wtncuzcskpigqpmnxwws.supabase.co";
const CONV = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const FOREIGN_IDS = ["01010101-0101-4101-8101-010101010101", "02020202-0202-4202-8202-020202020202"];
const STOP = "STOP-AFTER-GUARDS";

// A fake world: every rpc, channel and Worker call is recorded. No network.
function fakeWorld({ profilesByUid, rosterByUid, hostedByUid = {}, follows = [] }) {
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
            data: table === "profiles" ? profilesByUid[uid] : table === "games" ? hostedByUid[uid] ?? [] : rosterByUid[uid],
            error: null,
          }),
          in: async (col, ids) => ({ data: follows.filter((f) => ids.includes(f[col])), error: null }),
        }),
      }),
      rpc: async (name) => {
        writes.push(name);
        return { error: null };
      },
      channel: (t) => {
        channels.push(t);
        throw new Error(STOP);
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

const testProfile = (id) => [{ id, username: "dabbler_test", display_name: "Test" }];
const onFixture = [{ game_id: FIXTURE_GAME_ID, status: "active" }];
const goodWorld = (extra = {}) =>
  fakeWorld({
    profilesByUid: { "uid-a": testProfile("pa"), "uid-b": testProfile("pb") },
    rosterByUid: { "uid-a": onFixture, "uid-b": onFixture },
    ...extra,
  });

function assertQuiet(lines) {
  const out = lines.join("\n");
  assert.ok(!out.includes("PASSWORD"), "no credential printed");
  assert.ok(!out.includes("eyJ"), "no token printed");
  for (const id of FOREIGN_IDS) assert.ok(!out.includes(id), "no foreign game id printed");
}

async function refused(world, overrides, code) {
  const { d, lines } = deps(world, overrides);
  await assert.rejects(runLive(d), (e) => e.code === code);
  assert.deepEqual(world.writes, [], "no write before the guards pass");
  assert.deepEqual(world.channels, [], "no channel before the guards pass");
  assert.deepEqual(world.fetches, [], "no Worker call before the guards pass");
  assertQuiet(lines);
}

test("refuses a wrong project URL before any credential is read", async () => {
  let credentialReads = 0;
  await refused(
    goodWorld(),
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
  await refused(
    fakeWorld({
      profilesByUid: { "uid-a": testProfile("pa"), "uid-b": [{ id: "pb", username: "real_user", display_name: "Real Person" }] },
      rosterByUid: { "uid-a": onFixture, "uid-b": onFixture },
    }),
    {},
    "not-a-test-profile",
  );
});

test("refuses B on another game, never printing its id", async () => {
  await refused(
    fakeWorld({
      profilesByUid: { "uid-a": testProfile("pa"), "uid-b": testProfile("pb") },
      rosterByUid: { "uid-a": onFixture, "uid-b": [...onFixture, { game_id: FOREIGN_IDS[0], status: "active" }] },
    }),
    {},
    "foreign-game",
  );
});

test("refuses a block when B hosts a game", async () => {
  await refused(goodWorld({ hostedByUid: { "uid-b": [{ id: "g" }] } }), {}, "block-unsafe");
});

test("refuses a block when B follows or is followed by someone but A", async () => {
  await refused(goodWorld({ follows: [{ follower_profile_id: "pb", following_profile_id: "p-third" }] }), {}, "block-unsafe");
  await refused(goodWorld({ follows: [{ follower_profile_id: "p-third", following_profile_id: "pb" }] }), {}, "block-unsafe");
});

test("A on other games is allowed: only the count is printed, then the run continues", async () => {
  const world = fakeWorld({
    profilesByUid: { "uid-a": testProfile("pa"), "uid-b": testProfile("pb") },
    rosterByUid: {
      "uid-a": [...onFixture, ...FOREIGN_IDS.map((game_id) => ({ game_id, status: "active" })), { game_id: "left-one", status: "left" }],
      "uid-b": onFixture,
    },
    follows: [{ follower_profile_id: "pa", following_profile_id: "pb" }, { follower_profile_id: "pb", following_profile_id: "pa" }],
  });
  const { d, lines } = deps(world);
  await assert.rejects(runLive(d), (e) => e.message === STOP, "stopped by the fake at the first channel, i.e. past all guards");
  const out = lines.join("\n");
  assert.match(out, /Account A is also active on 2 other game\(s\)/);
  assert.match(out, /Block check: B hosts 0 game\(s\) and has 0 follow\(s\) with anyone but A/);
  assertQuiet(lines);
  assert.deepEqual(world.writes, ["rpc_join_game"], "only the guarded, fixture-scoped rejoin cleanup wrote");
});

test("refuses when the environment is incomplete or malformed", async () => {
  const w = goodWorld();
  const { d } = deps(w, { env: { SUPABASE_URL: URL_OK } });
  await assert.rejects(runLive(d), (e) => e.code === "missing-env");
  const { d: d2 } = deps(w, { env: { SUPABASE_URL: URL_OK, SUPABASE_ANON_KEY: "k", MESSAGING_WORKER_URL: "http://insecure", MESSAGING_CONVERSATION_ID: CONV } });
  await assert.rejects(runLive(d2), (e) => e.code === "bad-env");
});

test("B's rejoin cleanup is registered once, before the first roster change", () => {
  const src = readFileSync(new URL("../lib/live.mjs", import.meta.url), "utf8");
  const needle = 'cleanup.push(async () => {\n      await act("B", "rpc_join_game"';
  const reg = src.indexOf(needle);
  assert.ok(reg > 0, "a rejoin cleanup callback is registered");
  assert.equal(src.split(needle).length - 1, 1, "registered once");
  for (const change of ['await act("B", "rpc_leave_game"', 'await act("A", "rpc_remove_player"', 'act("B", "rpc_block_user"']) {
    assert.ok(src.indexOf(change) > reg, `${change} comes after the rejoin registration`);
  }
});

test("every roster change and block in the runner goes through the wrapper", () => {
  const src = readFileSync(new URL("../lib/live.mjs", import.meta.url), "utf8");
  assert.ok(!/\.rpc\(/.test(src), "live.mjs never calls client.rpc directly");
  const calls = [...src.matchAll(/\bact\("([AB])", "(rpc_[a-z_]+)"/g)].map((m) => m[2]);
  assert.ok(calls.length >= 6);
  for (const c of calls) assert.ok(["rpc_join_game", "rpc_leave_game", "rpc_remove_player", "rpc_block_user", "rpc_unblock_user"].includes(c));
});
