-- KAN-971: following a hashtag writes user_hashtag_preferences.
-- KAN-86 left `authenticated` with SELECT only, so every follow write was
-- refused with "permission denied". The row-level policy uhp_write
-- (user_id = auth.uid()) already scopes writes to the caller's own rows.
GRANT INSERT, UPDATE, DELETE ON public.user_hashtag_preferences TO authenticated;
