---
name: reachability-method
description: How to measure dead code in this repo correctly — import-graph BFS from main.dart, and the three distinct reachability measures that must never be conflated.
metadata:
  type: reference
---

Three measures, three different answers. Conflating them produced wrong numbers twice.

1. **Import-reachable** — file-level BFS over `import`/`export`/`part` from `lib/main.dart`.
   A file outside this set is not compiled in. This is the authoritative dead-code measure.
   Script: `.claude/jobs/*/tmp/reach.py` (recreate it; job dirs are cleaned up).
2. **Route-referenced** — the class appears in `lib/app/app_router.dart`. Necessary, not
   sufficient.
3. **UI-reachable** — some visible widget navigates there.

**Why it matters:** Dabbler ships as **Flutter Web on Cloudflare Pages**, so every
registered route path is reachable by typing a URL even with no button pointing at it.
"No UI links to it" is therefore not "users cannot get there" — it is a weaker claim, and
several findings (`/transactions`, admin screens, `SocialOnboardingFriendsScreen`) turn on
exactly that distinction.

**How to apply:** counting classes with no external reference undercounts badly — it misses
transitively-dead subtrees where dead screen A imports dead screen B. Always run the BFS.
Two caveats: `lib/providers.dart` is a barrel export, so anything it re-exports counts as
import-reachable whether or not it is used; and private per-file helpers (`_ErrorView`,
`_EmptyView`) inflate any class-name census — 18 of 25 non-routed classes in run 2.

**A guard is not protection unless its flag is closed.** Several routes carry a `redirect`
that tests a `FeatureFlags` constant. Reading "it's flag-gated" off the presence of the
guard is wrong: on 2026-08-27 all four flags guarding placeholder routes were `true`, so
none of the guards fired. **Cite the flag's value at a line, not the existence of the gate.**

**Never write "all N are unreachable."** The check runs per route; the claim must too. On
2026-08-27 I verified five placeholder routes as orphans, wrote the sentence over six, and
`socialChat` — pushed by an unconditional Message button at `user_profile_screen.dart:1094`
— was the sixth. A blanket claim forecloses its exceptions instead of listing them, and
this one nearly retired a live launch blocker. **List the members you verified and stop.**
See `docs/LEARN.md` "A correction is a claim, and it inherits the burden of the claim it
replaces".

Related: [[audit-run2-inventory-2026-08-27]], [[confirmed-dead-code]].
