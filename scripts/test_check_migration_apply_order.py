#!/usr/bin/env python3
"""Offline tests for scripts/check_migration_apply_order.py (KAN-788). No database.

    python3 scripts/test_check_migration_apply_order.py
"""
import contextlib
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_migration_apply_order as c  # noqa: E402

PROVIDER = "20261104110000_kan713_location_triggers.sql"
ANCHOR = "20261104100000_kan713_access_helpers.sql"
GUARDED = "20261104100300_kan714_b03_views_rating_host_metrics.sql"
FREE = "20261104100100_kan714_b01_views_game_card_my_games.sql"

FILES = {
    ANCHOR: "CREATE OR REPLACE FUNCTION public.kan713_meetup_visible(p uuid) RETURNS boolean AS $$ SELECT true $$;",
    FREE: "CREATE OR REPLACE VIEW public.v_game_card AS SELECT 1;",
    GUARDED: """DO $g$ BEGIN
  FOR r IN SELECT * FROM (VALUES ('public.games', 'trg_kan713_games_a_location')) AS t(rel, tg) LOOP NULL; END LOOP;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN NULL; END IF;
  RAISE EXCEPTION 'KAN-722: prerequisite stage missing: %', 'x';
END $g$;""",
    PROVIDER: "-- CREATE TRIGGER trg_commented_out\nCREATE TRIGGER trg_kan713_games_a_location BEFORE INSERT ON public.games "
              "FOR EACH ROW EXECUTE FUNCTION public.f();",
}


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        for name, body in FILES.items():
            with open(os.path.join(self.tmp.name, name), "w", encoding="utf-8") as fh:
                fh.write(body)
        self.provides, self.requires = c.scan(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = c.main(["--migrations", self.tmp.name, *args])
        return rc, out.getvalue(), err.getvalue()

    def write_order(self, names):
        path = os.path.join(self.tmp.name, "order.txt")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("# planned order\n" + "\n".join(names) + "\n")
        return path


class Scan(Fixture):
    def test_guard_requirements_are_read_from_the_guarded_file_only(self):
        self.assertEqual(self.requires, {GUARDED: ["kan713_meetup_visible", "trg_kan713_games_a_location"]})

    def test_creators_are_found_and_comments_ignored(self):
        self.assertEqual(self.provides["trg_kan713_games_a_location"], [PROVIDER])
        self.assertEqual(self.provides["kan713_meetup_visible"], [ANCHOR])
        self.assertNotIn("trg_commented_out", self.provides)


class Check(Fixture):
    def test_filename_order_fails_loudly(self):
        rc, _, err = self.run_main()
        self.assertEqual(rc, 1)
        self.assertIn("MIGRATION APPLY ORDER VIOLATED", err)
        self.assertIn(f"{GUARDED} requires trg_kan713_games_a_location, created by {PROVIDER}, which is applied AFTER it", err)

    def test_the_decided_order_passes(self):
        rc, out, _ = self.run_main("--order", self.write_order([ANCHOR, PROVIDER, FREE, GUARDED]))
        self.assertEqual(rc, 0)
        self.assertIn("apply order OK: 4 migrations", out)

    def test_a_creator_missing_from_the_order_fails(self):
        rc, _, err = self.run_main("--order", self.write_order([ANCHOR, FREE, GUARDED]))
        self.assertEqual(rc, 1)
        self.assertIn("which is not in the apply order", err)

    def test_a_name_no_migration_creates_is_unresolved_not_a_failure(self):
        requires = {GUARDED: ["trg_made_by_dynamic_sql"]}
        violations, unresolved = c.check([GUARDED], self.provides, requires)
        self.assertEqual((violations, unresolved), ([], [(GUARDED, "trg_made_by_dynamic_sql")]))


class PrintOrder(Fixture):
    def test_the_provider_moves_to_just_after_its_anchor(self):
        rc, out, _ = self.run_main("--print-order")
        self.assertEqual(rc, 0)
        self.assertEqual(out.split(), [ANCHOR, PROVIDER, FREE, GUARDED])

    def test_without_a_placement_rule_the_provider_moves_before_its_first_dependent(self):
        order = c.repaired(sorted(FILES), self.provides, self.requires, place_after={})
        self.assertEqual(order, [ANCHOR, FREE, PROVIDER, GUARDED])

    def test_the_printed_order_passes_its_own_check(self):
        order = c.repaired(sorted(FILES), self.provides, self.requires)
        self.assertEqual(c.check(order, self.provides, self.requires)[0], [])


class RealRepository(unittest.TestCase):
    def test_the_repository_filename_order_is_rejected_and_the_printed_order_accepted(self):
        provides, requires = c.scan(c.MIGRATIONS)
        names = sorted(n for n in os.listdir(c.MIGRATIONS) if n.endswith(".sql"))
        self.assertTrue(c.check(names, provides, requires)[0])
        fixed = c.repaired(names, provides, requires)
        self.assertEqual(c.check(fixed, provides, requires)[0], [])
        self.assertEqual(sorted(fixed), names)  # same files, same version strings: only the order differs


if __name__ == "__main__":
    unittest.main()
