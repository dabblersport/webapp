-- Meetups listing match (Listings.dc.html, Meetups): expose the venue's setting
-- (indoor / outdoor) on v_meetup_list so the card can tag it and the filter
-- sheet can filter on it. Existing columns keep their order; the new column is
-- appended. CREATE OR REPLACE VIEW keeps owner, options and grants; no DROP.
-- venue_is_indoor: true / false from the venue's active spaces (true when any
-- space is indoor); NULL when the meetup has no venue (setting unknown).
CREATE OR REPLACE VIEW public.v_meetup_list AS
 SELECT m.id,
    m.title,
    m.description,
    m.start_at,
    m.end_at,
    m.capacity,
    m.members_only,
    m.listing_visibility,
    m.rsvp_policy,
    m.is_cancelled,
    m.vibe_key,
    m.created_at,
    m.updated_at,
    m.creator_profile_id,
    cp.display_name AS creator_display_name,
    cp.username AS creator_username,
    cp.avatar_url AS creator_avatar_url,
    m.sport_id,
    s.sport_key,
    s.name_en AS sport_name_en,
    s.name_ar AS sport_name_ar,
    s.emoji AS sport_emoji,
    m.area_id,
    a.name AS area_name,
    m.venue_id,
    v.name_en AS venue_name,
    m.location_name,
    m.geo_location_id,
    m.min_skill,
    m.max_skill,
    m.joining_rule,
    m.cost_cover,
    COALESCE(c.going_count, 0::bigint) AS going_count,
    COALESCE(c.interested_count, 0::bigint) AS interested_count,
    COALESCE(c.declined_count, 0::bigint) AS declined_count,
    att.status AS my_rsvp_status,
        CASE
            WHEN auth.uid() IS NULL THEN '[]'::jsonb
            ELSE COALESCE(( SELECT jsonb_agg(jsonb_build_object('avatar_url', ap.avatar_url, 'display_name', ap.display_name) ORDER BY x.updated_at DESC NULLS LAST) AS jsonb_agg
               FROM ( SELECT r2.profile_id,
                        r2.updated_at
                       FROM meetup_rsvps r2
                      WHERE r2.meetup_id = m.id AND r2.status = 'going'::text
                      ORDER BY r2.updated_at DESC NULLS LAST, r2.created_at DESC
                     LIMIT 5) x
                 JOIN profiles ap ON ap.id = x.profile_id), '[]'::jsonb)
        END AS attendee_avatars,
    ( SELECT bool_or(vs.indoor)
        FROM venue_spaces vs
       WHERE vs.venue_id = m.venue_id AND vs.is_active = true) AS venue_is_indoor
   FROM meetups m
     LEFT JOIN profiles cp ON cp.id = m.creator_profile_id
     LEFT JOIN sports s ON s.id = m.sport_id
     LEFT JOIN areas a ON a.id = m.area_id
     LEFT JOIN venues v ON v.id = m.venue_id
     LEFT JOIN v_meetup_counts c ON c.meetup_id = m.id
     LEFT JOIN meetup_rsvps att ON att.meetup_id = m.id AND att.user_id = auth.uid()
  WHERE can_view_owner(m.creator_user_id, m.listing_visibility) = true
  ORDER BY (COALESCE(m.updated_at, m.created_at)) DESC;
