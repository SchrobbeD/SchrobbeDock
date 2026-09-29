-- ====================================================================
-- SEED DATA: SCHROBBEDOCK LOKAAL TESTEN
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. CATALOGUS: TEST APPLICATIES (HUB & SPOKES)
-- --------------------------------------------------------------------
INSERT INTO public.apps (id, slug, name, is_active)
VALUES 
    ('22222222-2222-2222-2222-222222222222', 'hub_admin', 'Centraal Hub Beheer', true),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'dock_planner', 'SchrobbeDock Planner', true),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'dock_warehouse', 'SchrobbeDock Magazijn & Logistiek', true)
ON CONFLICT (id) DO UPDATE SET
    slug = EXCLUDED.slug,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

-- --------------------------------------------------------------------
-- 2. ACCOUNTS AANMAKEN (AUTH.USERS & AUTH.IDENTITIES)
-- Wachtwoord voor alle accounts is 'password123'
-- --------------------------------------------------------------------

-- A. Super Admin: admin@hub.local
INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated', 'authenticated', 'admin@hub.local',
    crypt('password123', gen_salt('bf')),
    NOW(), NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Super","last_name":"Admin","preferences":{"theme_mode":"system","primary_color":"#EA580C","secondary_color":"#B45309","preset":"amber_rust"}}',
    NOW(), NOW()
) ON CONFLICT (id) DO UPDATE SET
    encrypted_password = crypt('password123', gen_salt('bf')),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data;

INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    format('{"sub":"%s","email":"%s"}', '11111111-1111-1111-1111-111111111111', 'admin@hub.local')::jsonb,
    'email', '11111111-1111-1111-1111-111111111111',
    NOW(), NOW(), NOW()
) ON CONFLICT (id, provider) DO NOTHING;

-- B. Test User 1: user1@hub.local (Jan Jansen - Planner gebruiker)
INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-3333-3333-333333333333',
    'authenticated', 'authenticated', 'user1@hub.local',
    crypt('password123', gen_salt('bf')),
    NOW(), NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Jan","last_name":"Jansen","preferences":{"theme_mode":"system","primary_color":"#EA580C","secondary_color":"#B45309","preset":"amber_rust"}}',
    NOW(), NOW()
) ON CONFLICT (id) DO UPDATE SET
    encrypted_password = crypt('password123', gen_salt('bf')),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data;

INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
    '33333333-3333-3333-3333-333333333333',
    '33333333-3333-3333-3333-333333333333',
    format('{"sub":"%s","email":"%s"}', '33333333-3333-3333-3333-333333333333', 'user1@hub.local')::jsonb,
    'email', '33333333-3333-3333-3333-333333333333',
    NOW(), NOW(), NOW()
) ON CONFLICT (id, provider) DO NOTHING;

-- C. Test User 2: user2@hub.local (Sophie Peeters - Magazijn & Planner beheerder)
INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444444',
    'authenticated', 'authenticated', 'user2@hub.local',
    crypt('password123', gen_salt('bf')),
    NOW(), NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Sophie","last_name":"Peeters","preferences":{"theme_mode":"dark","primary_color":"#2563EB","secondary_color":"#1D4ED8","preset":"ocean_deep"}}',
    NOW(), NOW()
) ON CONFLICT (id) DO UPDATE SET
    encrypted_password = crypt('password123', gen_salt('bf')),
    raw_user_meta_data = EXCLUDED.raw_user_meta_data;

INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
    '44444444-4444-4444-4444-444444444444',
    '44444444-4444-4444-4444-444444444444',
    format('{"sub":"%s","email":"%s"}', '44444444-4444-4444-4444-444444444444', 'user2@hub.local')::jsonb,
    'email', '44444444-4444-4444-4444-444444444444',
    NOW(), NOW(), NOW()
) ON CONFLICT (id, provider) DO NOTHING;

-- --------------------------------------------------------------------
-- 3. PROFIELEN SYNCHRONISEREN IN PUBLIC.PROFILES
-- --------------------------------------------------------------------
INSERT INTO public.profiles (id, email, first_name, last_name, preferences)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'admin@hub.local', 'Super', 'Admin', '{"theme_mode":"system","primary_color":"#EA580C","secondary_color":"#B45309","preset":"amber_rust"}'::jsonb),
    ('33333333-3333-3333-3333-333333333333', 'user1@hub.local', 'Jan', 'Jansen', '{"theme_mode":"system","primary_color":"#EA580C","secondary_color":"#B45309","preset":"amber_rust"}'::jsonb),
    ('44444444-4444-4444-4444-444444444444', 'user2@hub.local', 'Sophie', 'Peeters', '{"theme_mode":"dark","primary_color":"#2563EB","secondary_color":"#1D4ED8","preset":"ocean_deep"}'::jsonb)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    preferences = EXCLUDED.preferences;

-- --------------------------------------------------------------------
-- 4. APPLICATIELICENTIES KOPPELEN
-- --------------------------------------------------------------------

-- Super Admin: Heeft Hub Admin
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'enterprise', 'super_admin', null)
ON CONFLICT (user_id, app_id) DO NOTHING;

-- User 1 (Jan Jansen): Licentie voor SchrobbeDock Planner (Pro)
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pro', 'user', null)
ON CONFLICT (user_id, app_id) DO NOTHING;

-- User 2 (Sophie Peeters): Licenties voor Planner én Magazijn (Manager)
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES 
    ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'basic', 'user', null),
    ('44444444-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'pro', 'manager', null)
ON CONFLICT (user_id, app_id) DO NOTHING;