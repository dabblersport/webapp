-- KAN-982c (PEER R1, comment 16446): 24 live games have no title, so every KAN-982 game notice rendered broken
-- ("You were removed from", " is full"). kan982_notify, the one helper every KAN-982 notice goes through, now adds
-- title_en / title_ar from public.kan981_event_title(event_id, lang) (title, else "<Sport> game" / "مباراة <رياضة>",
-- else "Your game" / "مباراتك"). notify_v2 lets {title}_en / {title}_ar override {title} per language. A producer
-- that already passes title_en / title_ar keeps its own values.
-- CREATE OR REPLACE only: same signature, attributes and ACL. No DROP, no DELETE.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.kan982_notify(uuid,text,jsonb,text,uuid,uuid,text)'::regprocedure))
       <> '9cd3cdc895bd19b7263a28f83acdbb1f' THEN
    RAISE EXCEPTION 'KAN-982c guard: kan982_notify changed since KAN-982';
  END IF;
  IF to_regprocedure('public.kan981_event_title(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN-982c guard: kan981_event_title missing (KAN-981)';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.kan982_notify(p_to uuid, p_kind text, p_args jsonb, p_entity_type text, p_entity_id uuid,
                                                p_actor uuid, p_dedupe_key text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_args  jsonb := COALESCE(p_args, '{}'::jsonb);
  v_event uuid;
BEGIN
  IF p_to IS NULL THEN RETURN NULL; END IF;

  -- KAN-982c: a localized title that never renders empty (untitled games).
  IF p_entity_id IS NOT NULL AND NOT (v_args ? 'title_en') THEN
    IF p_entity_type = 'game' THEN
      SELECT g.event_id INTO v_event FROM public.games g WHERE g.id = p_entity_id;
    ELSIF p_entity_type = 'meetup' THEN
      SELECT m.event_id INTO v_event FROM public.meetups m WHERE m.id = p_entity_id;
    END IF;
    IF v_event IS NOT NULL THEN
      v_args := v_args || jsonb_strip_nulls(jsonb_build_object(
                  'title_en', public.kan981_event_title(v_event, 'en'),
                  'title_ar', public.kan981_event_title(v_event, 'ar')));
    END IF;
  END IF;

  RETURN public.notify_v2(p_to, p_kind, v_args, p_entity_type, p_entity_id, p_actor, NULL, p_dedupe_key);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'kan982_notify % to %: % (%)', p_kind, p_to, SQLERRM, SQLSTATE;
  RETURN NULL;
END;
$function$;
