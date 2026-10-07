-- ================================================================
-- Migratie: Verfijning van Ongelezen Badges en Triggers voor Feedback
-- ================================================================

-- 1. Zorg dat nieuwe rapporten standaard has_unread_admin = TRUE hebben
ALTER TABLE public.feedback_reports
  ALTER COLUMN has_unread_admin SET DEFAULT TRUE;

CREATE OR REPLACE FUNCTION public.handle_new_feedback_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.has_unread_admin := TRUE;
  NEW.has_unread_user := FALSE;
  NEW.last_message_at := COALESCE(NEW.last_message_at, NEW.created_at, NOW());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_new_feedback_report_unread ON public.feedback_reports;
CREATE TRIGGER tr_new_feedback_report_unread
  BEFORE INSERT ON public.feedback_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_feedback_report();

-- 2. Verbeterde trigger voor chatberichten
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
      WHEN NEW.sender_role IN ('user', 'github_dev') THEN TRUE 
      WHEN NEW.sender_role = 'admin' THEN FALSE
      ELSE has_unread_admin 
    END,
    has_unread_user = CASE 
      WHEN NEW.sender_role IN ('admin', 'github_dev') THEN TRUE 
      WHEN NEW.sender_role = 'user' THEN FALSE
      ELSE has_unread_user 
    END,
    updated_at = NOW()
  WHERE id = NEW.report_id;

  RETURN NEW;
END;
$$;
