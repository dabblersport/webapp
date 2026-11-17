"""KAN-978 (W0-5): generates the notification kind registry's server tables.

Input: the KAN-974 migration,
supabase/migrations/20261117045242_kan974_notification_envelope_v2.sql
(section 4, the 35 live kinds, and section 5, the Epic's new kinds): each
kind's category, is_active, breaks_quiet, can_mute and EN / AR title and body
templates.

Output:
  --dart  lib/features/notifications/domain/notification_kind_titles.dart and
          notification_kind_bodies.dart (overwritten), then run
          `dart format` on those two files.
  --arb   appends the EN and AR template block to lib/l10n/app_en.arb and
          app_ar.arb, then run `flutter gen-l10n`. Refuses when the block is
          already there (edit the ARB entries by hand after that).

Run from the repo root:
  python3 -I tool/notifications/gen_kind_tables.py . --dart
A kind added on the server goes into the migration first; then add its client
row to notification_kind_table*.dart and its key to the registry test."""
import json
import re
import sys

root = sys.argv[1]
sql = open(f"{root}/supabase/migrations/20261117045242_kan974_notification_envelope_v2.sql", encoding="utf-8").read()


def tuples(section):
    out = []
    for line in section.splitlines():
        line = line.strip()
        if not line.startswith("('"):
            continue
        vals, i = [], 1
        while i < len(line):
            c = line[i]
            if c == "'":
                j, s = i + 1, ""
                while True:
                    if line[j] == "'" and j + 1 < len(line) and line[j + 1] == "'":
                        s += "'"
                        j += 2
                    elif line[j] == "'":
                        break
                    else:
                        s += line[j]
                        j += 1
                vals.append(s)
                i = j + 1
            elif line.startswith("true", i):
                vals.append(True); i += 4
            elif line.startswith("false", i):
                vals.append(False); i += 5
            else:
                i += 1
        out.append(vals)
    return out


s4 = sql.split("-- 4. Templates")[1].split("-- 5. New kinds")[0]
s5 = sql.split("-- 5. New kinds")[1].split("-- Every kind now carries")[0]
kinds = []
for v in tuples(s4):
    key, cat, bq, ten, tar, ben, bar = v
    kinds.append(dict(key=key, cat=cat, bq=bq, mute=True, active=True, ten=ten, tar=tar, ben=ben, bar=bar))
for v in tuples(s5):
    key, len_, lar, prio, ch, cat, bq, mute, ten, tar, ben, bar = v
    kinds.append(dict(key=key, cat=cat, bq=bq, mute=mute, active=False, ten=ten, tar=tar, ben=ben, bar=bar))
assert len(kinds) == 87, len(kinds)

RENAME = {"old": "oldValue", "new": "newValue", "close_time": "closeTime"}
ATT = {"activity.checkin_open", "activity.checkin_closing", "activity.checked_in", "activity.attendance_corrected",
       "activity.no_show_pending", "activity.review_requested", "activity.review_accepted", "activity.review_kept",
       "activity.no_show_confirmed", "activity.showup_rate_updated"}
REM = {"game.reminder", "meetup.reminder", "meetup.confirm_attendance"}


def prefix(k):
    if k in REM:
        return "rem"
    if k in ATT:
        return "att"
    if k.startswith("activity."):
        return "res"
    if k.startswith("security."):
        return "sec"
    return "notif"


def arb_key(k, part):
    return f"{prefix(k)}_{part}_{k.replace('.', '_')}"


def phs(text):
    seen = []
    for m in re.findall(r"\{([a-z_]+)\}", text):
        if m not in seen:
            seen.append(m)
    return seen


def to_arb(text):
    return re.sub(r"\{([a-z_]+)\}", lambda m: "{" + RENAME.get(m.group(1), m.group(1)) + "}", text)


en, ar = {}, {}
for k in kinds:
    for part, e, a in (("t", k["ten"], k["tar"]), ("b", k["ben"], k["bar"])):
        key = arb_key(k["key"], part)
        en[key] = to_arb(e)
        p = phs(e)
        assert set(phs(a)) <= set(p), (k["key"], part)
        meta = {"description": f"KAN-978: server template {k['key']} ({'title' if part == 't' else 'body'})."}
        if p:
            meta["placeholders"] = {RENAME.get(x, x): {"type": "String"} for x in p}
        en["@" + key] = meta
        ar[key] = to_arb(a)


def append_block(path, block):
    text = open(path, encoding="utf-8").read().rstrip()
    assert text.endswith("}")
    body = text[:-1].rstrip()
    lines = [f"  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}" for k, v in block.items()]
    open(path, "w", encoding="utf-8").write(body + ",\n" + ",\n".join(lines) + "\n}\n")


if "--arb" in sys.argv:
    if '"notif_t_game_full"' in open(f"{root}/lib/l10n/app_en.arb", encoding="utf-8").read():
        sys.exit("The template block is already in the ARB files; not appending again.")
    append_block(f"{root}/lib/l10n/app_en.arb", en)
    append_block(f"{root}/lib/l10n/app_ar.arb", ar)


def dart_switch(fn, part, doc):
    out = [doc, f"String? {fn}(AppLocalizations l, String kind, NotifArg a) =>", "    switch (kind) {"]
    for k in kinds:
        p = phs(k["ten"] if part == "t" else k["ben"])
        args = ", ".join(f"a('{x}')" for x in p)
        call = f"l.{arb_key(k['key'], part)}" + (f"({args})" if p else "")
        out.append(f"      '{k['key']}' => {call},")
    out += ["      _ => null,", "    };", ""]
    return "\n".join(out)


HEADER = """// GENERATED by tool/notifications/gen_kind_tables.py (KAN-978); do not edit.
// Input: the KAN-974 migration (sections 4 and 5),
// supabase/migrations/20261117045242_kan974_notification_envelope_v2.sql.
// Regenerate: python3 -I tool/notifications/gen_kind_tables.py . --dart
// Part of the notification kind registry (notification_kinds.dart).
import 'package:dabbler/l10n/app_localizations.dart';

/// Resolves a template placeholder (the server's argument name) to its text.
typedef NotifArg = String Function(String name);
"""

titles = HEADER + "\n" + dart_switch(
    "notificationTitleTemplate", "t",
    "/// The kind's localized title template, or null for an unknown kind.") + "\n"
titles += "/// The server argument names a kind's title uses (in order).\n"
titles += "const Map<String, List<String>> notificationTitleArgs = <String, List<String>>{\n"
for k in kinds:
    p = phs(k["ten"])
    titles += f"  '{k['key']}': <String>[{', '.join(repr(x).replace(chr(34), chr(39)) for x in p)}],\n"
titles += "};\n\n"
titles += "/// The server's kind facts: category, active, breaks_quiet, can_mute.\n"
titles += "const Map<String, (String, bool, bool, bool)> notificationServerKinds =\n    <String, (String, bool, bool, bool)>{\n"
for k in kinds:
    titles += f"  '{k['key']}': ('{k['cat']}', {str(k['active']).lower()}, {str(k['bq']).lower()}, {str(k['mute']).lower()}),\n"
titles += "};\n"
bodies = HEADER.replace("typedef NotifArg = String Function(String name);\n", "").replace(
    "import 'package:dabbler/l10n/app_localizations.dart';",
    "import 'package:dabbler/l10n/app_localizations.dart';\n\nimport 'notification_kind_titles.dart' show NotifArg;") + "\n" + dart_switch(
    "notificationBodyTemplate", "b",
    "/// The kind's localized body template, or null for an unknown kind.")

if "--dart" in sys.argv:
    d = f"{root}/lib/features/notifications/domain"
    open(f"{d}/notification_kind_titles.dart", "w", encoding="utf-8").write(titles)
    open(f"{d}/notification_kind_bodies.dart", "w", encoding="utf-8").write(bodies)

print(len(kinds), "kinds;", len(en) // 2, "arb keys")
print(",".join(k["key"] for k in kinds))
