-- ================================================================
-- Migratie: Statusportaal, Issue Chat en Realtime Notificaties
-- ================================================================

-- 1. Kolommen toevoegen aan public.feedback_reports voor status & ongelezen tracking
ALTER TABLE public.feedback_reports
  ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS has_unread_user BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_unread_admin BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_feedback_reports_unread_user ON public.feedback_reports(user_id, has_unread_user);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_unread_admin ON public.feedback_reports(has_unread_admin);

-- 2. Nieuwe tabel public.feedback_messages
CREATE TABLE IF NOT EXISTS public.feedback_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID REFERENCES public.feedback_reports(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('user', 'admin', 'github_dev')),
    sender_name TEXT NOT NULL,
    message TEXT NOT NULL,
    attachment_urls TEXT[] DEFAULT '{}',
    github_comment_id BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexen
CREATE INDEX IF NOT EXISTS idx_feedback_messages_report_id ON public.feedback_messages(report_id);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_created_at ON public.feedback_messages(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_feedback_messages_github_comment_id ON public.feedback_messages(github_comment_id);

-- 3. Trigger om ongelezen vlaggen en last_message_at automatisch bij te werken
CREATE OR REPLACE FUNCTION public.handle_new_feedback_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.feedback_reports
  SET 
    last_message_at = NEW.created_at,
    has_unread_admin = CASE 
      WHEN NEW.sender_role = 'user' THEN TRUE 
      ELSE has_unread_admin 
    END,
    has_unread_user = CASE 
      WHEN NEW.sender_role IN ('admin', 'github_dev') THEN TRUE 
      ELSE has_unread_user 
    END,
    updated_at = NOW()
  WHERE id = NEW.report_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_new_feedback_message ON public.feedback_messages;
CREATE TRIGGER tr_new_feedback_message
  AFTER INSERT ON public.feedback_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_feedback_message();

-- 4. RPC om een melding te markeren als gelezen door gebruiker of admin
CREATE OR REPLACE FUNCTION public.mark_feedback_as_read(target_report_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_report_owner UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Niet geauthenticeerd';
  END IF;

  SELECT user_id INTO v_report_owner
  FROM public.feedback_reports
  WHERE id = target_report_id;

  IF v_report_owner IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_licenses ul
    JOIN public.apps a ON ul.app_id = a.id
    WHERE ul.user_id = v_user_id
      AND a.slug = 'hub_admin'
      AND ul.role = 'super_admin'
      AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
  ) INTO v_is_admin;

  IF v_is_admin THEN
    UPDATE public.feedback_reports
    SET has_unread_admin = FALSE
    WHERE id = target_report_id;
  END IF;

  IF v_report_owner = v_user_id THEN
    UPDATE public.feedback_reports
    SET has_unread_user = FALSE
    WHERE id = target_report_id;
  END IF;
END;
$$;

-- 5. Row Level Security (RLS) op feedback_messages
ALTER TABLE public.feedback_messages ENABLE ROW LEVEL SECURITY;

-- SELECT
DROP POLICY IF EXISTS "Users can view messages of own reports" ON public.feedback_messages;
CREATE POLICY "Users can view messages of own reports"
ON public.feedback_messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.feedback_reports r
    WHERE r.id = feedback_messages.report_id
      AND r.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can view all feedback messages" ON public.feedback_messages;
CREATE POLICY "Admins can view all feedback messages"
ON public.feedback_messages
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

-- INSERT
DROP POLICY IF EXISTS "Users can insert messages on own reports" ON public.feedback_messages;
CREATE POLICY "Users can insert messages on own reports"
ON public.feedback_messages
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND sender_role = 'user'
  AND EXISTS (
    SELECT 1 FROM public.feedback_reports r
    WHERE r.id = feedback_messages.report_id
      AND r.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Admins can insert feedback messages" ON public.feedback_messages;
CREATE POLICY "Admins can insert feedback messages"
ON public.feedback_messages
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND sender_role = 'admin'
  AND EXISTS (
    SELECT 1 FROM public.user_licenses ul
    JOIN public.apps a ON ul.app_id = a.id
    WHERE ul.user_id = auth.uid()
      AND a.slug = 'hub_admin'
      AND ul.role = 'super_admin'
      AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
  )
);

-- DELETE (alleen super admins)
DROP POLICY IF EXISTS "Admins can delete feedback messages" ON public.feedback_messages;
CREATE POLICY "Admins can delete feedback messages"
ON public.feedback_messages
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

-- 6. Permissies
GRANT ALL ON TABLE public.feedback_messages TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_feedback_as_read(UUID) TO authenticated, service_role;

-- 7. Supabase Realtime publicatie toevoegingen
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'feedback_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.feedback_reports;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'feedback_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.feedback_messages;
  END IF;
END $$;
