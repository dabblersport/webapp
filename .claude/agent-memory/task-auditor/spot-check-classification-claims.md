---
name: spot-check-classification-claims
description: When a ticket classifies a batch of files (e.g. "dead", "no consumers", "accepted risk"), verify each label against real call sites — "dead" claims are the ones most likely to be wrong
metadata:
  type: feedback
---

On KAN-58's 2nd rework pass, flutter-feature-agent classified 19 SharedPreferences/Hive
files as session-scoped/preference-scoped/dead per a DECISIONS.md T-004 amendment. 18 of
19 were accurate on spot-check. One — `lib/features/profile/data/datasources/
profile_data_sources.dart` (`ProfileLocalDataSourceImpl`) — was labeled "Dead, verified via
grep, nothing to clear," but a two-line grep (`grep -rn "ProfileLocalDataSourceImpl\|
profileLocalDataSourceProvider" lib`) showed it wired into `profileRepositoryProvider` and
read directly in `settings_screen.dart` to clear per-user cache. Not dead at all — an
in-memory cache holding the same shape of cross-account risk as the `ProfileCacheService`
the ticket was fixing.

**Why the false "dead" label was easy to write:** the file's own grep match was a
doc-comment string ("Typically implemented with Hive, SQLite, or SharedPreferences"), not
a real import — so the author's dead-code check (grep for the class name) found no *direct*
match either, since `ProfileLocalDataSourceImpl` is the class instantiated, and the
providers around it use different names in the chain (`profileLocalDataSourceProvider` →
`profileRepositoryProvider`). A shallow "does this file's own name appear elsewhere" check
missed the indirection through Riverpod providers.

**How to apply:** whenever a ticket's rework includes a batch classification (dead / no
consumers / accepted risk / low severity) across N files, don't just check the count and
read the labels for internal consistency — grep for the *actual class or function name*
declared in the file across the whole repo, not just the file's own path substring. A
"dead" label is the one most worth checking first: it's the label that requires the least
justification to write and the most damage if wrong (nothing gets fixed, and the next
person trusts the record). Two or three files is enough for a spot-check at medium effort;
prioritize "dead" and "accepted risk" labels over "wired"/"preference-scoped" ones, since
the former require an author to prove a negative and are more likely to be asserted
without a full grep.

See [[decisions-amend-silently]] for the related lesson about re-reading DECISIONS.md
amendments in full at review time.
