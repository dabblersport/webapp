-- KAN-1032 (SEC-2): post-media UPDATE/DELETE were open to any authenticated user.
-- Restrict to the object's owner: first path folder = uid (app path `{uid}/posts|comments/...`)
-- or storage owner_id = uid (covers one legacy `posts/...` object uploaded before the uid prefix).
DROP POLICY IF EXISTS post_media_update_own ON storage.objects;
CREATE POLICY post_media_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'post-media' AND auth.uid() IS NOT NULL
    AND ((storage.foldername(name))[1] = auth.uid()::text OR owner_id = auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'post-media' AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS post_media_delete_own ON storage.objects;
CREATE POLICY post_media_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'post-media' AND auth.uid() IS NOT NULL
    AND ((storage.foldername(name))[1] = auth.uid()::text OR owner_id = auth.uid()::text)
  );
