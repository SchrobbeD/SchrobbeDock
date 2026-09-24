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
  - GitHub Actions workflow [.github/workflows/deploy_web.yml](file:///c:/Users/robbe/Documents/SchrobbeDock/.github/workflows/deploy_web.yml) geconfigureerd voor automatische Flutter Web release build en SFTP deployment.
- **Git Status**: Alle wijzigingen succesvol gecommit en gepusht naar `main`. Werkboom is schoon.

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

### 2. Toekomstige Feature: Google OAuth Registratie via Uitnodigingscode
- **Probleem**: Momenteel ondersteunt het registratiescherm (`/register`) uitsluitend e-mail + wachtwoord. Als een nieuwe gebruiker via een uitnodigingslink binnenkomt en kiest voor Google, ontbreekt de koppeling tussen de invite code en het nieuwe OAuth-account.
- **Doel**: Een uitgenodigde gebruiker kan op `/register` kiezen tussen *"Registreren met Wachtwoord"* óf *"Aanmelden met Google"*, waarbij de licenties uit de uitnodiging direct en automatisch worden toegekend aan het Google-profiel.
- **Architectuur / Oplossingsrichting**:
  - *Optie A (OAuth Redirect State)*: De `invite_code` behouden in de OAuth handshake via redirect parameters en in de `handle_new_user()` trigger verwerken.
  - *Optie B (Onboarding Claim Scherm)*: Indien een nieuw Google-account inlogt zonder licenties, leidt de Hub hem direct naar een tussenscherm *"Koppel je uitnodigingscode"* alvorens het dashboard te tonen.

### 3. CI/CD: Automatische Flutter Web Deployment naar one.com via SFTP
- **Doel**: Bij elke release of push naar `main` bouwt GitHub Actions de Flutter Web app (`flutter build web --release`) en uploadt de statische distributie via SFTP naar de one.com server (bijv. hoofddomein of `hub.jouwdomein.com`).
- **Benodigdheden**:
  - GitHub Secrets voor SFTP (`ONE_SFTP_SERVER`, `ONE_SFTP_USER`, `ONE_SFTP_PASSWORD`, `ONE_REMOTE_PATH`).
  - `.htaccess` bestand in de web root voor correcte Apache URL-rewriting (voorkomt 404-errors bij direct refreshen van client-side routes zoals `/dashboard`).
  - GitHub Actions workflowbestand `.github/workflows/deploy_web.yml`.

### 4. Documentatie: Repository README & Beheerdershandleiding
- **README.md (Developer Onboarding)**:
  - Overzicht van de Hub & Spoke ecosysteem architectuur.
  - Lokale installatie- en opstartinstructies (Supabase CLI, Flutter, migraties draaien, seed data).
  - CI/CD overzicht (Supabase DB pushes & Web hosting deploy).
- **Handleiding / Gebruikersgids (`docs/HANDLEIDING.md`)**:
  - Eindgebruikers: Registratie via uitnodigingscode, inloggen (e-mail vs Google), instellen van TOTP in Authenticator app.
  - Platform Admins: Genereren van uitnodigingen gekoppeld aan applicaties en tiers, tracking van genodigden, en de herstelprocedure bij verloren 2FA-sleutels (Admin 2FA Reset).

### 5. Toekomstige Feature: Ecosysteem-brede Thema & Layout Personalisatie (Oranje Accentkleur in Hub & Spokes)
- **Doel**: Gebruikers stellen hun favoriete layout en kleurenpalet (met als eerste focus een warm/energiek **Oranje palet**) in via de Hub, waarna **álle Spoke applicaties** deze voorkeur automatisch en consistent per gebruiker overnemen.
- **Architectuur (Hub & Spoke Distributie)**:
  - **Centrale Supabase Backend**:
    - `public.profiles`: kolom `preferences jsonb DEFAULT '{"theme_mode": "system", "accent_color": "orange", "density": "comfortable"}'::jsonb`.
    - **RLS**: Gebruikers kunnen uitsluitend hun eigen `preferences` inzien en bijwerken (`auth.uid() = id`).
    - **Zero-Latency Sync Trigger**: Een PostgreSQL trigger spiegelt gewijzigde `preferences` direct door naar `auth.users.raw_user_meta_data`. Hierdoor beschikken zowel de Hub als alle Spokes direct bij koude start over de kleurvoorkeur in het lokale sessie-JWT (`supabase.auth.currentUser.userMetadata`), zónder extra database round-trips of UI-knipperingen (FOUC).
  - **Spoke Applicatie Integratie**:
    - **Shared Design Token Library / Contract**: Een gedeelde package of model (`schrobbedock_theme`) waarin het kleurensysteem (licht/donker, oranje tinten `#F97316` / `#EA580C`, layout margins) centraal is gedefinieerd.
    - Elke Spoke app initialiseert zijn `MaterialApp` / `ThemeData` via de Riverpod provider die direct luistert naar de `userMetadata['preferences']` van de centrale sessie.
    - Wijzigt een gebruiker zijn thema in de Hub of Spoke? Realtime Supabase broadcast of sessie-update synchroniseert dit live naar alle openstaande applicaties.
  - **Licentie & Toegang**:
    - Beschikbaar voor **elke actieve gebruiker** over alle geautoriseerde Spokes heen.
    - Optionele uitbreiding: B2B/Enterprise organisaties kunnen desgewenst een verplicht bedrijfs-accent (branding) afdwingen via organisatie-licenties.
  - **Frontend Implementatie (Flutter Hub & Spokes)**:
    - Riverpod `themeModeProvider` en `accentColorProvider`.
    - Live theme switcher in het gebruikersprofiel met oranje preset (`Colors.deepOrange` / hex tokens) en density toggle.


