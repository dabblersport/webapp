-- KAN-177: repair venue authorisation functions that reference public.organiser_profiles,
-- a relation that does not exist (the live table is public.organiser). All five raise
-- 42P01 at function startup, so every RLS policy depending on them is inoperative.
--
-- Pure substitution: public.organiser_profiles -> public.organiser.
-- Bodies are taken verbatim from pg_get_functiondef on the live catalogue (CONVENTIONS.md 6g),
-- so SECURITY DEFINER, search_path and row_security attributes are reproduced exactly.
-- CREATE OR REPLACE (not DROP+CREATE) preserves proacl; DROP would reset to pg_default_acl
-- and silently re-grant anon by name.

CREATE OR REPLACE FUNCTION public.can_manage_venue(p_user_id uuid, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select
    -- Global admin
    public.is_admin(p_user_id)

    -- Global venue admin role
    or exists (
      select 1
      from public.role_grants rg
      where rg.user_id = p_user_id
        and rg.role = 'venue_admin'
    )

    -- Scoped organiser ↔ venue relationship
    or exists (
      select 1
      from public.organiser_venues ov
      join public.organiser op
        on op.id = ov.organiser_profile_id
      join public.profiles p
        on p.id = op.profile_id
      where ov.venue_id = p_venue_id
        and p.user_id = p_user_id
        and ov.role in ('partner', 'manager', 'host')
    );
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_venue_members(p_user_id uuid, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select
    -- Global admin
    public.is_admin(p_user_id)

    -- Global venue admin role
    or exists (
      select 1
      from public.role_grants rg
      where rg.user_id = p_user_id
        and rg.role = 'venue_admin'
    )

    -- Scoped organiser with ownership authority
    or exists (
      select 1
      from public.organiser_venues ov
      join public.organiser op
        on op.id = ov.organiser_profile_id
      join public.profiles p
        on p.id = op.profile_id
      where ov.venue_id = p_venue_id
        and p.user_id = p_user_id
        and ov.role = 'partner'
    );
$function$;

CREATE OR REPLACE FUNCTION public.can_view_venue_bookings(p_user_id uuid, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select
    -- Global admins can view all bookings
    public.is_admin(p_user_id)

    -- Global venue admin role
    or exists (
      select 1
      from public.role_grants rg
      where rg.user_id = p_user_id
        and rg.role = 'venue_admin'
    )

    -- Scoped partner/manager access
    or exists (
      select 1
      from public.organiser_venues ov
      join public.organiser op
        on op.id = ov.organiser_profile_id
      join public.profiles p
        on p.id = op.profile_id
      where ov.venue_id = p_venue_id
        and p.user_id = p_user_id
        and ov.role in ('partner', 'manager')
    );
$function$;

CREATE OR REPLACE FUNCTION public.can_create_venue_booking(p_user_id uuid, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select
    -- Global admin
    public.is_admin(p_user_id)

    -- Global venue admin role
    or exists (
      select 1
      from public.role_grants rg
      where rg.user_id = p_user_id
        and rg.role = 'venue_admin'
    )

    -- Scoped organiser with booking authority
    or exists (
      select 1
      from public.organiser_venues ov
      join public.organiser op
        on op.id = ov.organiser_profile_id
      join public.profiles p
        on p.id = op.profile_id
      where ov.venue_id = p_venue_id
        and p.user_id = p_user_id
        and ov.role = 'partner'
    );
$function$;

CREATE OR REPLACE FUNCTION public.can_edit_venue_details(p_user_id uuid, p_venue_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET row_security TO 'off'
AS $function$
  select
    -- Global admin
    public.is_admin(p_user_id)

    -- Global venue admin role
    or exists (
      select 1
      from public.role_grants rg
      where rg.user_id = p_user_id
        and rg.role = 'venue_admin'
    )

    -- Scoped organiser with edit power
    or exists (
      select 1
      from public.organiser_venues ov
      join public.organiser op
        on op.id = ov.organiser_profile_id
      join public.profiles p
        on p.id = op.profile_id
      where ov.venue_id = p_venue_id
        and p.user_id = p_user_id
        and ov.role = 'partner'
    );
$function$;
