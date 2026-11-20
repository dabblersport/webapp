#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f .env ]]; then
  echo 'Missing .env release configuration' >&2
  exit 1
fi
if [[ ! -f android/key.properties ]]; then
  echo 'Missing Android release signing configuration' >&2
  exit 1
fi
python3 - <<'PYCONFIG'
import json
from pathlib import Path

config = {}
for line in Path('.env').read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        key, value = line.split('=', 1)
        config[key.strip()] = value.strip().strip('"').strip("'")

required = ('SUPABASE_URL', 'GOOGLE_WEB_CLIENT_ID', 'MESSAGING_API_BASE_URL')
missing = [key for key in required if not config.get(key)]
if not (config.get('SUPABASE_PUBLISHABLE_KEY') or config.get('SUPABASE_ANON_KEY')):
    missing.append('SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY')
if missing:
    raise SystemExit('Missing release configuration: ' + ', '.join(missing))

google = json.loads(Path('android/app/google-services.json').read_text())
web_clients = {
    client['client_id']
    for app in google['client']
    for client in app.get('oauth_client', [])
    if client.get('client_type') == 3
}
if config['GOOGLE_WEB_CLIENT_ID'] not in web_clients:
    raise SystemExit('GOOGLE_WEB_CLIENT_ID must match a registered Web OAuth client')
print('Client release configuration validated')
PYCONFIG
exec flutter build appbundle --release --dart-define-from-file=.env "$@"
