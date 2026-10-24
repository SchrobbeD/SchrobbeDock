-- ============================================================================
-- Registratie van Spoke App: WinterRaket (winterraket)
-- ============================================================================

-- 1. App registreren in centrale catalogus
INSERT INTO public.apps (
    name,
    slug,
    description,
    launch_url,
    icon_name,
    github_repo_owner,
    github_repo_name,
    is_active
) VALUES (
    'WinterRaket',
    'winterraket',
    'Spoke applicatie WinterRaket binnen het SchrobbeDock ecosysteem.',
    'https://winterraket.robbedillen.be',
    'widgets',
    'SchrobbeD',
    'winterraket',
    true
) ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    launch_url = EXCLUDED.launch_url;

-- 2. Dedicated PostgreSQL schema aanmaken voor data-isolatie
CREATE SCHEMA IF NOT EXISTS app_winterraket;

-- Geef rechten aan geauthenticeerde gebruikers
GRANT USAGE ON SCHEMA app_winterraket TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA app_winterraket TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app_winterraket TO authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA app_winterraket TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_winterraket GRANT ALL ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_winterraket GRANT ALL ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_winterraket GRANT ALL ON ROUTINES TO authenticated, service_role;
