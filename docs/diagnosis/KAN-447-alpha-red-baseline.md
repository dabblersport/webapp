# KAN-447 — Alpha red baseline: diagnosis of 59 failing render/measure tests

Base: `origin/Alpha` @ `4214cf8d` · Flutter 3.47.5 (stable, rev 6a19cca564) · branch `alpha-deir-el-bahari` · diagnosis only, no change under `lib/` or `test/`.

## Verdict

**All 59 failures have one root cause, and it is the environment — not a stale expectation, not a code regression.**

Every one of the 13 test files loads its fonts with a private `_loadFonts()` (or `loadSettingsFonts()`) that reads
`'${Directory.current.parent.path}/dabbler-design-system/fonts'` and, when that folder is missing, **silently `return`s**
(`if (!file.existsSync()) return;`). The tests therefore only render with the real faces when `dabbler-code` has the
`dabbler-design-system` checkout as a **sibling directory**. In any other layout — a git worktree under `.claude/worktrees/…`
(where every Thebes code team runs), or a CI checkout — the folder does not exist, no font is registered, Flutter's test
engine falls back to **Ahem** (every glyph a full-em square), text is several times too wide, and everything that was
tuned to the real Glory / Meral Sans / Wingx metrics overflows, mis-measures or pushes controls off-screen.

### Proof (two runs, same commit, same SDK, same surface sizes, same text scale)

| run | layout | command | result |
|---|---|---|---|
| A | worktree `…/.claude/worktrees/kan-447-deir` (parent has **no** `dabbler-design-system`) at `4214cf8d` | `flutter test --no-pub <13 files>` | 210 pass, **59 fail** (counts per file equal the ticket: game_venue_detail 9, listings 9, auth_entry 8, admin_moderation_misc 8, account_privacy 6, nav_bar_measure 4, explore_submissions 4, otp_verify_scenarios 3, venue_submissions 2, user_sport_profile 2, notifications 2, profile_screen 1, onboarding_steps 1) |
| B | worktree at `4214cf8d` placed in a folder that has a `dabbler-design-system` sibling (a symlink to the pinned pub-cache copy `…/git/dabbler-design-system-3ba6f7c5…`, the commit `pubspec.lock` resolves to) | `flutter test --no-pub -r expanded -j 4 <13 files>` | **269 pass, 0 fail** (`00:27 +269: All tests passed!`) |

Nothing differs between A and B except whether the font folder is found. That rules out the other candidates the ticket named:

- **Stale expectation** — no: the expectations pass unchanged in B.
- **Code regressed** — no: the same `lib/` passes in B.
- **SDK** — no: the same Flutter 3.47.5 in A and B.
- **Surface size / text scale** — no: unchanged between A and B (the tests set their own surface).
- **Font** — yes: the only variable.

## Where the cause is in the code (file:line)

- `test/support/render_mode.dart:35` — `_dsFontsDir()` already has the *right* behaviour (sibling first, then the path from `.dart_tool/package_config.json` at `:37-52`), and `loadRenderFonts()` (`:62`) uses it. **None of the 13 files calls it.**
- 12 of the 13 files carry their own copy that uses only the sibling path and returns silently when absent:
  `game_venue_detail_render_test.dart:30,35` · `listings_render_test.dart:89,94` · `auth_entry_render_test.dart:44,49` · `admin_moderation_misc_render_test.dart:61,66` · `explore_submissions_render_test.dart:46,51` · `otp_verify_scenarios_render_test.dart:42,47` · `venue_submissions_render_test.dart:99,104` · `user_sport_profile_render_test.dart:43,48` · `notifications_render_test.dart:35,40` · `profile_screen_render_test.dart:39,44` · `onboarding_steps_render_test.dart:41,46` · `nav_bar_measure_test.dart:69-70,78` (sibling, then `../ds-luxor/fonts`).
- `account_privacy_render_test.dart:35` calls `loadSettingsFonts()` = `test/features/profile/settings_render_support.dart:21-29`, same sibling-only, silent-return pattern.
- 29 files under `test/` hardcode `parent.path}/dabbler-design-system` (`grep -rln "parent.path}/dabbler-design-system" test`). The other 16 were not run or diagnosed here (outside this ticket); they are exposed to the same condition by the same pattern, so they are fragile whether or not they are red today.
- `docs/local-design-system.md` documents the sibling layout only for DS development; nothing says render tests need it.

## The 59 failures, grouped by symptom (all one cause: fonts missing → Ahem)

The symptom groups below are how the single cause shows up. They are listed so every failure is accounted for with its own evidence; they are **not** five separate defects.

### S1 — DabblerButton label overflow (DS `lib/src/controls/button.dart:563`; label is `maxLines: 1, softWrap: false`) — 25

| # | test file | test name | evidence |
|---|---|---|---|
| S1.1 | `auth_entry_render_test.dart` | renders auth-welcome - rtl (variant: TargetPlatform.iOS) | DS src/controls/button.dart:563 (113px); features/auth_onboarding/presentation/widgets/auth_entry_parts.dart:318 (109px) |
| S1.2 | `auth_entry_render_test.dart` | renders sheet-language - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (113px); features/auth_onboarding/presentation/widgets/auth_entry_parts.dart:318 (109px) |
| S1.3 | `auth_entry_render_test.dart` | renders sheet-region - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (113px); features/auth_onboarding/presentation/widgets/auth_entry_parts.dart:318 (109px) |
| S1.4 | `game_venue_detail_render_test.dart` | game: no booking, meetup or message-squad action is built | DS src/controls/button.dart:563 (67px) |
| S1.5 | `game_venue_detail_render_test.dart` | renders game-detail - ltr (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (67px) |
| S1.6 | `game_venue_detail_render_test.dart` | renders game-detail - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (67px) |
| S1.7 | `game_venue_detail_render_test.dart` | renders game-detail-full - ltr (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (67px) |
| S1.8 | `game_venue_detail_render_test.dart` | renders game-detail-full - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (67px) |
| S1.9 | `game_venue_detail_render_test.dart` | renders game-detail-host - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (51px) |
| S1.10 | `game_venue_detail_render_test.dart` | renders game-detail-host-full - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (51px) |
| S1.11 | `listings_render_test.dart` | first-time games widget - ltr (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (53px) |
| S1.12 | `listings_render_test.dart` | first-time games widget - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (53px) |
| S1.13 | `listings_render_test.dart` | games C4 default - rtl light (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (28px); DS src/controls/button.dart:563 (39px) |
| S1.14 | `listings_render_test.dart` | games C4 filters - rtl light (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (28px); DS src/controls/button.dart:563 (39px) |
| S1.15 | `listings_render_test.dart` | games listing - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (28px); DS src/controls/button.dart:563 (39px) |
| S1.16 | `listings_render_test.dart` | games listing: filter sheet - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (28px); DS src/controls/button.dart:563 (39px) |
| S1.17 | `listings_render_test.dart` | games listing: rail tap opens the sheet - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (28px); DS src/controls/button.dart:563 (39px) |
| S1.18 | `listings_render_test.dart` | no upcoming games widgets - ltr (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (25px); DS src/controls/button.dart:563 (49px); DS src/controls/button.dart:563 (53px); DS src/controls/button.dart:563 (77px) |
| S1.19 | `listings_render_test.dart` | no upcoming games widgets - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (25px); DS src/controls/button.dart:563 (49px); DS src/controls/button.dart:563 (53px); DS src/controls/button.dart:563 (77px) |
| S1.20 | `onboarding_steps_render_test.dart` | persona welcome — rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (7.0px) |
| S1.21 | `otp_verify_scenarios_render_test.dart` | renders email-verification - ltr (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (23px); DS src/controls/button.dart:563 (49px); DS src/controls/button.dart:563 (81px) |
| S1.22 | `otp_verify_scenarios_render_test.dart` | renders email-verification - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (17px); DS src/controls/button.dart:563 (49px) |
| S1.23 | `otp_verify_scenarios_render_test.dart` | renders forgot-password - rtl (variant: TargetPlatform.macOS) | DS src/controls/button.dart:563 (23px) |
| S1.24 | `venue_submissions_render_test.dart` | my submissions list (ltr) | DS src/controls/button.dart:563 (15px) |
| S1.25 | `venue_submissions_render_test.dart` | my submissions list (rtl) | DS src/controls/button.dart:563 (15px) |

### S2 — other located overflows — 10

| # | test file | test name | evidence |
|---|---|---|---|
| S2.1 | `admin_moderation_misc_render_test.dart` | moderation queue renders (ltr) | features/admin/presentation/screens/moderation_queue_screen.dart:124 (40px); features/admin/presentation/screens/moderation_queue_screen.dart:139 (28px) |
| S2.2 | `admin_moderation_misc_render_test.dart` | moderation queue renders (rtl) | features/admin/presentation/screens/moderation_queue_screen.dart:124 (16px); features/admin/presentation/screens/moderation_queue_screen.dart:139 (28px) |
| S2.3 | `admin_moderation_misc_render_test.dart` | report dialog renders (ltr) | DS src/controls/chip.dart:508 (50px) |
| S2.4 | `admin_moderation_misc_render_test.dart` | report dialog renders (rtl) | DS src/controls/chip.dart:508 (31px) |
| S2.5 | `admin_moderation_misc_render_test.dart` | transactions empty renders (ltr) | DS src/cards/transaction_row.dart:107 (20px) |
| S2.6 | `admin_moderation_misc_render_test.dart` | transactions empty renders (rtl) | DS src/cards/transaction_row.dart:107 (4.7px) |
| S2.7 | `admin_moderation_misc_render_test.dart` | transactions renders (ltr) | DS src/cards/transaction_row.dart:107 (20px) |
| S2.8 | `admin_moderation_misc_render_test.dart` | transactions renders (rtl) | DS src/cards/transaction_row.dart:107 (4.7px) |
| S2.9 | `game_venue_detail_render_test.dart` | renders venue-detail - rtl (variant: TargetPlatform.macOS) | DS src/cards/card.dart:398 (8.0px) |
| S2.10 | `game_venue_detail_render_test.dart` | renders venue-detail-full - rtl (variant: TargetPlatform.macOS) | DS src/cards/card.dart:398 (8.0px) |

### S3 — overflow caught by the test’s own `takeException()`, widget not named in the log — 12

| # | test file | test name | evidence |
|---|---|---|---|
| S3.1 | `auth_entry_render_test.dart` | renders auth-welcome - ltr (variant: TargetPlatform.iOS) | overflow 133px right; test fails on `takeException()`, widget not named |
| S3.2 | `auth_entry_render_test.dart` | renders landing - ltr (variant: TargetPlatform.macOS) | overflow 133px right; test fails on `takeException()`, widget not named |
| S3.3 | `auth_entry_render_test.dart` | renders landing - rtl (variant: TargetPlatform.macOS) | overflow 109px right; test fails on `takeException()`, widget not named |
| S3.4 | `auth_entry_render_test.dart` | renders sheet-language - ltr (variant: TargetPlatform.macOS) | overflow 133px right; test fails on `takeException()`, widget not named |
| S3.5 | `auth_entry_render_test.dart` | renders sheet-region - ltr (variant: TargetPlatform.macOS) | overflow 133px right; test fails on `takeException()`, widget not named |
| S3.6 | `explore_submissions_render_test.dart` | explore filter sheet — ltr | overflow 48px right; test fails on `takeException()`, widget not named |
| S3.7 | `explore_submissions_render_test.dart` | explore filter sheet — rtl | overflow 48px right; test fails on `takeException()`, widget not named |
| S3.8 | `explore_submissions_render_test.dart` | venue submissions — ltr | overflow 15px right; test fails on `takeException()`, widget not named |
| S3.9 | `explore_submissions_render_test.dart` | venue submissions — rtl | overflow 15px right; test fails on `takeException()`, widget not named |
| S3.10 | `notifications_render_test.dart` | activity log — ltr | overflow 1.00px right; test fails on `takeException()`, widget not named |
| S3.11 | `notifications_render_test.dart` | activity log — rtl | overflow 4.3px right; test fails on `takeException()`, widget not named |
| S3.12 | `profile_screen_render_test.dart` | switch-profile sheet - ltr | overflow 17px right; test fails on `takeException()`, widget not named |

### S4 — nav bar geometry vs the Home Feed frame — 4

| # | test file | test name | evidence |
|---|---|---|---|
| S4.1 | `nav_bar_measure_test.dart` | closed bar vs the Home Feed frame — LTR | geometry `expect(zero,isTrue)` false (nav_bar_measure_test.dart:308/311) — pill/fade-wrapper rect differs from frame |
| S4.2 | `nav_bar_measure_test.dart` | closed bar vs the Home Feed frame — RTL | geometry `expect(zero,isTrue)` false (nav_bar_measure_test.dart:308/311) — pill/fade-wrapper rect differs from frame |
| S4.3 | `nav_bar_measure_test.dart` | create menu open vs the frame — LTR | geometry `expect(zero,isTrue)` false (nav_bar_measure_test.dart:308/311) — pill/fade-wrapper rect differs from frame |
| S4.4 | `nav_bar_measure_test.dart` | create menu open vs the frame — RTL | geometry `expect(zero,isTrue)` false (nav_bar_measure_test.dart:308/311) — pill/fade-wrapper rect differs from frame |

### S5 — finder / tap misses (0 widgets found) — 8

| # | test file | test name | evidence |
|---|---|---|---|
| S5.1 | `account_privacy_render_test.dart` | privacy blocked page — ltr | Found 0 widgets with text  |
| S5.2 | `account_privacy_render_test.dart` | privacy blocked page — rtl | Found 0 widgets with text  |
| S5.3 | `account_privacy_render_test.dart` | privacy blocked page, empty — ltr | Found 0 widgets with text  |
| S5.4 | `account_privacy_render_test.dart` | privacy blocked page, empty — rtl | Found 0 widgets with text  |
| S5.5 | `account_privacy_render_test.dart` | privacy contact page and audience sheet — ltr | Found 0 widgets with text  |
| S5.6 | `account_privacy_render_test.dart` | privacy contact page and audience sheet — rtl | Found 0 widgets with text  |
| S5.7 | `user_sport_profile_render_test.dart` | sport profile empty renders — ltr | Found 0 widgets with text  |
| S5.8 | `user_sport_profile_render_test.dart` | sport profile tracker renders — ltr | Found 0 widgets with type  |

### Why S5 and S4 are the same cause, not separate ones

- S5 (`account_privacy` ×6, `user_sport_profile` ×2): the test taps / finds text (`'Direct messages'`, `'Blocked accounts'`, `'No games for this sport yet.'`, `DabblerProfileRow`) that, with Ahem metrics, sits below the fold or inside a differently laid-out list, so the finder sees 0 widgets (`account_privacy_render_test.dart:169-174, 203, 218`; `user_sport_profile_render_test.dart:445-448, 462-464`). All 8 pass in run B.
- S4 (`nav_bar_measure` ×4): the test measures text-derived rects (pill 287.1 design vs 307.0 app, `nav_bar_measure_test.dart:308-311, 543, 612`); the measured widths come from the real faces by design (the file's own note: "Flutter rounds a text line to whole px"). With Ahem the numbers cannot match. All 4 pass in run B.

## Cause table

| # | cause | verdict | failures | evidence |
|---|---|---|---|---|
| C1 | Render tests load DS fonts only from a sibling `../dabbler-design-system/fonts`, skip silently when absent → Ahem fallback | **environment differs** (font) — a test-harness defect, not a Product defect | 59 / 59 | run A vs run B above; `grep` locations above; per-test evidence in the tables |
| C2 | Stale expectation | none found | 0 | all 269 pass unchanged in run B |
| C3 | Code regression | none found | 0 | same `lib/` at `4214cf8d` is green in run B |
| C4 | SDK / surface size / text scale | none found | 0 | identical in A and B |

## Proposed fix tickets (none implemented here)

1. **Harden render-test font loading (fixes C1).** Make every render test call the one existing `loadRenderFonts()` (`test/support/render_mode.dart:62`), delete the 13 private copies and `settings_render_support.dart:21`'s copy, and extend the same to the other 16 files that hardcode the sibling path. Acceptance: the 13 files pass with the `dabbler-design-system` folder **absent** next to `dabbler-code` (font path resolved through `package_config.json`), 269/269.
2. **Fail loudly, never fall back to Ahem silently.** In the shared loader, throw (or `fail()`) when no font file is found, naming the folders tried. Acceptance: with the font folder deliberately unresolvable, the first test fails with that message instead of 59 unrelated layout errors.
3. **Document / provision the layout for Thebes worktrees** until (1) lands: either the team-worktree setup creates the sibling (`dabbler-design-system` next to the worktree) or the integration rule stays "no new failures by test name". Add one line to `docs/local-design-system.md`.
4. **(Optional, observation, not a defect)** `DabblerButton` labels are `softWrap: false` with no ellipsis (DS `button.dart` "whiteSpace: nowrap" by design), so any layout the real fonts fit only just will overflow on a font change. Worth a DS note, not a ticket now.

## Method and limits

- Run A: the 13 files, `flutter test --no-pub`, at `4214cf8d` from the worktree above; failures parsed per test (59 distinct test names, counts equal the ticket).
- Overflow locations come from Flutter's "relevant error-causing widget" lines in the per-file logs. For S3 the test asserts `takeException()` and only the first exception is printed, so the widget is not named; those tests pass in run B.
- Run B used a symlinked pub-cache copy of the **pinned** DS commit as the sibling, so the fonts are exactly the pinned ones; the repo's own sibling checkout (`Dabbler/dabbler-design-system`, branch `alpha-ds-action-area`) was not used and nothing there or in the shared `dabbler-code` checkout was touched.
- `origin/Alpha` advanced to `b744f3a6` while this ran; the diagnosis is at `4214cf8d` as ticketed and was not re-run on the newer commit.
- No file under `lib/` or `test/` was changed; goldens untouched; nothing pushed; no database access.
