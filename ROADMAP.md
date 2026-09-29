# SchrobbeDock - Project Status & Backlog

## Status Huidige Sessie
- **GitHub Actions**: `production.yml` geactiveerd met automatische `push` trigger op `main` voor `supabase/**` (en `workflow_dispatch`), geüpgraded naar `actions/checkout@v4`.
- **MFA Recovery & Hybride Authenticatie**: 
  - Admin 2FA Reset functionaliteit ([20260923223000_admin_mfa_reset.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260923223000_admin_mfa_reset.sql)) en beheertab in de Hub.
  - Hybride MFA in [router.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/router.dart): Google Trust voor standaard accounts (geen dubbele 2FA), Zero-Trust voor e-mail/wachtwoord en alle `/admin/*` routes.
  - Automatische opschoning van onbevestigde factoren ([20260923233000_cleanup_unverified_mfa.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260923233000_cleanup_unverified_mfa.sql)) om duplicate errors bij verlaten van enrollment te voorkomen.
  - Automatische 6-cijferige verificatie (directe check zodra 6 cijfers ingevuld zijn, zonder op de knop te hoeven drukken) in [mfa_verify_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/mfa_verify_screen.dart) en [mfa_enroll_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/mfa_enroll_screen.dart).
- **Uitnodigingen & Registratie UX**:
  - `recipient_name` veld toegevoegd aan `public.invitations` ([20260923230000_invitation_recipient_name.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260923230000_invitation_recipient_name.sql)) voor administratieve tracking van wie welke code ontvangt.
  - Automatisch kant-en-klaar uitnodigingsbericht met directe registratielink en uitnodigingscode gegenereerd bij het aanmaken, plus kopieerknoppen op de uitnodigingskaarten in de Hub.
  - Telefoonnummervalidatie toegevoegd aan het registratieformulier in [register_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/register_screen.dart).
- **CI/CD Web Deployment (one.com)**:
  - `.htaccess` toegevoegd in [hub_app/web/.htaccess](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/web/.htaccess) voor Apache URL-rewriting (voorkomt 404-errors bij SPA routing).
  - GitHub Actions workflow [.github/workflows/deploy_web.yml](file:///c:/Users/robbe/Documents/SchrobbeDock/.github/workflows/deploy_web.yml) met `wlixcc/SFTP-Deploy-Action@v1.2.6` geconfigureerd, succesvol getest en live gedeployd naar het one.com SFTP cluster (`ssh.c49x8am1a.service.one`).
- **Google OAuth Registratie & Invite Claim Flow**:
  - Migratie [20260924234500_google_oauth_invite_claim.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260924234500_google_oauth_invite_claim.sql) met bijgewerkte `handle_new_user()` trigger (OAuth profielondersteuning en naamparsing) en atomic `claim_invitation(target_code)` RPC met row-level locking.
  - In [register_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/register_screen.dart) directe *"Aanmelden & Registreren met Google"* knop toegevoegd met code-caching via `SharedPreferences`.
  - In [dashboard_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/dashboard_screen.dart) automatische inwisseling na login, Zero-Trust fallback claim card voor accounts zonder licenties, en een universele inwisselknop in de navigatiebalk.
- **Ecosysteem-brede Thema & Layout Personalisatie (Warm Amber & Slate)**:
  - Supabase migratie [20260929213000_user_theme_preferences.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260929213000_user_theme_preferences.sql) met `preferences` JSONB kolom, auto-sync PostgreSQL trigger naar `auth.users.raw_user_meta_data` (zero-latency claim in sessie JWT), en veilige `update_user_preferences` RPC.
  - Modulaire themamodule in [hub_app/lib/theme/schrobbedock_theme.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/theme/schrobbedock_theme.dart) met Deep Slate dark mode (`#0F172A`, `#1E293B`, `#334155`), gecureerde templates (Warm Amber & Roest [default], Ocean Deep, Emerald Forest, Midnight Violet, Slate Monolith) en dynamic `ThemeData` generator.
  - Riverpod `themePreferencesProvider` (Notifier) met automatische DB-sync en offline caching in `SharedPreferences`.
  - Vernieuwde Hub-layout in [dashboard_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/dashboard_screen.dart):
    - Top `AppBar` met SchrobbeDock branding en ronde User Avatar met dropdown (Profiel, Uiterlijk & Thema, Code Inwisselen, Admin Beheer, Uitloggen).
    - Responsive `BottomNavigationBar` voor mobiele weergaves (< 650px).
    - Simpele, klikbare App Cards zonder ruis, met een discreet info-knopje `(i)` rechtsboven voor licentie- en appdetails in een nette popup.
  - [theme_customizer_dialog.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/widgets/theme_customizer_dialog.dart): interactieve dialog met modus-switch (Systeem/Licht/Donker), template presets en custom color picker met live preview en hex-code invoer.
  - 100% testdekking en lint-vrij: unit tests in [theme_preferences_test.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/test/theme_preferences_test.dart) en `flutter analyze` geslaagd.
- **Git Workflow**: Werkzaamheden uitgevoerd op feature branch `feat/theme-personalization-layout` (lokaal gecommit, niet gepusht naar remote).

---

## Eerstvolgende Punten

### 1. Nieuwe Feature: Centraal Probleem- & Feedbackmeldsysteem
- **Doel**: Gebruikers moeten vanuit **elke app** (en de centrale Hub) laagdrempelig een probleem, bug of suggestie kunnen melden.
- **Architectuur (Hub & Spoke)**:
  - **Database (Supabase)**:
    - Centrale tabel `feedback_reports` (gekoppeld aan `app_id`, `user_id`, categorie, omschrijving, device/platform metadata, screenshots).
    - **RLS**: Gebruikers mogen enkel eigen reports inserten; alleen Platform Admins mogen alles inzien en status updaten (`open`, `in_investigation`, `resolved`).
  - **Frontend / Clients**:
    - Universele/modulaire Flutter feedback modal/widget die eenvoudig in elke app (Spoke) geïmporteerd kan worden.
    - Beheer-/overzichtsscherm in de centrale Hub voor admins.

### 2. Account- & Gebruikersbeheer: Verwijderen door Admin & Self-Service Profiel (AVG/GDPR)
- **Doel**: 
  1. Platform Admins kunnen vanuit de Hub gebruikers deactiveren of definitief verwijderen uit het ecosysteem.
  2. Gebruikers kunnen via een profieloverzicht (`/profile`) hun opgeslagen accountgegevens raadplegen en zelfstandig hun account definitief laten verwijderen (Right to be Forgotten).
- **Gevolgen voor Google OAuth bij Verwijdering (Architectuuranalyse)**:
  - **In Supabase**: Bij het verwijderen van een record in `auth.users` worden via PostgreSQL foreign keys met `ON DELETE CASCADE` automatisch het record in `public.profiles`, alle `public.user_licenses`, en de gekoppelde `auth.identities` (de Google OAuth link) definitief gewist. Lopende JWT-sessies worden per direct ongeldig.
  - **Bij Google zelf**: Het Google-account van de gebruiker blijft bij Google ongewijzigd bestaan.
  - **Wat gebeurt er als de verwijderde gebruiker later opnieuw op "Inloggen met Google" klikt?**
    - Supabase ziet hem als een **volledig nieuwe bezoeker** (de oude `auth.users.id` bestaat immers niet meer).
    - Er wordt een nieuw, leeg profiel aangemaakt.
    - Door onze **Zero-Trust architectuur** krijgt het account **0 licenties**. De gebruiker landt direct op de *"Geen Actieve Licenties Gevonden"* fallback kaart en heeft GEEN toegang tot Hub Beheer of Spokes, tenzij een beheerder hem opnieuw een geldige uitnodigingscode verstrekt.
- **Architectuur (Hub & Spoke)**:
  - **Database (Supabase)**:
    - RPC `delete_user_by_admin(target_user_id UUID)`: Uitsluitend uitvoerbaar door `super_admin` van `hub_admin`. Verwijdert de gebruiker via `supabase_auth_admin` cascade.
    - RPC `delete_own_account()`: Uitvoerbaar door de ingelogde gebruiker zelf (`auth.uid() = id`), met optionele soft-delete audit tracking.
  - **Frontend / Clients**:
    - **Admin Hub (`/admin/invites` tab Gebruikers)**: Rode actieknop *"Gebruiker Verwijderen"* met bevestigingsdialoog ("Typ de naam over om te bevestigen").
    - **Self-Service Profiel (`/profile`)**: Overzicht van opgeslagen gegevens (naam, e-mail, telefoon, adres, gekoppelde login provider zoals Google), plus een gevarenzone met *"Account Definitief Verwijderen"*.

### 4. Documentatie: Repository README & Beheerdershandleiding
- **README.md (Developer Onboarding)**:
  - Overzicht van de Hub & Spoke ecosysteem architectuur.
  - Lokale installatie- en opstartinstructies (Supabase CLI, Flutter, migraties draaien, seed data).
  - CI/CD overzicht (Supabase DB pushes & Web hosting deploy).
- **Handleiding / Gebruikersgids (`docs/HANDLEIDING.md`)**:
  - Eindgebruikers: Registratie via uitnodigingscode, inloggen (e-mail vs Google), instellen van TOTP in Authenticator app.
  - Platform Admins: Genereren van uitnodigingen gekoppeld aan applicaties en tiers, tracking van genodigden, en de herstelprocedure bij verloren 2FA-sleutels (Admin 2FA Reset).

