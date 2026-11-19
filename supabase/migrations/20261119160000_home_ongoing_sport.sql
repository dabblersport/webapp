-- Home game stack: rpc_my_ongoing_events also returns the event's sport key and
-- emoji, so a live game's ring can show its sport (games has no sport column).
DO $mig$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'rpc_my_ongoing_events';
  IF position('''sport_emoji''' IN v_def) > 0 THEN RETURN; END IF;
  v_def := replace(v_def,
    '''schedule_revision'', k.schedule_revision,',
    '''schedule_revision'', k.schedule_revision,
             ''sport_key'', (SELECT s.sport_key FROM public.events e2 JOIN public.sports s ON s.id = e2.sport_id WHERE e2.id = k.id),
             ''sport_emoji'', (SELECT s.emoji FROM public.events e2 JOIN public.sports s ON s.id = e2.sport_id WHERE e2.id = k.id),');
  IF position('''sport_emoji''' IN v_def) = 0 THEN
    RAISE EXCEPTION 'rpc_my_ongoing_events: anchor not found';
  END IF;
  EXECUTE v_def;
END
$mig$;
