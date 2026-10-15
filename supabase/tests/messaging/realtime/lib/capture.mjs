// KAN-545: a wake listener that keeps NO payload value. For each wake it stores only the sorted key names, two
// booleans (is it a sync wake, is it a msg wake), whether the conversation id equals the expected one, whether a
// seq is present, and the arrival time. Nothing else from the payload is kept, so nothing can be printed.

export function summarizeWake(raw, expectedConversationId) {
  const inner = raw && typeof raw === "object" && raw.payload && typeof raw.payload === "object" ? raw.payload : raw;
  const body = inner && typeof inner === "object" ? inner : {};
  return {
    keys: Object.keys(body).sort(),
    isSync: body.type === "sync",
    isMsg: body.type === "msg",
    hasSeq: body.seq !== undefined && body.seq !== null,
    conversationMatches: body.conversation_id === expectedConversationId,
  };
}

export function makeCapture(expectedConversationId, now = () => Date.now()) {
  const wakes = [];
  return {
    wakes,
    onBroadcast(raw) {
      wakes.push({ ...summarizeWake(raw, expectedConversationId), at: now() });
    },
    count() {
      return wakes.length;
    },
    since(mark) {
      return wakes.slice(mark);
    },
  };
}
