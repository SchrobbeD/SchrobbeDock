-- ====================================================================
-- MIGRATIE: ADMIN 2FA RESET & GEBRUIKERSSTATUS BEHEER
-- ====================================================================

-- 1. Functie om gebruikerslijst met MFA-status op te halen (alleen voor Platform Admins)
CREATE OR REPLACE FUNCTION public.admin_get_users_with_mfa()
RETURNS TABLE (
    id UUID,
    email TEXT,
    first_name TEXT,
    last_name TEXT,
    created_at TIMESTAMPTZ,
    has_mfa BOOLEAN,
    mfa_factors_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    -- Toegangscontrole: uitsluitend super_admin van hub_admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Toegang geweigerd: uitsluitend voor Platform Admins.';
    END IF;

    RETURN QUERY
    SELECT 
        p.id,
        p.email,
        p.first_name,
        p.last_name,
        p.created_at,
        EXISTS (
            SELECT 1 FROM auth.mfa_factors mf 
            WHERE mf.user_id = p.id AND mf.status = 'verified'
        ) AS has_mfa,
        (
            SELECT COUNT(*)::INT FROM auth.mfa_factors mf 
            WHERE mf.user_id = p.id AND mf.status = 'verified'
        ) AS mfa_factors_count
    FROM public.profiles p
    ORDER BY p.created_at DESC;
END;
$$;

-- 2. Functie om MFA voor een specifieke gebruiker te resetten
CREATE OR REPLACE FUNCTION public.admin_reset_user_mfa(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    -- Toegangscontrole: uitsluitend super_admin van hub_admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Toegang geweigerd: uitsluitend voor Platform Admins.';
    END IF;

    -- Verwijder alle MFA-factoren voor de doelgebruiker
    DELETE FROM auth.mfa_factors
    WHERE user_id = target_user_id;

    RETURN TRUE;
END;
$$;

-- 3. Toegangsrechten toekennen aan authenticated rol
REVOKE EXECUTE ON FUNCTION public.admin_get_users_with_mfa() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_users_with_mfa() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_reset_user_mfa(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_mfa(UUID) TO authenticated;
