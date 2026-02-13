-- =============================================================================
-- Migration: Unified user_blocks table (user-level blocking)
-- Replaces: profile_blocks, blocked_users, blocks
-- Key: auth.users.id (NOT profile.id)
-- =============================================================================

-- 1. Create the canonical user_blocks table
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT user_blocks_no_self CHECK (blocker_user_id != blocked_user_id),
  CONSTRAINT user_blocks_unique UNIQUE (blocker_user_id, blocked_user_id)
);

-- Indexes for fast bidirectional lookups
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks (blocker_user_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks (blocked_user_id);

-- 2. RLS policies (drop first to make idempotent)
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_blocks_select ON public.user_blocks;
DROP POLICY IF EXISTS user_blocks_insert ON public.user_blocks;
DROP POLICY IF EXISTS user_blocks_delete ON public.user_blocks;

-- Users can read blocks they are involved in (either direction)
CREATE POLICY user_blocks_select ON public.user_blocks
  FOR SELECT USING (
    auth.uid() = blocker_user_id OR auth.uid() = blocked_user_id
  );

-- Users can only insert blocks where they are the blocker
CREATE POLICY user_blocks_insert ON public.user_blocks
  FOR INSERT WITH CHECK (auth.uid() = blocker_user_id);

-- Users can only delete their own blocks (unblock)
CREATE POLICY user_blocks_delete ON public.user_blocks
  FOR DELETE USING (auth.uid() = blocker_user_id);

-- 3. Helper function: bidirectional block check
-- Drop existing function first (parameter names may differ)
DROP FUNCTION IF EXISTS public.is_blocked(UUID, UUID);
CREATE OR REPLACE FUNCTION public.is_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE (blocker_user_id = user_a AND blocked_user_id = user_b)
       OR (blocker_user_id = user_b AND blocked_user_id = user_a)
  );
$$;

-- 4. Rewrite rpc_block_user to use user_blocks (user-level, auth.uid() directly)
DROP FUNCTION IF EXISTS public.rpc_block_user(UUID);
CREATE OR REPLACE FUNCTION public.rpc_block_user(p_peer UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_caller = p_peer THEN
    RAISE EXCEPTION 'Cannot block yourself';
  END IF;

  -- Insert into user_blocks (user-level IDs)
  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id)
  VALUES (v_caller, p_peer)
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;

  -- Remove follow relationships (profile_follows uses profile IDs, so we need to resolve)
  DELETE FROM public.profile_follows
  WHERE (follower_profile_id IN (SELECT id FROM profiles WHERE user_id = v_caller)
     AND following_profile_id IN (SELECT id FROM profiles WHERE user_id = p_peer))
     OR (follower_profile_id IN (SELECT id FROM profiles WHERE user_id = p_peer)
     AND following_profile_id IN (SELECT id FROM profiles WHERE user_id = v_caller));

  -- Remove friendships if they exist
  BEGIN
    DELETE FROM public.friendships
    WHERE (user_id IN (SELECT id FROM profiles WHERE user_id = v_caller)
       AND peer_user_id IN (SELECT id FROM profiles WHERE user_id = p_peer))
       OR (user_id IN (SELECT id FROM profiles WHERE user_id = p_peer)
       AND peer_user_id IN (SELECT id FROM profiles WHERE user_id = v_caller));
  EXCEPTION WHEN undefined_table THEN
    -- friendships table may not exist
    NULL;
  END;
END;
$$;

-- 5. Rewrite rpc_unblock_user to use user_blocks
DROP FUNCTION IF EXISTS public.rpc_unblock_user(UUID);
CREATE OR REPLACE FUNCTION public.rpc_unblock_user(p_peer UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller UUID := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.user_blocks
  WHERE blocker_user_id = v_caller AND blocked_user_id = p_peer;
END;
$$;

-- 6. Migrate existing data from old tables into user_blocks
-- From profile_blocks (profile-scoped → resolve to user_id via profiles)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profile_blocks' AND table_schema = 'public') THEN
    INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id, created_at)
    SELECT DISTINCT
      p1.user_id AS blocker_user_id,
      p2.user_id AS blocked_user_id,
      COALESCE(pb.created_at, now())
    FROM public.profile_blocks pb
    JOIN public.profiles p1 ON p1.id = pb.blocker_profile_id
    JOIN public.profiles p2 ON p2.id = pb.blocked_profile_id
    WHERE p1.user_id != p2.user_id
    ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  END IF;
END $$;

-- From blocked_users (may already be user-scoped)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'blocked_users' AND table_schema = 'public') THEN
    INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id, created_at)
    SELECT DISTINCT
      COALESCE(bu.user_id, bu.blocker_id) AS blocker_user_id,
      COALESCE(bu.blocked_user_id, bu.blocked_id) AS blocked_user_id,
      COALESCE(bu.created_at, now())
    FROM public.blocked_users bu
    WHERE COALESCE(bu.user_id, bu.blocker_id) IS NOT NULL
      AND COALESCE(bu.blocked_user_id, bu.blocked_id) IS NOT NULL
      AND COALESCE(bu.user_id, bu.blocker_id) != COALESCE(bu.blocked_user_id, bu.blocked_id)
    ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  END IF;
EXCEPTION WHEN undefined_column THEN
  -- Column names vary; skip if structure doesn't match
  NULL;
END $$;

-- From blocks table (profile-scoped → resolve to user_id)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'blocks' AND table_schema = 'public') THEN
    INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id, created_at)
    SELECT DISTINCT
      p1.user_id AS blocker_user_id,
      p2.user_id AS blocked_user_id,
      COALESCE(b.created_at, now())
    FROM public.blocks b
    JOIN public.profiles p1 ON p1.id = b.blocker_id
    JOIN public.profiles p2 ON p2.id = b.blocked_id
    WHERE p1.user_id != p2.user_id
    ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;
  END IF;
END $$;

-- =============================================================================
-- 7. Drop legacy blocking tables (data already migrated above)
-- =============================================================================

-- Drop trigger first, then profile_blocks
DROP TRIGGER IF EXISTS trg_profile_block_cleanup ON public.profile_blocks;
DROP FUNCTION IF EXISTS public.trgfn_profile_block_cleanup();
DROP TABLE IF EXISTS public.profile_blocks;

-- Drop blocks table
DROP TABLE IF EXISTS public.blocks;

-- Drop blocked_users table (if it exists)
DROP TABLE IF EXISTS public.blocked_users;

-- NOTE: safety_blocklist_terms is a content-moderation word list, NOT user blocking. Keep it.
