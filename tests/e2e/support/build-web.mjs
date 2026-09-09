#!/usr/bin/env node
// Builds the static web bundle this harness serves and tests against.
//
// KAN-166 scope boundary: this mirrors scripts/cloudflare-build.sh's
// required env vars and its `flutter build web` invocation so the tested
// bundle matches what actually ships, but it is a separate script — it
// never modifies scripts/cloudflare-build.sh, which stays a read-only
// reference.
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config as loadDotenv } from 'dotenv';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..', '..');

// tests/e2e/.env.e2e is gitignored and optional. process.env always wins,
// so a real CI-injected value is never shadowed by a stale local file.
const envFile = path.join(here, '..', '.env.e2e');
if (existsSync(envFile)) {
  loadDotenv({ path: envFile });
}

const REQUIRED = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'APP_NAME', 'ENVIRONMENT'];
const missing = REQUIRED.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(
    `ERROR: missing required env var(s) for the e2e web build: ${missing.join(', ')}`,
  );
  console.error(
    'Set them in the environment, or copy tests/e2e/.env.e2e.example to tests/e2e/.env.e2e and fill them in.',
  );
  process.exit(1);
}

function run(cmd, args) {
  const result = spawnSync(cmd, args, { cwd: repoRoot, stdio: 'inherit' });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

run('flutter', ['pub', 'get']);

run('flutter', [
  'build',
  'web',
  '--release',
  '--base-href',
  '/',
  `--dart-define=SUPABASE_URL=${process.env.SUPABASE_URL}`,
  `--dart-define=SUPABASE_ANON_KEY=${process.env.SUPABASE_ANON_KEY}`,
  `--dart-define=APP_NAME=${process.env.APP_NAME}`,
  `--dart-define=ENVIRONMENT=${process.env.ENVIRONMENT}`,
  `--dart-define=GOOGLE_WEB_CLIENT_ID=${process.env.GOOGLE_WEB_CLIENT_ID ?? ''}`,
]);
