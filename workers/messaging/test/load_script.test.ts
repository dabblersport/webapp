// Load script: ONLY the dry-run and refusal paths are exercised. No request is sent.
import { describe, expect, it, vi } from "vitest";
// @ts-expect-error plain .mjs module
import { run, validateConfig } from "../scripts/load/load.mjs";

const base = { PILOT_PEAK_RPS: "5" };

describe("load script refusals", () => {
  it("refuses when MESSAGING_LOAD_BASE_URL is unset", () => {
    expect(() => validateConfig({ ...base })).toThrow(/^REFUSED: MESSAGING_LOAD_BASE_URL is unset/);
  });
  it("refuses a non-local host that is not allow-listed", () => {
    expect(() => validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "https://example.invalid" })).toThrow(/^REFUSED: host/);
  });
  it("refuses when the allow-list names a different host", () => {
    expect(() =>
      validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "https://a.example.invalid", MESSAGING_LOAD_ALLOW_HOST: "example.invalid" }),
    ).toThrow(/^REFUSED: host/);
  });
  it("refuses a protected path without a token", () => {
    expect(() =>
      validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "http://127.0.0.1:8787", MESSAGING_LOAD_PATH: "/v1/whoami" }),
    ).toThrow(/MESSAGING_LOAD_TOKEN/);
  });
  it("refuses without PILOT_PEAK_RPS", () => {
    expect(() => validateConfig({ MESSAGING_LOAD_BASE_URL: "http://localhost:8787" })).toThrow(/PILOT_PEAK_RPS/);
  });
  it("accepts localhost, ::1, and an exactly allow-listed host", () => {
    expect(validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "http://localhost:8787" }).sustainRps).toBe(10);
    expect(validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "http://[::1]:8787" }).host).toBe("[::1]");
    expect(
      validateConfig({ ...base, MESSAGING_LOAD_BASE_URL: "https://staging.example.invalid", MESSAGING_LOAD_ALLOW_HOST: "staging.example.invalid" }).host,
    ).toBe("staging.example.invalid");
  });
});

describe("load script dry run", () => {
  it("returns the D26 plan and sends nothing", async () => {
    const doFetch = vi.fn(() => {
      throw new Error("dry run must not send");
    });
    const out = vi.fn();
    const r = await run({ ...base, MESSAGING_LOAD_BASE_URL: "http://127.0.0.1:8787", STEP_PCT: "50", MAX_STEPS: "2" }, { dryRun: true, doFetch, out });
    expect(doFetch).not.toHaveBeenCalled();
    expect(r.phases.map((p: { rps: number }) => p.rps)).toEqual([10, 15, 23]);
    expect(r.phases[0].name).toBe("sustain-2x-pilot-peak");
  });
  it("a refused config sends nothing either", async () => {
    const doFetch = vi.fn();
    await expect(run({ ...base, MESSAGING_LOAD_BASE_URL: "https://example.invalid" }, { dryRun: false, doFetch, out: vi.fn() })).rejects.toThrow(/REFUSED/);
    expect(doFetch).not.toHaveBeenCalled();
  });
});

describe("load script path / resolved-target guard (KAN-506 QA fix)", () => {
  const local = { ...base, MESSAGING_LOAD_BASE_URL: "http://127.0.0.1:8787", MESSAGING_LOAD_TOKEN: "t" };
  const refused: [string, string][] = [
    ["network-path //host", "//evil.example/x"],
    ["triple slash", "///evil.example"],
    ["slash-backslash", "/\\evil.example/x"],
    ["leading backslashes", "\\\\evil.example"],
    ["tab", "/\tevil"],
    ["tab then slash", "/\t/evil.example"],
    ["newline then slash", "/\n/evil.example"],
    ["absolute http URL", "http://evil.example/x"],
    ["scheme-relative other port", "//127.0.0.1:9999/x"],
    ["bare host", "evil.example/x"],
    ["space", "/a b"],
    ["userinfo @", "/@evil.example"],
  ];
  it.each(refused)("refuses %s", (_name, path) => {
    expect(() => validateConfig({ ...local, MESSAGING_LOAD_PATH: path })).toThrow(/^REFUSED:/);
  });
  it("the QA repro //evil.example/x is refused in dry run and sends nothing", async () => {
    const doFetch = vi.fn();
    await expect(
      run({ ...base, MESSAGING_LOAD_BASE_URL: "http://127.0.0.1:8787", MESSAGING_LOAD_PATH: "//evil.example/x" }, { dryRun: true, doFetch, out: vi.fn() }),
    ).rejects.toThrow(/^REFUSED:/);
    expect(doFetch).not.toHaveBeenCalled();
  });
  it("refuses an allow-listed base whose path would switch protocol/port", () => {
    const b = { ...base, MESSAGING_LOAD_TOKEN: "t", MESSAGING_LOAD_BASE_URL: "https://staging.example.invalid", MESSAGING_LOAD_ALLOW_HOST: "staging.example.invalid" };
    expect(() => validateConfig({ ...b, MESSAGING_LOAD_PATH: "//staging.example.invalid:8443/x" })).toThrow(/^REFUSED:/);
    expect(() => validateConfig({ ...b, MESSAGING_LOAD_PATH: "http://staging.example.invalid/x" })).toThrow(/^REFUSED:/);
  });
  const accepted: [string, string][] = [
    ["default /health", "/health"],
    ["plain path", "/v1/conversations/abc/messages"],
    ["encoded %2F%2F is a literal segment", "/%2F%2Fevil.example"],
    ["query string", "/v1/x?limit=5"],
  ];
  it.each(accepted)("accepts %s and keeps the base origin", (_name, path) => {
    const cfg = validateConfig({ ...local, MESSAGING_LOAD_PATH: path });
    expect(new URL(cfg.target).origin).toBe(new URL(local.MESSAGING_LOAD_BASE_URL).origin);
  });
});

describe("load script never follows a redirect", () => {
  it("sends only to cfg.target with redirect: manual and counts a 302 to another host as an error", async () => {
    const doFetch = vi.fn(async () => ({
      ok: false,
      status: 302,
      type: "basic",
      headers: new Headers({ location: "http://evil.example/x" }),
      arrayBuffer: async () => new ArrayBuffer(0),
    }));
    const report = await run(
      { ...base, PILOT_PEAK_RPS: "20", MESSAGING_LOAD_BASE_URL: "http://127.0.0.1:8787", DURATION_S: "0.05", STEP_DURATION_S: "0.05", MAX_STEPS: "1" },
      { dryRun: false, doFetch, out: vi.fn() },
    );
    expect(doFetch).toHaveBeenCalled();
    for (const [u, init] of doFetch.mock.calls as unknown as [string, RequestInit][]) {
      expect(u).toBe("http://127.0.0.1:8787/health");
      expect(init.redirect).toBe("manual");
    }
    expect(report.results[0].errors).toBe(report.results[0].sent);
    expect(report.sustainPassed).toBe(false);
  });
});
