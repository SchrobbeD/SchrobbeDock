-- ====================================================================
-- MIGRATIE: GEBRUIKERSTHEMA & LAYOUT PERSONALISATIE
-- ====================================================================

-- 1. Voeg preferences kolom toe aan public.profiles met Amber/Roest en Slate als default
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{
        "theme_mode": "system",
        "primary_color": "#EA580C",
        "secondary_color": "#B45309",
        "preset": "amber_rust"
    }'::jsonb;

-- Update bestaande profielen die nog geen preferences hebben ingesteld
UPDATE public.profiles
SET preferences = '{
    "theme_mode": "system",
    "primary_color": "#EA580C",
    "secondary_color": "#B45309",
    "preset": "amber_rust"
}'::jsonb
WHERE preferences IS NULL;

-- 2. Trigger functie om gewijzigde preferences automatisch te spiegelen naar auth.users.raw_user_meta_data
-- Hierdoor hebben de centrale Hub en álle Spokes bij koude start direct toegang tot de voorkeuren via het sessie-JWT
CREATE OR REPLACE FUNCTION public.sync_profile_preferences_to_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.preferences IS NOT NULL) OR 
       (TG_OP = 'UPDATE' AND NEW.preferences IS DISTINCT FROM OLD.preferences) THEN
        UPDATE auth.users
        SET raw_user_meta_data = jsonb_set(
            COALESCE(raw_user_meta_data, '{}'::jsonb),
            '{preferences}',
            NEW.preferences,
            true
        )
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_profile_preferences ON public.profiles;
CREATE TRIGGER trigger_sync_profile_preferences
AFTER INSERT OR UPDATE OF preferences ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_preferences_to_auth();

-- Eenmalige backfill: sync bestaande voorkeuren direct naar auth.users
UPDATE auth.users u
SET raw_user_meta_data = jsonb_set(
    COALESCE(u.raw_user_meta_data, '{}'::jsonb),
    '{preferences}',
    p.preferences,
    true
)
FROM public.profiles p
WHERE p.id = u.id AND p.preferences IS NOT NULL;

-- 3. RPC functie voor het veilig updaten van voorkeuren door de ingelogde gebruiker
CREATE OR REPLACE FUNCTION public.update_user_preferences(new_prefs JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_updated_prefs JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Niet geautoriseerd: log in om voorkeuren aan te passen.';
    END IF;

    UPDATE public.profiles
    SET preferences = new_prefs
    WHERE id = v_user_id
    RETURNING preferences INTO v_updated_prefs;

    RETURN v_updated_prefs;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_preferences(JSONB) TO authenticated;
