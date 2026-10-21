-- KAN-615: a comparable server timestamp for the profile language, so the offline settings sync (KAN-608) can apply
-- last-write-wins to it like the other synced settings.
--
-- AUTHORED ONLY. Not applied by the authoring team; Memphis applies it after CEO approval.
--
-- Naming: the ticket says `users.language`; the table behind it is `public.profiles` (SupabaseConfig.usersTable =
-- 'profiles'; there is no public.users). The column is added there.
--
-- Additive: one nullable column, one new function, one new trigger. No DROP of any table, column, policy, data or
-- pre-existing function. No RLS or grant change: the column inherits the existing table grants and row policies.
-- Existing rows stay NULL (never edited since this column existed); no backfill.
--
-- Server time, not a client timestamp: the trigger below stamps now() whenever `language` changes, and keeps the
-- column untouched on every other update (a client cannot write it directly).

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS language_updated_at timestamptz;

CREATE OR REPLACE FUNCTION public.trgfn_profiles_language_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.language IS DISTINCT FROM OLD.language THEN
    NEW.language_updated_at := now();
  ELSE
    NEW.language_updated_at := OLD.language_updated_at;
  END IF;
  RETURN NEW;
END;
$$;

-- Drops only the trigger this migration creates (re-run safe).
DROP TRIGGER IF EXISTS trg_profiles_language_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_language_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trgfn_profiles_language_updated_at();

COMMIT;
