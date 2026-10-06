-- ================================================================
-- Migratie: RLS en Storage Policies voor Verwijderen van Feedback
-- ================================================================

-- 1. DELETE policy op public.feedback_reports
-- Alleen Super Admins op 'hub_admin' mogen feedbackrapporten definitief wissen.
DROP POLICY IF EXISTS "Admins can delete feedback" ON public.feedback_reports;
CREATE POLICY "Admins can delete feedback" 
ON public.feedback_reports 
FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.user_licenses ul
    JOIN public.apps a ON ul.app_id = a.id
    WHERE ul.user_id = auth.uid()
      AND a.slug = 'hub_admin'
      AND ul.role = 'super_admin'
      AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
  )
);

-- 2. Storage DELETE policy op storage.objects voor bucket 'feedback_attachments'
-- Super Admins mogen bijlagen fysiek verwijderen uit de bucket.
DROP POLICY IF EXISTS "Admins can delete feedback attachments" ON storage.objects;
CREATE POLICY "Admins can delete feedback attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'feedback_attachments'
  AND EXISTS (
    SELECT 1 FROM public.user_licenses ul
    JOIN public.apps a ON ul.app_id = a.id
    WHERE ul.user_id = auth.uid()
      AND a.slug = 'hub_admin'
      AND ul.role = 'super_admin'
      AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
  )
);
