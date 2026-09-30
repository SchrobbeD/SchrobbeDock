-- ====================================================================
-- MIGRATIE: EXCLUSIEF ROBHUB PARODIETHEMA & INVITE CONFIGURATIE
-- ====================================================================

-- 1. Voeg can_access_robhub toe aan public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS can_access_robhub BOOLEAN NOT NULL DEFAULT false;

-- 2. Voeg can_access_robhub en initial_theme_template toe aan public.invitations
ALTER TABLE public.invitations
    ADD COLUMN IF NOT EXISTS can_access_robhub BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.invitations
    ADD COLUMN IF NOT EXISTS initial_theme_template TEXT NOT NULL DEFAULT 'amber_rust';

-- 3. Update handle_new_user() trigger om RobHub-rechten en startthema's toe te kennen bij accountregistratie
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite_code TEXT;
    v_invitation RECORD;
    v_is_oauth BOOLEAN := FALSE;
    v_first_name TEXT;
    v_last_name TEXT;
    v_full_name TEXT;
    v_initial_template TEXT;
    v_new_prefs JSONB;
BEGIN
    v_invite_code := new.raw_user_meta_data->>'invite_code';
    
    -- Controleer of het een OAuth provider betreft (Google, etc.)
    IF new.raw_app_meta_data->>'provider' IS NOT NULL AND new.raw_app_meta_data->>'provider' != 'email' THEN
        v_is_oauth := TRUE;
    END IF;

    -- Voor email registraties is een invite code ALTIJD verplicht (behalve bootstrap admin)
    IF NOT v_is_oauth AND v_invite_code IS NULL AND new.email != 'admin@hub.local' THEN
        RAISE EXCEPTION 'Registratie is uitsluitend toegestaan met een geldige uitnodigingscode.';
    END IF;

    -- Bepaal naamvelden (Google geeft full_name of name mee in user_meta_data)
    v_first_name := new.raw_user_meta_data->>'first_name';
    v_last_name := new.raw_user_meta_data->>'last_name';
    v_full_name := COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name');

    IF v_first_name IS NULL AND v_full_name IS NOT NULL THEN
        IF position(' ' IN v_full_name) > 0 THEN
            v_first_name := split_part(v_full_name, ' ', 1);
            v_last_name := substring(v_full_name from position(' ' IN v_full_name) + 1);
        ELSE
            v_first_name := v_full_name;
        END IF;
    END IF;

    -- Profiel invoegen of bijwerken
    INSERT INTO public.profiles (
        id,
        email,
        first_name,
        last_name,
        phone,
        address_street,
        address_number,
        address_postal_code,
        address_city,
        address_country
    )
    VALUES (
        new.id,
        new.email,
        v_first_name,
        v_last_name,
        new.raw_user_meta_data->>'phone',
        new.raw_user_meta_data->>'address_street',
        new.raw_user_meta_data->>'address_number',
        new.raw_user_meta_data->>'address_postal_code',
        new.raw_user_meta_data->>'address_city',
        COALESCE(new.raw_user_meta_data->>'address_country', 'België')
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        first_name = COALESCE(public.profiles.first_name, EXCLUDED.first_name),
        last_name = COALESCE(public.profiles.last_name, EXCLUDED.last_name);

    -- Als er een invite code meegegeven is, valideer en activeer licenties, RobHub en thema direct
    IF v_invite_code IS NOT NULL THEN
        SELECT * INTO v_invitation
        FROM public.invitations
        WHERE UPPER(code) = UPPER(TRIM(v_invite_code))
          AND is_used = FALSE
          AND (expires_at IS NULL OR expires_at > NOW())
        FOR UPDATE;

        IF FOUND THEN
            -- Licenties toekennen
            INSERT INTO public.user_licenses (user_id, app_id, tier, role)
            SELECT new.id, il.app_id, il.tier, il.role
            FROM public.invitation_licenses il
            WHERE il.invitation_id = v_invitation.id
            ON CONFLICT (user_id, app_id) DO NOTHING;

            -- Markeer uitnodiging als gebruikt
            UPDATE public.invitations
            SET is_used = TRUE,
                used_by = new.id
            WHERE id = v_invitation.id;

            -- 1. RobHub toegang verlenen indien ingesteld op de uitnodiging
            IF v_invitation.can_access_robhub = TRUE OR v_invitation.initial_theme_template = 'rob_hub' THEN
                UPDATE public.profiles
                SET can_access_robhub = TRUE
                WHERE id = new.id;
            END IF;

            -- 2. Startthema configureren en direct toepassen op profiel en user metadata
            v_initial_template := COALESCE(v_invitation.initial_theme_template, 'amber_rust');
            IF v_initial_template = 'rob_hub' THEN
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'dark',
                    'primary_color', '#FFA31A',
                    'secondary_color', '#E58E00',
                    'preset', 'rob_hub',
                    'saved_themes', '[]'::jsonb
                );
            ELSIF v_initial_template = 'ocean_deep' THEN
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'system',
                    'primary_color', '#2563EB',
                    'secondary_color', '#1D4ED8',
                    'preset', 'ocean_deep',
                    'saved_themes', '[]'::jsonb
                );
            ELSIF v_initial_template = 'emerald_forest' THEN
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'system',
                    'primary_color', '#059669',
                    'secondary_color', '#047857',
                    'preset', 'emerald_forest',
                    'saved_themes', '[]'::jsonb
                );
            ELSIF v_initial_template = 'midnight_violet' THEN
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'system',
                    'primary_color', '#7C3AED',
                    'secondary_color', '#6D28D9',
                    'preset', 'midnight_violet',
                    'saved_themes', '[]'::jsonb
                );
            ELSIF v_initial_template = 'slate_monolith' THEN
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'system',
                    'primary_color', '#475569',
                    'secondary_color', '#334155',
                    'preset', 'slate_monolith',
                    'saved_themes', '[]'::jsonb
                );
            ELSE
                v_new_prefs := jsonb_build_object(
                    'theme_mode', 'system',
                    'primary_color', '#EA580C',
                    'secondary_color', '#B45309',
                    'preset', 'amber_rust',
                    'saved_themes', '[]'::jsonb
                );
            END IF;

            IF v_new_prefs IS NOT NULL THEN
                UPDATE public.profiles
                SET preferences = v_new_prefs
                WHERE id = new.id;

                new.raw_user_meta_data := COALESCE(new.raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('preferences', v_new_prefs);
            END IF;
        ELSE
            IF NOT v_is_oauth THEN
                RAISE EXCEPTION 'Ongeldige of verlopen uitnodigingscode: %', v_invite_code;
            END IF;
        END IF;
    END IF;

    RETURN new;
END;
$$;

-- 4. Update claim_invitation(target_code TEXT) voor gebruikers die binnen de app een code inwisselen
CREATE OR REPLACE FUNCTION public.claim_invitation(target_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_invitation RECORD;
    v_apps TEXT[];
    v_current_prefs JSONB;
    v_new_prefs JSONB;
    v_initial_template TEXT;
    v_primary TEXT;
    v_secondary TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authenticatie vereist om een uitnodigingscode te claimen.';
    END IF;

    IF target_code IS NULL OR TRIM(target_code) = '' THEN
        RAISE EXCEPTION 'Geen uitnodigingscode opgegeven.';
    END IF;

    -- Zoek de uitnodiging met row-level locking
    SELECT * INTO v_invitation
    FROM public.invitations
    WHERE UPPER(code) = UPPER(TRIM(target_code))
      AND is_used = FALSE
      AND (expires_at IS NULL OR expires_at > NOW())
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Uitnodigingscode is ongeldig, reeds gebruikt of verlopen.';
    END IF;

    -- Licenties toekennen aan de ingelogde gebruiker
    INSERT INTO public.user_licenses (user_id, app_id, tier, role)
    SELECT v_user_id, il.app_id, il.tier, il.role
    FROM public.invitation_licenses il
    WHERE il.invitation_id = v_invitation.id
    ON CONFLICT (user_id, app_id) DO UPDATE SET
        tier = EXCLUDED.tier,
        role = EXCLUDED.role;

    -- Markeer uitnodiging als gebruikt
    UPDATE public.invitations
    SET is_used = TRUE,
        used_by = v_user_id
    WHERE id = v_invitation.id;

    -- Update RobHub toegang op gebruikersprofiel indien geautoriseerd
    IF v_invitation.can_access_robhub = TRUE OR v_invitation.initial_theme_template = 'rob_hub' THEN
        UPDATE public.profiles
        SET can_access_robhub = TRUE
        WHERE id = v_user_id;
    END IF;

    -- Initial startthema configureren
    v_initial_template := COALESCE(v_invitation.initial_theme_template, 'amber_rust');
    SELECT preferences INTO v_current_prefs FROM public.profiles WHERE id = v_user_id;
    IF v_current_prefs IS NULL THEN
        v_current_prefs := '{}'::jsonb;
    END IF;

    IF v_initial_template = 'rob_hub' THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', 'dark',
            'primary_color', '#FFA31A',
            'secondary_color', '#E58E00',
            'preset', 'rob_hub',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    ELSIF v_initial_template = 'ocean_deep' THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', COALESCE(v_current_prefs->>'theme_mode', 'system'),
            'primary_color', '#2563EB',
            'secondary_color', '#1D4ED8',
            'preset', 'ocean_deep',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    ELSIF v_initial_template = 'emerald_forest' THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', COALESCE(v_current_prefs->>'theme_mode', 'system'),
            'primary_color', '#059669',
            'secondary_color', '#047857',
            'preset', 'emerald_forest',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    ELSIF v_initial_template = 'midnight_violet' THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', COALESCE(v_current_prefs->>'theme_mode', 'system'),
            'primary_color', '#7C3AED',
            'secondary_color', '#6D28D9',
            'preset', 'midnight_violet',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    ELSIF v_initial_template = 'slate_monolith' THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', COALESCE(v_current_prefs->>'theme_mode', 'system'),
            'primary_color', '#475569',
            'secondary_color', '#334155',
            'preset', 'slate_monolith',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    ELSIF v_initial_template IN ('amber_rust', 'warm_amber') THEN
        v_new_prefs := jsonb_build_object(
            'theme_mode', COALESCE(v_current_prefs->>'theme_mode', 'system'),
            'primary_color', '#EA580C',
            'secondary_color', '#B45309',
            'preset', 'amber_rust',
            'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
        );
    END IF;

    IF v_new_prefs IS NOT NULL THEN
        UPDATE public.profiles
        SET preferences = v_new_prefs
        WHERE id = v_user_id;

        UPDATE auth.users
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('preferences', v_new_prefs)
        WHERE id = v_user_id;
    END IF;

    -- Haal namen van toegekende apps op voor feedback
    SELECT COALESCE(array_agg(a.name), ARRAY[]::TEXT[]) INTO v_apps
    FROM public.invitation_licenses il
    JOIN public.apps a ON a.id = il.app_id
    WHERE il.invitation_id = v_invitation.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Uitnodigingscode succesvol geactiveerd!',
        'apps', to_jsonb(v_apps),
        'can_access_robhub', (v_invitation.can_access_robhub = TRUE OR v_initial_template = 'rob_hub'),
        'initial_theme_template', v_initial_template
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_invitation(TEXT) TO authenticated;

-- 5. Update admin_get_users_with_mfa() om ook can_access_robhub terug te geven
DROP FUNCTION IF EXISTS public.admin_get_users_with_mfa();

CREATE OR REPLACE FUNCTION public.admin_get_users_with_mfa()
RETURNS TABLE (
    id UUID,
    email TEXT,
    first_name TEXT,
    last_name TEXT,
    created_at TIMESTAMPTZ,
    has_mfa BOOLEAN,
    mfa_factors_count INT,
    can_access_robhub BOOLEAN
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
        ) AS mfa_factors_count,
        COALESCE(p.can_access_robhub, false) AS can_access_robhub
    FROM public.profiles p
    ORDER BY p.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_get_users_with_mfa() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_users_with_mfa() TO authenticated;

-- 6. RPC voor Platform Admins om RobHub toegang toe te kennen of in te trekken
CREATE OR REPLACE FUNCTION public.admin_set_robhub_access(target_user_id UUID, grant_access BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_current_prefs JSONB;
    v_reset_prefs JSONB;
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

    -- Update toegangsflag
    UPDATE public.profiles
    SET can_access_robhub = grant_access
    WHERE id = target_user_id;

    -- Als toegang wordt ingetrokken en de gebruiker heeft momenteel RobHub actief:
    -- Val automatisch terug naar de standaard Warm Amber & Roest
    IF grant_access = FALSE THEN
        SELECT preferences INTO v_current_prefs FROM public.profiles WHERE id = target_user_id;
        IF v_current_prefs->>'preset' = 'rob_hub' THEN
            v_reset_prefs := jsonb_build_object(
                'theme_mode', 'system',
                'primary_color', '#EA580C',
                'secondary_color', '#B45309',
                'preset', 'amber_rust',
                'saved_themes', COALESCE(v_current_prefs->'saved_themes', '[]'::jsonb)
            );
            UPDATE public.profiles
            SET preferences = v_reset_prefs
            WHERE id = target_user_id;

            UPDATE auth.users
            SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('preferences', v_reset_prefs)
            WHERE id = target_user_id;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_set_robhub_access(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_robhub_access(UUID, BOOLEAN) TO authenticated;
