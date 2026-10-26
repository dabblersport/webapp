-- KAN-594 STEP 1 -- DRAFT, READ-ONLY, NOT A MIGRATION, NOT APPLIED.
-- Candidate-set query for the Nearby tab. It contains NO ranking weights: the recency/distance blend is
-- deliberately absent until product approves the examples in docs/kan594/nearby_ranking_examples.md (AC3).
-- Parameters (psql-style placeholders):
--   :city            selected City, canonical text (the same value Home writes to posts.posted_from_city)
--   :followed        uuid[] of the viewer's Following sports (KAN-593), or NULL/empty = no filter
--   :as_of           timestamptz frozen by page 1 and sent back unchanged by every later page
--   :after_created   timestamptz, :after_id uuid  -- keyset cursor of the last row of the previous page (NULL on page 1)
--   :lim             page size
-- Origin lat/lng is not needed to pick candidates; it only matters once weights exist.

SELECT p.id, p.created_at, p.geo_lat, p.geo_lng, p.sport_id
FROM public.posts p
WHERE coalesce(p.posted_from_city, 'Dubai') = :city      -- KAN-592: NULL = legacy post = Dubai
  AND p.kind = 'original'
  AND p.origin_type <> 'system'
  AND p.is_deleted = false
  AND p.is_hidden_admin = false
  AND p.created_at <= :as_of                              -- posts created after page 1 never shift later pages
  AND (:followed IS NULL OR cardinality(:followed) = 0    -- KAN-593 rule: empty Following = unfiltered
       OR p.sport_id IS NULL OR p.sport_id = ANY (:followed))
  -- privacy: reuse the exact visibility predicate of the existing feeds; add it here when authored as a migration.
  AND (:after_created IS NULL OR (p.created_at, p.id) < (:after_created, :after_id))
ORDER BY p.created_at DESC, p.id DESC                     -- City-only order (AC1): newest first, id breaks ties
LIMIT :lim;

-- Probe (read-only): how many posts fall outside any city or lack coordinates, for the missing-coordinate rule.
-- SELECT count(*) FILTER (WHERE posted_from_city IS NULL)            AS legacy_dubai,
--        count(*) FILTER (WHERE geo_lat IS NULL OR geo_lng IS NULL)  AS no_coordinates,
--        count(*)                                                    AS total
-- FROM public.posts WHERE kind='original' AND is_deleted=false AND is_hidden_admin=false;
