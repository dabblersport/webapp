-- KAN-974 [W0-1] Notification envelope v2 (Epic KAN-973).
--
-- Adds, beside the untouched process_notification_event:
--   * notifications: template_key, args, source_event_id, dedupe_key (unique per recipient), group_key, schema_version
--   * notification_kinds: title_template_en/ar, body_template_en/ar, breaks_quiet, can_mute, category
--   * templates + flags for the 35 existing kinds (they stay active and keep their current sender)
--   * 52 new kinds, all INACTIVE; each producer ticket activates its own
--   * notify_v2(...) SECURITY DEFINER sender, execute for service_role only; notify_v2_render helper
--
-- Decisions encoded: I-3 (breaks_quiet = cancellations, changes to an upcoming event, removal, waitlist promotion,
-- reminders; never social) + CEO "security notices: always on, cannot be muted, break through quiet hours";
-- assumption "Turn off notifications like this mutes that kind" (can_mute per kind); `activity.starting_soon` is not
-- registered (it is the 30m reminder rung); old rows keep title/body/action_route (schema_version 1).
-- Not touched: process_notification_event, emit_event, trg_push_on_notification_insert, notification_settings,
-- events / event_changes, fcm_tokens.

-- 1. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure))
       <> '960d2aa2d3b0187064497e6a27c2ed3a' THEN
    RAISE EXCEPTION 'kan974 pre-image: process_notification_event changed since the claim';
  END IF;
  IF md5(pg_get_functiondef('public.emit_event(text,text,uuid,uuid,jsonb)'::regprocedure))
       <> 'c3acfd9d3d7bfecf010400e0363db114' THEN
    RAISE EXCEPTION 'kan974 pre-image: emit_event changed since the claim';
  END IF;
  IF to_regprocedure('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)') IS NOT NULL
     OR to_regproc('public.notify_v2') IS NOT NULL THEN
    RAISE EXCEPTION 'kan974 pre-image: notify_v2 already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
               AND ((table_name = 'notifications' AND column_name IN
                      ('template_key','args','source_event_id','dedupe_key','group_key','schema_version'))
                 OR (table_name = 'notification_kinds' AND column_name IN
                      ('title_template_en','title_template_ar','body_template_en','body_template_ar',
                       'breaks_quiet','can_mute','category')))) THEN
    RAISE EXCEPTION 'kan974 pre-image: an envelope v2 column already exists';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds) <> 35 THEN
    RAISE EXCEPTION 'kan974 pre-image: expected 35 notification kinds, found %',
      (SELECT count(*) FROM public.notification_kinds);
  END IF;
END
$guard$;

-- 2. notifications: envelope columns ---------------------------------------------------------------------------------
-- schema_version: 1 = legacy row (process_notification_event and direct inserts), 2 = written by notify_v2.
-- Adding a NOT NULL column with a constant default does not rewrite the table; old rows read 1.
ALTER TABLE public.notifications
  ADD COLUMN template_key    text,
  ADD COLUMN args            jsonb,
  ADD COLUMN source_event_id text,
  ADD COLUMN dedupe_key      text,
  ADD COLUMN group_key       text,
  ADD COLUMN schema_version  smallint NOT NULL DEFAULT 1;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_args_object_chk CHECK (args IS NULL OR jsonb_typeof(args) = 'object'),
  ADD CONSTRAINT notifications_schema_version_chk CHECK (schema_version IN (1, 2));

CREATE UNIQUE INDEX notifications_to_user_dedupe_key_uidx
  ON public.notifications (to_user_id, dedupe_key) WHERE dedupe_key IS NOT NULL;

CREATE INDEX notifications_to_user_group_key_idx
  ON public.notifications (to_user_id, group_key) WHERE group_key IS NOT NULL;

COMMENT ON COLUMN public.notifications.template_key IS
  'KAN-974: key of the notification_kinds row whose templates rendered title/body (v2 rows only).';
COMMENT ON COLUMN public.notifications.args IS
  'KAN-974: template arguments (jsonb object). A key suffixed _en/_ar overrides the plain key for that language.';
COMMENT ON COLUMN public.notifications.source_event_id IS
  'KAN-974: opaque id of the domain event that produced the row (e.g. an event_changes id).';
COMMENT ON COLUMN public.notifications.dedupe_key IS
  'KAN-974: idempotency key, unique per recipient (notifications_to_user_dedupe_key_uidx).';
COMMENT ON COLUMN public.notifications.group_key IS
  'KAN-974: grouping/aggregation key for the client and KAN-980.';
COMMENT ON COLUMN public.notifications.schema_version IS
  'KAN-974: 1 = legacy row, 2 = written by notify_v2. title/body/action_route stay filled for old clients.';

-- 3. notification_kinds: templates and delivery flags ----------------------------------------------------------------
ALTER TABLE public.notification_kinds
  ADD COLUMN title_template_en text,
  ADD COLUMN title_template_ar text,
  ADD COLUMN body_template_en  text,
  ADD COLUMN body_template_ar  text,
  ADD COLUMN breaks_quiet      boolean NOT NULL DEFAULT false,
  ADD COLUMN can_mute          boolean NOT NULL DEFAULT true,
  ADD COLUMN category          text;

ALTER TABLE public.notification_kinds
  ADD CONSTRAINT notification_kinds_category_chk CHECK (category IS NULL OR category IN
    ('social', 'messages', 'games', 'meetups', 'activities', 'system', 'security', 'booking'));

COMMENT ON COLUMN public.notification_kinds.breaks_quiet IS
  'KAN-974 / I-3: true only for cancellations, changes to an upcoming event, removal, waitlist promotion, reminders, and security notices.';
COMMENT ON COLUMN public.notification_kinds.can_mute IS
  'KAN-974: false = the user cannot mute this kind ("Turn off notifications like this" is not offered). Security notices.';
COMMENT ON COLUMN public.notification_kinds.category IS
  'KAN-974: settings/chip group: social, messages, games, meetups, activities (game or meetup, by entity), system, security, booking.';

-- 4. Templates and flags for the 35 existing kinds (label, priority, channels, is_active unchanged) ------------------
UPDATE public.notification_kinds k
   SET category = v.category, breaks_quiet = v.bq, can_mute = true,
       title_template_en = v.t_en, title_template_ar = v.t_ar, body_template_en = v.b_en, body_template_ar = v.b_ar
  FROM (VALUES
  ('arena.payment_required','booking',false,'Payment required for your booking','مطلوب الدفع لحجزك','Complete the payment to keep your booking.','أكمل الدفع للاحتفاظ بحجزك.'),
  ('auth.welcome','system',false,'Welcome to Dabbler','أهلًا بك في دابلر','Set up your profile to find games near you.','أكمل ملفك الشخصي لتجد مباريات بالقرب منك.'),
  ('friend.accepted','social',false,'{actor} followed you back','{actor} تابعك أيضًا','Tap to see their profile.','اضغط لعرض ملفه الشخصي.'),
  ('friend.requested','social',false,'{actor} wants to connect','{actor} يريد التواصل معك','Tap to see their profile.','اضغط لعرض ملفه الشخصي.'),
  ('game.invited','games',false,'{actor} invited you to a game','{actor} دعاك إلى مباراة','Tap to see the game and reply.','اضغط لعرض المباراة والرد.'),
  ('game.join_accepted','games',false,'Your request to join was accepted','تم قبول طلب انضمامك','You''re in. See the game details.','أنت مشارك الآن. اطّلع على تفاصيل المباراة.'),
  ('game.join_request','games',false,'{actor} wants to join your game','{actor} يريد الانضمام إلى مباراتك','Review the request.','راجع الطلب.'),
  ('game.player_joined','games',false,'{actor} joined your game','{actor} انضم إلى مباراتك','See who''s playing.','اطّلع على قائمة اللاعبين.'),
  ('game.reminder','games',true,'Your game starts soon','مباراتك تبدأ قريبًا','Get ready and check the time and venue.','استعد وتحقق من الوقت والمكان.'),
  ('game.removed','games',true,'You were removed from a game','تمت إزالتك من مباراة','Tap to see the details.','اضغط لعرض التفاصيل.'),
  ('game.updated','games',true,'A game you joined was updated','تم تحديث مباراة انضممت إليها','Tap to see what changed.','اضغط لمعرفة ما تغيّر.'),
  ('game.waitlist_promoted','games',true,'You''ve been promoted from the waitlist','انتقلت من قائمة الانتظار إلى المباراة','You have a place in the game now.','لديك مكان في المباراة الآن.'),
  ('meetup.cancelled','meetups',true,'A meet-up you signed up for was cancelled','تم إلغاء لقاء سجّلت فيه','Tap to see the details.','اضغط لعرض التفاصيل.'),
  ('meetup.invited','meetups',false,'{actor} invited you to a meet-up','{actor} دعاك إلى لقاء','Tap to see the meet-up and reply.','اضغط لعرض اللقاء والرد.'),
  ('meetup.player_joined','meetups',false,'{actor} joined your meet-up','{actor} انضم إلى لقائك','See who''s coming.','اطّلع على قائمة الحضور.'),
  ('meetup.request_approved','meetups',false,'Your request to join a meet-up was approved','تمت الموافقة على طلب انضمامك إلى اللقاء','You''re in. See the meet-up details.','أنت مشارك الآن. اطّلع على تفاصيل اللقاء.'),
  ('meetup.request_declined','meetups',false,'Your request to join a meet-up was declined','تم رفض طلب انضمامك إلى اللقاء','Find another meet-up near you.','ابحث عن لقاء آخر بالقرب منك.'),
  ('meetup.request_received','meetups',false,'{actor} asked to join your meet-up','{actor} طلب الانضمام إلى لقائك','Review the request.','راجع الطلب.'),
  ('meetup.rsvp_received','meetups',false,'{actor} is going to your meet-up','{actor} سيحضر لقاءك','See who''s coming.','اطّلع على قائمة الحضور.'),
  ('message.received','messages',false,'New message from {actor}','رسالة جديدة من {actor}','Open the chat to read it.','افتح المحادثة لقراءتها.'),
  ('moderation.report_submitted','system',false,'New content report','بلاغ جديد عن محتوى','Review it in the moderation queue.','راجعه في قائمة الإشراف.'),
  ('moderation.user_blocked','system',false,'User block recorded','تم تسجيل حظر مستخدم','A user blocked another user.','قام مستخدم بحظر مستخدم آخر.'),
  ('reward.badge_awarded','system',false,'You earned a new badge!','حصلت على شارة جديدة!','See it on your rewards page.','شاهدها في صفحة المكافآت.'),
  ('social.circle_joined','social',false,'{actor} joined your circle','{actor} انضم إلى دائرتك','Say hello.','رحّب به.'),
  ('social.comment_liked','social',false,'{actor} liked your comment','{actor} أعجبه تعليقك','Tap to see the comment.','اضغط لعرض التعليق.'),
  ('social.followed','social',false,'{actor} started following you','{actor} بدأ متابعتك','Tap to see their profile.','اضغط لعرض ملفه الشخصي.'),
  ('social.friend_accepted','social',false,'{actor} followed you back','{actor} تابعك أيضًا','Tap to see their profile.','اضغط لعرض ملفه الشخصي.'),
  ('social.friend_request','social',false,'{actor} wants to connect','{actor} يريد التواصل معك','Tap to see their profile.','اضغط لعرض ملفه الشخصي.'),
  ('social.mentioned_in_comment','social',false,'{actor} mentioned you in a comment','{actor} أشار إليك في تعليق','Tap to see the comment.','اضغط لعرض التعليق.'),
  ('social.mentioned_in_post','social',false,'{actor} mentioned you in a post','{actor} أشار إليك في منشور','Tap to see the post.','اضغط لعرض المنشور.'),
  ('social.post_commented','social',false,'{actor} commented on your post','{actor} علّق على منشورك','Tap to read the comment.','اضغط لقراءة التعليق.'),
  ('social.post_liked','social',false,'{actor} liked your post','{actor} أعجبه منشورك','Tap to see the post.','اضغط لعرض المنشور.'),
  ('social.post_reacted','social',false,'{actor} reacted to your post','{actor} تفاعل مع منشورك','Tap to see the post.','اضغط لعرض المنشور.'),
  ('squad.invited','social',false,'{actor} invited you to a squad','{actor} دعاك إلى فريق','Tap to see the squad and reply.','اضغط لعرض الفريق والرد.'),
  ('system.announcement','system',false,'Announcement from Dabbler','إعلان من دابلر','Tap to read it.','اضغط لقراءته.')
  ) AS v(key, category, bq, t_en, t_ar, b_en, b_ar)
 WHERE k.key = v.key;

-- 5. New kinds of the Epic, all inactive -----------------------------------------------------------------------------
INSERT INTO public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active,
   category, breaks_quiet, can_mute, title_template_en, title_template_ar, body_template_en, body_template_ar)
SELECT v.key, v.label_en, v.label_ar, v.prio::public.notify_priority, v.ch::public.notify_channel[], NULL, NULL, false,
       v.category, v.bq, v.can_mute, v.t_en, v.t_ar, v.b_en, v.b_ar
  FROM (VALUES
  -- membership (W1-B4)
  ('game.join_declined','Join request declined','تم رفض طلب الانضمام','normal','{inapp,push}','games',false,true,'Your request to join {title} was declined','تم رفض طلب انضمامك إلى {title}','Find another game near you.','ابحث عن مباراة أخرى بالقرب منك.'),
  ('game.invite_accepted','Invite accepted','تم قبول الدعوة','normal','{inapp,push}','games',false,true,'{actor} accepted your invite to {title}','{actor} قبل دعوتك إلى {title}','See who''s playing.','اطّلع على قائمة اللاعبين.'),
  ('game.invite_declined','Invite declined','تم رفض الدعوة','low','{inapp}','games',false,true,'{actor} declined your invite to {title}','{actor} رفض دعوتك إلى {title}','You can invite someone else.','يمكنك دعوة شخص آخر.'),
  ('game.invite_withdrawn','Invite withdrawn','تم سحب الدعوة','low','{inapp}','games',false,true,'Your invite to {title} was withdrawn','تم سحب دعوتك إلى {title}','The organiser withdrew the invite.','سحب المنظّم الدعوة.'),
  ('game.invite_expired','Invite expired','انتهت صلاحية الدعوة','low','{inapp}','games',false,true,'Your invite to {title} expired','انتهت صلاحية دعوتك إلى {title}','The invite is no longer valid.','لم تعد الدعوة صالحة.'),
  ('game.player_left','Player left your game','غادر لاعب مباراتك','normal','{inapp,push}','games',false,true,'{actor} left {title}','{actor} غادر {title}','A place is open in your game.','أصبح هناك مكان شاغر في مباراتك.'),
  ('game.full','Game is full','اكتمل عدد المباراة','normal','{inapp,push}','games',false,true,'{title} is full','اكتمل العدد في {title}','Every place in your game is taken.','تم شغل جميع الأماكن في مباراتك.'),
  ('game.waitlist_joined','Joined the waitlist','انضممت إلى قائمة الانتظار','normal','{inapp}','games',false,true,'You''re on the waitlist for {title}','أنت في قائمة الانتظار لـ {title}','We''ll tell you if a place opens.','سنخبرك إذا توفر مكان.'),
  ('game.waitlist_position_changed','Waitlist position changed','تغيّر ترتيبك في قائمة الانتظار','low','{inapp}','games',false,true,'You moved up the waitlist for {title}','تقدّمت في قائمة الانتظار لـ {title}','You''re now number {position}.','ترتيبك الآن {position}.'),
  ('meetup.removed','Removed from meet-up','تمت إزالتك من اللقاء','high','{inapp,push}','meetups',true,true,'You were removed from {title}','تمت إزالتك من {title}','{organiser} removed you: {reason}','أزالك {organiser}: {reason}'),
  ('meetup.player_left','Someone left your meet-up','غادر شخص لقاءك','normal','{inapp,push}','meetups',false,true,'{actor} left {title}','{actor} غادر {title}','A place is open in your meet-up.','أصبح هناك مكان شاغر في لقائك.'),
  ('meetup.rsvp_interested','Someone is interested in your meet-up','شخص مهتم بلقائك','low','{inapp}','meetups',false,true,'{actor} is interested in {title}','{actor} مهتم بـ {title}','See who''s interested.','اطّلع على المهتمين.'),
  -- event changes and cancel (W1-B3)
  ('game.cancelled','Game cancelled','تم إلغاء المباراة','high','{inapp,push}','games',true,true,'{title} was cancelled','تم إلغاء {title}','The organiser cancelled this game.','ألغى المنظّم هذه المباراة.'),
  ('game.time_changed','Game time changed','تغيّر موعد المباراة','high','{inapp,push}','games',true,true,'{title} has a new time','تغيّر موعد {title}','Was {old}, now {new}.','كان {old}، والآن {new}.'),
  ('game.venue_changed','Game venue changed','تغيّر مكان المباراة','high','{inapp,push}','games',true,true,'{title} has a new venue','تغيّر مكان {title}','Was {old}, now {new}.','كان {old}، والآن {new}.'),
  ('game.details_changed','Game details changed','تغيّرت تفاصيل المباراة','high','{inapp,push}','games',true,true,'{title} was updated','تم تحديث {title}','{field} changed from {old} to {new}.','تغيّر {field} من {old} إلى {new}.'),
  ('game.occurrence_cancelled','Game date cancelled','تم إلغاء موعد المباراة','high','{inapp,push}','games',true,true,'{title} on {when} was cancelled','تم إلغاء {title} يوم {when}','Only this date is cancelled. The series continues.','أُلغي هذا الموعد فقط، وتستمر السلسلة.'),
  ('game.series_changed','Game series changed','تغيّرت سلسلة المباريات','high','{inapp,push}','games',true,true,'The {title} series was updated','تم تحديث سلسلة {title}','Tap to see what changed in the upcoming dates.','اضغط لمعرفة ما تغيّر في المواعيد القادمة.'),
  ('meetup.time_changed','Meet-up time changed','تغيّر موعد اللقاء','high','{inapp,push}','meetups',true,true,'{title} has a new time','تغيّر موعد {title}','Was {old}, now {new}.','كان {old}، والآن {new}.'),
  ('meetup.venue_changed','Meet-up venue changed','تغيّر مكان اللقاء','high','{inapp,push}','meetups',true,true,'{title} has a new venue','تغيّر مكان {title}','Was {old}, now {new}.','كان {old}، والآن {new}.'),
  ('meetup.details_changed','Meet-up details changed','تغيّرت تفاصيل اللقاء','high','{inapp,push}','meetups',true,true,'{title} was updated','تم تحديث {title}','{field} changed from {old} to {new}.','تغيّر {field} من {old} إلى {new}.'),
  ('meetup.occurrence_cancelled','Meet-up date cancelled','تم إلغاء موعد اللقاء','high','{inapp,push}','meetups',true,true,'{title} on {when} was cancelled','تم إلغاء {title} يوم {when}','Only this date is cancelled. The series continues.','أُلغي هذا الموعد فقط، وتستمر السلسلة.'),
  ('meetup.series_changed','Meet-up series changed','تغيّرت سلسلة اللقاءات','high','{inapp,push}','meetups',true,true,'The {title} series was updated','تم تحديث سلسلة {title}','Tap to see what changed in the upcoming dates.','اضغط لمعرفة ما تغيّر في المواعيد القادمة.'),
  -- reminders (W1-B5); games keep game.reminder
  ('meetup.reminder','Meet-up starts soon','اللقاء يبدأ قريبًا','high','{inapp,push}','meetups',true,true,'{title} starts {when}','{title} يبدأ {when}','Tap to see the details and get ready.','اضغط لعرض التفاصيل والاستعداد.'),
  ('meetup.confirm_attendance','Confirm your attendance','أكّد حضورك','high','{inapp,push}','meetups',true,true,'{title} is today at {time}','{title} اليوم الساعة {time}','Are you going?','هل ستحضر؟'),
  -- attendance (W2-B1)
  ('activity.checkin_open','Check-in is open','تسجيل الحضور متاح','normal','{inapp,push}','activities',false,true,'Check-in is open for {title}','تسجيل الحضور متاح لـ {title}','Check in before {close_time}.','سجّل حضورك قبل {close_time}.'),
  ('activity.checkin_closing','Check-in closes soon','تسجيل الحضور يُغلق قريبًا','normal','{inapp,push}','activities',false,true,'Check-in for {title} closes soon','تسجيل الحضور لـ {title} يُغلق قريبًا','Check in now so you''re counted.','سجّل حضورك الآن ليتم احتسابك.'),
  ('activity.checked_in','Checked in','تم تسجيل الحضور','low','{inapp}','activities',false,true,'You checked in to {title}','سجّلت حضورك في {title}','Have a great game.','نتمنى لك وقتًا ممتعًا.'),
  ('activity.attendance_corrected','Attendance corrected','تم تعديل الحضور','normal','{inapp,push}','activities',false,true,'Your attendance for {title} was updated','تم تعديل حضورك في {title}','{organiser} changed it to {status}.','غيّره {organiser} إلى {status}.'),
  ('activity.no_show_pending','Marked as not attended','تم تسجيلك كغائب','high','{inapp,push}','activities',false,true,'You were marked as not attended at {title}','تم تسجيلك كغائب في {title}','This confirms in 48h unless you ask for a review.','يتم التأكيد خلال 48 ساعة ما لم تطلب مراجعة.'),
  ('activity.review_requested','Attendance review requested','طلب مراجعة الحضور','normal','{inapp,push}','activities',false,true,'{actor} asked to review their attendance at {title}','{actor} طلب مراجعة حضوره في {title}','Accept the correction or keep your decision.','اقبل التصحيح أو أبقِ على قرارك.'),
  ('activity.review_accepted','Attendance corrected after review','تم تصحيح الحضور بعد المراجعة','normal','{inapp,push}','activities',false,true,'Your attendance at {title} was corrected','تم تصحيح حضورك في {title}','The organiser accepted your review request.','قبل المنظّم طلب المراجعة.'),
  ('activity.review_kept','No-show kept after review','تم تثبيت الغياب بعد المراجعة','normal','{inapp,push}','activities',false,true,'Your no-show at {title} stands','تم تثبيت غيابك في {title}','The organiser kept the original decision.','أبقى المنظّم على القرار الأصلي.'),
  ('activity.no_show_confirmed','No-show confirmed','تم تأكيد الغياب','normal','{inapp,push}','activities',false,true,'Your no-show at {title} is confirmed','تم تأكيد غيابك في {title}','It now counts toward your show-up rate.','يُحتسب الآن في نسبة حضورك.'),
  ('activity.showup_rate_updated','Show-up rate updated','تم تحديث نسبة الحضور','low','{inapp}','activities',false,true,'Your show-up rate is now {rate}%','نسبة حضورك الآن {rate}%','Based on {count} confirmed games and meet-ups.','بناءً على {count} من المباريات واللقاءات المؤكدة.'),
  -- lifecycle (W2-B2)
  ('activity.confirm_end','Confirm the end','أكّد الانتهاء','normal','{inapp,push}','activities',false,true,'Did {title} end?','هل انتهى {title}؟','Confirm the end so players can submit results.','أكّد الانتهاء ليتمكن اللاعبون من إدخال النتيجة.'),
  ('activity.confirm_end_reminder','Reminder to confirm the end','تذكير بتأكيد الانتهاء','normal','{inapp,push}','activities',false,true,'Reminder: confirm {title} has ended','تذكير: أكّد انتهاء {title}','Otherwise it closes as "scheduled time ended".','وإلا سيُغلق على أنه «انتهى الوقت المحدد».'),
  ('activity.auto_closed','Closed automatically','أُغلق تلقائيًا','low','{inapp}','activities',false,true,'{title} closed','تم إغلاق {title}','The scheduled time ended.','انتهى الوقت المحدد.'),
  ('activity.ended','Activity ended','انتهى النشاط','normal','{inapp,push}','activities',false,true,'{title} has ended','انتهى {title}','Thanks for playing.','شكرًا لمشاركتك.'),
  -- results (W2-B3) and ratings (W2-B4)
  ('activity.post_activity','Enter the score and rate','أدخل النتيجة وقيّم','normal','{inapp,push}','activities',false,true,'How did {title} go?','كيف كان {title}؟','Enter the score and rate the players. Closes in 48h.','أدخل النتيجة وقيّم اللاعبين. يُغلق خلال 48 ساعة.'),
  ('activity.result_ready','Result ready to approve','النتيجة جاهزة للموافقة','high','{inapp,push}','activities',false,true,'Approve the result for {title}','وافق على نتيجة {title}','Most players said {score}. Approve or reject within 24h.','أغلب اللاعبين قالوا {score}. وافق أو ارفض خلال 24 ساعة.'),
  ('activity.result_enter_final','Enter the final score','أدخل النتيجة النهائية','high','{inapp,push}','activities',false,true,'Enter the final score for {title}','أدخل النتيجة النهائية لـ {title}','Players didn''t agree on a score. You have 24h.','لم يتفق اللاعبون على نتيجة. لديك 24 ساعة.'),
  ('activity.result_confirmed','Result confirmed','تم تأكيد النتيجة','normal','{inapp,push}','activities',false,true,'Final result for {title}: {score}','النتيجة النهائية لـ {title}: {score}','Tap to see the result.','اضغط لعرض النتيجة.'),
  ('activity.result_corrected','Result set by the organiser','حدّد المنظّم النتيجة','normal','{inapp,push}','activities',false,true,'The organiser set the final result for {title}: {score}','حدّد المنظّم النتيجة النهائية لـ {title}: {score}','Tap to see the result.','اضغط لعرض النتيجة.'),
  ('activity.result_closed','Closed with no result','أُغلق بدون نتيجة','low','{inapp}','activities',false,true,'{title} closed with no result','أُغلق {title} بدون نتيجة','No final score was entered in time.','لم يتم إدخال نتيجة نهائية في الوقت المحدد.'),
  ('activity.rating_reminder','Rating reminder','تذكير بالتقييم','low','{inapp,push}','activities',false,true,'Rate {title} before it closes','قيّم {title} قبل الإغلاق','Your ratings help everyone. The window closes soon.','تقييماتك تساعد الجميع. تُغلق الفترة قريبًا.'),
  ('activity.summary','Activity summary','ملخص النشاط','low','{inapp}','activities',false,true,'Your summary for {title} is ready','ملخصك لـ {title} جاهز','See your result and ratings.','اطّلع على نتيجتك وتقييماتك.'),
  -- security notices (W1-B7): always on, cannot be muted, break through quiet hours
  ('security.new_signin','New sign-in','تسجيل دخول جديد','high','{inapp,push}','security',true,false,'New sign-in to your Dabbler account','تسجيل دخول جديد إلى حسابك في دابلر','Was this you? Tap to review.','هل كان هذا أنت؟ اضغط للمراجعة.'),
  ('security.password_changed','Password changed','تم تغيير كلمة المرور','high','{inapp,push}','security',true,false,'Your password was changed','تم تغيير كلمة المرور','Wasn''t you? Secure your account now.','لم تكن أنت؟ أمّن حسابك الآن.'),
  ('security.email_changed','Email changed','تم تغيير البريد الإلكتروني','high','{inapp,push}','security',true,false,'Your email address was changed','تم تغيير بريدك الإلكتروني','Wasn''t you? Secure your account now.','لم تكن أنت؟ أمّن حسابك الآن.'),
  -- social replies and reposts (included per the plan's assumptions)
  ('social.comment_replied','Reply to your comment','رد على تعليقك','normal','{inapp,push}','social',false,true,'{actor} replied to your comment','{actor} ردّ على تعليقك','Tap to read the reply.','اضغط لقراءة الرد.'),
  ('social.post_reposted','Post reposted','إعادة نشر منشورك','normal','{inapp,push}','social',false,true,'{actor} reposted your post','{actor} أعاد نشر منشورك','Tap to see the post.','اضغط لعرض المنشور.')
  ) AS v(key, label_en, label_ar, prio, ch, category, bq, can_mute, t_en, t_ar, b_en, b_ar);

-- Every kind now carries a category, templates in both languages and the flags.
ALTER TABLE public.notification_kinds
  ALTER COLUMN category SET NOT NULL,
  ALTER COLUMN title_template_en SET NOT NULL,
  ALTER COLUMN title_template_ar SET NOT NULL,
  ALTER COLUMN body_template_en SET NOT NULL,
  ALTER COLUMN body_template_ar SET NOT NULL;

-- 6. Template renderer -----------------------------------------------------------------------------------------------
-- {key} is replaced by args->>(key || '_' || lang) when present, else args->>key. Unresolved placeholders are removed.
CREATE FUNCTION public.notify_v2_render(p_template text, p_args jsonb, p_lang text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_out  text := p_template;
  v_args jsonb := COALESCE(p_args, '{}'::jsonb);
  r      record;
BEGIN
  IF v_out IS NULL THEN
    RETURN NULL;
  END IF;
  -- language-specific keys first (e.g. when_ar), then plain keys
  FOR r IN SELECT key, value FROM jsonb_each_text(v_args)
            WHERE key LIKE '%\_' || p_lang ESCAPE '\' LOOP
    v_out := replace(v_out, '{' || left(r.key, length(r.key) - length(p_lang) - 1) || '}', COALESCE(r.value, ''));
  END LOOP;
  FOR r IN SELECT key, value FROM jsonb_each_text(v_args) LOOP
    v_out := replace(v_out, '{' || r.key || '}', COALESCE(r.value, ''));
  END LOOP;
  v_out := regexp_replace(v_out, '\{[A-Za-z_][A-Za-z0-9_]*\}', '', 'g');
  v_out := btrim(regexp_replace(v_out, '\s{2,}', ' ', 'g'));
  RETURN NULLIF(v_out, '');
END;
$function$;

-- 7. notify_v2 -------------------------------------------------------------------------------------------------------
-- Returns the notifications.id written (or, on a dedupe hit, the id of the row already there); NULL when nothing was
-- written: inactive kind, actor/recipient block, muted kind, or handed to the aggregation path.
CREATE FUNCTION public.notify_v2(
  p_to_user_id      uuid,
  p_kind_key        text,
  p_args            jsonb DEFAULT '{}'::jsonb,
  p_entity_type     text  DEFAULT NULL,
  p_entity_id       uuid  DEFAULT NULL,
  p_actor_user_id   uuid  DEFAULT NULL,
  p_source_event_id text  DEFAULT NULL,
  p_dedupe_key      text  DEFAULT NULL,
  p_group_key       text  DEFAULT NULL,
  p_action_route    text  DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_kind   public.notification_kinds%ROWTYPE;
  v_args   jsonb := COALESCE(p_args, '{}'::jsonb);
  v_lang   text;
  v_actor  text;
  v_title  text;
  v_body   text;
  v_route  text;
  v_id     uuid;
BEGIN
  IF p_to_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '22004', message = 'notify_v2: recipient is required';
  END IF;
  IF p_dedupe_key IS NULL OR btrim(p_dedupe_key) = '' THEN
    RAISE EXCEPTION USING errcode = '22004', message = 'notify_v2: dedupe_key is required';
  END IF;
  IF jsonb_typeof(v_args) <> 'object' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'notify_v2: args must be a jsonb object';
  END IF;

  SELECT * INTO v_kind FROM public.notification_kinds WHERE key = p_kind_key;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode = '22023', message = format('notify_v2: unknown kind %s', p_kind_key);
  END IF;

  -- inactive kind: nothing is written (each producer ticket activates its own kind)
  IF NOT v_kind.is_active THEN
    RETURN NULL;
  END IF;

  -- block, either direction, between the actor and the recipient
  IF p_actor_user_id IS NOT NULL AND p_actor_user_id <> p_to_user_id AND EXISTS (
       SELECT 1 FROM public.user_blocks b
        WHERE (b.blocker_user_id = p_to_user_id AND b.blocked_user_id = p_actor_user_id)
           OR (b.blocker_user_id = p_actor_user_id AND b.blocked_user_id = p_to_user_id)) THEN
    RETURN NULL;
  END IF;

  -- "Turn off notifications like this": a muted kind writes nothing, unless the kind cannot be muted
  IF v_kind.can_mute AND EXISTS (
       SELECT 1 FROM public.notification_settings s
        WHERE s.user_id = p_to_user_id AND p_kind_key = ANY (COALESCE(s.muted_kinds, '{}'::text[]))) THEN
    RETURN NULL;
  END IF;

  -- recipient's language: the active profile's language, then user_settings.locale, then English
  SELECT CASE WHEN lower(left(COALESCE(
                 (SELECT p.language FROM public.profiles p
                   WHERE p.user_id = p_to_user_id AND p.language IS NOT NULL
                   ORDER BY p.is_active DESC NULLS LAST, p.updated_at DESC NULLS LAST LIMIT 1),
                 (SELECT us.locale FROM public.user_settings us WHERE us.user_id = p_to_user_id),
                 'en'), 2)) = 'ar' THEN 'ar' ELSE 'en' END
    INTO v_lang;

  -- actor display name, unless the producer passed one
  IF p_actor_user_id IS NOT NULL THEN
    SELECT p.display_name INTO v_actor FROM public.profiles p
     WHERE p.user_id = p_actor_user_id AND p.is_active = true
     ORDER BY p.updated_at DESC NULLS LAST LIMIT 1;
  END IF;
  IF NOT (v_args ? 'actor') THEN
    v_args := v_args || jsonb_build_object('actor',
                COALESCE(v_actor, CASE WHEN v_lang = 'ar' THEN 'شخص ما' ELSE 'Someone' END));
  END IF;

  v_title := public.notify_v2_render(
               CASE WHEN v_lang = 'ar' THEN v_kind.title_template_ar ELSE v_kind.title_template_en END, v_args, v_lang);
  v_body  := public.notify_v2_render(
               CASE WHEN v_lang = 'ar' THEN v_kind.body_template_ar ELSE v_kind.body_template_en END, v_args, v_lang);
  v_title := COALESCE(v_title, CASE WHEN v_lang = 'ar' THEN v_kind.label_ar ELSE v_kind.label_en END);

  -- same deep links as process_notification_event when the producer passes none
  v_route := COALESCE(p_action_route, CASE
    WHEN p_entity_type = 'game' AND p_entity_id IS NOT NULL THEN
      '/sports/games/' || p_entity_id::text || CASE WHEN p_kind_key = 'game.join_request' THEN '?focus=requests' ELSE '' END
    WHEN p_entity_type = 'meetup' AND p_entity_id IS NOT NULL THEN
      '/meetups/' || p_entity_id::text ||
      CASE WHEN p_kind_key IN ('meetup.request_received', 'meetup.rsvp_received') THEN '/manage' ELSE '' END
    ELSE NULL END);

  -- Aggregation stays as it is (KAN-980 owns it): a kind with an enabled rule is handed to the existing path.
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules r
              WHERE r.kind_key = p_kind_key AND r.enabled = true) THEN
    PERFORM public.process_notification_event(p_to_user_id, p_kind_key, p_entity_type, p_entity_id,
                                              p_actor_user_id, v_title, v_body);
    RETURN NULL;
  END IF;

  INSERT INTO public.notifications (
    to_user_id, kind_key, title, body, action_route, context, priority, is_read, created_at,
    template_key, args, source_event_id, dedupe_key, group_key, schema_version)
  VALUES (
    p_to_user_id, p_kind_key, v_title, v_body, v_route,
    jsonb_build_object('entity_type', p_entity_type, 'entity_id', p_entity_id,
                       'actor_user_id', p_actor_user_id, 'actor_display_name', COALESCE(v_actor, 'Someone')),
    v_kind.default_priority, false, now(),
    v_kind.key, v_args, p_source_event_id, p_dedupe_key, p_group_key, 2)
  ON CONFLICT (to_user_id, dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT n.id INTO v_id FROM public.notifications n
     WHERE n.to_user_id = p_to_user_id AND n.dedupe_key = p_dedupe_key;
  END IF;

  RETURN v_id;
END;
$function$;

COMMENT ON FUNCTION public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text) IS
  'KAN-974: notification envelope v2 sender. Idempotent on (to_user_id, dedupe_key); priority from the kind; '
  'respects is_active, user_blocks and muted_kinds (can_mute); title/body rendered in the recipient language.';

-- 8. Grants: server-side only ----------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION public.notify_v2_render(text,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_v2_render(text,jsonb,text) TO service_role;

-- 9. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF md5(pg_get_functiondef('public.process_notification_event(uuid,text,text,uuid,uuid,text,text)'::regprocedure))
       <> '960d2aa2d3b0187064497e6a27c2ed3a' THEN
    RAISE EXCEPTION 'kan974 post-image: process_notification_event changed';
  END IF;
  IF md5(pg_get_functiondef('public.emit_event(text,text,uuid,uuid,jsonb)'::regprocedure))
       <> 'c3acfd9d3d7bfecf010400e0363db114' THEN
    RAISE EXCEPTION 'kan974 post-image: emit_event changed';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds) <> 87
     OR (SELECT count(*) FROM public.notification_kinds WHERE is_active) <> 35 THEN
    RAISE EXCEPTION 'kan974 post-image: expected 87 kinds with 35 active';
  END IF;
  IF has_function_privilege('anon', 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan974 post-image: notify_v2 is executable by a client role';
  END IF;
END
$post$;
