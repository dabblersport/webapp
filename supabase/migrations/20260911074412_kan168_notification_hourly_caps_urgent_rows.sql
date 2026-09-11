-- KAN-168 / T-067 — `urgent` has no hourly cap. Fix the DATA, not the NULL branch.
-- Authored and applied by backend-5 (Heka) 2026-09-11.
--
-- APPLIED: forward-only via MCP `apply_migration`, never `db push` (T-068).
-- Remote ledger version 20260911074412, name
-- `kan168_notification_hourly_caps_urgent_rows`.
--
-- THIS FILENAME IS DELIBERATELY THE LEDGER VERSION, NOT A ROUND-HOUR STAMP.
-- T-068 §B found 25 of 28 repo migrations absent from the remote ledger for
-- exactly one reason: `apply_migration` writes its own second-precision version
-- and never learns the repo filename, while the repo file was written
-- separately by hand with a round-hour stamp, so "the two artefacts were never
-- linked". This file was renamed from 20260911080000_ to the version the ledger
-- actually recorded, after applying. It costs nothing and it makes this
-- migration the one case where `supabase migration list` can match repo to
-- remote by name. Do not "tidy" it back to a round hour.
--
-- ===========================================================================
-- WHAT THIS DOES
-- ===========================================================================
-- public.notification_hourly_caps carries a cap row per (plan_key, priority).
-- public.notify_priority is a FOUR-value enum (low, normal, high, urgent) but
-- only THREE rungs are populated, on every plan. can_send_notification_now
-- reads a missing cap row as `IF v_cap IS NULL THEN RETURN true`, so a call at
-- `urgent` returns true unconditionally — an unbounded send.
--
-- This migration adds the missing `urgent` rung, one row per plan, at
-- max_per_hour = 50, and then ASSERTS completeness in the same transaction.
--
-- ===========================================================================
-- WHY DATA AND NOT THE NULL BRANCH (T-067, and the rejection is load-bearing)
-- ===========================================================================
-- Changing `IF v_cap IS NULL THEN RETURN true` to deny looks like the wider fix
-- and is the more dangerous one: a blanket deny-on-missing-row means any future
-- plan_key added without cap rows silences every notification for its users —
-- precisely the failure KAN-155 step 5 exists to prevent, where the retired
-- 'kickoff' literal made the lookup miss. Fail-open there is DELIBERATE.
-- can_send_notification_now is untouched by this migration: body, prosecdef,
-- provolatile and search_path all stay exactly as they are.
--
-- WHY 50
-- The live ladder is 5 / 10 / 20 (low / normal / high). 50 sits above the high
-- rung by the same order the ladder already uses, is far above any legitimate
-- urgent volume, and still bounds a runaway loop. FLAT across all plans because
-- the live table is already flat — every one of the 8 plans carries an
-- identical 5/10/20. If plan differentiation is ever restored, `urgent` moves
-- with the rest of the ladder and is not re-decided here.
--
-- SEVERITY: LATENT, NOT LIVE. can_send_notification_now has no caller (zero
-- references in lib/, test/, supabase/functions/, and no database object
-- invokes it) and no notification kind emits `urgent`. Nothing is uncapped
-- today. It becomes a real fail-open the moment either half is wired, by
-- someone who is not re-reading the NULL branch.
--
-- ===========================================================================
-- MEASURED LIVE ON wtncuzcskpigqpmnxwws, 2026-09-11, BEFORE AUTHORING
-- ===========================================================================
--   subscription_plans           8 rows: corporate_growth, corporate_starter,
--                                organiser_free, organiser_pro, player_free,
--                                player_pro, venue_basic, venue_pro
--                                (the post-KAN-155 key set; kickoff/pro/prime
--                                are retired and absent)
--   notify_priority              4 values: low, normal, high, urgent
--   notification_hourly_caps    24 rows — every plan at low=5, normal=10,
--                                high=20. ZERO `urgent` rows on any plan.
--   expected after this file    32 = 8 plans x 4 priorities
--
-- The completeness assertion below was RUN AGAINST LIVE BEFORE THIS MIGRATION
-- and raised:
--   P0001: notification_hourly_caps incomplete: 24 rows, expected 32
--          (plans x notify_priority values)
-- A probe nobody has seen fail is not evidence. This one has been seen to fail.
--
-- ===========================================================================
-- WHY THE ROWS ARE DERIVED, NOT LISTED
-- ===========================================================================
-- The INSERT selects plan keys FROM public.subscription_plans rather than
-- hardcoding the eight. Two reasons, both correctness rather than taste:
--   1. notification_hourly_caps.plan_key is FK -> subscription_plans(key)
--      (notification_hourly_caps_plan_key_fkey, ON DELETE CASCADE). A derived
--      list cannot violate it; a hardcoded list can, and would fail at apply
--      time on any key that has moved. KAN-155 has already renamed this entire
--      key set once.
--   2. If a plan is added between authoring and apply, the derived insert
--      covers it and the assertion still passes. A hardcoded list would insert
--      8, leave the new plan uncapped, and the assertion would then correctly
--      abort the migration rather than silently shipping the same class of gap
--      this ticket exists to close.
--
-- ===========================================================================
-- WHY A COUNT IS A SUFFICIENT COMPLETENESS ASSERTION HERE
-- ===========================================================================
-- This is the non-obvious part, so it is stated rather than assumed. A bare
-- count would normally be a weak check. It is airtight on THIS table because
-- the table's own constraints bound the row set to the cross product:
--   * notification_hourly_caps_pkey is PRIMARY KEY (plan_key, priority), so no
--     (plan, priority) pair can appear twice;
--   * notification_hourly_caps_plan_key_fkey constrains plan_key to a real
--     subscription_plans row, so no row sits outside the plan set;
--   * priority is public.notify_priority, so no row sits outside the enum.
-- The rows are therefore a DUPLICATE-FREE SUBSET of plans x priorities. A
-- subset of a finite set whose cardinality equals that set IS that set — so
-- count = plans x priorities proves full coverage, not merely the right total.
-- Both factors are counted by join against the live catalogue; neither 8 nor 4
-- is written down as a literal anywhere below.

begin;

-- ---------------------------------------------------------------------------
-- 1. the missing `urgent` rung, one row per plan
-- ---------------------------------------------------------------------------
-- ON CONFLICT DO NOTHING absorbs nothing today — zero `urgent` rows were
-- measured live above. It is the idempotency guarantee for the writer (T-049
-- house invariant, KAN-128 precedent), not a fix for an observed duplicate. It
-- makes a re-drive of this migration a no-op instead of a 23505, and it
-- deliberately will NOT overwrite a cap someone has since tuned by hand.

insert into public.notification_hourly_caps (plan_key, priority, max_per_hour)
select p.key, 'urgent'::public.notify_priority, 50
  from public.subscription_plans p
on conflict (plan_key, priority) do nothing;

-- ---------------------------------------------------------------------------
-- 2. close the CLASS, in-transaction (T-067's actual requirement)
-- ---------------------------------------------------------------------------
-- The point of this block is not to check the eight rows above landed — it is
-- to make the ABSENCE LOUD from here on. The next plan_key or the next
-- notify_priority value added without cap rows fails its migration rather than
-- silently inheriting unlimited sends, which is exactly how this gap arrived.
-- KAN-155 step 6 established this DO $$ style; this follows it.
--
-- If this raises, the transaction aborts and nothing is written. That is the
-- intended behaviour. Do not loosen it to make a migration pass.

do $$
declare
  v_actual   int;
  v_expected int;
begin
  select count(*) into v_actual from public.notification_hourly_caps;

  select (select count(*) from public.subscription_plans)
       * (select count(*) from pg_enum e
            join pg_type t on t.oid = e.enumtypid
           where t.typname = 'notify_priority')
    into v_expected;

  if v_actual <> v_expected then
    raise exception
      'notification_hourly_caps incomplete: % rows, expected % (plans x notify_priority values)',
      v_actual, v_expected;
  end if;
end $$;

commit;
