-- KAN-186 / T-077 Part A: convert the 12 DELETE-group tables' profile-keyed
-- blocking FKs to ON DELETE CASCADE, so account erasure is no longer blocked by
-- them. Authored by backend-8, 2026-09-11.
--
-- ============================================================================
-- STATUS: AUTHORED, NOT APPLIED. apply_migration was DENIED by the Claude Code
-- permission classifier on 2026-09-11, after team-lead had authorised it for
-- this migration. The harness permission layer is separate from that
-- authorisation and refused the call; the ticket's own status note predicted
-- exactly this ("This ticket's ALTER TABLE shape may be denied the same way"),
-- so the denial confirms that prediction rather than contradicting anything.
--
-- NOTHING HAS BEEN RUN AGAINST wtncuzcskpigqpmnxwws. The DDL below was not
-- re-routed through execute_sql: doing so would have bypassed the denial rather
-- than respected it. This file is the authored artifact awaiting an authorised
-- apply. IT IS NOT EVIDENCE THAT THE CONSTRAINTS WERE CHANGED.
--
-- FILENAME CARRIES NO VERSION PREFIX, DELIBERATELY. Per T-068 step 5 the repo
-- file is named from the exact version string apply_migration RETURNS. No apply
-- has returned one, so no prefix is invented here -- a guessed timestamp would
-- be indistinguishable at a glance from a real ledger version. Rename this file
-- to the returned version when the apply succeeds.
--
-- PRE-STATE, read live 2026-09-11 immediately before the denied apply:
--   FKs referencing public.profiles                          51
--   of those, blocking (confdeltype IN ('a','r'))            20
--   Part-B constraints excluded by name                       7
--   this migration's scope                                   13
--   posts_author_user_profile_fkey confupdtype               'r' (the only one)
--   rows: posts 503, reactions 102, comments 67, other nine   0
--   profiles rows                                            165
-- The pre-check block below re-asserts all of this at apply time, so a drift
-- between this reading and the eventual apply aborts rather than proceeding.
-- ============================================================================
--
-- WHAT THIS DOES NOT DO
--   * It does NOT add DELETE statements to delete_my_account(). T-077 is explicit:
--     the fix mechanism is the FK action, not the function body. The function is
--     not touched here, and neither is its (stale, separately-recorded) comment.
--   * It does NOT touch any Part-B table -- games, meetups, squads, challenges --
--     nor the challenges/squads duplicate-constraint cleanup, which T-077 assigns
--     to whoever implements Part B (now KAN-176's backend child, KAN-191).
--
-- AC1 -- THE POPULATION IS DERIVED LIVE, NOT COPIED FROM THE TICKET
--
--   SELECT conrelid::regclass, conname, confdeltype, confupdtype,
--          pg_get_constraintdef(oid)
--     FROM pg_constraint
--    WHERE confrelid = 'public.profiles'::regclass
--      AND contype = 'f'
--      AND confdeltype IN ('a','r');
--
-- returned 20 rows on 2026-09-11 (51 FKs reference profiles in total). Seven are
-- Part B and are excluded BY CONSTRAINT NAME, never by a table-name filter --
-- squads carries three and challenges two, so a table filter would over-exclude
-- on squads and cannot express "this constraint but not that one" at all:
--
--   challenges_owner_profile_id_fkey        (challenges)
--   fk_challenges_owner_profile             (challenges)
--   games_creator_profile_id_fkey           (games)
--   meetups_owner_profile_id_fkey           (meetups)     <- named *owner*, on column creator_profile_id
--   squads_created_by_profile_fkey          (squads)
--   squads_owner_profile_fkey               (squads)
--   squads_owner_profile_id_fkey            (squads)
--
-- 20 - 7 = 13, which is this migration's whole scope. posts contributes two of
-- them (a plain and a composite FK), which is why 12 tables yield 13 constraints.
-- squad_invites_to_profile_id_fkey is already CASCADE, so it never entered the
-- blocking set and is untouched -- only its sibling created_by_profile_id FK is here.
--
-- AC2 -- THE LANDMINE, AND WHY EVERY DEFINITION BELOW IS RESTATED IN FULL
--
-- Postgres cannot ALTER a foreign key's ON DELETE action in place; ALTER
-- CONSTRAINT only reaches deferrability. DROP + ADD is therefore forced, and DROP
-- discards EVERY attribute of the old constraint, not just the one being changed.
--
-- posts_author_user_profile_fkey is the only one of the 20 with a non-default
-- ON UPDATE -- confirmed live, confupdtype 'r' where the other 12 are all 'a':
--
--   FOREIGN KEY (author_user_id, author_profile_id) REFERENCES profiles(user_id, id)
--     ON UPDATE RESTRICT ON DELETE RESTRICT
--
-- A DROP + ADD that restates only ON DELETE silently downgrades that to NO ACTION
-- -- a real behaviour change smuggled in under what looks like a pure ON DELETE
-- fix, and invisible in a diff that reads "RESTRICT -> CASCADE" as intended. Every
-- definition below is therefore transcribed from that constraint's own live
-- pg_get_constraintdef output, with ON UPDATE restated verbatim where present.
-- This is T-058's whole-body-restatement discipline applied to constraints.
--
-- The composite FK resolves against the unique INDEX uq_profiles_user_id_id on
-- profiles(user_id, id) -- a unique index, not a unique constraint. Postgres
-- accepts either as an FK target, so the re-ADD finds it; checked before dropping,
-- because a DROP whose ADD cannot succeed would leave posts unconstrained.
--
-- WHY THE ASSERTIONS EXIST
--
-- The pre-check fails the whole transaction if the live constraint set has drifted
-- from the census this file was authored against -- a 21st blocking constraint
-- appearing between census and apply would otherwise go silently unfixed, and an
-- action that had already changed would be re-derived from a stale assumption.
-- The post-check asserts the end state from pg_constraint inside the same
-- transaction, so a partial or wrong result rolls back rather than being reported
-- as success. Both are structural: neither can pass by reading this file.
--
-- EVERY GUARD BELOW WAS DEMONSTRATED FAILING BEFORE THIS FILE WAS TRUSTED.
-- Prompted by backend-2's KAN-188 finding: an assert that matched on
-- pg_get_function_identity_arguments(oid) = 'uuid, uuid' never matched, because
-- that function emits parameter NAMES -- so every IF tested NULL, nothing raised,
-- and the assert passed while the exposure it guarded was still open. Run against
-- the live catalogue on 2026-09-11, nothing here inferred from reading the SQL:
--
--   post-check vs the unconverted schema        -> raises, "found 0"
--   pre-check  vs the unconverted schema        -> passes, matches 13
--     (the pair is what matters: 0 and 13 from the same join prove the 0 is
--      confdeltype='c' discriminating, not a predicate that matches nothing)
--   one constraint name perturbed               -> 12, not 13
--   LANDMINE: posts_author_user_profile_fkey claimed ON UPDATE 'a' (real 'r')
--                                               -> 0, and the same row with the
--                                                  true 'r' -> 1. confupdtype is
--                                                  genuinely compared, so the one
--                                                  attribute this migration could
--                                                  silently destroy is guarded
--   Part-B list with one bogus name             -> 6, not 7
--   unique-index guard, absent index            -> reaches its own message
--   unique-index guard v3, column set perturbed -> 0, not 1
--
-- WHY THESE FAIL CLOSED AND backend-2'S FAILED OPEN. Every guard here is
-- "count, then RAISE IF n <> expected". A predicate that silently matches nothing
-- yields 0, and 0 <> expected, so it aborts. An assert shaped as
-- "RAISE IF <boolean>" has no such floor: a NULL boolean is not true, nothing
-- raises, and silence reads as success. The shape is the safety property, not the
-- care taken writing it.
--
-- LOCK / BLAST RADIUS
--
-- Each ADD CONSTRAINT takes SHARE ROW EXCLUSIVE on the referencing table AND on
-- public.profiles, and validates existing rows. Row counts at apply time:
-- posts 503, reactions 102, comments 67, and 0 in the other nine. profiles is
-- locked 13 times across this transaction; writes to profiles block for its
-- duration, reads are unaffected. At these sizes the window is milliseconds.
--
-- No NOT VALID + VALIDATE split: all 13 are convalidated = true today, so
-- reproducing them as NOT VALID would itself be an unrequested behaviour change.
--
-- LANDING MECHANISM
--
-- Not via `supabase db push` -- T-068 bars it. To be applied with apply_migration
-- by the owning backend-N under G-002 once the permission classifier allows it;
-- validation_route PEER, reviewer another backend-N.
--
-- WHAT SITTING 2 STILL OWES, AND WHY IT IS NOT HERE
--
-- ACs 3 and 4 -- an account blocked only by DELETE-group tables completing
-- delete_my_account(), and the same demonstrated against one of the 3 real
-- duplicate active/inactive profile pairs -- are NOT attempted by this file and
-- cannot be. They require deleting a real production user's data, which is
-- CEO-only under 019 and was not granted. They are also not authorable until
-- this migration has actually landed. Recorded here so their absence is a stated
-- gap rather than something a future reader has to notice is missing.

BEGIN;

-- ---------------------------------------------------------------- pre-check
DO $kan186_pre$
DECLARE
  n int;
BEGIN
  SELECT count(*) INTO n
    FROM (VALUES
      ('public.challenge_invites'::regclass,      'challenge_invites_created_by_profile_id_fkey',   'a', 'a'),
      ('public.comment_mentions'::regclass,       'comment_mentions_mentioned_profile_id_fkey',     'a', 'a'),
      ('public.comments'::regclass,               'post_comments_author_profile_id_fkey',           'r', 'a'),
      ('public.game_rating_events'::regclass,     'game_rating_events_rater_profile_id_fkey',       'r', 'a'),
      ('public.post_hides'::regclass,             'post_hides_owner_profile_id_fkey',               'a', 'a'),
      ('public.post_mentions'::regclass,          'post_mentions_mentioned_profile_id_fkey',        'a', 'a'),
      ('public.posts'::regclass,                  'posts_author_profile_id_fkey',                   'r', 'a'),
      ('public.posts'::regclass,                  'posts_author_user_profile_fkey',                 'r', 'r'),
      ('public.reactions'::regclass,              'post_reactions_actor_profile_id_fkey',           'a', 'a'),
      ('public.squad_invites'::regclass,          'squad_invites_created_by_profile_id_fkey',       'r', 'a'),
      ('public.squad_join_requests'::regclass,    'squad_join_requests_profile_id_fkey',            'r', 'a'),
      ('public.user_reputation_events'::regclass, 'user_reputation_events_rater_profile_id_fkey',   'r', 'a'),
      ('public.venue_rating_events'::regclass,    'venue_rating_events_rater_profile_id_fkey',      'r', 'a')
    ) AS e(rel, cname, deltype, updtype)
    JOIN pg_constraint c
      ON c.conrelid = e.rel
     AND c.conname  = e.cname
     AND c.confrelid = 'public.profiles'::regclass
     AND c.contype = 'f'
     AND c.confdeltype = e.deltype
     AND c.confupdtype = e.updtype;

  IF n <> 13 THEN
    RAISE EXCEPTION 'KAN-186 pre-check: expected all 13 DELETE-group constraints in their authored state, matched %. The live set has drifted from the census this migration was authored against; re-derive before applying.', n;
  END IF;

  SELECT count(*) INTO n
    FROM pg_constraint
   WHERE confrelid = 'public.profiles'::regclass
     AND contype = 'f'
     AND confdeltype IN ('a','r');

  IF n <> 20 THEN
    RAISE EXCEPTION 'KAN-186 pre-check: the live blocking FK set is % constraints, not the 20 this migration enumerates. A constraint appeared or changed since the census and would go unfixed.', n;
  END IF;

  -- The composite FK's target index, which must be intact before its constraint
  -- is dropped. THIS GUARD WAS REWRITTEN TWICE, and the
  -- second rewrite is the one the shape rule above demanded of my own file.
  --
  -- v1 used 'public.uq_profiles_user_id_id'::regclass inside NOT EXISTS. Wrong:
  -- if the index were absent the CAST raises undefined_table (42P01) before
  -- NOT EXISTS is evaluated, so the abort is generic instead of the sentence
  -- below. Fail-closed, but the diagnostic dies exactly when it is needed.
  --
  -- v2 matched by name through pg_class. Still boolean-shaped -- IF NOT EXISTS --
  -- which was the ONLY guard in this file not in the count-then-compare form.
  -- EXISTS never returns NULL, so it could not fail open the way backend-2's
  -- did. But it asserted existence and uniqueness WITHOUT asserting columns: an
  -- index of that name over different columns would have satisfied it, and the
  -- real failure would then surface as a confusing ADD CONSTRAINT error rather
  -- than as this message. Weaker in a second way too -- it ignored indpred, and
  -- profiles carries exactly one PARTIAL unique index today
  -- (idx_one_active_profile_per_user, on (user_id) WHERE is_active), which
  -- cannot back a foreign key at all. Counted live: 1, so that is a real
  -- object in this schema and not a hypothetical.
  --
  -- v3, below, is count-shaped and asserts the column SET. Demonstrated live:
  -- 1 against the real catalogue, 0 with the column expectation perturbed.
  SELECT count(*) INTO n
    FROM pg_index i
    JOIN pg_class ic ON ic.oid = i.indexrelid
    JOIN pg_namespace ns ON ns.oid = ic.relnamespace
   WHERE i.indrelid = 'public.profiles'::regclass
     AND i.indisunique
     AND NOT i.indisexclusion
     AND i.indpred IS NULL
     AND ns.nspname = 'public'
     AND ic.relname = 'uq_profiles_user_id_id'
     AND (SELECT array_agg(a.attname::text ORDER BY a.attname)
            FROM unnest(i.indkey::int[]) AS k(attnum)
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.attnum)
         = ARRAY['id','user_id'];

  IF n <> 1 THEN
    RAISE EXCEPTION 'KAN-186 pre-check: expected exactly 1 total unique index public.uq_profiles_user_id_id on profiles over {user_id, id}, found %. posts_author_user_profile_fkey could be dropped but not recreated.', n;
  END IF;
END
$kan186_pre$;

-- ------------------------------------------------------- the 13 conversions
-- Each pair: the live definition, then the same definition with ON DELETE
-- CASCADE and every other attribute restated unchanged.

-- 1. challenge_invites -- live: FOREIGN KEY (created_by_profile_id) REFERENCES profiles(id)
ALTER TABLE public.challenge_invites
  DROP CONSTRAINT challenge_invites_created_by_profile_id_fkey;
ALTER TABLE public.challenge_invites
  ADD CONSTRAINT challenge_invites_created_by_profile_id_fkey
  FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 2. comment_mentions -- live: FOREIGN KEY (mentioned_profile_id) REFERENCES profiles(id)
ALTER TABLE public.comment_mentions
  DROP CONSTRAINT comment_mentions_mentioned_profile_id_fkey;
ALTER TABLE public.comment_mentions
  ADD CONSTRAINT comment_mentions_mentioned_profile_id_fkey
  FOREIGN KEY (mentioned_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 3. comments -- live: FOREIGN KEY (author_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.comments
  DROP CONSTRAINT post_comments_author_profile_id_fkey;
ALTER TABLE public.comments
  ADD CONSTRAINT post_comments_author_profile_id_fkey
  FOREIGN KEY (author_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 4. game_rating_events -- live: FOREIGN KEY (rater_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.game_rating_events
  DROP CONSTRAINT game_rating_events_rater_profile_id_fkey;
ALTER TABLE public.game_rating_events
  ADD CONSTRAINT game_rating_events_rater_profile_id_fkey
  FOREIGN KEY (rater_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 5. post_hides -- live: FOREIGN KEY (owner_profile_id) REFERENCES profiles(id)
ALTER TABLE public.post_hides
  DROP CONSTRAINT post_hides_owner_profile_id_fkey;
ALTER TABLE public.post_hides
  ADD CONSTRAINT post_hides_owner_profile_id_fkey
  FOREIGN KEY (owner_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 6. post_mentions -- live: FOREIGN KEY (mentioned_profile_id) REFERENCES profiles(id)
ALTER TABLE public.post_mentions
  DROP CONSTRAINT post_mentions_mentioned_profile_id_fkey;
ALTER TABLE public.post_mentions
  ADD CONSTRAINT post_mentions_mentioned_profile_id_fkey
  FOREIGN KEY (mentioned_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 7. posts (plain) -- live: FOREIGN KEY (author_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.posts
  DROP CONSTRAINT posts_author_profile_id_fkey;
ALTER TABLE public.posts
  ADD CONSTRAINT posts_author_profile_id_fkey
  FOREIGN KEY (author_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 8. posts (composite) -- THE LANDMINE. Live definition, verbatim:
--      FOREIGN KEY (author_user_id, author_profile_id) REFERENCES profiles(user_id, id)
--        ON UPDATE RESTRICT ON DELETE RESTRICT
--    ON UPDATE RESTRICT is restated below. Omitting it would silently downgrade
--    this constraint to ON UPDATE NO ACTION.
ALTER TABLE public.posts
  DROP CONSTRAINT posts_author_user_profile_fkey;
ALTER TABLE public.posts
  ADD CONSTRAINT posts_author_user_profile_fkey
  FOREIGN KEY (author_user_id, author_profile_id) REFERENCES public.profiles(user_id, id)
  ON UPDATE RESTRICT ON DELETE CASCADE;

-- 9. reactions -- live: FOREIGN KEY (actor_profile_id) REFERENCES profiles(id)
ALTER TABLE public.reactions
  DROP CONSTRAINT post_reactions_actor_profile_id_fkey;
ALTER TABLE public.reactions
  ADD CONSTRAINT post_reactions_actor_profile_id_fkey
  FOREIGN KEY (actor_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 10. squad_invites -- live: FOREIGN KEY (created_by_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
--     Its sibling squad_invites_to_profile_id_fkey is already CASCADE and is NOT touched.
ALTER TABLE public.squad_invites
  DROP CONSTRAINT squad_invites_created_by_profile_id_fkey;
ALTER TABLE public.squad_invites
  ADD CONSTRAINT squad_invites_created_by_profile_id_fkey
  FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 11. squad_join_requests -- live: FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.squad_join_requests
  DROP CONSTRAINT squad_join_requests_profile_id_fkey;
ALTER TABLE public.squad_join_requests
  ADD CONSTRAINT squad_join_requests_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 12. user_reputation_events -- live: FOREIGN KEY (rater_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.user_reputation_events
  DROP CONSTRAINT user_reputation_events_rater_profile_id_fkey;
ALTER TABLE public.user_reputation_events
  ADD CONSTRAINT user_reputation_events_rater_profile_id_fkey
  FOREIGN KEY (rater_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 13. venue_rating_events -- live: FOREIGN KEY (rater_profile_id) REFERENCES profiles(id) ON DELETE RESTRICT
ALTER TABLE public.venue_rating_events
  DROP CONSTRAINT venue_rating_events_rater_profile_id_fkey;
ALTER TABLE public.venue_rating_events
  ADD CONSTRAINT venue_rating_events_rater_profile_id_fkey
  FOREIGN KEY (rater_profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- --------------------------------------------------------------- post-check
DO $kan186_post$
DECLARE
  n int;
BEGIN
  -- AC2, end state: all 13 are CASCADE, and confupdtype is unchanged from its
  -- pre-apply value for every one of them -- 'r' for the composite, 'a' for the rest.
  SELECT count(*) INTO n
    FROM (VALUES
      ('public.challenge_invites'::regclass,      'challenge_invites_created_by_profile_id_fkey',   'a'),
      ('public.comment_mentions'::regclass,       'comment_mentions_mentioned_profile_id_fkey',     'a'),
      ('public.comments'::regclass,               'post_comments_author_profile_id_fkey',           'a'),
      ('public.game_rating_events'::regclass,     'game_rating_events_rater_profile_id_fkey',       'a'),
      ('public.post_hides'::regclass,             'post_hides_owner_profile_id_fkey',               'a'),
      ('public.post_mentions'::regclass,          'post_mentions_mentioned_profile_id_fkey',        'a'),
      ('public.posts'::regclass,                  'posts_author_profile_id_fkey',                   'a'),
      ('public.posts'::regclass,                  'posts_author_user_profile_fkey',                 'r'),
      ('public.reactions'::regclass,              'post_reactions_actor_profile_id_fkey',           'a'),
      ('public.squad_invites'::regclass,          'squad_invites_created_by_profile_id_fkey',       'a'),
      ('public.squad_join_requests'::regclass,    'squad_join_requests_profile_id_fkey',            'a'),
      ('public.user_reputation_events'::regclass, 'user_reputation_events_rater_profile_id_fkey',   'a'),
      ('public.venue_rating_events'::regclass,    'venue_rating_events_rater_profile_id_fkey',      'a')
    ) AS e(rel, cname, updtype)
    JOIN pg_constraint c
      ON c.conrelid = e.rel
     AND c.conname  = e.cname
     AND c.confrelid = 'public.profiles'::regclass
     AND c.contype = 'f'
     AND c.confdeltype = 'c'
     AND c.confupdtype = e.updtype
     AND c.convalidated;

  IF n <> 13 THEN
    RAISE EXCEPTION 'KAN-186 post-check: expected 13 validated CASCADE constraints with ON UPDATE unchanged, found %.', n;
  END IF;

  -- AC5, asserted rather than promised: the seven Part-B constraints are all
  -- still present and still RESTRICT. Nothing in this migration reached them.
  SELECT count(*) INTO n
    FROM pg_constraint
   WHERE confrelid = 'public.profiles'::regclass
     AND contype = 'f'
     AND confdeltype = 'r'
     AND conname IN ('challenges_owner_profile_id_fkey','fk_challenges_owner_profile',
                     'games_creator_profile_id_fkey','meetups_owner_profile_id_fkey',
                     'squads_created_by_profile_fkey','squads_owner_profile_fkey',
                     'squads_owner_profile_id_fkey');

  IF n <> 7 THEN
    RAISE EXCEPTION 'KAN-186 post-check: expected the 7 Part-B constraints untouched and still RESTRICT, found %.', n;
  END IF;

  -- And the blocking set is now exactly those seven and nothing else.
  SELECT count(*) INTO n
    FROM pg_constraint
   WHERE confrelid = 'public.profiles'::regclass
     AND contype = 'f'
     AND confdeltype IN ('a','r');

  IF n <> 7 THEN
    RAISE EXCEPTION 'KAN-186 post-check: expected 7 blocking FKs remaining (all Part B), found %.', n;
  END IF;
END
$kan186_post$;

COMMIT;
