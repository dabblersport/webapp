-- Rollback for KAN-1032: restores the pre-fix (insecure) definitions exactly.
DROP POLICY IF EXISTS post_media_update_own ON storage.objects;
CREATE POLICY post_media_update_own ON storage.objects
  FOR UPDATE TO authenticated
  USING ((bucket_id = 'post-media'::text) AND (auth.uid() IS NOT NULL));

DROP POLICY IF EXISTS post_media_delete_own ON storage.objects;
CREATE POLICY post_media_delete_own ON storage.objects
  FOR DELETE TO authenticated
  USING ((bucket_id = 'post-media'::text) AND (auth.uid() IS NOT NULL));
