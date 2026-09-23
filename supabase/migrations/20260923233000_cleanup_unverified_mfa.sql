-- ====================================================================
-- MIGRATIE: CLEANUP ONVOLTOOIDE (UNVERIFIED) MFA FACTOREN
-- ====================================================================

CREATE OR REPLACE FUNCTION public.cleanup_unverified_mfa_factors()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    DELETE FROM auth.mfa_factors
    WHERE user_id = auth.uid()
      AND status = 'unverified';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cleanup_unverified_mfa_factors() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_unverified_mfa_factors() TO authenticated;
