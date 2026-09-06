-- Applied to live DB on 2026-07-12 (migrations: proper_notification_titles,
-- flush_aggregates_label_fallback, backfill_generic_notification_titles).
--
-- Requirement: no in-app notification may carry a generic title
-- ("New notification" / "New Notification" / "New Activity").
--
-- Root causes found in live data:
--   * process_notification_event had no title branch for game.player_joined /
--     meetup.player_joined (fired by fn_public_activities_notify without a
--     title) -> ELSE 'New notification' produced 182 generic rows.
--   * flush_notification_aggregates fell back to 'New Activity' for kinds it
--     didn't handle; 10 old social.post_liked rows predated its handler.
--   * 2 legacy friend rows titled 'New Notification' predated the friend-RPC
--     title fix (commit 8e3d58c).
--
-- Fixes (all three applied):
--
-- 1) process_notification_event — full CREATE OR REPLACE with:
--      WHEN 'game.player_joined'   THEN v_display_name || ' joined your game'
--      WHEN 'meetup.player_joined' THEN v_display_name || ' joined your meet-up'
--      ELSE NULL
--    followed by a catalog-label fallback for unknown/future kinds:
--      IF v_final_title IS NULL THEN
--          SELECT label_en INTO v_final_title
--          FROM public.notification_kinds WHERE key = p_kind_key;
--          v_final_title := COALESCE(v_final_title, 'Notification');
--      END IF;
--    (rest of the function body unchanged from the live version, including the
--     game action_route block; see the schema snapshot for the full text)
--
-- 2) flush_notification_aggregates — DEFAULT FALLBACK branch replaced:
--      ELSE
--          SELECT label_en INTO v_title
--          FROM public.notification_kinds WHERE key = v_record.kind_key;
--          v_title := COALESCE(v_title, 'Notification');
--          v_route := null;
--          v_context := jsonb_build_object(
--              'entity_type', v_record.entity_type,
--              'entity_id', v_record.entity_id,
--              'actor_user_id', v_record.actors[1],
--              'actor_display_name', v_display_name,
--              'actor_user_ids', to_jsonb(v_record.actors),
--              'total_count', v_record.total_count);
--
-- 3) Backfill of existing rows (verbatim below):

UPDATE public.notifications
SET title = COALESCE(NULLIF(context->>'actor_display_name',''), 'Someone') || ' joined your game'
WHERE kind_key = 'game.player_joined' AND title ILIKE 'new notification%';

UPDATE public.notifications
SET title = COALESCE(NULLIF(context->>'actor_display_name',''), 'Someone') || ' joined your meet-up'
WHERE kind_key = 'meetup.player_joined' AND title ILIKE 'new notification%';

UPDATE public.notifications n
SET title = COALESCE(
        NULLIF(n.context->>'actor_display_name',''),
        (SELECT pr.display_name FROM public.profiles pr
          WHERE pr.user_id = (n.context->>'actor_user_id')::uuid LIMIT 1),
        'Someone')
    || CASE WHEN COALESCE((n.context->>'total_count')::int, 1) > 1
            THEN ' and ' || (COALESCE((n.context->>'total_count')::int, 1) - 1) || ' others liked your post'
            ELSE ' liked your post'
       END
WHERE n.kind_key = 'social.post_liked' AND n.title = 'New Activity';

UPDATE public.notifications n
SET title = COALESCE(
        NULLIF(n.context->>'actor_display_name',''),
        (SELECT pr.display_name FROM public.profiles pr
          WHERE pr.user_id = (n.context->>'actor_user_id')::uuid LIMIT 1),
        'Someone') || ' sent you a friend request'
WHERE n.kind_key IN ('friend.requested','social.friend_request')
  AND n.title ILIKE 'new notification%';

-- Safety sweep: anything still generic gets its catalog label.
UPDATE public.notifications n
SET title = k.label_en
FROM public.notification_kinds k
WHERE k.key = n.kind_key
  AND (n.title ILIKE 'new notification%' OR n.title = 'New Activity');
