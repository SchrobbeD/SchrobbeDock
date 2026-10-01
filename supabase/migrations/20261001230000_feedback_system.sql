-- ================================================================
-- Migratie: Centraal Feedback- & Probleemrapportagesysteem
-- Uitbreiding apps tabel, feedback_reports tabel & storage bucket
-- ================================================================

-- 1. Uitbreiding public.apps met GitHub repository tracking
ALTER TABLE public.apps 
  ADD COLUMN IF NOT EXISTS github_repo_owner TEXT DEFAULT 'SchrobbeD',
  ADD COLUMN IF NOT EXISTS github_repo_name TEXT;

-- Update standaard repository voor de hub
UPDATE public.apps 
SET github_repo_owner = 'SchrobbeD', github_repo_name = 'SchrobbeDock'
WHERE slug = 'hub_admin' AND (github_repo_name IS NULL OR github_repo_name = '');

-- 2. Centrale tabel voor feedback en probleemrapportages
CREATE TABLE IF NOT EXISTS public.feedback_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    app_id UUID REFERENCES public.apps(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('bug', 'enhancement', 'question', 'other')),
    severity TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    environment_info JSONB DEFAULT '{}'::jsonb,
    attachment_urls TEXT[] DEFAULT '{}',
    stack_trace TEXT,
    github_issue_url TEXT,
    github_issue_number INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexen voor performant filteren
CREATE INDEX IF NOT EXISTS idx_feedback_reports_app_id ON public.feedback_reports(app_id);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_user_id ON public.feedback_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_status ON public.feedback_reports(status);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_created_at ON public.feedback_reports(created_at DESC);

-- 3. Row Level Security (RLS)
ALTER TABLE public.feedback_reports ENABLE ROW LEVEL SECURITY;

-- Gebruikers mogen eigen rapporten aanmaken
CREATE POLICY "Users can create own feedback" 
ON public.feedback_reports 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Gebruikers zien eigen rapporten
CREATE POLICY "Users can view own feedback" 
ON public.feedback_reports 
FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

-- Platform Super Admins zien alle rapporten over alle apps
CREATE POLICY "Admins can view all feedback" 
ON public.feedback_reports 
FOR SELECT 
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

-- Platform Super Admins mogen status en details van rapporten updaten
CREATE POLICY "Admins can update all feedback" 
ON public.feedback_reports 
FOR UPDATE 
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
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_licenses ul
    JOIN public.apps a ON ul.app_id = a.id
    WHERE ul.user_id = auth.uid()
      AND a.slug = 'hub_admin'
      AND ul.role = 'super_admin'
      AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
  )
);

-- 4. Automatische updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_feedback_reports_updated_at ON public.feedback_reports;
CREATE TRIGGER tr_feedback_reports_updated_at
  BEFORE UPDATE ON public.feedback_reports
  FOR EACH ROW EXECUTE FUNCTION public.handle_feedback_updated_at();

-- 5. Storage Bucket voor screenshots en bijlagen
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'feedback_attachments',
  'feedback_attachments',
  true,
  10485760, -- Max 10MB
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'text/plain']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies
CREATE POLICY "Authenticated users upload feedback attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'feedback_attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Public read feedback attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'feedback_attachments');
