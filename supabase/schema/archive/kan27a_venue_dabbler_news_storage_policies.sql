-- KAN-27A — storage.objects RLS gaps on the `venue` and `dabbler-news`
-- buckets, authored by backend-owner, assigned by cto per the KAN-56
-- triage (2026-08-29). Separate migration from KAN-56 — different
-- surface (storage, not views), per instruction not to bundle.
--
-- RECORD NOTE (2026-08-29, T-031): this file was never applied as a
-- whole and should not be read as a ledger entry. The 5 CREATE POLICY
-- statements below were already live in production before this file's
-- DROP POLICY line was added (ledger: 20260828215203
-- kan27a_venue_dabbler_news_storage_policies, applied by an unidentified
-- actor — flagged for master-analyst to reconcile on KAN-27, not
-- guessed at here). The DROP POLICY line was added afterwards per T-030
-- and, per T-031 (a migration file is immutable once applied — corrections
-- ship as a new file, never an edit to one already applied), was NOT run
-- from this file. cto instead applied the DROP alone as its own migration,
-- `kan27a_followup_drop_open_dabbler_news_write`, with its own ledger row.
-- Both halves are confirmed live (5 storage.objects policies on these two
-- buckets, no open-write policy on dabbler-news) as of 2026-08-29. This
-- file is kept for its authorship reasoning and verification content, not
-- as a record of what was run — see the two real ledger entries above for
-- that.
--
-- Verified live against wtncuzcskpigqpmnxwws before writing this file:
--
--   SELECT id, public FROM storage.buckets WHERE id IN ('venue','dabbler-news');
--   -- venue: public=true | dabbler-news: public=true
--
--   SELECT policyname, cmd, roles FROM pg_policies
--   WHERE schemaname='storage' AND tablename='objects'
--     AND (qual ILIKE '%venue%' OR qual ILIKE '%dabbler-news%'
--          OR with_check ILIKE '%venue%' OR with_check ILIKE '%dabbler-news%');
--   -- venue: ZERO rows — no policy of any kind, any command.
--   -- dabbler-news: ONE row — "service role write dabbler-news", INSERT,
--   --   roles={public}, with_check (bucket_id = 'dabbler-news'). No SELECT
--   --   policy at all.
--
-- Both bucket name constants (SupabaseConfig.venueImagesBucket = 'venue',
-- SupabaseConfig.dabblerNewsBucket = 'dabbler-news') are defined in
-- lib/core/config/supabase_config.dart but grep across lib/ and
-- supabase/functions/ finds no other reference to either — neither
-- bucket is currently wired to any client code path or edge function.
-- This migration closes the RLS gap regardless (T-020: a control's data
-- is never readable by the people it constrains applies to buckets sitting
-- unused same as any other; leaving RLS off is not "safe because
-- nothing's wired up yet" — it's a landmine for whichever feature wires
-- it up first), matching the `post-media` bucket's existing shape as the
-- closest live precedent for "public-read image bucket, admin-managed":
--
--   post_media_select_public: SELECT, roles={public}, USING (bucket_id = 'post-media')
--   post_media_insert_authenticated: INSERT, roles={public},
--     WITH CHECK (bucket_id = 'post-media' AND auth.uid() IS NOT NULL
--                 AND (storage.foldername(name))[1] = auth.uid()::text)
--
-- venue has no folder-ownership convention established anywhere in the
-- schema (no venue_id-prefixed path pattern exists to check against), so
-- write is scoped to role instead of folder: `is_admin()` (global admin,
-- same check used by every other admin_*/rpc_admin_* function in this
-- schema) OR `is_venue_admin(auth.uid())` (the single-arg, global
-- venue_admin role — there is no venue_id available on a storage.objects
-- row to call the two-arg per-venue overload against, so this does not
-- attempt per-venue scoping; if venue images end up needing "only the
-- admin of *this* venue can upload", that needs a path convention first,
-- filed as a follow-up, not invented here).
--
-- dabbler-news: the missing SELECT is added, per KAN-27A's stated scope.
--
-- A related but separate defect was found while scoping this ticket: the
-- existing "service role write dabbler-news" policy is INSERT, roles=
-- {public}, with_check (bucket_id = 'dabbler-news'), no auth check at all
-- — anon can upload arbitrary objects into this bucket today. Its name is
-- the tell: service_role bypasses RLS entirely, so a policy written "for"
-- service_role does nothing for it and instead grants that permission to
-- every role RLS actually applies to (ruled DROP, not rewrite — T-030).
-- That fix does NOT ship in this migration — it is out of KAN-27A's
-- scope and is tracked, authored and reviewed separately as KAN-75, so
-- the decision of what gate replaces it (service-role-only vs is_admin)
-- gets its own deliberate review rather than riding in on this file.

BEGIN;

-- venue: public read (matches bucket.public = true and the post-media
-- precedent), admin-managed write.
CREATE POLICY venue_select_public ON storage.objects
FOR SELECT
USING (bucket_id = 'venue');

CREATE POLICY venue_insert_admin ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'venue'
  AND (public.is_admin(auth.uid()) OR public.is_venue_admin(auth.uid()))
);

CREATE POLICY venue_update_admin ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'venue'
  AND (public.is_admin(auth.uid()) OR public.is_venue_admin(auth.uid()))
);

CREATE POLICY venue_delete_admin ON storage.objects
FOR DELETE
USING (
  bucket_id = 'venue'
  AND (public.is_admin(auth.uid()) OR public.is_venue_admin(auth.uid()))
);

-- dabbler-news: missing SELECT, matching the bucket's public=true posture.
-- The open unauthenticated write policy ("service role write dabbler-news")
-- is a separate defect, tracked and fixed under KAN-75 / T-030 — not this
-- ticket's scope. Do not add it back here; see KAN-75 for that migration.
CREATE POLICY dabbler_news_select_public ON storage.objects
FOR SELECT
USING (bucket_id = 'dabbler-news');

COMMIT;

-- ============================================================================
-- VERIFICATION — run as postgres after apply.
-- ============================================================================
--
-- 1. Public/anon read now works on both buckets:
--    BEGIN; SET LOCAL ROLE anon;
--    SELECT count(*) FROM storage.objects WHERE bucket_id = 'venue';         -- expect: no error (0 or more rows, not permission denied)
--    SELECT count(*) FROM storage.objects WHERE bucket_id = 'dabbler-news';  -- expect: no error
--    ROLLBACK;
--
-- 2. A non-admin authenticated caller cannot write to venue:
--    DO $$
--    DECLARE v_non_admin uuid;
--    BEGIN
--      SELECT id INTO v_non_admin FROM auth.users
--        WHERE id NOT IN (SELECT user_id FROM public.role_grants WHERE role IN ('admin','super_admin','venue_admin'))
--        LIMIT 1;
--      SET LOCAL ROLE authenticated;
--      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_non_admin)::text, true);
--      -- expect INSERT to fail RLS (0 rows affected / policy violation) --
--      -- run as a real insert attempt in a rolled-back transaction if you
--      -- want to confirm end to end; not scripted here since it requires
--      -- a real object row shape.
--    END $$;
--
-- 3. Policy count sanity — both buckets now have exactly the expected
--    shape:
--    SELECT bucket_id_qual, cmd, count(*) FROM (
--      SELECT (regexp_match(qual, '''([a-z-]+)'''))[1] AS bucket_id_qual, cmd
--      FROM pg_policies WHERE schemaname='storage' AND tablename='objects'
--        AND (qual ILIKE '%venue%' OR qual ILIKE '%dabbler-news%')
--    ) s GROUP BY 1,2 ORDER BY 1,2;
--    -- expect: venue -> DELETE 1, SELECT 1, UPDATE 1 (INSERT is on
--    -- with_check, won't show in this qual-only query — check
--    -- with_check separately); dabbler-news -> SELECT 1.
--    --
--    -- NOTE: this migration does NOT touch the "service role write
--    -- dabbler-news" INSERT policy (the one with no auth check, granting
--    -- anon write) — that is a separate defect, KAN-75 / T-030, with its
--    -- own migration and its own G-002 review. Do not expect it gone
--    -- here, and do not add its fix to this file after the fact —
--    -- corrections to an already-applied migration ship as a new
--    -- migration (T-031), not an edit to this one.
