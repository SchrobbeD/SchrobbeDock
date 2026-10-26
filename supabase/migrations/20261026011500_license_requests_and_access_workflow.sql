-- ====================================================================
-- MIGRATIE: CENTRALE TOEGANGSAANVRAGEN (PUBLIC.LICENSE_REQUESTS)
-- ====================================================================

-- 1. Tabel voor toegangsaanvragen aanmaken
CREATE TABLE IF NOT EXISTS public.license_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    app_id UUID REFERENCES public.apps(id) ON DELETE CASCADE NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexen voor performant filteren op dashboard en per gebruiker/app
CREATE INDEX IF NOT EXISTS idx_license_requests_user_id ON public.license_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_license_requests_app_id ON public.license_requests(app_id);
CREATE INDEX IF NOT EXISTS idx_license_requests_status ON public.license_requests(status);
CREATE INDEX IF NOT EXISTS idx_license_requests_created_at ON public.license_requests(created_at DESC);

-- 2. Row Level Security (RLS)
ALTER TABLE public.license_requests ENABLE ROW LEVEL SECURITY;

-- Gebruikers mogen eigen aanvragen bekijken
CREATE POLICY "Users can view own license requests"
ON public.license_requests
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Gebruikers mogen een aanvraag voor zichzelf indienen
CREATE POLICY "Users can create own license requests"
ON public.license_requests
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Platform Super Admins hebben volledige lees/update toegang
CREATE POLICY "Admins can view all license requests"
ON public.license_requests
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

CREATE POLICY "Admins can update license requests"
ON public.license_requests
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
);

-- 3. RPC: request_app_access (voor Spoke apps en Hub gebruikers)
CREATE OR REPLACE FUNCTION public.request_app_access(
    target_app_slug TEXT,
    request_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_app RECORD;
    v_existing_license RECORD;
    v_existing_request RECORD;
    v_request_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authenticatie vereist om toegang aan te vragen.';
    END IF;

    -- Zoek applicatie op basis van slug
    SELECT id, name, slug INTO v_app
    FROM public.apps
    WHERE slug = LOWER(TRIM(target_app_slug))
      AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Applicatie met slug "%" bestaat niet of is inactief.', target_app_slug;
    END IF;

    -- Controleer of de gebruiker reeds een actieve licentie heeft
    SELECT * INTO v_existing_license
    FROM public.user_licenses
    WHERE user_id = v_user_id
      AND app_id = v_app.id
      AND (valid_until IS NULL OR valid_until > NOW());

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'code', 'ALREADY_HAVE_LICENSE',
            'message', 'Je hebt al een actieve licentie voor ' || v_app.name || '.'
        );
    END IF;

    -- Controleer of er al een 'pending' aanvraag openstaat
    SELECT * INTO v_existing_request
    FROM public.license_requests
    WHERE user_id = v_user_id
      AND app_id = v_app.id
      AND status = 'pending'
    LIMIT 1;

    IF FOUND THEN
        -- Werk reden en timestamp bij
        UPDATE public.license_requests
        SET reason = COALESCE(request_reason, reason),
            updated_at = NOW()
        WHERE id = v_existing_request.id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'code', 'REQUEST_UPDATED',
            'message', 'Je openstaande aanvraag voor ' || v_app.name || ' is bijgewerkt.',
            'request_id', v_existing_request.id
        );
    END IF;

    -- Nieuwe aanvraag invoegen
    INSERT INTO public.license_requests (
        user_id,
        app_id,
        reason,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        v_app.id,
        request_reason,
        'pending',
        NOW(),
        NOW()
    ) RETURNING id INTO v_request_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'code', 'REQUEST_CREATED',
        'message', 'Toegangsaanvraag voor ' || v_app.name || ' is succesvol ingediend.',
        'request_id', v_request_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_app_access(TEXT, TEXT) TO authenticated;

-- 4. RPC: review_license_request (voor Platform Admins)
CREATE OR REPLACE FUNCTION public.review_license_request(
    request_id UUID,
    new_status TEXT,
    assigned_tier TEXT DEFAULT 'basic',
    assigned_role TEXT DEFAULT 'user'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_req RECORD;
    v_app_name TEXT;
    v_user_email TEXT;
BEGIN
    -- Validatie admin rechten
    IF NOT EXISTS (
        SELECT 1 FROM public.user_licenses ul
        JOIN public.apps a ON ul.app_id = a.id
        WHERE ul.user_id = v_admin_id
          AND a.slug = 'hub_admin'
          AND ul.role = 'super_admin'
          AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
    ) THEN
        RAISE EXCEPTION 'Toegang geweigerd: uitsluitend voor Platform Admins.';
    END IF;

    IF new_status NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Ongeldige status: moet "approved" of "rejected" zijn.';
    END IF;

    -- Haal aanvraag op met row lock
    SELECT lr.*, a.name AS app_name, p.email AS user_email
    INTO v_req
    FROM public.license_requests lr
    JOIN public.apps a ON a.id = lr.app_id
    JOIN public.profiles p ON p.id = lr.user_id
    WHERE lr.id = request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aanvraag niet gevonden.';
    END IF;

    IF new_status = 'approved' THEN
        -- Atomair licentie toekennen of updaten
        INSERT INTO public.user_licenses (
            user_id,
            app_id,
            tier,
            role,
            created_at
        ) VALUES (
            v_req.user_id,
            v_req.app_id,
            COALESCE(assigned_tier, 'basic'),
            COALESCE(assigned_role, 'user'),
            NOW()
        )
        ON CONFLICT (user_id, app_id) DO UPDATE SET
            tier = EXCLUDED.tier,
            role = EXCLUDED.role,
            valid_until = NULL;

        -- Status bijwerken
        UPDATE public.license_requests
        SET status = 'approved',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = request_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'status', 'approved',
            'message', 'Aanvraag goedgekeurd en licentie voor ' || v_req.app_name || ' toegekend aan ' || v_req.user_email || '.'
        );
    ELSE
        -- Status bijwerken naar rejected
        UPDATE public.license_requests
        SET status = 'rejected',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = request_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'status', 'rejected',
            'message', 'Aanvraag afgewezen voor ' || v_req.user_email || '.'
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_license_request(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- 5. Realtime inschakelen voor live dashboard updates
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.license_requests;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
$$;
