#!/usr/bin/env python3
"""Migration apply-order check (KAN-788). Reads files only; never connects to any database.

    python3 scripts/check_migration_apply_order.py                    check filename order (what `supabase db reset` does)
    python3 scripts/check_migration_apply_order.py --order FILE       check the order listed in FILE (one name per line, # comments)
    python3 scripts/check_migration_apply_order.py --print-order      print the repaired order for a fresh cluster

A migration that opens with a prerequisite guard (it raises 'prerequisite stage missing') names what must already
exist: quoted trigger names ('trg_...') and helpers it looks up with to_regprocedure('public.fn(...)'). The check finds
the migration that CREATES each of those (CREATE [OR REPLACE] TRIGGER / FUNCTION) and fails, exit 1, when that
creator is applied after the guarded migration or is missing from the order. A name no migration creates statically
(a harness object, or one made by dynamic SQL) is reported as unresolved and does not fail the check.

Why it exists: 20261104110000_kan713_location_triggers.sql sorts AFTER the KAN-714 B files (20261104100100..101400),
but B03, B06, B09, B11 and B14 require its triggers. Production applied KAN-713 first (KAN-714 contract section 7);
a fresh cluster built in filename order stops at B03 with 'KAN-722: prerequisite stage missing'. Decision and proof:
supabase/tests/events_p2/KAN788_APPLY_ORDER.md.
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS = os.path.join(ROOT, "supabase", "migrations")

GUARD_MARK = "prerequisite stage missing"
CREATES = re.compile(r"\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?(TRIGGER|FUNCTION)\s+"
                     r"(?:(?:\"?public\"?)\.)?\"?([A-Za-z_][A-Za-z0-9_]*)\"?", re.IGNORECASE)
REQ_TRIGGER = re.compile(r"'(trg_[A-Za-z0-9_]+)'")
REQ_FUNCTION = re.compile(r"to_regprocedure\(\s*'public\.([A-Za-z_][A-Za-z0-9_]*)\(", re.IGNORECASE)

# The decided order (KAN788_APPLY_ORDER.md): a migration listed here applies right after the named one, which is the
# order production applied them in. Only fresh clusters use this; no version string is renamed.
PLACE_AFTER = {
    "20261104110000_kan713_location_triggers.sql": "20261104100000_kan713_access_helpers.sql",
}


def strip_comments(sql):
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    return re.sub(r"--[^\n]*", " ", sql)


def scan(directory):
    """Returns (provides, requires): name -> creating files, file -> required names."""
    provides, requires = {}, {}
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".sql"):
            continue
        with open(os.path.join(directory, name), encoding="utf-8") as fh:
            sql = strip_comments(fh.read())
        for _kind, obj in CREATES.findall(sql):
            provides.setdefault(obj.lower(), []).append(name)
        if GUARD_MARK in sql:
            names = {t.lower() for t in REQ_TRIGGER.findall(sql)} | {f.lower() for f in REQ_FUNCTION.findall(sql)}
            requires[name] = sorted(names)
    return provides, requires


def creator(obj, provides, dependent):
    """The first migration, in filename order, that creates obj (the dependent itself does not count)."""
    files = [f for f in provides.get(obj, []) if f != dependent]
    return min(files) if files else None


def check(order, provides, requires):
    """Returns (violations, unresolved). order: list of migration file names in apply order."""
    pos = {name: i for i, name in enumerate(order)}
    violations, unresolved = [], []
    for dep in order:
        for obj in requires.get(dep, []):
            src = creator(obj, provides, dep)
            if src is None:
                unresolved.append((dep, obj))
            elif src not in pos:
                violations.append(f"{dep} requires {obj}, created by {src}, which is not in the apply order")
            elif pos[src] > pos[dep]:
                violations.append(f"{dep} requires {obj}, created by {src}, which is applied AFTER it "
                                  f"(position {pos[src] + 1} > {pos[dep] + 1})")
    return violations, unresolved


def repaired(order, provides, requires, place_after=PLACE_AFTER):
    """Filename order with PLACE_AFTER applied; any creator still late moves up to just before its first dependent."""
    order = list(order)
    for name, anchor in place_after.items():
        if name in order and anchor in order:
            order.remove(name)
            order.insert(order.index(anchor) + 1, name)
    out, seen = [], set()

    def emit(name, stack):
        if name in seen or name in stack:
            return
        for obj in requires.get(name, []):
            src = creator(obj, provides, name)
            if src is not None and src in order:
                emit(src, stack | {name})
        seen.add(name)
        out.append(name)

    for name in order:
        emit(name, set())
    return out


def read_order(path):
    with open(path, encoding="utf-8") as fh:
        lines = [ln.split("#", 1)[0].strip() for ln in fh]
    return [os.path.basename(ln) for ln in lines if ln]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--migrations", default=MIGRATIONS)
    ap.add_argument("--order", help="file listing the planned apply order; default: filename order")
    ap.add_argument("--print-order", action="store_true", help="print the repaired apply order and exit 0")
    args = ap.parse_args(argv)

    provides, requires = scan(args.migrations)
    default = sorted(n for n in os.listdir(args.migrations) if n.endswith(".sql"))
    if args.print_order:
        print("\n".join(repaired(default, provides, requires)))
        return 0

    order = read_order(args.order) if args.order else default
    violations, unresolved = check(order, provides, requires)
    for dep, obj in unresolved:
        print(f"unresolved (no migration creates it statically): {dep} requires {obj}")
    if violations:
        source = args.order or "filename order"
        print(f"MIGRATION APPLY ORDER VIOLATED ({source}): {len(violations)} prerequisite(s) applied too late", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        print("Apply in the order printed by: python3 scripts/check_migration_apply_order.py --print-order "
              "(supabase/tests/events_p2/KAN788_APPLY_ORDER.md)", file=sys.stderr)
        return 1
    print(f"apply order OK: {len(order)} migrations, {sum(len(v) for v in requires.values())} guarded prerequisites checked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
