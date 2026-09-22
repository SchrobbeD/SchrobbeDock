-- ==========================================
-- 1. CORE TABELLEN (HUB)
-- ==========================================

CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.apps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE public.user_licenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    app_id UUID REFERENCES public.apps(id) ON DELETE CASCADE NOT NULL,
    tier TEXT DEFAULT 'basic',
    role TEXT DEFAULT 'user',
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, app_id)
);

-- ==========================================
-- 2. ROW LEVEL SECURITY (RLS)
-- ==========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_licenses ENABLE ROW LEVEL SECURITY;

-- Profielen: Alleen de eigenaar kan zijn profiel lezen/updaten
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Apps: Iedere ingelogde gebruiker mag actieve apps zien
CREATE POLICY "Authenticated users view active apps" ON public.apps FOR SELECT USING (auth.role() = 'authenticated' AND is_active = TRUE);

-- Licenties: Gebruikers zien uitsluitend hun eigen licenties
CREATE POLICY "Users view own licenses" ON public.user_licenses FOR SELECT USING (auth.uid() = user_id);

-- ==========================================
-- 3. AUTOMATISERING (TRIGGERS)
-- ==========================================

-- Maak automatisch een profiel aan in public.profiles wanneer een user registreert
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- 4. CENTRALE LICENTIE CHECK (VOOR SPOKE APPS)
-- ==========================================

-- Helper functie die straks door de RLS van spoke-applicaties wordt aangeroepen
CREATE OR REPLACE FUNCTION public.has_app_access(target_app_slug TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_licenses ul
        JOIN apps a ON a.id = ul.app_id
        WHERE ul.user_id = auth.uid()
          AND a.slug = target_app_slug
          AND a.is_active = TRUE
          AND (ul.valid_until IS NULL OR ul.valid_until > NOW())
    );
$$;