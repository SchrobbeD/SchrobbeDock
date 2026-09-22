-- ====================================================================
-- MIGRATIE: PROFIEL UITBREIDING, INVITE SYSTEEM & LICENTIE AUTOMATISERING
-- ====================================================================

-- 1. PROFIELEN UITBREIDEN
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS first_name TEXT,
    ADD COLUMN IF NOT EXISTS last_name TEXT,
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS address_street TEXT,
    ADD COLUMN IF NOT EXISTS address_number TEXT,
    ADD COLUMN IF NOT EXISTS address_postal_code TEXT,
    ADD COLUMN IF NOT EXISTS address_city TEXT,
    ADD COLUMN IF NOT EXISTS address_country TEXT DEFAULT 'België',
    ADD COLUMN IF NOT EXISTS organization_id UUID;

-- 2. UITNODIGINGSTABELLEN
CREATE TABLE IF NOT EXISTS public.invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '14 days'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.invitation_licenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invitation_id UUID REFERENCES public.invitations(id) ON DELETE CASCADE NOT NULL,
    app_id UUID REFERENCES public.apps(id) ON DELETE CASCADE NOT NULL,
    tier TEXT DEFAULT 'basic',
    role TEXT DEFAULT 'user',
    UNIQUE(invitation_id, app_id)
);

-- 3. RLS INSTELLEN
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_licenses ENABLE ROW LEVEL SECURITY;

-- Super admins hebben volledige controle over invitations
CREATE POLICY "Super admins manage invitations"
ON public.invitations
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    )
);

CREATE POLICY "Super admins manage invitation licenses"
ON public.invitation_licenses
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
    )
);

-- 4. VEILIGE RPC VOOR PUBLIC INVITE VALIDATIE
CREATE OR REPLACE FUNCTION public.check_invite_code(target_code TEXT)
RETURNS TABLE (
    is_valid BOOLEAN,
    app_names TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invitation_id UUID;
    v_is_used BOOLEAN;
    v_expires_at TIMESTAMPTZ;
    v_apps TEXT[];
BEGIN
    SELECT id, is_used, expires_at INTO v_invitation_id, v_is_used, v_expires_at
    FROM public.invitations
    WHERE UPPER(code) = UPPER(TRIM(target_code));

    IF v_invitation_id IS NULL OR v_is_used = TRUE OR (v_expires_at IS NOT NULL AND v_expires_at < NOW()) THEN
        RETURN QUERY SELECT FALSE, ARRAY[]::TEXT[];
        RETURN;
    END IF;

    SELECT COALESCE(array_agg(a.name), ARRAY[]::TEXT[]) INTO v_apps
    FROM public.invitation_licenses il
    JOIN public.apps a ON a.id = il.app_id
    WHERE il.invitation_id = v_invitation_id;

    RETURN QUERY SELECT TRUE, v_apps;
END;
$$;

-- 5. TRIGGER AANPASSEN VOOR PROFIELEN EN AUTOMATISCHE LICENTIES
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite_code TEXT;
    v_invitation RECORD;
BEGIN
    v_invite_code := new.raw_user_meta_data->>'invite_code';

    -- Registratie vereist een geldige invite code, behalve voor bootstrap/admin accounts
    IF v_invite_code IS NULL AND new.email != 'admin@hub.local' THEN
        RAISE EXCEPTION 'Registratie is uitsluitend toegestaan met een geldige uitnodigingscode.';
    END IF;

    -- Profiel invoegen met extra persoonsgegevens
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
        new.raw_user_meta_data->>'first_name',
        new.raw_user_meta_data->>'last_name',
        new.raw_user_meta_data->>'phone',
        new.raw_user_meta_data->>'address_street',
        new.raw_user_meta_data->>'address_number',
        new.raw_user_meta_data->>'address_postal_code',
        new.raw_user_meta_data->>'address_city',
        COALESCE(new.raw_user_meta_data->>'address_country', 'België')
    );

    -- Als er een invite code is, valideer en activeer de licenties direct
    IF v_invite_code IS NOT NULL THEN
        SELECT * INTO v_invitation
        FROM public.invitations
        WHERE UPPER(code) = UPPER(TRIM(v_invite_code))
          AND is_used = FALSE
          AND (expires_at IS NULL OR expires_at > NOW())
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Ongeldige of verlopen uitnodigingscode: %', v_invite_code;
        END IF;

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
    END IF;

    RETURN new;
END;
$$;
