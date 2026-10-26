-- ============================================================================
-- Compatibiliteitsview: public.licenses
-- Zorgt dat Spoke apps zowel via public.user_licenses als public.licenses 
-- kunnen controleren op actieve licenties.
-- ============================================================================

CREATE OR REPLACE VIEW public.licenses AS
SELECT 
    ul.id,
    ul.user_id,
    a.slug AS app_id,
    a.id AS app_uuid,
    ul.tier,
    ul.role,
    ul.valid_until,
    (ul.valid_until IS NULL OR ul.valid_until > now()) AS is_active
FROM public.user_licenses ul
JOIN public.apps a ON a.id = ul.app_id;

GRANT SELECT ON public.licenses TO authenticated, service_role;
