-- ============================================================================
-- Registratie van Spoke App: Raket (raket)
-- ============================================================================

-- 1. App registreren in centrale catalogus
INSERT INTO public.apps (
    name,
    slug,
    github_repo_owner,
    github_repo_name,
    is_active
) VALUES (
    'Raket',
    'raket',
    'SchrobbeD',
    'raket',
    true
) ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    github_repo_owner = EXCLUDED.github_repo_owner,
    github_repo_name = EXCLUDED.github_repo_name,
    is_active = EXCLUDED.is_active;

-- 2. Dedicated PostgreSQL schema aanmaken voor data-isolatie
CREATE SCHEMA IF NOT EXISTS app_raket;

-- Geef rechten aan geauthenticeerde gebruikers
GRANT USAGE ON SCHEMA app_raket TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA app_raket TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app_raket TO authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA app_raket TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_raket GRANT ALL ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_raket GRANT ALL ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_raket GRANT ALL ON ROUTINES TO authenticated, service_role;
