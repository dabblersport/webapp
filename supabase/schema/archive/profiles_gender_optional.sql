-- Gender is optional in onboarding Step 1: allow profiles.gender to be NULL.
-- The default ('male') is dropped so an omitted gender is stored as NULL rather
-- than being silently guessed. rpc_onboard_profile passes p_gender through
-- lower(), which yields NULL for NULL, so no function change is required.

ALTER TABLE public.profiles
  ALTER COLUMN gender DROP NOT NULL,
  ALTER COLUMN gender DROP DEFAULT;
