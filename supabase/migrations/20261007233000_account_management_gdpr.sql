-- ====================================================================
-- MIGRATIE: ACCOUNT- & GEBRUIKERSBEHEER (AVG / GDPR "RIGHT TO BE FORGOTTEN")
-- ====================================================================

-- 1. Functie voor Platform Admins om een account definitief te verwijderen
CREATE OR REPLACE FUNCTION public.delete_user_by_admin(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_admin_count INT;
    v_target_is_admin BOOLEAN;
BEGIN
    -- 1. Toegangscontrole: uitsluitend super_admin van hub_admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    ) THEN
        RAISE EXCEPTION 'Toegang geweigerd: uitsluitend voor Platform Admins.';
    END IF;

    -- 2. Zelfverwijdering via admin interface blokkeren (bescherming tegen accidentele lockout)
    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Je kunt je eigen administrator-account niet verwijderen via Admin Beheer. Gebruik hiervoor je profielinstellingen.';
    END IF;

    -- 3. Controleer of de doelgebruiker een super_admin is en of er minimaal 1 andere overblijft
    SELECT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = target_user_id
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    ) INTO v_target_is_admin;

    IF v_target_is_admin THEN
        SELECT COUNT(DISTINCT ul.user_id) INTO v_admin_count
        FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE a.slug = 'hub_admin'
          AND ul.role = 'super_admin';

        IF v_admin_count <= 1 THEN
            RAISE EXCEPTION 'Dit is de enige overgebleven Platform Admin en kan niet worden verwijderd.';
        END IF;
    END IF;

    -- 4. Verwijder de gebruiker definitief uit auth.users (cascadeert automatisch naar profiles, licenses, identities, etc.)
    DELETE FROM auth.users WHERE id = target_user_id;

    RETURN TRUE;
END;
$$;

-- 2. Functie voor gebruikers om zelfstandig hun eigen account definitief te verwijderen
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_super_admin BOOLEAN;
    v_admin_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Niet ingelogd.';
    END IF;

    -- Als de gebruiker een super_admin is, controleer of hij de enige is
    SELECT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = v_user_id
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    ) INTO v_is_super_admin;

    IF v_is_super_admin THEN
        SELECT COUNT(DISTINCT ul.user_id) INTO v_admin_count
        FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE a.slug = 'hub_admin'
          AND ul.role = 'super_admin';

        IF v_admin_count <= 1 THEN
            RAISE EXCEPTION 'Als enige Platform Admin kun je je account niet verwijderen. Draag eerst beheerderstoegang over aan een andere gebruiker.';
        END IF;
    END IF;

    -- Verwijder definitief uit auth.users (cascadeert naar alle gerelateerde tabellen)
    DELETE FROM auth.users WHERE id = v_user_id;

    RETURN TRUE;
END;
$$;

-- 3. Rechten toekennen
REVOKE EXECUTE ON FUNCTION public.delete_user_by_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_by_admin(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.delete_own_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
