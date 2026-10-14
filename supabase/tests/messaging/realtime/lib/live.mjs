// KAN-545: the live scenarios. Everything external is injected (clients, fetch, clock, Keychain reader, reporter)
// so the guard paths can be unit tested with fakes and no network. This file never prints anything itself: all
// output goes through the reporter (PASS/FAIL lines, counts and timings only). No credential, token, key or wake
// payload value is stored or printed; wakes are reduced to key names and booleans by lib/capture.mjs.

import { randomUUID } from "node:crypto";
import { FIXTURE_GAME_ID, GuardError, assertProjectUrl, decodeExp, decodeExpMinusIat, keysAllowed, runGuards } from "./guards.mjs";
import { makeCapture } from "./capture.mjs";

const WAKE_WAIT_MS = 3000; // T-A1: a wake must arrive within 3 s
const QUIET_WINDOW_MS = 3000; // how long "receives nothing" is observed
const SYNC_WAIT_MS = 5000; // T-A4
const T4_GRACE_MS = 30_000;
const POLL_MS = 50;

export const PRECONDITIONS = [
  "Worker MESSAGING_ACCESS_MODE is \"allowlist\" for this run (the runner does not deploy; set it back to \"off\" afterwards).",
  "Both test accounts are in public.msg_access_allowlist.",
  "A (Keychain dabbler-test-user) is the HOST of the fixture game and B (dabbler-test-user-b) is an active player on it.",
  "MESSAGING_CONVERSATION_ID is the msg_conversations id of the fixture game (clients cannot read that table).",
  "T-A4 needs KAN-542's SQL (and the Vault secret) applied; without it that test reports NOT RUN.",
];

export function readEnv(env) {
  const need = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "MESSAGING_WORKER_URL", "MESSAGING_CONVERSATION_ID"];
  const missing = need.filter((k) => !env[k]);
  if (missing.length > 0) throw new GuardError("missing-env", `missing environment: ${missing.join(", ")}`);
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuid.test(env.MESSAGING_CONVERSATION_ID)) throw new GuardError("bad-env", "MESSAGING_CONVERSATION_ID is not a uuid");
  if (!/^https:\/\//i.test(env.MESSAGING_WORKER_URL)) throw new GuardError("bad-env", "MESSAGING_WORKER_URL must be https");
  return {
    supabaseUrl: env.SUPABASE_URL,
    anonKey: env.SUPABASE_ANON_KEY,
    workerUrl: env.MESSAGING_WORKER_URL.replace(/\/+$/, ""),
    conversationId: env.MESSAGING_CONVERSATION_ID.toLowerCase(),
    t4MaxWaitMs: Math.max(0, Number(env.T4_MAX_WAIT_SECONDS ?? 900)) * 1000,
  };
}

/** Reads the facts the guards need, as the signed-in account (RLS limits it to its own rows). */
export async function readFacts(client, uid) {
  const prof = await client.from("profiles").select("id, username, display_name").eq("user_id", uid);
  const roster = await client.from("game_roster").select("game_id, status").eq("user_id", uid);
  if (prof.error || roster.error) throw new GuardError("facts-unreadable", "could not read the account's own profile or roster");
  return { profiles: prof.data ?? [], roster: roster.data ?? [] };
}

export async function runLive(deps) {
  const { env, reporter, readCredential, createClient, fetchFn, sleep, now } = deps;
  const cfg = readEnv(env);
  assertProjectUrl(cfg.supabaseUrl); // before any credential is read or sent anywhere
  const cleanup = [];
  const captures = [];

  const sessionFor = async (label, service, opts = {}) => {
    const cred = await readCredential(service);
    const client = createClient(cfg.supabaseUrl, cfg.anonKey, {
      auth: { autoRefreshToken: opts.autoRefresh !== false, persistSession: false },
    });
    const { data, error } = await client.auth.signInWithPassword({ email: cred.email, password: cred.password });
    if (error || !data?.session) throw new GuardError("sign-in", `${label}: sign-in failed`);
    cleanup.push(() => client.auth.signOut({ scope: "local" }).catch(() => {}));
    return { client, uid: data.user.id, token: () => data.session.access_token, session: data.session };
  };

  const listen = (client, topic, isPrivate, label) =>
    new Promise((resolve) => {
      const cap = makeCapture(cfg.conversationId, now);
      captures.push({ label, cap });
      let status = "CONNECTING";
      const channel = client
        .channel(topic, { config: { private: isPrivate } })
        .on("broadcast", { event: "msg" }, (raw) => cap.onBroadcast(raw));
      cleanup.push(() => client.removeChannel(channel).catch(() => {}));
      const handle = { cap, channel, status: () => status, subscribed: false };
      let settled = false;
      const settle = () => {
        if (!settled) {
          settled = true;
          resolve(handle);
        }
      };
      channel.subscribe((s) => {
        status = s;
        handle.subscribed = s === "SUBSCRIBED";
        if (s !== "SUBSCRIBED" || !settled) settle();
      });
      setTimeout(settle, 8000);
    });

  const waitFor = async (pred, ms) => {
    const end = now() + ms;
    while (now() < end) {
      if (pred()) return true;
      await sleep(POLL_MS);
    }
    return pred();
  };

  const worker = async (token, method, path, body) => {
    const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
    if (method === "POST") headers["Idempotency-Key"] = randomUUID();
    const res = await fetchFn(`${cfg.workerUrl}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
    let reason = null;
    try {
      const j = await res.json();
      reason = j?.error?.reason ?? null;
    } catch {
      /* not json */
    }
    return { status: res.status, reason };
  };
  const send = (token) =>
    worker(token, "POST", `/v1/conversations/${cfg.conversationId}/messages`, { body: "kan545 realtime check" });

  try {
    reporter.note("KAN-545 Realtime live runner. Preconditions (printed, never changed by the runner):");
    PRECONDITIONS.forEach((p) => reporter.note(` - ${p}`));

    // ---- sign in and guard BEFORE any write -------------------------------------------------------------
    const A = await sessionFor("A", deps.serviceA);
    const B = await sessionFor("B", deps.serviceB);
    const facts = { A: await readFacts(A.client, A.uid), B: await readFacts(B.client, B.uid) };
    runGuards({ supabaseUrl: cfg.supabaseUrl, facts });
    reporter.note("Guards passed: project, test profiles, fixture game only.");
    const bProfileId = facts.B.profiles[0].id;
    // Registered BEFORE the first roster change (T-A4 leave, removal): whatever throws later, finally rejoins B.
    // rpc_join_game is idempotent for an already-active member.
    cleanup.push(async () => {
      await B.client.rpc("rpc_join_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
    });

    // ---- T1 ---------------------------------------------------------------------------------------------
    const life = decodeExpMinusIat(A.token());
    reporter.line("T1", life === 3600 ? "PASS" : "FAIL", "access token lifetime exp-iat in seconds (expected 3600)", { seconds: life });

    // ---- listeners: A, A on a second device, B (all private), anon non-private ------------------------------
    const lA = await listen(A.client, `user:${A.uid}`, true, "A");
    const A2 = await sessionFor("A-device-2", deps.serviceA);
    const lA2 = await listen(A2.client, `user:${A2.uid}`, true, "A2");
    const lB = await listen(B.client, `user:${B.uid}`, true, "B");
    const anon = createClient(cfg.supabaseUrl, cfg.anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
    cleanup.push(() => anon.removeAllChannels?.());
    const lAnon = await listen(anon, `user:${B.uid}`, false, "anon-nonprivate");
    reporter.note(
      `Listeners subscribed: A=${lA.subscribed} A2=${lA2.subscribed} B=${lB.subscribed} anon-nonprivate=${lAnon.subscribed}`,
    );

    // ---- T-A1, T-A2, T7: one message from A -----------------------------------------------------------------
    {
      const mB = lB.cap.count();
      const mA2 = lA2.cap.count();
      const mAnon = lAnon.cap.count();
      const t0 = now();
      const r = await send(A.token());
      const gotB = await waitFor(() => lB.cap.count() > mB, WAKE_WAIT_MS);
      const gotA2 = await waitFor(() => lA2.cap.count() > mA2, WAKE_WAIT_MS);
      await sleep(500);
      const wakeB = lB.cap.since(mB);
      reporter.line(
        "T-A1",
        r.status === 201 && gotB && wakeB.every((w) => w.isMsg && w.conversationMatches) ? "PASS" : "FAIL",
        "a message from A wakes B within 3 s on a valid connection",
        { sendStatus: r.status, wakes: wakeB.length, ms: gotB ? wakeB[0].at - t0 : -1 },
      );
      reporter.line("T-A2", gotA2 ? "PASS" : "FAIL", "A's own other-device topic is woken", { wakes: lA2.cap.count() - mA2 });
      reporter.line(
        "T7",
        lAnon.cap.count() - mAnon === 0 ? "PASS" : "FAIL",
        "a NON-private join of the topic receives nothing private",
        { received: lAnon.cap.count() - mAnon, joined: lAnon.subscribed },
      );
    }

    // ---- T-A3: B blocks A ----------------------------------------------------------------------------------
    {
      const blocked = await B.client.rpc("rpc_block_user", { p_peer: A.uid });
      cleanup.push(() => B.client.rpc("rpc_unblock_user", { p_peer: A.uid }));
      if (blocked.error) {
        reporter.line("T-A3", "FAIL", "B could not block A", { blockOk: false });
      } else {
        const m = lB.cap.count();
        await send(A.token());
        await sleep(QUIET_WINDOW_MS);
        const n = lB.cap.count() - m;
        reporter.line("T-A3", n === 0 ? "PASS" : "FAIL", "after B blocks A, B gets no wake from A's next message", { wakes: n });
      }
      await B.client.rpc("rpc_unblock_user", { p_peer: A.uid });
    }

    // ---- T-A4: B leaves and rejoins; A gets a sync wake (needs KAN-542 applied) --------------------------------
    {
      const m = lA.cap.count();
      await B.client.rpc("rpc_leave_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
      await waitFor(() => lA.cap.since(m).some((w) => w.isSync), SYNC_WAIT_MS);
      const afterLeave = lA.cap.since(m).filter((w) => w.isSync).length;
      await B.client.rpc("rpc_join_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
      await waitFor(() => lA.cap.since(m).filter((w) => w.isSync).length > afterLeave, SYNC_WAIT_MS);
      const total = lA.cap.since(m).filter((w) => w.isSync).length;
      if (total === 0) {
        reporter.line("T-A4", "NOT RUN", "no sync wake arrived: KAN-542's SQL is not applied yet (or its Vault secret is absent)", { syncWakes: 0 });
      } else {
        reporter.line("T-A4", "PASS", "a leave and a join of B produce a sync wake for A", { afterLeave, syncWakesTotal: total });
      }
    }

    // ---- removal: T3, T5, T6 -------------------------------------------------------------------------------
    {
      const removed = await A.client.rpc("rpc_remove_player", { p_game_id: FIXTURE_GAME_ID, p_profile_id: bProfileId });
      if (removed.error) {
        for (const id of ["T3", "T5", "T6"]) reporter.line(id, "FAIL", "A could not remove B from the fixture game", { removeOk: false });
      } else {
        await sleep(1000);
        // T3: B refreshes its session, then A's next message wakes B zero times.
        const rf = await B.client.auth.refreshSession();
        const m3 = lB.cap.count();
        await send(A.token());
        await sleep(QUIET_WINDOW_MS);
        const n3 = lB.cap.count() - m3;
        reporter.line("T3", !rf.error && n3 === 0 ? "PASS" : "FAIL", "after removal and refreshSession(), B receives 0 wakes", { refreshOk: !rf.error, wakes: n3 });

        // T5: B gets 0 wakes on its own topic, and joining A's private topic is refused or silent.
        const m5 = lB.cap.count();
        const lForeign = await listen(B.client, `user:${A.uid}`, true, "B-on-A-topic");
        const mF = lForeign.cap.count();
        await send(A.token());
        await sleep(QUIET_WINDOW_MS);
        const own = lB.cap.count() - m5;
        const foreign = lForeign.cap.count() - mF;
        reporter.line("T5", own === 0 && foreign === 0 ? "PASS" : "FAIL", "after removal B gets 0 wakes; A's private topic is refused or silent", {
          ownTopicWakes: own,
          foreignTopicWakes: foreign,
          foreignJoinRefused: !lForeign.subscribed,
        });

        // T6: B's next list call returns the reason `removed`.
        const list = await worker(B.token(), "GET", `/v1/conversations/${cfg.conversationId}/messages?limit=1`);
        reporter.line("T6", list.status === 403 && list.reason === "removed" ? "PASS" : "FAIL", "B's next list returns the reason removed", {
          status: list.status,
          reasonIsRemoved: list.reason === "removed",
        });
      }
      // restore B's membership now (also registered in cleanup in case something threw above)
      await B.client.rpc("rpc_join_game", { p_actor_type: "player", p_game_id: FIXTURE_GAME_ID });
      const back = await readFacts(B.client, B.uid);
      const restored = back.roster.some((r) => r.game_id === FIXTURE_GAME_ID && r.status === "active");
      reporter.line("RESTORE", restored ? "PASS" : "FAIL", "B is an active member of the fixture game again", { restored });
    }

    // ---- T9: every captured wake's key set is a subset of {type, conversation_id, seq, id} ------------------------
    {
      const all = captures.flatMap((c) => c.cap.wakes);
      const bad = all.filter((w) => !keysAllowed(w.keys)).length;
      const wrongConv = all.filter((w) => !w.conversationMatches).length;
      if (all.length === 0) reporter.line("T9", "NOT RUN", "no wake was captured", { wakes: 0 });
      else
        reporter.line("T9", bad === 0 && wrongConv === 0 ? "PASS" : "FAIL", "every wake key set is a subset of {type, conversation_id, seq, id}", {
          wakes: all.length,
          badKeySets: bad,
          wrongConversation: wrongConv,
        });
    }

    // ---- T4: a client that never refreshes keeps its socket no longer than exp + 30 s -------------------------------
    {
      const C = await sessionFor("A-no-refresh", deps.serviceA, { autoRefresh: false });
      const lC = await listen(C.client, `user:${C.uid}`, true, "A-no-refresh");
      const expMs = decodeExp(C.token()) * 1000;
      const waitMs = expMs + T4_GRACE_MS - now();
      if (!lC.subscribed) {
        reporter.line("T4", "FAIL", "the no-refresh client could not subscribe", { subscribed: false });
      } else if (waitMs > cfg.t4MaxWaitMs) {
        reporter.line("T4", "NOT RUN", `needs ${Math.ceil(waitMs / 60000)} min of wall time, more than the ${Math.round(cfg.t4MaxWaitMs / 60000)} min limit (set T4_MAX_WAIT_SECONDS to run it)`, {
          waitSeconds: Math.ceil(waitMs / 1000),
        });
      } else {
        const dropped = await waitFor(() => lC.status() !== "SUBSCRIBED", Math.max(0, waitMs) + 5000);
        const afterExp = Math.round((now() - expMs) / 1000);
        reporter.line("T4", dropped && afterExp <= T4_GRACE_MS / 1000 ? "PASS" : "FAIL", "the socket of a never-refreshing client closes by exp + 30 s", {
          disconnected: dropped,
          secondsAfterExp: afterExp,
        });
      }
    }

    reporter.line("T2", "N-A", "per-user topics (CEO design): there is no shared topic to test");
    reporter.line("T8", "SKIPPED", "CEO ruling: load test skipped");
  } finally {
    for (const fn of cleanup.reverse()) {
      try {
        await fn();
      } catch {
        /* cleanup is best effort */
      }
    }
    reporter.note("Operator: set the Worker MESSAGING_ACCESS_MODE back to \"off\" with your normal config process. The runner does not deploy.");
  }
  return reporter.results;
}
