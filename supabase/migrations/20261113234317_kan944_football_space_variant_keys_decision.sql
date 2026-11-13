-- KAN-944 item 3, product decision (coordinator, 2026-11-14): re-key 13 Football venue_spaces.
--   (a) football_touch (not a Football variant)  -> football_small_sided
--   (b) empty list, 5-a-side / 8-a-side          -> football_small_sided
--   (c) 6f6423cc (11s grass tagged futsal)       -> football_standard
--   (d) 59f5c1a8 (Athletics Track tagged futsal) is NOT changed: its only sport is Football (single sport_id) and
--       its surface is football_11s_grass, so an empty list would just create a new keyless Football space.
--   (e) the 5 NULL-key spaces are NOT changed.
-- Capacity: trg_set_venue_space_capacity (BEFORE UPDATE OF sport_variant_keys) overwrites capacity with the first
-- key's required_players (small_sided 14, standard 22). Every row below already has a capacity, so the second
-- UPDATE writes the old capacity back (it does not touch sport_variant_keys, so the trigger does not fire).
-- Old values (id | old keys | old capacity -> new keys | capacity kept):
--   622e6013-f334-4f0b-9eff-7a6946906b4f | {football_touch} | 12 -> {football_small_sided} | 12
--   1b0dacf7-f646-4296-ac48-41b948cbdde3 | {football_touch} | 12 -> {football_small_sided} | 12
--   a17c00f8-c5ab-41df-90db-2ac161a9293d | {football_touch} | 12 -> {football_small_sided} | 12
--   ebb3b2a2-4c05-4f6c-89b0-68d560ddd56c | {football_touch} | 12 -> {football_small_sided} | 12
--   dc8a289a-adf4-4ba4-a1f3-9fb1c4a4eabd | {}               | 10 -> {football_small_sided} | 10
--   c8813f0e-2ce5-420d-a32a-085a4c7c3e5d | {}               | 10 -> {football_small_sided} | 10
--   f7bf8832-5234-43e1-af3e-43a911c320bc | {}               | 16 -> {football_small_sided} | 16
--   dcd76b60-1dc9-49bb-89f0-879a86c19986 | {}               | 10 -> {football_small_sided} | 10
--   adb6eaac-18de-44e3-9a2b-a8b7846c015c | {}               | 10 -> {football_small_sided} | 10
--   6aad9fd7-889c-46f8-9e31-3c55adbb20e0 | {}               | 10 -> {football_small_sided} | 10
--   39be907c-d677-4bb2-8bfe-512c37983daa | {}               | 10 -> {football_small_sided} | 10
--   510b6f11-2563-4687-918a-3c42c97ca9a9 | {}               | 10 -> {football_small_sided} | 10
--   6f6423cc-2fb8-4ac6-80bd-3a0dbd817f71 | {football_futsal}| 10 -> {football_standard}    | 10
-- Reverse: set sport_variant_keys back to the old keys, then capacity back to the old capacity, guarded on the new values.
-- Applied live 2026-11-14 (recorded version 20261113234317).

DO $mig$
DECLARE n int;
BEGIN
  CREATE TEMP TABLE kan944_map (id uuid PRIMARY KEY, old_keys text[], new_keys text[], old_cap int) ON COMMIT DROP;
  INSERT INTO kan944_map VALUES
    ('622e6013-f334-4f0b-9eff-7a6946906b4f', '{football_touch}',  '{football_small_sided}', 12),
    ('1b0dacf7-f646-4296-ac48-41b948cbdde3', '{football_touch}',  '{football_small_sided}', 12),
    ('a17c00f8-c5ab-41df-90db-2ac161a9293d', '{football_touch}',  '{football_small_sided}', 12),
    ('ebb3b2a2-4c05-4f6c-89b0-68d560ddd56c', '{football_touch}',  '{football_small_sided}', 12),
    ('dc8a289a-adf4-4ba4-a1f3-9fb1c4a4eabd', '{}',                '{football_small_sided}', 10),
    ('c8813f0e-2ce5-420d-a32a-085a4c7c3e5d', '{}',                '{football_small_sided}', 10),
    ('f7bf8832-5234-43e1-af3e-43a911c320bc', '{}',                '{football_small_sided}', 16),
    ('dcd76b60-1dc9-49bb-89f0-879a86c19986', '{}',                '{football_small_sided}', 10),
    ('adb6eaac-18de-44e3-9a2b-a8b7846c015c', '{}',                '{football_small_sided}', 10),
    ('6aad9fd7-889c-46f8-9e31-3c55adbb20e0', '{}',                '{football_small_sided}', 10),
    ('39be907c-d677-4bb2-8bfe-512c37983daa', '{}',                '{football_small_sided}', 10),
    ('510b6f11-2563-4687-918a-3c42c97ca9a9', '{}',                '{football_small_sided}', 10),
    ('6f6423cc-2fb8-4ac6-80bd-3a0dbd817f71', '{football_futsal}', '{football_standard}',    10);

  -- Pre-guard: every row still carries exactly its old keys and old capacity.
  SELECT count(*) INTO n FROM public.venue_spaces s JOIN kan944_map m ON m.id = s.id
   WHERE s.sport_variant_keys = m.old_keys AND s.capacity = m.old_cap;
  IF n <> 13 THEN
    RAISE EXCEPTION 'KAN-944: pre-guard failed: % of 13 rows match their old values', n;
  END IF;

  UPDATE public.venue_spaces s SET sport_variant_keys = m.new_keys
    FROM kan944_map m WHERE m.id = s.id AND s.sport_variant_keys = m.old_keys;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 13 THEN RAISE EXCEPTION 'KAN-944: expected 13 key updates, got %', n; END IF;

  -- Keep the existing capacity (the trigger overwrote it from the new key).
  UPDATE public.venue_spaces s SET capacity = m.old_cap
    FROM kan944_map m WHERE m.id = s.id AND s.capacity IS DISTINCT FROM m.old_cap;

  -- Post-check.
  SELECT count(*) INTO n FROM public.venue_spaces s JOIN kan944_map m ON m.id = s.id
   WHERE s.sport_variant_keys = m.new_keys AND s.capacity = m.old_cap;
  IF n <> 13 THEN
    RAISE EXCEPTION 'KAN-944: post-check failed: % of 13 rows have new keys and old capacity', n;
  END IF;
  IF EXISTS (SELECT 1 FROM public.venue_spaces WHERE 'football_touch' = ANY (sport_variant_keys)) THEN
    RAISE EXCEPTION 'KAN-944: post-check failed: football_touch still present';
  END IF;
END $mig$;
