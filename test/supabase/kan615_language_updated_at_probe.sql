-- KAN-615 probe. Run on a LOCAL or BRANCH database that has the migration applied (never production). Everything
-- runs in one transaction and is rolled back. NOT run by the authoring team.
BEGIN;

DO $$
DECLARE
  pid uuid;
  before_ts timestamptz;
  after_ts timestamptz;
BEGIN
  SELECT id INTO pid FROM public.profiles WHERE language_updated_at IS NULL LIMIT 1;
  IF pid IS NULL THEN RAISE EXCEPTION 'probe needs a profile row with language_updated_at NULL (a pre-migration row)'; END IF;

  -- (c) an existing row reads NULL
  SELECT language_updated_at INTO before_ts FROM public.profiles WHERE id = pid;
  IF before_ts IS NOT NULL THEN RAISE EXCEPTION '(c) expected NULL, got %', before_ts; END IF;

  -- (b) another column does not change it
  UPDATE public.profiles SET bio = coalesce(bio, '') || ' ' WHERE id = pid;
  SELECT language_updated_at INTO after_ts FROM public.profiles WHERE id = pid;
  IF after_ts IS NOT NULL THEN RAISE EXCEPTION '(b) bio update changed language_updated_at'; END IF;

  -- (a) a language change sets it to ~now
  UPDATE public.profiles
     SET language = CASE WHEN language = 'ar' THEN 'en' ELSE 'ar' END
   WHERE id = pid;
  SELECT language_updated_at INTO after_ts FROM public.profiles WHERE id = pid;
  IF after_ts IS NULL OR after_ts < now() - interval '1 minute' THEN
    RAISE EXCEPTION '(a) language change did not stamp language_updated_at (%)', after_ts;
  END IF;

  -- a client cannot set it directly
  UPDATE public.profiles SET language_updated_at = '2000-01-01' WHERE id = pid;
  SELECT language_updated_at INTO before_ts FROM public.profiles WHERE id = pid;
  IF before_ts IS DISTINCT FROM after_ts THEN RAISE EXCEPTION 'direct write to language_updated_at was accepted'; END IF;

  -- setting language to the same value is not a change
  UPDATE public.profiles SET language = language WHERE id = pid;
  SELECT language_updated_at INTO before_ts FROM public.profiles WHERE id = pid;
  IF before_ts IS DISTINCT FROM after_ts THEN RAISE EXCEPTION 'same-value language write stamped the column'; END IF;

  RAISE NOTICE 'KAN-615 probe: all checks passed';
END $$;

ROLLBACK;
