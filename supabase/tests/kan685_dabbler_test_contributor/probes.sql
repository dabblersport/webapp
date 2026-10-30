-- KAN-685 post-write probes (read-only). Expect: persona_type contributor, onboarding_intention play_organise, onboard true;
-- organiser 1, player 1, host 0; persona counts contributor 4, player 144, host 5, organiser 19, socialiser 10.
SELECT persona_type, onboarding_intention, onboard FROM public.profiles WHERE id = '5eeb4305-9277-458e-a56f-a5ed77e3f208' AND user_id = 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
SELECT (SELECT count(*) FROM public.organiser WHERE profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208') AS organiser,
       (SELECT count(*) FROM public.player    WHERE profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208') AS player,
       (SELECT count(*) FROM public.host      WHERE profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208') AS host;
SELECT persona_type, onboarding_intention, onboard, count(*) FROM public.profiles GROUP BY 1,2,3 ORDER BY 1,2,3;
SELECT count(*) AS other_profiles_updated_since_run FROM public.profiles WHERE id <> '5eeb4305-9277-458e-a56f-a5ed77e3f208' AND updated_at > now() - interval '30 minutes';
