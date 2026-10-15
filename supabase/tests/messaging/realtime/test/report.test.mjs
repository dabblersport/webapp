import test from "node:test";
import assert from "node:assert/strict";
import { formatLine, makeReporter, safeText } from "../lib/report.mjs";
import { makeCapture, summarizeWake } from "../lib/capture.mjs";
import { parseAccount, readCredential } from "../lib/keychain.mjs";

test("a line prints status, id, reason and counts only", () => {
  assert.equal(formatLine("T1", "PASS", "lifetime", { seconds: 3600 }), "PASS    T1  lifetime | seconds=3600");
  assert.throws(() => formatLine("T1", "MAYBE"));
  assert.throws(() => formatLine("T1", "PASS", "", { who: "someone" }), TypeError, "counts are numbers or booleans");
});

test("token-, key- and hex-looking text is withheld", () => {
  const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.abcdefghijklmnop";
  for (const s of [jwt, "key " + "a".repeat(40), "sb_publishable_abc", "Bearer abcdefghijkl"]) {
    assert.match(safeText(s), /withheld/);
  }
  const out = [];
  makeReporter((l) => out.push(l)).line("X", "FAIL", `leak ${jwt}`);
  assert.ok(!out.join("\n").includes("eyJ"));
});

test("a wake is reduced to key names and booleans; no value is kept", () => {
  const conv = "16223736-0ebb-4088-b823-91f3f9ef5643";
  const raw = { event: "msg", type: "broadcast", payload: { type: "msg", conversation_id: conv, seq: 7, id: "platform-id", extra: "SECRET-TEXT" } };
  const s = summarizeWake(raw, conv);
  assert.deepEqual(s.keys, ["conversation_id", "extra", "id", "seq", "type"]);
  assert.equal(s.isMsg, true);
  assert.equal(s.conversationMatches, true);
  assert.ok(!JSON.stringify(s).includes("SECRET-TEXT"));
  assert.ok(!JSON.stringify(s).includes("platform-id"));
  const cap = makeCapture(conv, () => 5);
  cap.onBroadcast({ payload: { type: "sync", conversation_id: "other" } });
  assert.equal(cap.count(), 1);
  assert.equal(cap.wakes[0].isSync, true);
  assert.equal(cap.wakes[0].conversationMatches, false);
  assert.deepEqual(Object.keys(cap.wakes[0]).sort(), ["at", "conversationMatches", "hasSeq", "isMsg", "isSync", "keys"]);
});

test("keychain account is parsed from the attribute listing; reads use security without a shell", async () => {
  assert.equal(parseAccount('keychain: "x"\n    "acct"<blob>="a.test@example.com"\n'), "a.test@example.com");
  assert.equal(parseAccount("nothing"), null);
  const calls = [];
  const exec = async (cmd, args) => {
    calls.push([cmd, args]);
    return args.includes("-w") ? { stdout: "pw-from-keychain\n" } : { stdout: '"acct"<blob>="a.test@example.com"' };
  };
  const cred = await readCredential("dabbler-test-user", exec);
  assert.deepEqual(cred, { email: "a.test@example.com", password: "pw-from-keychain" });
  assert.ok(calls.every(([cmd, args]) => cmd === "security" && args[0] === "find-generic-password" && args.includes("-s")));
});
