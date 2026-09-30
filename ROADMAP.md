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
  - Zero-flash startup & persistentie gerealiseerd met synchrone SharedPreferences preload en live `localStorage` scanner in [index.html](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/web/index.html).
  - 100% testdekking en lint-vrij: unit tests in [theme_preferences_test.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/test/theme_preferences_test.dart) en `flutter analyze` geslaagd.
  - **Testscenario Voortgang**: Test 1 t/m 9 zijn succesvol afgerond en geverifieerd (inclusief mobiele navbar index-reset en async lifecycle).
  - **Huidige Taak / Focus**: Implementatie van **Feature 3 (Exclusief RobHub Parodiethema met invite-configuratie & zero-leak autorisatie)** alvorens te mergen naar `main`.
- **Git Workflow**: Werkzaamheden staan lokaal vastgelegd op feature branch `feat/theme-personalization-layout`. **Nog NIET gemerged naar `main`** totdat Feature 3 (RobHub) volledig is geïmplementeerd en geverifieerd.

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

### 3. Exclusief / Beperkt Toegankelijk Thema ("RobHub" Parodie Thema) (Voltooid ✅)
- **Status**: Volledig geïmplementeerd en gevalideerd met zero-leak beveiliging, vergrendelde dark mode, migratie `20260930213000_robhub_exclusive_theme.sql` en geautomatiseerde account-inrichting via `handle_new_user()` en `claim_invitation()`.
- **Doel**:
  - Een discreet en exclusief parodiethema ("RobHub") geïnspireerd op het bekende kleurenpalet en de typografie (puur zwart/diepzwart achtergrond, kenmerkend fel geeloranje `#FFA31A`, wit, en vette afgeronde typografie).
  - De app-balk en dashboardbranding transformeren voor gebruikers met dit thema van "SchrobbeDock Hub" naar de herkenbare **RobHub** badge (`Rob` in wit, `Hub` in zwarte letters binnen een fel geeloranje afgerond vlak).
- **Kindvriendelijk & Zero-Leak Beveiliging**:
  - Dit thema mag **strikt uitsluitend** zichtbaar zijn en geselecteerd kunnen worden door een select clubje gebruikers dat hiervoor expliciet door de beheerder is geautoriseerd.
  - Voor alle overige accounts (standaard gebruikers en kinderen) bestaat dit thema nergens in de themakeuzelijst of in de UI.
- **Architectuur & Impact (Hub & Spoke)**:
  - **Database (Supabase)**:
    - Toegangsflag toevoegen aan `public.profiles` (`can_access_robhub BOOLEAN NOT NULL DEFAULT false`).
    - Kolommen toevoegen aan `public.invitations`: `can_access_robhub BOOLEAN NOT NULL DEFAULT false` en `initial_theme_template TEXT DEFAULT 'warm_amber'`.
    - In `claim_invitation()` RPC: bij het claimen van de code worden de RobHub-toegangsrechten en het gekozen startthema direct overgenomen naar het profiel en de `preferences` van de gebruiker.
    - Alleen Platform Admins mogen deze vlag toekennen of intrekken via:
      1. Een toggle & start-thema dropdown bij het genereren van een nieuwe uitnodiging (`/admin/invites`).
      2. Een schakelaar in het Gebruikersoverzicht (`/admin/invites` -> tab Gebruikers) voor bestaande accounts.
  - **Frontend (Flutter)**:
    - In `create_invite_dialog.dart`: selectievakje *"Toegang tot RobHub thema toestaan"* en dropdown *"Standaard Startthema"* (bijv. Warm Amber, Ocean Deep, RobHub indien toegestaan).
    - In `theme_customizer_dialog.dart`: het RobHub-sjabloon wordt enkel gerenderd als de profiel-vlag actief is voor de ingelogde gebruiker.
    - In `dashboard_screen.dart` / AppBar: dynamische header-widget die bij actief RobHub-thema de kenmerkende logo-badge toont (`Rob` wit, `Hub` zwart op `#FFA31A`).

### 4. Documentatie: Repository README & Beheerdershandleiding
- **README.md (Developer Onboarding)**:
  - Overzicht van de Hub & Spoke ecosysteem architectuur.
  - Lokale installatie- en opstartinstructies (Supabase CLI, Flutter, migraties draaien, seed data).
  - CI/CD overzicht (Supabase DB pushes & Web hosting deploy).
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



