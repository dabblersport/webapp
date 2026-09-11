-- KAN-68 (BUG-07): the safety blocklist fails open twice over.
--
-- Ruling: T-020 in docs/DECISIONS.md (renumbered 2026-08-28 from T-016) --
-- FIX, do not delete. Explicit exception to T-007's delete-by-default. This
-- migration is amended by T-040 on the EXECUTE surface; see the two notes
-- marked [T-040] below.
--
-- Defect 1 -- the locale predicate can never match. The body filters
--   (locale = 'any' or locale = p_locale)
-- which treats 'any' as a property of the STORED TERM, while every caller
-- passes it as the QUERY locale (lib/services/moderation_service.dart:546
-- defaults {String locale = 'any'} and passes it through at :553). Both
-- stored terms are locale='en', so with p_locale='any' neither branch fires
-- and the function returns 0 for content that IS on the list.
--
-- Defect 2 -- RLS returns zero rows to every real caller. The function is
-- SECURITY INVOKER over safety_blocklist_terms, which has relrowsecurity=true
-- and ZERO policies. Verified live 2026-08-31: prosecdef=false, policies=0.
-- Fixing either defect alone still yields a blocklist that passes everything.
--
-- T-020(a): the table gets a SECURITY DEFINER function, NOT a read policy. A
-- read policy for authenticated would work and would be wrong -- every user
-- could download the list of banned terms and author around it. A moderation
-- control whose contents are readable by the people it constrains is not a
-- control. This is NOT T-012 by analogy: T-012's revoke-not-policies stance
-- covers definer-FUNNEL tables (games, squad_members). These two tables are
-- not a funnel -- both referencing functions are prosecdef=false, so the
-- tables are unreachable rather than access-controlled. Same axis, different
-- objects, different instrument.
--
-- CAUTION: CREATE OR REPLACE FUNCTION can reset a function's ACL. The
-- REVOKE/GRANT statements below therefore run AFTER each replace, never
-- before, and name PUBLIC as well as the individual roles (an anon-reachable
-- EXECUTE has two independent sources in this project: the PUBLIC "=X/" entry
-- and an explicit anon=X entry -- revoking one leaves the other).

begin;

-- ---------------------------------------------------------------------------
-- 1. content_hits_blocklist -- fix the predicate AND the privilege context.
-- ---------------------------------------------------------------------------
-- The corrected predicate adds the missing branch: a caller asking for 'any'
-- matches terms of ALL locales, which is the evident intent.
--
-- is_regex = false is retained deliberately. Both stored terms are
-- is_regex=false; regex terms remain silently unevaluated. That is a separate,
-- pre-existing gap and is NOT folded in here -- it needs its own decision
-- about which regex engine and what timeout budget.
create or replace function public.content_hits_blocklist(
  p_text text,
  p_locale text default 'any'
)
returns integer
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select count(*)::int
  from public.safety_blocklist_terms
  where is_regex = false
    and (p_locale = 'any' or locale = 'any' or locale = p_locale)
    and position(
          lower(term)
        in lower(coalesce(p_text, ''))
        ) > 0;
$function$;

-- [T-040] EXECUTE is narrowed to authenticated. T-020 ruled on the TABLE read
-- and did not reach the EXECUTE surface, which its own remedy creates: a
-- SECURITY DEFINER function returning a hit COUNT is an oracle, and PostgREST
-- exposes every public definer function as an RPC endpoint. Left anon-callable
-- it would let an unauthenticated attacker recover the banned terms by
-- probing -- reintroducing, through the front door, exactly the leak T-020
-- closed at the table. No caller is unauthenticated: the only call site is a
-- method on the live ModerationService, always behind a signed-in session.
revoke all on function public.content_hits_blocklist(text, text) from public;
revoke all on function public.content_hits_blocklist(text, text) from anon;
grant execute on function public.content_hits_blocklist(text, text) to authenticated;
grant execute on function public.content_hits_blocklist(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 2. _get_context_config -- close the direct surface; do NOT make it definer.
-- ---------------------------------------------------------------------------
-- [T-040] This AMENDS T-020(a), which said "same treatment" for
-- context_rating_config via _get_context_config. Measured 2026-08-31: the
-- function's only callers are venue_rating_recompute and game_rating_recompute,
-- both prosecdef=true. A SECURITY INVOKER function called from a SECURITY
-- DEFINER function already executes with the definer's privileges, so those
-- two callers reach context_rating_config regardless of RLS. Nothing in the
-- app calls it -- grep over lib/ returns no Dart caller.
--
-- Making it definer would therefore buy nothing and would create a new
-- anon-reachable definer RPC. The narrower instrument achieves T-020's actual
-- goal -- the config is not readable by the people it prices -- so the
-- function stays INVOKER and simply loses its client-facing grants.
revoke all on function public._get_context_config(text) from public;
revoke all on function public._get_context_config(text) from anon;
revoke all on function public._get_context_config(text) from authenticated;

-- ---------------------------------------------------------------------------
-- 3. The tables themselves -- no direct client access at all.
-- ---------------------------------------------------------------------------
-- Both currently carry anon=arwdDxtm and authenticated=arwdDxtm (full CRUD).
-- Neither is written or read directly by any client path; the only sanctioned
-- access is through the functions above. Revoking ALL rather than only SELECT
-- is deliberate and is narrower in blast radius than KAN-86's project-wide
-- write-grant sweep -- these two tables are named explicitly and do not wait
-- on it.
revoke all on table public.safety_blocklist_terms from anon;
revoke all on table public.safety_blocklist_terms from authenticated;
revoke all on table public.context_rating_config from anon;
revoke all on table public.context_rating_config from authenticated;

commit;

-- ===========================================================================
-- VERIFICATION -- run AS ROLE authenticated. NEVER as service role.
-- ===========================================================================
-- A service-role test bypasses RLS entirely and passes while production fails.
-- That is exactly how this defect survived its original review. Run this block
-- separately, after the migration, and read every line of the output.
--
--   begin;
--   set local role authenticated;
--
--   -- 1. The headline assertion (KAN-68 AC2). MUST be > 0.
--   select public.content_hits_blocklist('buy a fake passport here') as hits;
--
--   -- 2. Explicit locale still works. MUST be > 0.
--   select public.content_hits_blocklist('buy a fake passport here', 'en') as hits_en;
--
--   -- 3. A non-matching locale MUST NOT match an 'en' term. MUST be 0.
--   select public.content_hits_blocklist('buy a fake passport here', 'fr') as hits_fr;
--
--   -- 4. Clean text MUST be 0 -- proves 1-3 are not passing vacuously.
--   select public.content_hits_blocklist('lets play football on saturday') as hits_clean;
--
--   -- 5. The table itself MUST be unreachable. MUST raise permission denied,
--   --    NOT return 0. A 0 here would mean the grant was revoked but RLS is
--   --    doing the hiding, which is the weaker of the two states.
--   select count(*) from public.safety_blocklist_terms;
--
--   rollback;
--
-- Then, as a normal (non-superuser) inspection, confirm the ACLs actually
-- landed -- CREATE OR REPLACE has reset them in this project before:
--
--   select proname, prosecdef, proacl::text
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and proname in ('content_hits_blocklist', '_get_context_config');
--   -- content_hits_blocklist MUST show prosecdef=t and NO anon entry and no
--   -- bare "=X/" PUBLIC entry.
--
--   select relname, relacl::text from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--   where n.nspname = 'public'
--     and relname in ('safety_blocklist_terms', 'context_rating_config');
--   -- Neither MUST show an anon= or authenticated= entry.
--
-- Application to production is PO-only (decision 019). Do not apply this file
-- as part of authoring it.
