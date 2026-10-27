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
- **Spoke Scaffolding & Registratie van Raket**:
  - `scripts/create_spoke.ps1` geoptimaliseerd en uitgevoerd voor Spoke app **Raket** (`raket`).
  - Supabase database migratie [20261025224904_register_raket.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20261025224904_register_raket.sql) met dedicated schema `app_raket` en catalogusregistratie.
  - Initialisatie van de Raket repository op `https://github.com/SchrobbeD/Raket.git`.
- **Centrale Toegangsaanvragen (`public.license_requests`)**:
  - Supabase migratie [20261026011500_license_requests_and_access_workflow.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20261026011500_license_requests_and_access_workflow.sql) met RLS en atomic RPC functies `request_app_access` en `review_license_request`.
  - Nieuwe tab **"Toegangsaanvragen"** met live badge en filterbalk in [admin_invites_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/admin_invites_screen.dart).
- **Gedeeld Package `packages/schrobbedock_auth` (v1.0.0)**:
  - `LicenseGate` / `SchrobbeDockAuthGuard` voor automatische login checks en licentievalidatie.
  - `NoAccessView` met invite code inwisseling (`claim_invitation`) en toegangsaanvragen (`request_app_access`).
  - `LoginRequiredView` en `SchrobbeDockUserMenu` voor Spoke app AppBars.
- **Spoke-to-Hub Ecosysteem Alert Rule**:
  - Richtlijn vastgelegd in generator, Spoke integratiegids en agent rollen.

---

## Eerstvolgende Punten

### 0. Starten met Stap 5: Lokale Testomgeving & Functionele Tests (Raket & Hub) [PRIORITEIT - DIRECT BIJ START VOLGENDE SESSIE]
- **Doel**: De lokale ontwikkelstack activeren en end-to-end testen met de 8 seed users:
  1. **Docker Desktop & Supabase starten**:
     - Docker Desktop starten op Windows.
     - In `SchrobbeDock`: `npx supabase db reset` (bouwt alle migraties inclusief `app_raket` en seed data met 8 gebruikers op).
  2. **Raket Spoke starten & valideren**:
     - `flutter run -d emulator-5554` (verbindt nu automatisch via `http://10.0.2.2:54321` in debug mode).
     - **Happy Path Dubbelspel**: Inloggen met `user1@hub.local` t/m `user4@hub.local` (wachtwoord: `password123`) om de 4 baanslots te controleren.
     - **Unhappy Path**: Inloggen met `user7@hub.local` om `NoAccessView` en de "Toegang Aanvragen" flow te testen.
  3. **Admin Beoordeling in de Hub**:
     - In de Hub inloggen als `admin@hub.local` en de aanvraag van `user7` goedkeuren.

### 0.1. Mobile Responsiveness Fix in `schrobbedock_theme` (Customizer Dialog) [AFGEROND - v1.1.0]
- **Herkomst**: Overdrachtsbericht vanuit Spoke app **Raket** (getest op Android emulator 360-400dp viewport).
- **Probleem**: `SchrobbeDockTheme.showCustomizer(context)` veroorzaakte `RenderFlex` overflow errors op smartphones.
- **Geïmplementeerde Oplossingen in `packages/schrobbedock_theme` (v1.1.0)**:
  1. **Dialoog Form Factor**:
     - `ThemeCustomizerDialog.show(context)` en `SchrobbeDockTheme.showCustomizer(context)` openen op schermen < 600px (`MediaQuery.sizeOf(context).width < 600`) automatisch als een `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` met afgeronde bovenhoeken en drag handle. Op desktop/tablet blijft het een `Dialog`.
  2. **Weergavemodus SegmentedButton**:
     - `visualDensity: VisualDensity.compact` en compacte labels (`Donker` i.p.v. `Donker (Slate)` op mobiel) voorkomen rechterrand-overflows.
  3. **Responsive Secties & Wrap**:
     - *Mijn Opgeslagen Thema's* en *Colorpicker* headers omgezet van `Row` naar `Wrap`.
     - `ColorPicker` dynamisch begrensd via `LayoutBuilder` (clamped op `constraints.maxWidth` voor schermen < 360px).
     - Footer herstelknop voorzien van `Flexible` en compacte tekst.
     - ChoiceChips voorzien van compacte labels (`Primair` en `Secundair`).
  4. **Geautomatiseerde Testdekking**: Nieuwe unit- en widget tests in `test/theme_customizer_dialog_test.dart` (alle 14 package tests en 21 Hub tests geslaagd). Release tag `theme-v1.1.0` voorbereid.

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
  - **Tweeweg Melding- & Issue-Verwijdering (Zie Actiepunt 3)**:
    - Opgeschoven naar een prioritair ontwikkelpunt: volwaardige hard delete voor testdata-opschoning en AVG/GDPR in beide richtingen (Hub ↔ GitHub).
  - **Meerdere Foto's & Handmatige Bijlagen Toevoegen [AFGEROND - v1.1.0]**:
    - Gebruikers kunnen 0 tot 5 bijlagen meesturen. De automatische schermopname kan met 1 klik worden gewist.
    - Handmatige upload via `image_picker` geïntegreerd in `FeedbackDialog` met horizontale fotostrip, miniatuurweergaven, individuele verwijderknoppen en lightbox voorvertoning.
    - Volledige end-to-end verwerking in Supabase Storage (`feedback_attachments`), PostgreSQL (`attachment_urls TEXT[]`), Edge Function `submit-feedback` en responsive Markdown galerij in GitHub Issues.
  - **Live Productie Validatie & E2E Testen (Online Omgeving) [AFGEROND - 03-10-2026]**:
    - **Opgelost probleem**: Feedback inzendingen vielen live terug op de database fallback door een PostgreSQL permissiefout (`42501: permission denied for table apps`) doordat de `service_role` geen expliciete select-rechten had op `public.apps`.
    - **Doorvoerde fixes**:
      - Migratie `20261003231000_grant_service_role_permissions.sql` aangemaakt en uitgevoerd (`GRANT USAGE ON SCHEMA public... GRANT ALL ON ALL TABLES/SEQUENCES/ROUTINES TO service_role`).
      - CI/CD workflow `.github/workflows/production.yml` uitgebreid met automatische `supabase functions deploy`.
      - `.github/workflows/deploy_web.yml` uitgebreid met test en dependency management voor `schrobbedock_feedback`.
    - **Live Validatie**:
      - Edge Function `submit-feedback` succesvol live aangeroepen; issue #8 aangemaakt op GitHub met labels en metadata.
      - Edge Function `sync-feedback-status` live getest; statuswijzigingen (`in_progress`, `resolved`) synchroniseren met issue comments, labels en issue closure op GitHub.

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

### 3. Tweeweg Issue- & Feedbackverwijdering (Testdata & AVG/GDPR Opschoning) [AFGEROND]
- **Doel & Noodzaak**:
  - **Testdata & Spam Opschonen**: Tijdens ontwikkeling, acceptatietesten of door tests gegenereerde meldingen definitief kunnen verwijderen zonder sporen achter te laten.
  - **AVG / GDPR & Datalekken (Right to be Forgotten)**: Wanneer een gebruiker per ongeluk wachtwoorden, API-sleutels, persoonsgegevens of vertrouwelijke schermafbeeldingen meestuurt. Enkel sluiten van het issue laat de data in de GitHub geschiedenis en Supabase storage staan; een volledige **hard delete** in beide systemen is juridisch en qua beveiliging vereist.
- **Geïmplementeerde Architectuur & Tweeweg Werking (2 Richtingen)**:
  - **Richting 1: Hub ➔ GitHub (Verwijderen via Centraal Admin Dashboard)**:
    - **Frontend (`hub_app/lib/screens/admin_feedback_screen.dart`)**:
      - Prullenbak-actieknop per meldingenkaart met strikte waarschuwingsdialoog ("Typ 'VERWIJDER' om definitief te wissen").
      - Loading indicator tijdens verwerking en realtime foutafhandeling (bijv. bij ontbrekende GitHub admin-rechten).
    - **Backend & Edge Function (`delete-feedback`)**:
      - Nieuwe Edge Function aangeroepen met de Bearer JWT van de beheerder.
      - Valideert via Supabase Auth dat de beller de rol `super_admin` bezit (`public.has_role(auth.uid(), 'hub_admin', 'super_admin')`).
      - Roept GitHub REST API aan: `DELETE /repos/{owner}/{repo}/issues/{issue_number}` met de server-side `GITHUB_FEEDBACK_TOKEN` (Strict Sync: breekt af met duidelijke foutmelding als GitHub API weigert).
      - Verwijdert alle bijbehorende afbeeldingsbestanden uit Supabase Storage bucket `feedback_attachments`.
      - Verwijdert het database record definitief uit `public.feedback_reports`.
  - **Richting 2: GitHub ➔ Hub (Verwijderen via GitHub UI of API)**:
    - **Aanleiding**: Een beheerder/ontwikkelaar verwijdert een issue direct in de GitHub repository interface (*"Delete issue"* onderin de issue sidebar) of via GitHub CLI.
    - **Webhook Event Handler (`supabase/functions/github-webhook/index.ts`)**:
      - Vangt `issues` webhook events op met `action: "deleted"`.
      - Valideert HMAC SHA-256 handtekening (`GITHUB_WEBHOOK_SECRET`).
      - Zoekt het gekoppelde rapport in `public.feedback_reports` op basis van `github_issue_number` en repository mapping.
      - Verwijdert alle gekoppelde bestanden in storage bucket `feedback_attachments`.
      - Wist het record in `public.feedback_reports` om zwevende ("zombie") rapporten in de Hub te voorkomen.
- **Database & RLS Beveiliging**:
  - Migratie `20261006160000_feedback_delete_policy.sql`:
    - PostgreSQL RLS policy `DELETE ON public.feedback_reports`: Uitsluitend toegestaan voor Platform Admins (`is_admin()`) en `service_role`.
    - Storage policy voor `storage.objects` op `feedback_attachments`: `DELETE` uitsluitend voor admins en `service_role`.

### 4. Communicatie & Statusportaal tussen Melder en Admin (Mijn Feedback & Issue Chat in de Hub) [AFGEROND - v1.2.0]
- **Doel**:
  - Direct, laagdrempelig communicatiekanaal tussen de **melder (gebruiker)** en de **platformbeheerder (admin)** om gemelde problemen uit te klaren, ontbrekende informatie op te vragen en gebruikers op de hoogte te houden van de voortgang en status.
- **Opgeleverde Architectuur (Package-First v1.2.0)**:
  - **Shared Package (`packages/schrobbedock_feedback` v1.2.0)**:
    - `SchrobbeDockFeedback.showPortal(context, {appSlug})`: 1-regel methode voor alle Spoke apps en de Hub om een responsive statusportaal / dialoog te openen.
    - `FeedbackPortalView`: Herbruikbare full-page / split-view widget voor master-detail navigatie, statusfilters (*Open*, *In Behandeling*, *Opgelost*) en app-filtering.
    - `FeedbackChatWidget`: Universele realtime chat-component aangedreven door Supabase Realtime channels. Ondersteunt zowel melders- als beheerder-modus.
    - `SchrobbeDockFeedback.watchUnreadCount({appSlug, isAdmin})`: Realtime stream voor dynamische notificatiebadges in navigatiebalken.
  - **Database & RLS (`supabase/migrations/20261007140000_feedback_messages_and_chat.sql`)**:
    - Tabel `public.feedback_messages` met koppeling aan `report_id`, afzenderrollen (`user`, `admin`, `github_dev`), bijlagen en `github_comment_id`.
    - Triggers voor automatische tracking van `last_message_at` en ongelezen vlaggen (`has_unread_user`, `has_unread_admin`).
    - Strikte RLS policies en RPC `mark_feedback_as_read`.
    - Tabellen toegevoegd aan `supabase_realtime` publicatie.
  - **Tweeweg GitHub Synchronisatie via Edge Functions**:
    - Nieuwe functie `send-feedback-message`: Verstuurt reacties vanuit de Hub direct als opgemaakte GitHub Issue Comments en bewaart het GitHub comment-ID.
    - Bijgewerkte webhook `github-webhook`: Vangt `issue_comment` events op GitHub op met automatische loop- en botpreventie, en voegt reacties van externe developers direct in de Hub chat in (`sender_role: 'github_dev'`).
  - **Hub Integratie (`hub_app`)**:
    - Route `/my-feedback` met `MyFeedbackScreen`.
    - Realtime badges op de AppBar ("Mijn Meldingen"), het gebruikersmenu en de Admin Feedback knop.
    - Inbedding van de chat in de uitklapbare issuekaart in `/admin/feedback`.
    - Succesweergave van het feedbackdialoogvenster uitgebreid met *"Volg in Mijn Meldingen"*.

### 5. Versie-indicatie & Build Info in Admin Beheer (Live Versie Validatie) [AFGEROND]
- **Doel**: In de live productieomgeving (bijv. op `robbedillen.be`) direct en ondubbelzinnig kunnen verifiëren welke softwareversie, Git commit SHA en builddatum actief is. Dit voorkomt verwarring door agressieve browsercaching van Flutter Web (`flutter.js`, `main.dart.js`, service workers).
- **Architectuur & Technische Implementatie**:
  - **CI/CD Injectie (`.github/workflows/deploy_web.yml`)**:
    - Tijdens de `flutter build web --release` stap via `--dart-define` de actuele release- en git-metadata injecteren:
      - `--dart-define=APP_VERSION=1.0.0+${{ github.run_number }}`
      - `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`
      - `--dart-define=BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")`
  - **Centrale Versieklasse (`hub_app/lib/config/app_version.dart`)**:
    - Bevat helpers voor weergave van korte Git hash (`0832cf6`), semver versienummer en buildtijdstip met veilige fallbacks voor lokale ontwikkeling (`dev-local`).
  - **UI Integratie in Admin Beheer**:
    - **Admin AppBar / Header Badge**: Een subtiele, klikbare versiebadge in `/admin/invites` en `/admin/feedback` (bijv. `v1.0.0 (0832cf6)`).
    - **Systeem Info Modal / Dialoog**:
      - Toont versienummer, Git commit met directe GitHub commit link, builddatum en Supabase project-ID/omgeving.
      - **Knop *"Cache Legen & Geforceerd Herladen"***: Voert een harde herlaadactie uit (unregisters eventuele service workers en ververst `window.location`) zodat beheerders met 1 klik garanderen dat ze de nieuwste deployment zien.

### 6. Account- & Gebruikersbeheer: Verwijderen door Admin & Self-Service Profiel (AVG/GDPR) [AFGEROND]
- **Doel**: 
  1. Platform Admins kunnen vanuit de Hub gebruikers deactiveren of definitief verwijderen uit het ecosysteem.
  2. Gebruikers kunnen via een profieloverzicht (`/profile`) hun opgeslagen accountgegevens raadplegen, bewerken en zelfstandig hun account definitief laten verwijderen (Right to be Forgotten).
- **Gevolgen voor Google OAuth bij Verwijdering (Architectuuranalyse)**:
  - **In Supabase**: Bij het verwijderen van een record in `auth.users` worden via PostgreSQL foreign keys met `ON DELETE CASCADE` automatisch het record in `public.profiles`, alle `public.user_licenses`, en de gekoppelde `auth.identities` (de Google OAuth link) definitief gewist. Lopende JWT-sessies worden per direct ongeldig.
  - **Bij Google zelf**: Het Google-account van de gebruiker blijft bij Google ongewijzigd bestaan.
  - **Wat gebeurt er als de verwijderde gebruiker later opnieuw op "Inloggen met Google" klikt?**
    - Supabase ziet hem als een **volledig nieuwe bezoeker** (de oude `auth.users.id` bestaat immers niet meer).
    - Er wordt een nieuw, leeg profiel aangemaakt.
    - Door onze **Zero-Trust architectuur** krijgt het account **0 licenties**. De gebruiker landt direct op de *"Geen Actieve Licenties Gevonden"* fallback kaart en heeft GEEN toegang tot Hub Beheer of Spokes, tenzij een beheerder hem opnieuw een geldige uitnodigingscode verstrekt.
- **Ecosysteem-brede Verwijderingswaarschuwing (Single Account Impact)**:
  - **Duidelijke waarschuwing**: Het dialoogvenster benadrukt dat dit het account wist over het **GEHELE** SchrobbeDock-ecosysteem (niet slechts één Spoke).
  - **Dynamische App-oplijsting**: Toont een visuele lijst van alle applicaties waar de gebruiker momenteel toegang toe verliest (Hub, Dock Planner, etc.).
  - **Google Consent Revocation**: Bevat een directe link naar [Google Gekoppelde Apps](https://myaccount.google.com/connections) zodat de gebruiker ook aan Google-zijde de app-toestemming kan intrekken.
  - **Strikte bevestiging**: Verplicht overtypen van `'VERWIJDER'` in het invoerveld.
- **Architectuur (Hub & Spoke)**:
  - **Database (Supabase)**:
    - RPC `delete_user_by_admin(target_user_id UUID)`: Uitsluitend uitvoerbaar door `super_admin` van `hub_admin`. Beschermt tegen self-lockout en garandeert minimaal 1 overblijvende admin.
    - RPC `delete_own_account()`: Uitvoerbaar door de ingelogde gebruiker zelf (`auth.uid() = id`), met bescherming dat de laatste admin zijn rechten eerst moet overdragen.
  - **Frontend / Clients**:
    - **Admin Hub (`/admin/invites` tab Gebruikers & 2FA)**: Rode actieknop *"Account Verwijderen"* met strikte `'VERWIJDER'` modal.
    - **Self-Service Profiel (`/profile`)**: Formulier voor persoonsgegevens (naam, telefoon, adres), gekoppelde login provider, 2FA status, licentie-overzicht en Gevarenzone voor accountverwijdering.
    - **Post-delete UX**: Directe afmelding via `signOut()`, opruimen van lokale opslag en redirect naar `/login` met bevestiging.

### 6b. Google Cloud OAuth Consent Screen & Compliance (Productie Status) [AFGEROND]
- **Doel**: Voldoen aan alle vereisten van het Google API Services User Data Policy om de Google OAuth client van status *"Testing"* (100 gebruikerslimiet) officieel naar *"In Production"* te brengen.
- **Opgeleverde Status & Resultaat**:
  1. **Publieke Privacy Policy URL (`/privacy`) [AFGEROND]**:
     - `PrivacyPolicyScreen` in `hub_app/lib/screens/privacy_policy_screen.dart`.
     - Voldoet aan AVG/GDPR en bevat de verplichte Google API Limited Use Disclosure.
     - Publiek toegankelijk zonder login in `router.dart`.
  2. **Publieke Terms of Service (`/terms`) [AFGEROND]**:
     - `TermsOfServiceScreen` in `hub_app/lib/screens/terms_of_service_screen.dart` (inclusief Art. 7 Pintjesclausule).
     - Publiek toegankelijk zonder login in `router.dart`.
     - Links toegevoegd onderaan Login (`/login`) en Registratie (`/register`).
     - Gedekt door 21/21 geautomatiseerde tests.
  3. **Geverifieerd Domein (Google Search Console) [AFGEROND]**: Eigenaarschap van `robbedillen.be` succesvol geverifieerd via DNS TXT-record bij one.com.
  4. **OAuth Status Publiceren (Google Cloud Console) [AFGEROND]**: OAuth Client opgeschoond naar HTTPS-only en app succesvol gepubliceerd naar *"In Production"*. De 100-gebruikerslimiet is opgeheven.

### 7. Documentatie: Repository README, Spoke Ontwikkelingsgids & Beheerdershandleiding [AFGEROND]
- **README.md (Repository Overview & Setup) [AFGEROND]**:
  - Overzicht van de Hub & Spoke ecosysteem architectuur en componenten.
  - Lokale installatie- en opstartinstructies (Supabase CLI, Flutter, Edge Functions, seed data).
  - Testprotocollen en CI/CD overzicht (Supabase DB pushes & Web hosting deploy).
  - Package release tags en documentatie-index.
- **Spoke App Ontwikkelingsgids (`docs/SPOKE_INTEGRATION_GUIDE.md`) [AFGEROND]**:
  - Complete gids: *Wat moet een Spoke app minimaal implementeren en hoe start je een nieuw Spoke project?*
  - **Single Sign-On & Sessie**: Supabase Auth integratie, token handling en sessie-uitwisseling met de Hub.
  - **Licentie- en toegangsvalidatie**: Hoe een Spoke controleert of de ingelogde gebruiker een actieve licentie heeft in `public.user_licenses` en RLS enforcement.
  - **Package Versiebeheer & Git Release Tags**: Hoe Spoke apps pinnen op specifieke package releases (`ref: theme-v1.0.0`, `ref: feedback-v1.2.0`) om breaking changes en ongewenste updates te voorkomen.
  - **Thema-integratie**: Implementatie van `packages/schrobbedock_theme` (auto-sync met voorkeuren en integratie van `ThemeCustomizerDialog`).
  - **Feedback-integratie**: Implementatie van `packages/schrobbedock_feedback` (1-regel bug- en suggestierapportage naar de bijbehorende GitHub repo).
- **Handleiding / Gebruikersgids (`docs/HANDLEIDING.md`) [AFGEROND]**:
  - Eindgebruikers: Registratie via uitnodigingscode, inloggen (e-mail vs Google), instellen van TOTP in Authenticator app, thematisering, feedback en account verwijderen (AVG).
  - Platform Admins: Genereren van uitnodigingen met `recipient_name`, tracking van genodigden, herstelprocedure bij verloren 2FA-sleutels (Admin 2FA Reset), centraal feedbackcontrolepaneel met GitHub tweeweg sync en live versie validatie / cache purge.

### 8. Multi-Factor Authenticatie (MFA) Uitbreidingen: SMS, E-mail & Passkeys (WebAuthn)
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


### 9. Centrale Toegangsaanvragen & Licentie-Workflow (`public.license_requests`) [AFGEROND]
- **Doel**: Gebruikers die in een Spoke app terechtkomen zonder uitnodigingscode kunnen laagdrempelig toegang aanvragen bij de beheerder.
- **Opgeleverde Architectuur**:
  - **Database & RLS (`20261026011500_license_requests_and_access_workflow.sql`)**:
    - Tabel `public.license_requests` met row level locking en RLS (gebruikers beheren eigen verzoeken, Platform Admins beheren alle verzoeken).
    - RPC `request_app_access(target_app_slug, request_reason)`: Maakt of actualiseert openstaande verzoeken en voorkomt dubbele actieve licenties.
    - RPC `review_license_request(request_id, new_status, assigned_tier, assigned_role)`: Atomair toekennen van licentie in `public.user_licenses` bij goedkeuring en statusmutatie naar `approved` of `rejected`.
    - Realtime updates via `supabase_realtime` publicatie.
  - **Admin Hub Beheer (`hub_app/lib/screens/admin_invites_screen.dart`)**:
    - Nieuwe tab **Toegangsaanvragen** met live badge voor aantal openstaande verzoeken.
    - Segmented filterbalk (*In Afwachting*, *Goedgekeurd*, *Afgewezen*, *Alles*).
    - Modals voor directe goedkeuring (met tier- en rolselectie) en afwijzing.

### 10. Gedeelde Authenticatie & Licentie-Guard Package (`packages/schrobbedock_auth` v1.0.0) [AFGEROND]
- **Doel**: Een uniforme, framework-onafhankelijke licentie- en loginbewaker voor alle Spoke apps.
- **Opgeleverde Architectuur**:
  - **Standalone Package**: In `packages/schrobbedock_auth` (v1.0.0).
  - `LicenseGate` / `SchrobbeDockAuthGuard`: Omwikkelt Spoke apps en handelt automatisch ongeauthenticeerde bezoeken, actieve licenties, verlopen licenties en lopende aanvragen af.
  - `LoginRequiredView`: Strak aanmeldscherm met SSO-redirect naar de centrale Hub (`#/login?redirect=...`).
  - `NoAccessView`: Toegangs- en licentiewall met geïntegreerde uitnodigingscode inwisseling (`claim_invitation`), directe toegangsaanvraag (`request_app_access`), openstaande statusbanner en terugknop naar de Hub.
  - `SchrobbeDockUserMenu`: Kant-en-klare AppBar account- en profielwidget met avatar, Hub navigatie (`#/profile`, `#/dashboard`) en uitlogactie.
  - 3/3 tests geslaagd met 0 analyzer waarschuwingen.

### 11. Spoke-to-Hub Ecosysteem Alert Rule & Scaffolding [AFGEROND]
- **Doel**: Voorkomen dat Spoke agents centrale infrastructuur lokaal dupliceren of 'hacken'.
- **Implementatie**:
  - **Generator Script (`scripts/create_spoke.ps1`)**: Automatische injectie van `schrobbedock_auth` en de **Spoke-to-Hub Ecosysteem Alert Rule** in `.agents/rules/role.md` van elke nieuwe Spoke.
  - **Spoke Integratiegids (`docs/SPOKE_INTEGRATION_GUIDE.md`)**: Volledig bijgewerkt met `LicenseGate`, `SchrobbeDockUserMenu` en de verplichte overdrachtsprocedure.

### 12. Spoke CI/CD Pipeline & Deployment Automation [OPEN]
- **Doel**: Bij de creatie van een nieuwe Spoke applicatie direct duidelijke instructies, een checklist en een reminder bieden om optioneel CI/CD in te stellen voor automatische web deployment en build-validatie.
- **Te Realiseren Onderdelen**:
  1. **Reminder & Checklist bij Spoke Creatie**:
     - In `scripts/create_spoke.ps1` (zowel terminal output als `docs/GITHUB_SETUP.md`) een expliciete herinnering opnemen over het instellen van GitHub Actions CI/CD (web deployment via SFTP naar One.com subdomein of hosting, inclusief de benodigde secrets).
  2. **Kant-en-klaar CI/CD Template (`deploy_web.yml`)**:
     - Een optionele of standaard workflow genereren in `.github/workflows/deploy_web.yml` in de nieuwe Spoke, gebaseerd op de beproefde Hub-workflow (`flutter build web --release` met `--base-href`, `actions/checkout@v4`, en SFTP deployment).
  3. **Hosting & Routing Documentatie**:
     - Automatische opname van een `.htaccess` template voor Apache webservers (One.com) om SPA routing (GoRouter) te laten werken zonder 404's bij directe paginalinks.

