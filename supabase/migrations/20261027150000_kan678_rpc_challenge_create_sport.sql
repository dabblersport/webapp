-- KAN-678: let an organiser create a challenge. Additive 5-argument overload of rpc_challenge_create that carries the
-- sport key (cto ruling, shape B). The challenges trigger trgfn_set_challenge_sport_id needs a sport and the 4-argument
-- function never supplies one, so every call ends in invalid_sport. The 4-argument function is NOT redefined and NOT
-- removed; it is only revoked from PUBLIC and anon.
-- Body = the 4-argument body (baseline 20260829080500), plus sport in the INSERT and a sport_required guard.
-- Check order: not_authenticated, actor_type_invalid, visibility_invalid, organiser_required, sport_required;
-- an unknown key still raises invalid_sport from the existing trigger.

CREATE OR REPLACE FUNCTION public.rpc_challenge_create(p_profile_type text, p_title text, p_visibility text, p_sport text, p_description text)
RETURNS TABLE(id uuid, title text, visibility text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  me  uuid := auth.uid();
  pid uuid;
begin
  if me is null then
    raise exception using errcode='P0001', message='not_authenticated';
  end if;

  if p_profile_type not in ('player','organiser') then
    raise exception using errcode='P0001', message='actor_type_invalid';
  end if;

  if p_visibility not in ('public','circle','hidden') then
    raise exception using errcode='P0001', message='visibility_invalid';
  end if;

  -- pick the caller’s actor and require organiser to create challenges
  pid := public.choose_actor(p_profile_type);
  if not public.actor_is_organiser(pid) then
    raise exception using errcode='P0001', message='organiser_required';
  end if;

  if p_sport is null or btrim(p_sport) = '' then
    raise exception using errcode='P0001', message='sport_required';
  end if;

  -- rely on table defaults for: type ('challenge'), status ('draft'), etc.
  insert into public.challenges as c
    (owner_user_id, owner_profile_id, title, visibility, sport, description)
  values
    (me,            pid,              p_title, p_visibility, p_sport, p_description)
  returning c.id, c.title, c.visibility
  into id, title, visibility;

  return next;
end;
$$;

ALTER FUNCTION public.rpc_challenge_create(text, text, text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_challenge_create(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_challenge_create(text, text, text, text, text) TO authenticated, service_role;

-- The old 4-argument overload stays (kept, body untouched); it is only closed to PUBLIC and anon.
REVOKE ALL ON FUNCTION public.rpc_challenge_create(text, text, text, text) FROM PUBLIC, anon;
