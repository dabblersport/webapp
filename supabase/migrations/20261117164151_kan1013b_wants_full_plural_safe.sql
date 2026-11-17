-- KAN-1013b: plural-safe titles for meetup.wants_to_join_full (the kan979b approach). A grouped card fills {actor}
-- with "X and N others" / "X و N آخرين", so the verb must not agree with a single person.
--   EN: "{actor} asked to come to {title}, but it's full"   (past tense, fits one or many)
--   AR: "طلب حضور {title} من {actor}، لكنه مكتمل"          (noun phrase, fits a group)
-- Bodies unchanged. UPDATE of one kind row only; no DROP, no DELETE.

DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.notification_kinds
                  WHERE key = 'meetup.wants_to_join_full'
                    AND title_template_en = '{actor} wants to come to {title}, but it''s full'
                    AND title_template_ar = '{actor} يريد حضور {title}، لكنه مكتمل') THEN
    RAISE EXCEPTION 'KAN-1013b guard: meetup.wants_to_join_full titles are not the KAN-1013 ones';
  END IF;
END
$guard$;

UPDATE public.notification_kinds
   SET title_template_en = '{actor} asked to come to {title}, but it''s full',
       title_template_ar = 'طلب حضور {title} من {actor}، لكنه مكتمل'
 WHERE key = 'meetup.wants_to_join_full';
