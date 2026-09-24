-- Migratie: Ondersteuning voor Google OAuth registratie en claimen van uitnodigingscodes
-- 1. Pas handle_new_user() aan om OAuth accounts (zoals Google) toe te staan
-- 2. Maak de claim_invitation(target_code TEXT) RPC functie aan voor ingelogde gebruikers

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

    -- Als er een invite code meegegeven is, valideer en activeer de licenties direct
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
        ELSE
            IF NOT v_is_oauth THEN
                RAISE EXCEPTION 'Ongeldige of verlopen uitnodigingscode: %', v_invite_code;
            END IF;
        END IF;
    END IF;

    RETURN new;
END;
$$;

-- 2. RPC functie om als geauthenticeerde gebruiker een uitnodigingscode te claimen
CREATE OR REPLACE FUNCTION public.claim_invitation(target_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_invitation RECORD;
    v_apps TEXT[];
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

    -- Haal namen van toegekende apps op voor feedback
    SELECT COALESCE(array_agg(a.name), ARRAY[]::TEXT[]) INTO v_apps
    FROM public.invitation_licenses il
    JOIN public.apps a ON a.id = il.app_id
    WHERE il.invitation_id = v_invitation.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Uitnodigingscode succesvol geactiveerd!',
        'apps', to_jsonb(v_apps)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_invitation(TEXT) TO authenticated;
