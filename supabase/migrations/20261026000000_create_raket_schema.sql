-- ==============================================================================
-- Schema: app_raket (SchrobbeDock Tennis Spoke App)
-- Winterseizoen Tennisrotatie, Opstelling & Dynamische Kostenverdeling
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS app_raket;

-- 1. Seasons Tabel
CREATE TABLE IF NOT EXISTS app_raket.seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    total_court_fee NUMERIC(10,2) NOT NULL DEFAULT 1200.00,
    match_day_of_week INT NOT NULL DEFAULT 3, -- 3 = Woensdag
    match_start_time TIME NOT NULL DEFAULT '18:00',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Season Players Tabel
-- De 3 vaste spelers die voor de baan betalen hebben is_captain = true
CREATE TABLE IF NOT EXISTS app_raket.season_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID NOT NULL REFERENCES app_raket.seasons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('main_player', 'reserve')),
    is_captain BOOLEAN NOT NULL DEFAULT false,
    rotation_points INT NOT NULL DEFAULT 0,
    matches_played INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_season_user UNIQUE(season_id, user_id)
);

-- 3. Matches Tabel
CREATE TABLE IF NOT EXISTS app_raket.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID NOT NULL REFERENCES app_raket.seasons(id) ON DELETE CASCADE,
    match_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'uitvraag_gestart' CHECK (
        status IN (
            'uitvraag_gestart',
            'herinnering_reserves_verzonden',
            'opstelling_in_behandeling',
            'opstelling_definitief',
            'fallback_actief',
            'definitief_geblokkeerd',
            'afgerond',
            'geannuleerd'
        )
    ),
    match_type TEXT NOT NULL DEFAULT 'dubbelspel' CHECK (
        match_type IN ('dubbelspel', 'driespel', 'enkelspel', 'geen_wedstrijd')
    ),
    captains_choice_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Match Registrations Tabel
CREATE TABLE IF NOT EXISTS app_raket.match_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES app_raket.matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'available' CHECK (
        status IN ('available', 'declined', 'confirmed', 'selected_as_sub')
    ),
    is_captain_choice BOOLEAN NOT NULL DEFAULT false,
    responded_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_match_user UNIQUE(match_id, user_id)
);

-- Indexes voor performance
CREATE INDEX IF NOT EXISTS idx_season_players_season_user ON app_raket.season_players(season_id, user_id);
CREATE INDEX IF NOT EXISTS idx_matches_season_date ON app_raket.matches(season_id, match_date);
CREATE INDEX IF NOT EXISTS idx_match_registrations_match_user ON app_raket.match_registrations(match_id, user_id);

-- ==============================================================================
-- Row Level Security (RLS) & Helper Functies
-- ==============================================================================

-- Helper functie: controleert of een user een actieve licentie heeft voor raket
CREATE OR REPLACE FUNCTION app_raket.has_raket_license()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.licenses
        WHERE app_id = 'raket'
          AND user_id = auth.uid()
          AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper functie: controleert of de huidige user captain is in het seizoen
CREATE OR REPLACE FUNCTION app_raket.is_captain(p_season_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM app_raket.season_players
        WHERE season_id = p_season_id
          AND user_id = auth.uid()
          AND is_captain = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Inschakelen
ALTER TABLE app_raket.seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_raket.season_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_raket.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_raket.match_registrations ENABLE ROW LEVEL SECURITY;

-- Policies Seasons
CREATE POLICY "Leden met licentie kunnen seizoenen inzien"
    ON app_raket.seasons FOR SELECT
    USING (app_raket.has_raket_license());

CREATE POLICY "Captains kunnen seizoenen beheren"
    ON app_raket.seasons FOR ALL
    USING (app_raket.is_captain(id));

-- Policies Season Players
CREATE POLICY "Leden met licentie kunnen spelers inzien"
    ON app_raket.season_players FOR SELECT
    USING (app_raket.has_raket_license());

CREATE POLICY "Captains kunnen seizoensspelers beheren"
    ON app_raket.season_players FOR ALL
    USING (app_raket.is_captain(season_id));

-- Policies Matches
CREATE POLICY "Leden met licentie kunnen wedstrijden inzien"
    ON app_raket.matches FOR SELECT
    USING (app_raket.has_raket_license());

CREATE POLICY "Captains kunnen wedstrijden beheren"
    ON app_raket.matches FOR ALL
    USING (app_raket.is_captain(season_id));

-- Policies Match Registrations
CREATE POLICY "Leden met licentie kunnen registraties inzien"
    ON app_raket.match_registrations FOR SELECT
    USING (app_raket.has_raket_license());

CREATE POLICY "Spelers kunnen hun eigen registratie aanmaken of wijzigen"
    ON app_raket.match_registrations FOR INSERT
    WITH CHECK (auth.uid() = user_id AND app_raket.has_raket_license());

CREATE POLICY "Spelers kunnen hun eigen registratie updaten"
    ON app_raket.match_registrations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Captains kunnen alle match registraties beheren"
    ON app_raket.match_registrations FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM app_raket.matches m
            WHERE m.id = match_registrations.match_id
              AND app_raket.is_captain(m.season_id)
        )
    );

-- ==============================================================================
-- Rotatieranglijst Helper Functie (Optie A met Rotatiepunten)
-- ==============================================================================
CREATE OR REPLACE FUNCTION app_raket.get_rotation_ranking(p_season_id UUID, p_match_id UUID)
RETURNS TABLE (
    user_id UUID,
    role TEXT,
    is_captain BOOLEAN,
    matches_played INT,
    rotation_points INT,
    registration_status TEXT,
    responded_at TIMESTAMPTZ,
    rank BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sp.user_id,
        sp.role,
        sp.is_captain,
        sp.matches_played,
        sp.rotation_points,
        COALESCE(mr.status, 'none') as registration_status,
        mr.responded_at,
        ROW_NUMBER() OVER (
            ORDER BY 
                sp.matches_played ASC,
                sp.rotation_points DESC,
                mr.responded_at ASC NULLS LAST
        ) as rank
    FROM app_raket.season_players sp
    LEFT JOIN app_raket.match_registrations mr 
        ON mr.user_id = sp.user_id AND mr.match_id = p_match_id
    WHERE sp.season_id = p_season_id
      AND sp.role = 'reserve'
      AND mr.status = 'available';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
