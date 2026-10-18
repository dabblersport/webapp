// KAN-554: the step-6 live check for the messaging launch, against the production Worker, as the two test accounts.
// Prints only statuses, reasons, counts and timings: no password, token, id or message text. It changes no variable,
// deploys nothing and touches no database directly; every write goes through the Worker like the app does
// (one test message, one report). It REFUSES to run while the Worker answers with the off signal.
import { MARKER, call, isOff } from "../killswitch/drill.mjs";

export const NOT_ALL_YET = "MESSAGING_ACCESS_MODE is not all yet";

export function makeLaunchCheck({ fetchFn, cfg, A, B, out, now, uuid }) {
  const steps = [];
  const record = (name, pass, detail) => {
    steps.push({ name, pass, detail });
    out(`${pass ? "PASS" : "FAIL"}  ${name}  ${detail}`);
  };
  const stamp = () => new Date().toISOString();

  // The app's Messages list reads this RPC; count the rows for the game.
  async function messagesList(session) {
    const res = await fetchFn(`${cfg.supabaseUrl}/rest/v1/rpc/msg_my_conversations`, {
      method: "POST",
      headers: { apikey: cfg.anonKey, Authorization: `Bearer ${session.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_limit: 50 }),
    });
    let rows = null;
    try {
      rows = await res.json();
    } catch {
      rows = null;
    }
    return { status: res.status, rows: Array.isArray(rows) ? rows : null };
  }

  async function run() {
    out(`Launch check started ${stamp()}`);
    const conv = (s) => call(fetchFn, cfg, s, "GET", `/v1/games/${cfg.gameId}/conversation`);

    // Gate: refuse unless the Worker is open.
    const a0 = await conv(A);
    if (isOff(a0)) {
      out(NOT_ALL_YET);
      return { refused: true, reason: "off", steps };
    }
    if (a0.status !== 200) {
      out(`REFUSED: the Worker answered ${a0.status}${a0.reason ? ` (${a0.reason})` : ""} to the first request, so the check cannot start`);
      return { refused: true, reason: `status-${a0.status}`, steps };
    }
    out(`Gate open (${stamp()}): the Worker answers past the access gate.`);

    const b0 = await conv(B);
    const sameConv = a0.conversationId && a0.conversationId === b0.conversationId;
    record("1 both members get the game conversation", b0.status === 200 && sameConv, `A=${a0.status} B=${b0.status} same_conversation=${Boolean(sameConv)}`);
    record("2 the conversation is writable (game not ended)", a0.writable === true && b0.writable === true, `A=${a0.writable} B=${b0.writable} reason=${a0.readOnlyReason ?? "none"}`);
    if (!(a0.writable === true && b0.writable === true)) return { refused: false, steps, stopped: "not-writable" };
    const cid = a0.conversationId;

    const marker = `${MARKER} ${uuid().slice(0, 8)}`;
    const t0 = now();
    const send = await call(fetchFn, cfg, A, "POST", `/v1/conversations/${cid}/messages`, { body: { body: marker }, idempotencyKey: uuid() });
    record("3 A sends one test message", send.status === 201, `status=${send.status} reason=${send.reason ?? "none"} ms=${Math.round(now() - t0)}`);
    if (send.status !== 201) return { refused: false, steps, stopped: "send-failed" };

    // B reads it back. The list call counts messages that start with the drill marker; we send a unique one, so count B's view directly.
    const listRes = await fetchFn(`${cfg.workerUrl}/v1/conversations/${cid}/messages?limit=30`, { headers: { Authorization: `Bearer ${B.token}` } });
    let list = null;
    try {
      list = await listRes.json();
    } catch {
      list = null;
    }
    const msgs = Array.isArray(list?.messages) ? list.messages : [];
    const mine = msgs.filter((m) => m?.body === marker);
    record("4 B lists it (round trip)", listRes.status === 200 && mine.length === 1, `status=${listRes.status} marker_seen=${mine.length}`);

    const mid = mine[0]?.id;
    if (typeof mid === "string") {
      const rep = await fetchFn(`${cfg.workerUrl}/v1/messages/${mid}/report`, {
        method: "POST",
        headers: { Authorization: `Bearer ${B.token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ reason: "other" }),
      });
      record("5 B files a report on it", rep.status === 202, `status=${rep.status}`);
    } else {
      record("5 B files a report on it", false, "no message id to report");
    }

    for (const [label, s] of [["A", A], ["B", B]]) {
      const ml = await messagesList(s);
      const n = ml.rows ? ml.rows.filter((r) => r?.conversation_id === cid).length : -1;
      record(`6 Messages list of ${label} shows the game chat`, ml.status === 200 && n === 1, `status=${ml.status} rows_for_this_chat=${n}`);
    }
    out(`Launch check finished ${stamp()}: ${steps.filter((s) => s.pass).length} of ${steps.length} passed`);
    return { refused: false, steps };
  }
  return { run };
}
