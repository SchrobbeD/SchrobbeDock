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
  - **Ecosysteem-brede Thema & Layout Personalisatie (Warm Amber & Slate + RobHub)**:
  - Volledig afgerond, gevalideerd met 10/10 tests, database reset en gemerged naar `main`.
  - Inclusief exclusief parodiethema RobHub met vergrendelde dark mode, zero-leak autorisatie in uitnodigingen en profielen.

---

## Eerstvolgende Punten

### 1. Centraal Probleem- & Feedbackmeldsysteem (`packages/schrobbedock_feedback`) [AFGEROND - v1.0.0]
- **Doel**: Gebruikers moeten vanuit **elke Spoke app** (en de centrale Hub) laagdrempelig een probleem, bug of suggestie kunnen melden. Meldingen worden automatisch doorgestuurd als GitHub Issue naar de specifieke repository van die app.
- **Architectuur & Modulaire Spoke Integratie (Hub & Spoke)**:
  - **Shared Flutter Package (`packages/schrobbedock_feedback`)**:
    - Een opzichzelfstaande package in de root die Spoke apps als Git dependency importeren in `pubspec.yaml`:
      ```yaml
      schrobbedock_feedback:
        git:
          url: https://github.com/SchrobbeD/SchrobbeDock.git
          path: packages/schrobbedock_feedback
          ref: main
      ```
    - **Ultra-snelle integratie in Spoke apps (1 regel code)**:
      `SchrobbeDockFeedback.show(context, appSlug: 'dock_planner');`
    - **Optionele power-features**:
      - `SchrobbeDockFeedbackOverlay`: Subtiele zwevende hulp/feedback-knop onderin het scherm.
      - Global Error Boundary / Crash Catcher: Vangt ongepaste app-fouten op en biedt de gebruiker aan om de crash direct met stacktrace te rapporteren.
    - Bundelt dialoogvenster, screenshot preview/upload, metadata-collector (OS, browser, app-versie, schermresolutie).
  - **Database & Storage (Supabase)**:
    - Uitbreiding `public.apps` met `github_repo_owner` en `github_repo_name` voor dynamische multi-repo routing.
    - Centrale tabel `public.feedback_reports` (RLS: gebruikers mogen enkel eigen rapporten inserten; Platform Admins hebben volledige lees/update-toegang).
    - Supabase Storage bucket `feedback_attachments` voor screenshots.
  - **GitHub Synchronisatie**:
    - Supabase Edge Functions met GitHub REST API integratie (`submit-feedback` en `sync-feedback-status`).
    - Automatische aanmaak van Markdown issues met inline screenshots, metadata en badges via de server-side GitHub PAT (`GITHUB_FEEDBACK_TOKEN`).
    - **Volledige Tweeweg Synchronisatie (Hub ↔ GitHub)**:
      - Wijziging van status in de Hub (`in_progress`, `resolved`, `open`) past het GitHub Issue direct aan (open/close, label `in-progress` toevoegen/verwijderen) en plaatst een auditcomment.
      - Supabase Edge Function `github-webhook` met HMAC SHA256 webhook payload validatie (`GITHUB_WEBHOOK_SECRET`).
      - Sluiten of heropenen van issues op GitHub (manueel of via git commit messages zoals `closes #12`) synchroniseert direct real-time terug naar `public.feedback_reports` in Supabase en de Hub UI.
  - **Hub Beheer**:
    - Centraal scherm `/admin/feedback` voor platformbeheerders met filterbalk, diagnostische accordeon (omgeving & crash stacktrace), screenshot-vergroting en tweeweg statusbeheer.
    - Snelkoppelingen in Dashboard AppBar, User Action Menu en Admin Invites beheer.
  - **Toekomstige Uitbreiding: Tweeweg Melding- & Issue-Verwijdering (Hard Delete & AVG/GDPR Opschoning)**:
    - **Nut & Noodzaak**:
      - *Normaal gebruik*: Issues worden normaal gesloten (`resolved`/`closed`) om historische context en audit trails te behouden.
      - *Wanneer essentieel*:
        1. **AVG / GDPR & Datalekken**: Wanneer een gebruiker per ongeluk wachtwoorden, API-sleutels of gevoelige persoonsgegevens meestuurt in een screenshot of beschrijving. Enkel sluiten laat de gevoelige data in GitHub history staan; een **hard delete** is juridisch en qua beveiliging verplicht.
        2. **Spam & Testdata**: Snelle opruiming van testrapporten of corrupte/dubbele inzendingen.
    - **Architectuur (Tweeweg)**:
      - **Hub ➔ GitHub**: Admin klikt op *"Melding Verwijderen"* in `/admin/feedback` ➔ screenshot in Supabase storage bucket `feedback_attachments` wordt gewist ➔ Supabase Edge Function roept `DELETE /repos/{owner}/{repo}/issues/{issue_number}` aan op GitHub (vereist GitHub PAT met admin rechten op de repo) ➔ record in `feedback_reports` wordt verwijderd (hard delete of geanonimiseerde tombstone).
      - **GitHub ➔ Hub**: Beheerder verwijdert issue via GitHub UI ➔ GitHub stuurt `issues.deleted` webhook event ➔ `github-webhook` Edge Function verwijdert automatisch het gekoppelde record in `public.feedback_reports` en de opgeslagen screenshot in storage. Geen zwevende "zombie" records in het Hub dashboard.
  - **Toekomstige Uitbreiding: Meerdere Foto's & Handmatige Bijlagen Toevoegen**:
    - **Huidige situatie**: De dialoog maakt automatisch 1 screenshot van de actieve Flutter canvas/route via de render tree.
    - **Nieuwe functionaliteit**:
      - Gebruikers kunnen zelf handmatig extra foto's/bestanden uploaden (via file picker, drag & drop of plakken via klembord `Ctrl+V`).
      - Ondersteuning voor meerdere bijlagen (bijv. tot 3 à 5 afbeeldingen per melding) met een preview-rij/thumbnails en individuele verwijderknoppen.
      - **Database & Storage**: `screenshot_url` kolom in `public.feedback_reports` uitbreiden of aanvullen met `screenshot_urls TEXT[]` (of `JSONB` array met metadata).
      - **GitHub Issue Formatter**: Edge Function embedt alle bijlagen netjes onder elkaar of in een responsive Markdown tabel/galerij in het GitHub issue.
      - **Hub Beheer (`/admin/feedback`)**: Fotogalerij/lightbox om eenvoudig door alle bijgevoegde schermafbeeldingen van de melding te bladeren.

### 2. Gedeelde Design System & Theme Package voor Spoke Apps (`packages/schrobbedock_theme`) [AFGEROND - v1.0.0]
- **Doel**: Spoke apps kunnen net als de feedback module via 1 Git dependency exact hetzelfde thema- en stylingsysteem importeren.
- **Opgeleverde Architectuur (Optie B - Framework-agnostisch + Riverpod bridge)**:
  - **Standalone Package**: In `packages/schrobbedock_theme` met eigen `pubspec.yaml` (v1.0.0).
  - **Core Controller**: Gebouwd op native Flutter `ChangeNotifier` (`SchrobbeDockThemeController`) en `SchrobbeDockThemeScope`, 0 verplichte externe frameworks voor Spoke apps.
  - **Riverpod Bridge / Adapter**: `schrobbedock_theme_riverpod.dart` met `themePreferencesProvider`, `canAccessRobHubProvider` en `sharedPreferencesProvider`.
  - **Thema Dialog**: Volledige interactieve `ThemeCustomizerDialog` en `SchrobbeDockTheme.showCustomizer(context)`.
  - **RobHub & Autorisatiesync**: Presets, custom kleuren, pitch-black RobHub isolatie, auto-fallback naar Warm Amber bij verlies van rechten.
  - **Supabase Sync**: Synchronisatie met `raw_user_meta_data.preferences` en RPC `update_user_preferences`.
  - **Hub Integratie**: `hub_app` ontkoppeld en direct gekoppeld via `path: ../packages/schrobbedock_theme`. Alle 12 package tests en 10 Hub tests geslaagd met 0 analyzer waarschuwingen.

### 3. Account- & Gebruikersbeheer: Verwijderen door Admin & Self-Service Profiel (AVG/GDPR)
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

### 4. Documentatie: Repository README, Spoke Ontwikkelingsgids & Beheerdershandleiding
- **README.md (Repository Overview & Setup)**:
  - Overzicht van de Hub & Spoke ecosysteem architectuur.
  - Lokale installatie- en opstartinstructies (Supabase CLI, Flutter, migraties draaien, seed data).
  - CI/CD overzicht (Supabase DB pushes & Web hosting deploy).
- **Spoke App Ontwikkelingsgids (`docs/SPOKE_INTEGRATION_GUIDE.md`)**:
  - Complete gids: *Wat moet een Spoke app minimaal implementeren en hoe start je een nieuw Spoke project?*
  - **Single Sign-On & Sessie**: Supabase Auth integratie, token handling en sessie-uitwisseling met de Hub.
  - **Licentie- en toegangsvalidatie**: Hoe een Spoke controleert of de ingelogde gebruiker een actieve licentie heeft in `public.user_licenses` en RLS enforcement.
  - **Package Versiebeheer & Git Release Tags**: Hoe Spoke apps pinnen op specifieke package releases (bijv. `ref: theme-v1.0.0`) om breaking changes en ongewenste updates te voorkomen.
  - **Thema-integratie**: Implementatie van `packages/schrobbedock_theme` (auto-sync met voorkeuren en integratie van `ThemeCustomizerDialog`).
  - **Feedback-integratie**: Implementatie van `packages/schrobbedock_feedback` (1-regel bug- en suggestierapportage naar de bijbehorende GitHub repo).
- **Handleiding / Gebruikersgids (`docs/HANDLEIDING.md`)**:
  - Eindgebruikers: Registratie via uitnodigingscode, inloggen (e-mail vs Google), instellen van TOTP in Authenticator app.
  - Platform Admins: Genereren van uitnodigingen gekoppeld aan applicaties en tiers, tracking van genodigden, en de herstelprocedure bij verloren 2FA-sleutels (Admin 2FA Reset).

### 5. Multi-Factor Authenticatie (MFA) Uitbreidingen: SMS, E-mail & Passkeys (WebAuthn)
- **Doel**:
  - Naast de huidige authenticator-app (TOTP / RFC 6238) gebruikers de keuze bieden uit alternatieve en complementaire 2FA-methoden: SMS OTP, E-mail OTP en hardware/biometrische Passkeys (FIDO2 / WebAuthn).
- **Haalbaarheid & Architectuur (Supabase Auth & Flutter)**:
  - **1. SMS OTP (Phone MFA)**:
    - *Haalbaarheid*: Volledig ondersteund in Supabase Auth.
    - *Supabase Backend*: Vereist activering van de SMS provider (bijv. Twilio, MessageBird) in het Supabase Auth dashboard met API-sleutels.
    - *Aandachtspunt / Kosten*: Verzendkosten per SMS en rate limiting tegen SMS pumping/misbruik.
  - **2. E-mail OTP**:
    - *Haalbaarheid*: Supabase ondersteunt e-mail OTP codes (`verifyOtp` met `type: email`).
    - *Architectuur*: Als secundaire factor na wachtwoord/OAuth vereist dit een step-up flow of e-mail challenge binnen de sessieverificatie alvorens AAL2 geclaimd wordt.
  - **3. Passkeys (FIDO2 / WebAuthn)**:
    - *Haalbaarheid*: Zeer modern en veilig (TouchID, FaceID, Windows Hello, YubiKey).
    - *Frontend*: Flutter Web maakt gebruik van `window.navigator.credentials` (WebAuthn API); Flutter mobile/desktop gebruikt de Credential Manager API.
    - *Supabase Backend*: WebAuthn registratie gekoppeld aan de centrale identity en MFA assurance levels (`aal2`).
- **Impact op Hub & Spoke**:
  - Gecentraliseerd in de Hub: Gebruiker kan via `/profile` of `/mfa/enroll` de gewenste factor(en) registreren en beheren.
  - Hybride/Zero-Trust afdwinging: Het session-level token (`aal2`) blijft uniform voor alle aangesloten Spoke-apps, ongeacht welke factor gebruikt is.



