-- KAN-1010 [W4-1] Booking and payment templates (F-12: "Booking and payment are not live. Templates only, not wired").
--
-- Registry rows only, all INACTIVE: notify_v2 writes nothing for an inactive kind, so nothing can send these.
-- No producer, trigger, aggregation rule, settings or category_prefs change (category 'booking' already exists and the
-- UI hides it). Design rows: BKG-01..07 and PAY-02..07 (NOTIFICATIONS_DESIGN_REVIEW_2026-11-16.md A.2).
--   * breaks_quiet (I-3, "a cancellation, or any change to a booking ... break through"): booking.changed,
--     booking.cancelled, and booking.hold_expiring (a hold with a fixed expiry, report section 5). Others false.
--   * Every kind is mutable (none is a security notice), channels {inapp,push} (design: "ip").
--   * Templates take args producers must pass when wiring: venue, slot, when, old, new, amount.
--   * route_template NULL: there is no booking destination yet (BKG-08 is missing).
--   * timing marks each one {"status": "template", "wired": false, "design": "<frame>"}.
-- arena.payment_required (PAY-01): active today with 0 rows ever; its only sender trg_booking_payment_notify is
-- attached to no trigger. It becomes an alias of payment.pending ({"alias_of": "payment.pending"}) and inactive, as
-- the ticket requires ("mapped ... or marked as an alias; it stays inactive"). Its row is otherwise unchanged.
-- INSERT and one UPDATE only. No DROP, no DELETE.

-- 0. Pre-image guard ---------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF (SELECT count(*) FROM public.notification_kinds) <> 89
     OR md5((SELECT string_agg(k::text, '|' ORDER BY key) FROM public.notification_kinds k))
        <> '3709ff6252819bbe8b148115a5b4e126' THEN
    RAISE EXCEPTION 'KAN-1010 guard: notification_kinds changed since it was read';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds
              WHERE key ~ '^(booking|payment|refund)\.' OR key = 'venue.feedback_request') THEN
    RAISE EXCEPTION 'KAN-1010 guard: a booking/payment kind already exists';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.notification_kinds
                  WHERE key = 'arena.payment_required' AND is_active AND category = 'booking' AND timing = '{}'::jsonb)
     OR EXISTS (SELECT 1 FROM public.notifications WHERE kind_key = 'arena.payment_required')
     OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgfoid = 'public.trg_booking_payment_notify()'::regprocedure) THEN
    RAISE EXCEPTION 'KAN-1010 guard: arena.payment_required is not the unsent, unwired kind this expects';
  END IF;
END
$guard$;

-- 1. The 13 template kinds (inactive) --------------------------------------------------------------------------------
INSERT INTO public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active,
   title_template_en, title_template_ar, body_template_en, body_template_ar, breaks_quiet, can_mute, category)
VALUES
  ('booking.pending', 'Booking request sent', 'تم إرسال طلب الحجز', 'normal', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-01"}', false,
   'Booking request sent to {venue}', 'تم إرسال طلب الحجز إلى {venue}',
   'We''ll tell you when they confirm.', 'سنخبرك عندما يتم التأكيد.', false, true, 'booking'),
  ('booking.confirmed', 'Booking confirmed', 'تم تأكيد الحجز', 'normal', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-02"}', false,
   'Booking confirmed by {venue}', 'أكّد {venue} حجزك',
   'See your booking for {slot}.', 'اطّلع على حجزك لموعد {slot}.', false, true, 'booking'),
  ('booking.rejected', 'Booking not accepted', 'لم يتم قبول الحجز', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-03"}', false,
   '{venue} couldn''t take your booking', 'تعذّر على {venue} قبول حجزك',
   'Find another slot.', 'ابحث عن موعد آخر.', false, true, 'booking'),
  ('booking.hold_expiring', 'Booking hold ending', 'الحجز المؤقت على وشك الانتهاء', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-04"}', false,
   'Your hold at {venue} ends {when}', 'ينتهي حجزك المؤقت في {venue} {when}',
   'Complete your booking to keep the slot.', 'أكمل الحجز للاحتفاظ بالموعد.', true, true, 'booking'),
  ('booking.changed', 'Booking changed', 'تغيّر الحجز', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-05"}', false,
   'Your booking at {venue} changed', 'تغيّر حجزك في {venue}',
   'Was {old}, now {new}.', 'كان {old}، والآن {new}.', true, true, 'booking'),
  ('booking.cancelled', 'Booking cancelled', 'أُلغي الحجز', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-06"}', false,
   'Your booking at {venue} was cancelled', 'أُلغي حجزك في {venue}',
   'Any refund is shown separately.', 'يظهر أي استرداد بشكل منفصل.', true, true, 'booking'),
  ('venue.feedback_request', 'Rate your visit', 'قيّم زيارتك', 'low', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "BKG-07"}', false,
   'How was {venue}?', 'كيف كانت تجربتك في {venue}؟',
   'Rate your visit.', 'قيّم زيارتك.', false, true, 'booking'),
  ('payment.pending', 'Payment needed', 'الدفع مطلوب', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-02", "aliases": ["arena.payment_required"]}', false,
   'Payment needed for your booking · {amount}', 'مطلوب الدفع لحجزك · {amount}',
   'Complete the payment to keep your booking.', 'أكمل الدفع للاحتفاظ بحجزك.', false, true, 'booking'),
  ('payment.succeeded', 'Payment received', 'تم استلام الدفعة', 'normal', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-03"}', false,
   'Payment received · {amount}', 'تم استلام الدفعة · {amount}',
   'Your booking is paid.', 'تم دفع حجزك.', false, true, 'booking'),
  ('payment.failed', 'Payment failed', 'فشلت عملية الدفع', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-04"}', false,
   'Payment didn''t go through · {amount}', 'لم تتم عملية الدفع · {amount}',
   'Try again or get help.', 'حاول مرة أخرى أو اطلب المساعدة.', false, true, 'booking'),
  ('refund.processing', 'Refund processing', 'الاسترداد قيد المعالجة', 'normal', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-05"}', false,
   'Refund on its way · {amount}', 'الاسترداد في الطريق · {amount}',
   'Banks can take a few days.', 'قد يستغرق البنك بضعة أيام.', false, true, 'booking'),
  ('refund.completed', 'Refund completed', 'اكتمل الاسترداد', 'normal', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-06"}', false,
   'Refund completed · {amount}', 'اكتمل الاسترداد · {amount}',
   'It''s back on your payment method.', 'أُعيد المبلغ إلى وسيلة الدفع.', false, true, 'booking'),
  ('refund.failed', 'Refund failed', 'تعذّر الاسترداد', 'high', '{inapp,push}', NULL,
   '{"status": "template", "wired": false, "design": "PAY-07"}', false,
   'We couldn''t refund {amount}', 'تعذّر استرداد {amount}',
   'Get help to sort it out.', 'تواصل مع الدعم لحل المشكلة.', false, true, 'booking');

-- 2. arena.payment_required: alias of payment.pending, inactive ------------------------------------------------------
UPDATE public.notification_kinds
   SET is_active = false,
       timing    = '{"alias_of": "payment.pending", "status": "template", "wired": false, "design": "PAY-01"}'::jsonb
 WHERE key = 'arena.payment_required';

-- 3. Post asserts ------------------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF (SELECT count(*) FROM public.notification_kinds) <> 102 THEN
    RAISE EXCEPTION 'KAN-1010 post: expected 102 kinds';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_kinds
              WHERE (key ~ '^(booking|payment|refund|arena)\.' OR key = 'venue.feedback_request')
                AND (is_active OR category <> 'booking' OR NOT can_mute
                     OR title_template_ar !~ '[؀-ۿ]' OR body_template_ar !~ '[؀-ۿ]')) THEN
    RAISE EXCEPTION 'KAN-1010 post: a booking/payment kind is active, mis-categorised, unmutable or lacks Arabic';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notification_aggregation_rules
              WHERE kind_key ~ '^(booking|payment|refund|arena)\.' OR kind_key = 'venue.feedback_request') THEN
    RAISE EXCEPTION 'KAN-1010 post: a booking/payment kind has an aggregation rule';
  END IF;
END
$post$;
