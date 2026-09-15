// k6 smoke — INTENTIONAL performance validation. Not on any routine path.
//
// Run it on purpose, for a reason that names a risk:
//   npm run test:perf                       (reads SUPABASE_URL / SUPABASE_ANON_KEY from .env)
//   k6 run --vus 5 --duration 30s tests/perf/k6/smoke.js
//
// What this proves: the public edge answers under a small, steady load within
// bounds. What it does not prove: anything about a specific feature. A real
// perf script is written for a named path (matchmaking, booking/availability,
// messaging, a high-traffic RPC) when that path's risk justifies it, and it is
// stored here as a reusable Product asset. Read-only requests only; anon key
// only; never a mutating RPC; never against user data.
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 1,
  duration: '5s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500'],
  },
};

const URL = __ENV.SUPABASE_URL;
const KEY = __ENV.SUPABASE_ANON_KEY;

if (!URL || !KEY) {
  throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY are required (tests/perf/run.sh reads .env)');
}

const headers = { apikey: KEY, Authorization: `Bearer ${KEY}` };

export default function () {
  const health = http.get(`${URL}/auth/v1/health`, { headers: { apikey: KEY } });
  check(health, { 'auth health 200': (r) => r.status === 200 });

  // An allowlisted public view (docs/SCHEMA.md §2f, T-027): anon may read it.
  const view = http.get(`${URL}/rest/v1/v_potential_vibes_default?select=*&limit=1`, { headers });
  check(view, { 'public view 200': (r) => r.status === 200 });

  sleep(1);
}
