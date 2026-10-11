# Running Dabbler locally

The one standard way to run the app on iOS, Android and Chrome:

```bash
cd Dabbler/dabbler-code        # the app repository root (where pubspec.yaml is)
flutter run -d <device-id>     # ids: `flutter devices`
```

No `--dart-define` flags, wrapper script or alternate entrypoint are needed after
the one-time setup below.

## One-time setup

The app needs client-side configuration (Supabase URL and anon key, app name,
environment). It is read from `.env`, which is gitignored and never committed.

1. Create your local `.env` (copy `.env.example`, fill in the **client** values
   for the backend you use). Never put a service-role key or any server secret
   in it.
2. Select it for plain `flutter run`:

   ```bash
   scripts/setup_local_env.sh
   ```

   This checks the required key **names** (never printing values) and writes
   `assets/config/local.env` (gitignored), which debug and profile runs read when
   no `--dart-define` values are supplied. **Only an allowlist of client-safe keys
   is copied** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PUBLISHABLE_KEY`,
   `APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`); every other key in your
   `.env` is dropped, and the script prints the **names** it kept and dropped.

That is the only setup. Repeated `flutter run` commands keep using it.

### Switching or checking the local selection

```bash
scripts/setup_local_env.sh --from other.env   # select a different config file
scripts/setup_local_env.sh --check            # which required keys are set (names only)
scripts/setup_local_env.sh --clear            # remove the local selection
```

Run `flutter run` again (or hot restart) after changing it: the file is bundled as
an asset at build time.

## How configuration is resolved

For every key, in this order:

1. A `--dart-define` / `--dart-define-from-file` value (CI, release builds, and
   anyone who still passes flags) always wins. When the build supplies the
   required values, the local file is not read at all.
2. Otherwise, in debug and profile builds only, `assets/config/local.env`.
3. Otherwise the app stops at start-up and shows a **"Dabbler failed to start"**
   screen naming the missing keys and the setup command (it does not wait on the
   splash). `lib/core/config/environment.dart` is the single place that does this.

Release builds never read `assets/config/local.env`. Build releases and web
deployments with `--dart-define` values (see `scripts/cloudflare-build.sh`).

**Release/CI guard.** The file would otherwise be bundled into (and, on web,
served from) a release built on a machine that has a local selection. So
`scripts/check_no_local_env.sh` **fails the build** if `assets/config/local.env`
exists; `scripts/cloudflare-build.sh` runs it first. Run it at the start of any
other release or CI build too (iOS/Android archive scripts, CI jobs), or remove
the file first with `scripts/setup_local_env.sh --clear`.

## Targets

| Target | Command |
|---|---|
| iOS simulator | `flutter run -d <simulator-id>` |
| Android emulator/device | `flutter run -d <device-id>` |
| Chrome | `flutter run -d chrome` |

`run.sh` is no longer needed; it remains as an optional wrapper that passes
`--dart-define-from-file=.env` explicitly.

## Troubleshooting

- "Dabbler failed to start: Missing configuration ..." means the one-time setup
  has not been done (or a key is missing): run `scripts/setup_local_env.sh`.
- Changed `.env`? Run `scripts/setup_local_env.sh` again, then `flutter run`.
