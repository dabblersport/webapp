# Performance — k6, intentional only

**Owner:** `backend` capability. **Runner:** `qa`, on an explicit trigger only.
**Trigger:** never routine. Thebes routing (`agent/qa/routing.py`) selects `k6_perf` only
when a work item carries the `performance_scope` flag; editing a script under `tests/perf/`
does not make a run routine either.

```bash
npm run test:perf                        # tests/perf/k6/smoke.js, 1 VU, 5s
bash tests/perf/run.sh k6/<script>.js    # a named script
k6 run --vus 5 --duration 30s tests/perf/k6/smoke.js
```

Exit 0 means every threshold in the script held. Summary JSON lands in
`tests/perf/.results/summary.json` (gitignored).

## When a k6 run is justified

- a high-traffic API path
- matchmaking
- booking / availability
- messaging
- a major backend performance change
- a production-readiness milestone

Correctness validation comes first, always; a perf run on a path whose behaviour is not yet
proven measures the wrong thing.

## Rules for scripts

- **Read-only, anon key only.** No mutating RPC, no writes, no user data, no service-role
  key. Load against production must never be a way to change production.
- **One script per named path**, stored here as a reusable Product asset with its thresholds
  in the file, so the next run is the same run.
- **Thresholds are the verdict.** A script without `thresholds` cannot fail and therefore
  proves nothing.
- **Environment from `.env` or the process**; nothing in the script.
