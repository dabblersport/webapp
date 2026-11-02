-- KAN-775 (KAN-718 D07, Epic KAN-708): series occurrence uniqueness keyed on events.start_at, enforced at the
-- statement, so it still holds -- with the same product error -- once games.start_at and its index are withdrawn.
-- AUTHORED, NOT APPLIED. Review + apply through the normal Thebes path. Additive only: nothing is dropped, and
-- games_series_id_start_at_key (20261030120000_kan693_rpc_create_game_series.sql:33-34) stays; withdrawing it is
-- a later KAN-718 ticket.
--
-- THE INVARIANT. Today: UNIQUE (games.series_id, games.start_at) WHERE series_id IS NOT NULL, a NON-deferrable
-- unique index. Its contract, as consumed:
--   * fn_generate_game_series_occurrences (20261030140000:33-84) skips a slot that already exists, cancelled or not;
--   * rpc_edit_game_series_occurrence / rpc_edit_game_series_future (20261030130000) catch unique_violation
--     around their UPDATE and re-raise P0001 'occurrence_time_taken' -- which only works because the index
--     fires inside the statement, inside the RPC's BEGIN ... EXCEPTION block.
-- Once start_at lives on events the equivalent is: one events.start_at per games.series_id across all
-- occurrences (cancelled rows keep their slot), raised as 23505 AT THE STATEMENT.
--
-- WHY THIS FORM (not an events-side unique index). events carries no series key: series_id is a game-only column
-- on games (20261027120000_kan671_game_series.sql). An index on events would need events.series_id, i.e. a new
-- shared column the KAN-712 write contract (kan712_legacy_guard / kan712_events_compat_mirror) would have to own
-- and mirror -- a write-contract change in another ticket's files, and a second copy of series_id (dual write).
-- A trigger over games.series_id x events.start_at needs neither, so it is the least-invasive correct form.
--
-- WHY NOT JUST KAN-710 4e. 20261101140000_kan710_events_parent_schema.sql:210-249 already has
-- events_check_series_occurrence, but as DEFERRABLE INITIALLY DEFERRED constraint triggers (:269-271, :293-295).
-- Without the legacy index a duplicate would then surface only at COMMIT, as a raw 23505 the RPCs never see:
-- 'occurrence_time_taken' would silently become a generic error (local proof: probe W1 FAILs on the chain
-- without this migration). This migration adds the immediate twin; KAN-710's deferred check stays untouched
-- as the backstop (it also covers the games-before-events insert order, see below).
--
-- MECHANISM. public.kan718_series_occurrence_guard(), plain AFTER ROW triggers (fire at end of statement):
--   events: AFTER INSERT OR UPDATE OF start_at  -- the authoritative time write. KAN-712's guard routes every
--           legacy games UPDATE through an UPDATE of events (kan712_legacy_guard 2d), so this fires inside the
--           RPC statement and the RPC's unique_violation handler still maps it.
--   games:  AFTER INSERT OR UPDATE OF series_id, event_id  -- an occurrence joining a series (generator shape:
--           game created, then series_id set). games.start_at is deliberately NOT a trigger column, so the
--           later DROP COLUMN of games.start_at is not blocked by a dependency.
-- Serialisation: pg_advisory_xact_lock(hashtext('events_series:' || series_id)) -- the SAME key KAN-710 uses --
-- taken after the row write and held to commit; a concurrent writer of the same series waits, then re-reads
-- under a new READ COMMITTED statement snapshot and sees the winner. Every series game is event-linked:
-- KAN-711's validated games_event_id_not_null (20261102120000:307-315) is a pre-check here, so no occurrence
-- can be skipped by the event_id IS NULL branch.
-- Index: the guard probes games by series_id; KAN-671's games_series_id_idx serves it after the composite index
-- goes. CREATE INDEX IF NOT EXISTS with KAN-671's exact definition: a no-op where KAN-671 is applied.
--
-- Security: function owned by postgres, SECURITY DEFINER (it must read events, which no client role can),
-- search_path pinned to '' with every name qualified, EXECUTE revoked from PUBLIC/anon/authenticated/service_role
-- (KAN-711 convention). No table, view, grant or policy is created or changed; no row is written.
--
-- LIMITS. (1) Read-committed semantics, like KAN-710: a REPEATABLE READ/SERIALIZABLE writer racing another on
-- the same series could miss the winner's row (SERIALIZABLE would normally abort one via SSI). PostgREST and the
-- RPCs run READ COMMITTED. (2) A trigger, unlike an index, is skipped under session_replication_role = replica.
-- (3) KAN-712's re-cut post-condition (20261103110000:194-200) asserts the exact events trigger set; it already
-- differs after KAN-713 (trg_kan713_events_location) and differs again here -- a re-cut must drop or account for
-- both. Recorded, not changed (other tickets' files).
--
-- ROLLBACK (data-neutral; run in one transaction, before rolling back any earlier events migration):
--   DROP TRIGGER IF EXISTS trg_kan718_events_series_occurrence ON public.events;
--   DROP TRIGGER IF EXISTS trg_kan718_games_series_occurrence ON public.games;
--   DROP FUNCTION IF EXISTS public.kan718_series_occurrence_guard();
--   -- games_series_id_idx is KAN-671's index on live: do NOT drop it.
-- After rollback the invariant is held by games_series_id_start_at_key (+ KAN-710's deferred backstop); the
-- rollback must therefore not run after the index has been withdrawn.

begin;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions: predecessors present, data clean. Refuse; never repair or dedupe.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_dups bigint;
  v_unlinked bigint;
begin
  if to_regclass('public.events') is null or to_regclass('public.game_series') is null then
    raise exception 'KAN-775 pre: public.events (KAN-710) or public.game_series (KAN-671) missing';
  end if;
  if not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'series_id' and not attisdropped)
     or not exists (select 1 from pg_attribute where attrelid = 'public.games'::regclass and attname = 'event_id' and not attisdropped) then
    raise exception 'KAN-775 pre: games.series_id (KAN-671) or games.event_id (KAN-710) missing';
  end if;
  if to_regproc('public.events_check_series_occurrence') is null
     or (select count(*) from pg_trigger
          where (tgrelid, tgname) in (('public.events'::regclass, 'trg_events_series_start_check'),
                                      ('public.games'::regclass,  'trg_games_series_occurrence_check'))
            and tgenabled = 'O' and tgdeferrable and tginitdeferred) <> 2 then
    raise exception 'KAN-775 pre: KAN-710 series backstop (events_check_series_occurrence + its 2 deferred triggers) missing or disabled';
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.games'::regclass
                  and conname = 'games_event_id_not_null' and convalidated) then
    raise exception 'KAN-775 pre: KAN-711 games_event_id_not_null missing or not validated (a series game could be unlinked)';
  end if;
  if (select count(*) from pg_trigger where tgname like 'trg\_zz\_kan712\_%' and tgenabled = 'O') <> 5 then
    raise exception 'KAN-775 pre: KAN-712 stage B (20261103110000) not live';
  end if;
  -- First application only: the legacy index must still be there (this ticket lands before its withdrawal).
  if to_regproc('public.kan718_series_occurrence_guard') is null
     and to_regclass('public.games_series_id_start_at_key') is null then
    raise exception 'KAN-775 pre: games_series_id_start_at_key (KAN-693) is absent; D07 must be applied before the withdrawal';
  end if;

  select count(*) into v_unlinked
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where g.series_id is not null and e.id is null;
  if v_unlinked > 0 then
    raise exception 'KAN-775 pre: % series game(s) without a game events parent; reconcile first', v_unlinked;
  end if;

  select count(*) into v_dups from (
    select g.series_id, e.start_at
      from public.games g join public.events e on e.id = g.event_id
     where g.series_id is not null
     group by 1, 2 having count(*) > 1) d;
  if v_dups > 0 then
    raise exception 'KAN-775 pre: % duplicate (series_id, events.start_at) slot(s) exist; refusing (no silent dedupe)', v_dups;
  end if;
end
$pre$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Index the guard's lookup (KAN-671's definition; no-op where it exists)
-- ---------------------------------------------------------------------------------------------------------
create index if not exists games_series_id_idx on public.games (series_id) where series_id is not null;

-- ---------------------------------------------------------------------------------------------------------
-- 2. The guard
-- ---------------------------------------------------------------------------------------------------------
create or replace function public.kan718_series_occurrence_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_sid   uuid;
  v_ev    uuid;
  v_start timestamptz;
begin
  if tg_table_name = 'games' then
    if new.series_id is null or new.event_id is null then
      return null;
    end if;
    if tg_op = 'UPDATE' and new.series_id is not distinct from old.series_id
                        and new.event_id  is not distinct from old.event_id then
      return null;
    end if;
    v_sid := new.series_id;
    v_ev  := new.event_id;
    select e.start_at into v_start from public.events e where e.id = v_ev;
    if not found then
      return null;   -- parent not inserted yet (games-first order): the events INSERT branch + KAN-710 backstop cover it
    end if;
  elsif tg_table_name = 'events' then
    if new.event_type <> 'game' then
      return null;
    end if;
    if tg_op = 'UPDATE' and new.start_at is not distinct from old.start_at then
      return null;   -- KAN-712 routing lists start_at in every SET; only a real move matters
    end if;
    select g.series_id into v_sid from public.games g where g.event_id = new.id;
    if v_sid is null then
      return null;
    end if;
    v_ev    := new.id;
    v_start := new.start_at;
  else
    raise exception 'kan718_series_occurrence_guard: unsupported table %.%', tg_table_schema, tg_table_name;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('events_series:' || v_sid::text));

  if exists (
    select 1
      from public.games g
      join public.events e on e.id = g.event_id
     where g.series_id = v_sid
       and g.event_id <> v_ev
       and e.start_at = v_start
  ) then
    raise exception using
      errcode    = 'unique_violation',
      constraint = 'kan718_series_occurrence_unique',
      message    = format('series %s already has an occurrence at this start_at', v_sid),
      detail     = format('series_id=%s start_at=%s event_id=%s', v_sid, v_start, v_ev);
  end if;
  return null;
end
$fn$;

alter function public.kan718_series_occurrence_guard() owner to postgres;
revoke all on function public.kan718_series_occurrence_guard() from public, anon, authenticated, service_role;

comment on function public.kan718_series_occurrence_guard() is
  'KAN-775 (KAN-718 D07): one events.start_at per games.series_id, raised as 23505 at the statement. '
  'Successor of games_series_id_start_at_key once games.start_at is withdrawn; KAN-710 events_check_series_occurrence stays as the deferred backstop.';

-- ---------------------------------------------------------------------------------------------------------
-- 3. Triggers (immediate: not deferrable)
-- ---------------------------------------------------------------------------------------------------------
create or replace trigger trg_kan718_events_series_occurrence
  after insert or update of start_at on public.events
  for each row execute function public.kan718_series_occurrence_guard();

create or replace trigger trg_kan718_games_series_occurrence
  after insert or update of series_id, event_id on public.games
  for each row execute function public.kan718_series_occurrence_guard();

-- ---------------------------------------------------------------------------------------------------------
-- 4. Postconditions
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  f regprocedure := 'public.kan718_series_occurrence_guard()'::regprocedure;
begin
  if (select pg_get_userbyid(proowner) from pg_proc where oid = f) <> 'postgres'
     or not (select prosecdef from pg_proc where oid = f)
     or (select proconfig from pg_proc where oid = f) is distinct from array['search_path=""'] then
    raise exception 'KAN-775 post: guard owner/SECURITY DEFINER/search_path wrong';
  end if;
  if has_function_privilege('anon', f, 'EXECUTE') or has_function_privilege('authenticated', f, 'EXECUTE')
     or has_function_privilege('service_role', f, 'EXECUTE')
     or exists (select 1 from aclexplode((select proacl from pg_proc where oid = f)) a where a.grantee = 0) then
    raise exception 'KAN-775 post: guard EXECUTE is granted to a client role or PUBLIC';
  end if;
  if (select count(*) from pg_trigger
       where tgfoid = f and tgenabled = 'O' and not tgdeferrable
         and (tgrelid, tgname) in (('public.events'::regclass, 'trg_kan718_events_series_occurrence'),
                                   ('public.games'::regclass,  'trg_kan718_games_series_occurrence'))) <> 2 then
    raise exception 'KAN-775 post: the two immediate kan718 triggers are not both present and enabled';
  end if;
  if (select count(*) from pg_trigger
       where (tgrelid, tgname) in (('public.events'::regclass, 'trg_events_series_start_check'),
                                   ('public.games'::regclass,  'trg_games_series_occurrence_check'))
         and tgenabled = 'O' and tgdeferrable and tginitdeferred) <> 2 then
    raise exception 'KAN-775 post: KAN-710 deferred backstop changed';
  end if;
  if to_regclass('public.games_series_id_start_at_key') is null and to_regclass('public.games_series_id_idx') is null then
    raise exception 'KAN-775 post: no index serves games.series_id';
  end if;
end
$post$;

commit;
