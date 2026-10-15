// KAN-545: the ONLY output channel of the runner. It prints PASS / FAIL / N-A / NOT RUN lines with counts and
// timings. A line that looks like a token, a key or a long hex string is refused, so a credential can not be
// printed by mistake even if some code path tried.

const FORBIDDEN = [/eyJ[A-Za-z0-9_-]{10,}/, /[0-9a-f]{32,}/i, /sb_(publishable|secret)_/i, /Bearer\s+\S{8,}/i];

export const STATUSES = ["PASS", "FAIL", "N-A", "NOT RUN", "SKIPPED"];

export function safeText(text) {
  const s = String(text);
  for (const re of FORBIDDEN) {
    if (re.test(s)) return "[withheld: looked like a secret]";
  }
  return s;
}

export function formatLine(id, status, reason = "", counts = {}) {
  if (!STATUSES.includes(status)) throw new Error(`unknown status ${status}`);
  const parts = Object.entries(counts).map(([k, v]) => {
    if (typeof v !== "number" && typeof v !== "boolean") throw new TypeError("counts hold numbers and booleans only");
    return `${k}=${v}`;
  });
  const tail = [reason ? safeText(reason) : "", parts.join(" ")].filter(Boolean).join(" | ");
  return `${status.padEnd(7)} ${id}${tail ? `  ${tail}` : ""}`;
}

export function makeReporter(write = (s) => process.stdout.write(`${s}\n`)) {
  const results = [];
  return {
    results,
    line(id, status, reason, counts) {
      results.push({ id, status });
      write(formatLine(id, status, reason, counts));
    },
    note(text) {
      write(safeText(text));
    },
  };
}
