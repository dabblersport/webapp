import test from "node:test";
import assert from "node:assert/strict";
import { FIXTURE_GAME_ID, GuardError, assertBlockSafe, countForeignActive, runGuards } from "../lib/guards.mjs";
import { makeGuardedActions } from "../lib/actions.mjs";

const FOREIGN = "99999999-9999-4999-8999-999999999999";
const THIRD = "33333333-3333-4333-8333-333333333333";
const URL_OK = "https://wtncuzcskpigqpmnxwws.supabase.co";

function wrapper() {
  const sent = [];
  const client = { rpc: async (name, params) => (sent.push([name, params]), { error: null }) };
  const act = makeGuardedActions({ fixtureGameId: FIXTURE_GAME_ID, uidA: "uid-a", profileIdB: "prof-b" });
  return { sent, client, act };
}

test("wrapper allows exactly the fixture-scoped calls", async () => {
  const { sent, client, act } = wrapper();
  await act("B", client, "rpc_leave_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
  await act("B", client, "rpc_join_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
  await act("A", client, "rpc_remove_player", { p_game_id: FIXTURE_GAME_ID, p_profile_id: "prof-b" });
  await act("B", client, "rpc_block_user", { p_peer: "uid-a" });
  await act("B", client, "rpc_unblock_user", { p_peer: "uid-a" });
  assert.equal(sent.length, 5);
});

test("a roster call with a foreign game id is refused before any request", () => {
  const { sent, client, act } = wrapper();
  for (const name of ["rpc_leave_game", "rpc_join_game"]) {
    assert.throws(() => act("B", client, name, { p_actor_type: "player", p_game_id: FOREIGN }), (e) => e.code === "foreign-target");
  }
  assert.throws(() => act("A", client, "rpc_remove_player", { p_game_id: FOREIGN, p_profile_id: "prof-b" }), (e) => e.code === "foreign-target");
  assert.deepEqual(sent, []);
});

test("a removal of anyone but B, or a block of a third user, is refused before any request", () => {
  const { sent, client, act } = wrapper();
  assert.throws(() => act("A", client, "rpc_remove_player", { p_game_id: FIXTURE_GAME_ID, p_profile_id: "someone-else" }), (e) => e.code === "foreign-target");
  assert.throws(() => act("B", client, "rpc_block_user", { p_peer: THIRD }), (e) => e.code === "foreign-target");
  assert.throws(() => act("B", client, "rpc_unblock_user", { p_peer: THIRD }), (e) => e.code === "foreign-target");
  assert.deepEqual(sent, []);
});

test("wrong actor, wrong actor type and unknown functions are refused", () => {
  const { sent, client, act } = wrapper();
  assert.throws(() => act("A", client, "rpc_leave_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID }), (e) => e.code === "foreign-target");
  assert.throws(() => act("B", client, "rpc_join_game", { p_actor_type: "spectator", p_game_id: FIXTURE_GAME_ID }), (e) => e.code === "foreign-target");
  assert.throws(() => act("B", client, "rpc_remove_player", { p_game_id: FIXTURE_GAME_ID, p_profile_id: "prof-b" }), (e) => e.code === "foreign-target");
  assert.throws(() => act("A", client, "rpc_delete_game", { p_game_id: FIXTURE_GAME_ID }), (e) => e.code === "foreign-target");
  assert.deepEqual(sent, []);
});

test("a refusal message names no game id and no user id", () => {
  const { client, act } = wrapper();
  try {
    act("B", client, "rpc_join_game", { p_actor_type: "player", p_game_id: FOREIGN });
    assert.fail("should refuse");
  } catch (e) {
    assert.ok(e instanceof GuardError);
    assert.ok(!e.message.includes(FOREIGN));
    assert.ok(!/[0-9a-f]{8}-[0-9a-f]{4}/i.test(e.message));
  }
});

test("rule 1: B on another game is refused; rule 2: A on other games is allowed, count only", () => {
  const profiles = [{ username: "x_test", display_name: "T" }];
  const onFixture = { game_id: FIXTURE_GAME_ID, status: "active" };
  const other = (n) => ({ game_id: `0000000${n}-0000-4000-8000-000000000000`, status: "active" });
  const A = { profiles, roster: [onFixture, other(1), other(2), other(3), other(4), other(5), { game_id: "x", status: "left" }] };
  const B = { profiles, roster: [onFixture] };
  const out = runGuards({ supabaseUrl: URL_OK, facts: { A, B } });
  assert.deepEqual(out, { aOtherGames: 5 });
  assert.equal(countForeignActive(A.roster), 5);
  assert.throws(() => runGuards({ supabaseUrl: URL_OK, facts: { A: B, B: { profiles, roster: [onFixture, other(1)] } } }), (e) => e.code === "foreign-game");
});

test("rule 4: a block is refused when B hosts a game or follows others, or the facts are unknown", () => {
  assert.doesNotThrow(() => assertBlockSafe({ hostedGames: 0, followsWithOthers: 0 }));
  assert.throws(() => assertBlockSafe({ hostedGames: 1, followsWithOthers: 0 }), (e) => e.code === "block-unsafe");
  assert.throws(() => assertBlockSafe({ hostedGames: 0, followsWithOthers: 2 }), (e) => e.code === "block-unsafe");
  assert.throws(() => assertBlockSafe({ hostedGames: null, followsWithOthers: null }), (e) => e.code === "block-unsafe");
});

test("rule 5: the project and test-profile guards still refuse", () => {
  const ok = { profiles: [{ username: "a_test", display_name: "T" }], roster: [{ game_id: FIXTURE_GAME_ID, status: "active" }] };
  assert.throws(() => runGuards({ supabaseUrl: "https://x.supabase.co", facts: { A: ok, B: ok } }), (e) => e.code === "wrong-project");
  const real = { ...ok, profiles: [{ username: "real", display_name: "Real" }] };
  assert.throws(() => runGuards({ supabaseUrl: URL_OK, facts: { A: real, B: ok } }), (e) => e.code === "not-a-test-profile");
  assert.throws(() => runGuards({ supabaseUrl: URL_OK, facts: { A: ok, B: real } }), (e) => e.code === "not-a-test-profile");
});
