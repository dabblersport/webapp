-- Applied to remote as migration version 20260701170909.
--
-- Guideline 5.1.1 fix: delete_my_account() previously only ran
-- `delete from auth.users` and relied on ON DELETE CASCADE. Most tables
-- cascade correctly, but a handful of NOT NULL / ON DELETE NO ACTION or
-- RESTRICT foreign keys (created_by / approved_by / verified_by audit
-- columns on meetup_invites, meetup_link_tokens, squad_link_tokens,
-- game_link_tokens, user_freezes, blackouts, venue_bookings, role_grants,
-- profile_verifications, point_ledger, venue_submissions) would cause the
-- delete to raise a foreign-key violation and fail for any user who had
-- ever created one of those rows. Storage objects (avatars, post media)
-- were also never cleaned up. This migration makes deletion actually
-- succeed and fully erase the account's data, as required by Apple's
-- account-deletion guideline.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove storage objects owned by this user (avatars, post media, etc.)
  -- so no orphaned files remain after the account is gone.
  delete from storage.objects where owner = v_uid;

  -- Null out nullable audit/reference columns that don't cascade
  -- (ON DELETE SET NULL semantics applied manually, in-place).
  update public.role_grants set granted_by = null where granted_by = v_uid;
  update public.profile_verifications set verified_by = null where verified_by = v_uid;
  update public.point_ledger set created_by = null where created_by = v_uid;
  update public.venue_submissions set revoked_by = null where revoked_by = v_uid;
  update public.venue_submissions set rejected_by = null where rejected_by = v_uid;
  update public.venue_submissions set approved_by = null where approved_by = v_uid;
  update public.venue_submissions set returned_by = null where returned_by = v_uid;

  -- Delete rows with NOT NULL / restrictive FKs to auth.users that would
  -- otherwise block the account deletion outright. These are all
  -- user-owned artifacts (invite/link tokens, bookings, freezes the user
  -- issued), so deleting them is the correct "erase associated data"
  -- behaviour, not just a workaround.
  delete from public.meetup_invites where created_by = v_uid;
  delete from public.meetup_link_tokens where created_by = v_uid;
  delete from public.squad_link_tokens where created_by = v_uid;
  delete from public.game_link_tokens where created_by = v_uid;
  delete from public.user_freezes where created_by = v_uid;
  delete from public.blackouts where created_by = v_uid;
  delete from public.venue_bookings where created_by = v_uid;

  -- Finally remove the auth user. ON DELETE CASCADE now handles the rest:
  -- profiles, posts, comments, likes, wallets, notifications, user_blocks,
  -- moderation_reports, consent_records, fcm_tokens, etc.
  delete from auth.users where id = v_uid;
end;
$function$;
