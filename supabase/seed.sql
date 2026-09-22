-- 1. Maak een Super Admin aan in Supabase Auth (Enkel voor lokaal testen!)
-- Wachtwoord is 'password123'
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'admin@hub.local',
    crypt('password123', gen_salt('bf')),
    current_timestamp,
    current_timestamp,
    current_timestamp,
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Super","last_name":"Admin"}',
    current_timestamp,
    current_timestamp,
    '',
    '',
    '',
    ''
);

-- Koppel de identity aan het e-mail account
INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    format('{"sub":"%s","email":"%s"}', '11111111-1111-1111-1111-111111111111', 'admin@hub.local')::jsonb,
    'email',
    '11111111-1111-1111-1111-111111111111',
    current_timestamp,
    current_timestamp,
    current_timestamp
);

-- 2. Registreer de 'Hub Beheer' applicatie in de catalogus
INSERT INTO public.apps (id, slug, name, is_active)
VALUES ('22222222-2222-2222-2222-222222222222', 'hub_admin', 'Centraal Hub Beheer', true);

-- 3. Koppel de Super Admin licentie aan de gebruiker
INSERT INTO public.user_licenses (user_id, app_id, tier, role, valid_until)
VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'enterprise', 'super_admin', null);