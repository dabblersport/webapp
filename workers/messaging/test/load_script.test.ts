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
