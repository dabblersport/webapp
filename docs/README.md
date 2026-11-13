# docs

Plans, release runbooks, architecture and conventions moved to the governance repository,
`dabbler-docs/dabbler-code/` (https://github.com/dabblersport/dabbler-docs), on 2026-11-10.

Three things stay here on purpose, because code or CI reads them at run time:

- `SCHEMA.md` — `scripts/ci/check_anon_allowlist.sh` and `check_anon_function_grants.sh` parse it.
- `LOCAL_RUN.md` — `lib/core/config/environment.dart` points to it, and its test checks that.
- `messaging/` — `test/features/messaging/domain/contract_agreement_test.dart` reads it.

`experiments/` also remains until someone decides where it belongs.
