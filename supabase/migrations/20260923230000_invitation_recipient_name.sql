-- ====================================================================
-- MIGRATIE: RECIPIENT_NAME TOEVOEGEN AAN INVITATIONS (ADMIN TRACKING)
-- ====================================================================

ALTER TABLE public.invitations
    ADD COLUMN IF NOT EXISTS recipient_name TEXT;
