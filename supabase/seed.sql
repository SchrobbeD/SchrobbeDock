-- ====================================================================
-- SEED DATA: SCHROBBEDOCK LOKAAL TESTEN (HUB & SPOKES)
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. CATALOGUS: TEST APPLICATIES (HUB & SPOKES)
-- --------------------------------------------------------------------
INSERT INTO public.apps (id, slug, name, is_active, github_repo_owner, github_repo_name)
VALUES 
    ('22222222-2222-2222-2222-222222222222', 'hub_admin', 'Centraal Hub Beheer', true, 'SchrobbeD', 'SchrobbeDock'),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'dock_planner', 'SchrobbeDock Planner', true, 'SchrobbeD', 'SchrobbeDock'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'dock_warehouse', 'SchrobbeDock Magazijn & Logistiek', true, 'SchrobbeD', 'SchrobbeDock'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'raket', 'Raket', true, 'SchrobbeD', 'Raket')
ON CONFLICT (slug) DO UPDATE SET
    id = EXCLUDED.id,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active,
    github_repo_owner = EXCLUDED.github_repo_owner,
    github_repo_name = EXCLUDED.github_repo_name;

-- --------------------------------------------------------------------
-- 2. SEED UITNODIGINGEN VOOR TESTGEBRUIKERS
-- --------------------------------------------------------------------
INSERT INTO public.invitations (id, code, is_used, expires_at)
VALUES 
    ('55555555-5555-5555-5555-555555555555', 'INVITE-USER1-SEED', false, NOW() + INTERVAL '365 days'),
    ('66666666-6666-6666-6666-666666666666', 'INVITE-USER2-SEED', false, NOW() + INTERVAL '365 days'),
    ('77777777-7777-7777-7777-777777777777', 'INVITE-USER3-SEED', false, NOW() + INTERVAL '365 days'),
    ('88888888-8888-8888-8888-888888888888', 'INVITE-USER4-SEED', false, NOW() + INTERVAL '365 days'),
    ('99999999-9999-9999-9999-999999999999', 'INVITE-USER5-SEED', false, NOW() + INTERVAL '365 days'),
    ('aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', 'INVITE-USER6-SEED', false, NOW() + INTERVAL '365 days'),
    ('bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', 'INVITE-USER7-SEED', false, NOW() + INTERVAL '365 days')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.invitation_licenses (invitation_id, app_id, tier, role)
VALUES
    ('55555555-5555-5555-5555-555555555555', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user'),
    ('55555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pro', 'user'),
    ('66666666-6666-6666-6666-666666666666', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user'),
    ('66666666-6666-6666-6666-666666666666', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'basic', 'user'),
    ('66666666-6666-6666-6666-666666666666', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'pro', 'manager'),
    ('77777777-7777-7777-7777-777777777777', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user'),
    ('88888888-8888-8888-8888-888888888888', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user'),
    ('99999999-9999-9999-9999-999999999999', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'basic', 'user'),
    ('aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'basic', 'user')
ON CONFLICT (invitation_id, app_id) DO NOTHING;

-- --------------------------------------------------------------------
-- 3. ACCOUNTS AANMAKEN (AUTH.USERS & AUTH.IDENTITIES)
-- Wachtwoord voor alle accounts is 'password123'
-- --------------------------------------------------------------------

-- Helper functie om deterministisch users aan te maken
DO $$
DECLARE
    users_data JSONB := '[
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "email": "admin@hub.local",
            "first_name": "Super",
            "last_name": "Admin",
            "theme_mode": "system",
            "primary_color": "#EA580C",
            "secondary_color": "#B45309",
            "preset": "amber_rust",
            "can_access_robhub": true
        },
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "email": "user1@hub.local",
            "first_name": "Jan",
            "last_name": "Jansen",
            "theme_mode": "system",
            "primary_color": "#EA580C",
            "secondary_color": "#B45309",
            "preset": "amber_rust",
            "can_access_robhub": false
        },
        {
            "id": "44444444-4444-4444-4444-444444444444",
            "email": "user2@hub.local",
            "first_name": "Sophie",
            "last_name": "Peeters",
            "theme_mode": "dark",
            "primary_color": "#2563EB",
            "secondary_color": "#1D4ED8",
            "preset": "ocean_deep",
            "can_access_robhub": false
        },
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "email": "user3@hub.local",
            "first_name": "Thomas",
            "last_name": "De Smet",
            "theme_mode": "system",
            "primary_color": "#10B981",
            "secondary_color": "#047857",
            "preset": "emerald_lawn",
            "can_access_robhub": false
        },
        {
            "id": "66666666-6666-6666-6666-666666666666",
            "email": "user4@hub.local",
            "first_name": "Lukas",
            "last_name": "Vermeulen",
            "theme_mode": "dark",
            "primary_color": "#8B5CF6",
            "secondary_color": "#6D28D9",
            "preset": "royal_purple",
            "can_access_robhub": false
        },
        {
            "id": "77777777-7777-7777-7777-777777777777",
            "email": "user5@hub.local",
            "first_name": "Emma",
            "last_name": "Claes",
            "theme_mode": "light",
            "primary_color": "#EC4899",
            "secondary_color": "#BE185D",
            "preset": "sunset_rose",
            "can_access_robhub": false
        },
        {
            "id": "88888888-8888-8888-8888-888888888888",
            "email": "user6@hub.local",
            "first_name": "Dries",
            "last_name": "Wouters",
            "theme_mode": "system",
            "primary_color": "#F59E0B",
            "secondary_color": "#B45309",
            "preset": "warm_slate",
            "can_access_robhub": false
        },
        {
            "id": "99999999-9999-9999-9999-999999999999",
            "email": "user7@hub.local",
            "first_name": "Sanne",
            "last_name": "Jacobs",
            "theme_mode": "system",
            "primary_color": "#64748B",
            "secondary_color": "#334155",
            "preset": "slate_neutral",
            "can_access_robhub": false
        }
    ]'::jsonb;
    u JSONB;
BEGIN
    FOR u IN SELECT * FROM jsonb_array_elements(users_data)
    LOOP
        -- 1. auth.users
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, recovery_sent_at, last_sign_in_at,
            raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at,
            confirmation_token, email_change, email_change_token_new, recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            (u->>'id')::UUID,
            'authenticated', 'authenticated', (u->>'email'),
            crypt('password123', gen_salt('bf')),
            NOW(), NOW(), NOW(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object(
                'first_name', u->>'first_name',
                'last_name', u->>'last_name',
                'preferences', jsonb_build_object(
                    'theme_mode', u->>'theme_mode',
                    'primary_color', u->>'primary_color',
                    'secondary_color', u->>'secondary_color',
                    'preset', u->>'preset'
                )
            ),
            NOW(), NOW(),
            '', '', '', ''
        ) ON CONFLICT (id) DO UPDATE SET
            encrypted_password = crypt('password123', gen_salt('bf')),
            raw_user_meta_data = EXCLUDED.raw_user_meta_data,
            confirmation_token = '',
            email_change = '',
            email_change_token_new = '',
            recovery_token = '';

        -- 2. auth.identities
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            (u->>'id')::UUID,
            (u->>'id')::UUID,
            format('{"sub":"%s","email":"%s"}', u->>'id', u->>'email')::jsonb,
            'email', u->>'id',
            NOW(), NOW(), NOW()
        ) ON CONFLICT (id) DO NOTHING;

        -- 3. auth.mfa_factors (totp verified bypass voor frictieloos testen)
        INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret)
        VALUES (
            (substr(u->>'id', 1, 8) || '-ffff-ffff-ffff-' || substr(u->>'id', 25, 12))::UUID,
            (u->>'id')::UUID,
            'Seeded Authenticator App',
            'totp',
            'verified',
            NOW(), NOW(),
            'DUMMYSECRET' || substr(u->>'id', 1, 6)
        ) ON CONFLICT (id) DO NOTHING;

        -- 4. public.profiles
        INSERT INTO public.profiles (id, email, first_name, last_name, preferences, can_access_robhub)
        VALUES (
            (u->>'id')::UUID,
            u->>'email',
            u->>'first_name',
            u->>'last_name',
            jsonb_build_object(
                'theme_mode', u->>'theme_mode',
                'primary_color', u->>'primary_color',
                'secondary_color', u->>'secondary_color',
                'preset', u->>'preset'
            ),
            (u->>'can_access_robhub')::BOOLEAN
        ) ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name,
            preferences = EXCLUDED.preferences,
            can_access_robhub = EXCLUDED.can_access_robhub;

    END LOOP;
END $$;

-- --------------------------------------------------------------------
-- 4. DIRECTE TESTLICENTIES TOEKENNEN (PUBLIC.USER_LICENSES)
-- --------------------------------------------------------------------

-- Super Admin: Hub Admin licentie
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'enterprise', 'super_admin', null)
ON CONFLICT (user_id, app_id) DO NOTHING;

-- Spelers 1 t/m 4 (Vaste spelers dubbelspel): Actieve Pro licentie voor Raket
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES 
    ('33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user', null),
    ('44444444-4444-4444-4444-444444444444', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user', null),
    ('55555555-5555-5555-5555-555555555555', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user', null),
    ('66666666-6666-6666-6666-666666666666', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'pro', 'user', null)
ON CONFLICT (user_id, app_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    role = EXCLUDED.role;

-- Spelers 5 & 6 (Reservespelers): Actieve Basic licentie voor Raket
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES 
    ('77777777-7777-7777-7777-777777777777', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'basic', 'user', null),
    ('88888888-8888-8888-8888-888888888888', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'basic', 'user', null)
ON CONFLICT (user_id, app_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    role = EXCLUDED.role;

-- Planner & Warehouse testlicenties voor User 1 en User 2
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES 
    ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pro', 'user', null),
    ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'basic', 'user', null),
    ('44444444-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'pro', 'manager', null)
ON CONFLICT (user_id, app_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    role = EXCLUDED.role;

-- LET OP: user7@hub.local (Sanne Jacobs) krijgt BEWUST GEEN licentie!
-- Dit account dient om NoAccessView, invite-code inwisselen en toegangsaanvragen te testen.