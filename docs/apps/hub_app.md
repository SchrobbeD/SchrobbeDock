# SchrobbeDock - Hub App (Centrale Portal)

> **Documenttype**: Functionele & Architectonische Specificatie  
> **Status**: Actief / In Productie (v1.0.0)  
> **Rol in Ecosysteem**: Centrale Ingang, Identity Provider & Spoke App Launcher  
> **Platform**: Flutter Web (Responsive desktop, tablet & mobile)  
> **Doel voor Notebook / Gemini**: Gebruik dit document als context voor hoe de centrale Hub functioneert, zodat nieuwe Spoke apps hier naadloos op aansluiten.

---

## 1. Doel & Positie in het Ecosysteem

De **Hub App** is het kloppend hart van het SchrobbeDock platform. Binnen de Hub & Spoke architectuur is de Hub de enige plek waar:
1. **Gebruikers zich registreren, authenticeren en hun identiteit beheren.**
2. **Toegangsrechten en licenties worden uitgegeven, geclaimd en gevalideerd.**
3. **Gebruikers een overzicht zien van alle applicaties (Spokes) waar zij toegang toe hebben.**
4. **Centrale administratie plaatsvindt** (uitnodigingen, licentietoewijzing, feedbackbeheer en 2FA resets).
5. **Ecosysteem-brede voorkeuren (zoals thema en uiterlijk) worden geconfigureerd.**

Spoke apps (toekomstige apps) leunen volledig op de Hub voor authenticatie, gebruikersprofielen en licentiebepaling.

---

## 2. Functionele Modules & Schermen

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SCHROBBEDOCK HUB APP                            │
├──────────────────┬──────────────────┬─────────────────┬────────────────┤
│ 1. Authenticatie │ 2. Dashboard     │ 3. Profiel &    │ 4. Admin       │
│    & Toegang     │    & Launcher    │    Thema        │    Beheer      │
│ • Login / OAuth  │ • App Cards      │ • Personalia    │ • Invitations  │
│ • Registratie    │ • App Info (i)   │ • Thema-kiezer  │ • Feedback     │
│ • Hybride MFA    │ • Code Inwisselen│ • Licentie-overz│ • 2FA Reset    │
└──────────────────┴──────────────────┴─────────────────┴────────────────┘
```

---

### Module 1: Authenticatie, Toegang & Onboarding

De Hub regelt alle identiteitsstromen voor het volledige ecosysteem.

* **Login (`/login`)**:
  * Inloggen met e-mailadres en wachtwoord.
  * Direct inloggen via **Google OAuth**.
  * Onthoudt sessies via beveiligde cookies/local storage en herstelt actieve Supabase JWT sessies.
* **Registratie & Onboarding (`/register`)**:
  * Formulier voor nieuwe gebruikers: Voornaam, Achternaam, E-mailadres, Telefoonnummer (met validatie) en Wachtwoord.
  * **Uitnodigingscode Veld**: Optioneel of verplicht invulbaar.
  * **Google OAuth Registratie met Code-behoud**: Als een gebruiker kiest voor *“Aanmelden met Google”*, wordt een eventueel ingevulde uitnodigingscode tijdelijk gecached en direct na de OAuth redirect atomair verzilverd via de PostgreSQL `claim_invitation` RPC.
* **Hybride Multi-Factor Authenticatie (MFA / TOTP)**:
  * **Zero-Trust**: Verplicht voor accounts met wachtwoordauthenticatie en voor álle bezoeken aan beheerdersroutes (`/admin/*`).
  * **Google Trust**: Gebruikers die via Google OAuth inloggen worden vertrouwd voor standaard app-toegang en hoeven geen dubbele MFA te doorlopen, tenzij ze admin-functies willen benaderen.
  * **MFA Verificatie (`/mfa-verify`)**: 6-cijferige code-invoer met **automatische submit** zodra het 6e cijfer is getypt.
  * **MFA Koppeling (`/mfa-enroll`)**: QR-code scanner & handmatige geheime sleutel voor apps zoals Google Authenticator of 1Password. Onvoltooide/afgebroken koppelpogingen worden automatisch opgeruimd om conflicten te voorkomen.
  * **Admin 2FA Reset**: Platformbeheerders kunnen bij verloren apparaten de 2FA-factor van een gebruiker resetten via een beveiligde Supabase RPC.

---

### Module 2: Dashboard & Spoke App Launcher (`/`)

Het centrale startscherm na succesvolle login en verificatie.

* **Bovenbalk (AppBar) & Navigatie**:
  * SchrobbeDock branding en directe statusindicatoren.
  * Universele knop **“Code Inwisselen”**: Hiermee kan een reeds ingelogde gebruiker altijd een nieuwe uitnodigingscode claimen om direct toegang tot een extra Spoke app te ontgrendelen.
  * **User Avatar Menu**: Snelle toegang tot *Mijn Profiel*, *Uiterlijk & Thema*, *Mijn Feedback*, optionele *Admin Beheer*-pagina's en *Uitloggen*.
  * **Mobiele Navigatie**: Automatische responsive omschakeling naar een moderne `BottomNavigationBar` op schermen kleiner dan 650px.
* **Spoke App Grid (App Launcher)**:
  * Overzicht van alle applicaties geregistreerd in `public.apps`.
  * **Actieve App Cards**: Klikbare kaarten met app-icoon, naam en korte omschrijving. Een klik opent de Spoke app direct (in hetzelfde tabblad of als externe web-app/spoke URL).
  * **Discreet Info-icoon `(i)`**: Rechtsboven op elke kaart. Opent een compacte modal popup met details:
    * Actuele app-versie.
    * Licentiestatus van de huidige gebruiker (bijv. Rol: *Beheerder*, Plan: *Pro*, Geldig tot: *datum*).
    * Uitgebreide beschrijving en doeleinden van de app.
* **Zero-Trust Fallback Claim Card**:
  * Als een nieuwe gebruiker inlogt maar nog over **geen enkele licentie** beschikt, toont het dashboard een vriendelijke leegloop-statuskaart met een direct invoerveld om alsnog een uitnodigingscode in te voeren.

---

### Module 3: Profiel & Ecosysteem-Thematisering

* **Profielbeheer (`/profile`)**:
  * Inzien en bewerken van naam, e-mailadres en contactgegevens.
  * Overzicht van alle actieve licenties per Spoke app inclusief toegekende rollen.
  * Beveiligingsinstellingen: Wachtwoord wijzigen en actieve MFA-factoren inzien of ontkoppelen.
* **Thema & Uiterlijk Personalisatie (`schrobbedock_theme`)**:
  * Gebruikers kunnen via een interactieve dialoog hun complete interface-ervaring aanpassen.
  * **Themamodus**: Systeemvoorkeur volgen, altijd Licht, of altijd Donker (Deep Slate `#0F172A`).
  * **Kleurpaletten (Presets)**:
    * *Warm Amber & Roest* (Het officiële SchrobbeDock handelsmerk).
    * *Ocean Deep* (Maritiem diepblauw).
    * *Emerald Forest* (Rustgevend smaragdgroen).
    * *Midnight Violet* (Nachtelijk paars/indigo).
    * *Slate Monolith* (Neutraal industrieel grijs).
    * *RobHub* (Verborgen thema-parodie met vergrendelde dark mode, ontgrendelbaar via speciale code).
  * **Custom Color Picker**: Vrije keuze voor accentkleur met live preview en hex-code invoer.
  * **Cross-App Sync**: Thema-instellingen worden opgeslagen in `public.user_profiles.preferences` en via PostgreSQL triggers gesynchroniseerd naar `auth.users.raw_user_meta_data`. Hierdoor beschikken Spoke apps direct bij het inlezen van het gebruikers-JWT over de exacte themavoorkeuren zonder extra database query.

---

### Module 4: Centrale Administratie & Beheer (`/admin/*`)

Exclusief toegankelijk voor gebruikers met de rol `platform_admin`.

* **Uitnodigingenbeheer (`/admin/invitations`)**:
  * Aanmaken van nieuwe uitnodigingscodes.
  * Specificatie van:
    * Bestemmeling (`recipient_name`): Voor wie de uitnodiging bedoeld is (administratieve tracking).
    * Doel-applicatie (`app_id`) en toe te kennen rol (`role`, bijv. *user*, *manager*, *admin*).
    * Geldigheidsduur (vervaldatum).
    * Maximaal aantal keren inwisselbaar (standaard 1x).
  * **Klaar-om-te-delen bericht**: Genereert direct een nette uitnodigingstekst inclusief directe registratielink met pre-filled code, met één klik te kopiëren naar het klembord.
  * **Statusmonitoring**: Realtime overzicht van openstaande, geclaimde en verlopen codes (inclusief tijdstip en wie de code heeft verzilverd).
  * **Intrekken**: Ongebruikte codes kunnen op elk moment worden gedeactiveerd of verwijderd.
* **Feedback- & Meldingenbeheer (`/admin/feedback`)**:
  * Centraal controlepaneel voor alle storings-, bug- en functionaliteitsmeldingen afkomstig uit de Hub én alle Spoke apps (via `schrobbedock_feedback`).
  * Filteren op Spoke applicatie (`app_slug`), status (*open*, *in_progress*, *resolved*, *closed*) en type melding (*bug*, *feature*, *improvement*).
  * Inzien van meegestuurde schermafbeeldingen (opgeslagen in de Supabase Storage bucket `feedback_attachments`).
  * Inzien van diagnostische systeemmetadata (OS, browserversie, schermresolutie).
  * **GitHub Synchronisatie**: Meldingen worden automatisch doorgezet naar de specifieke GitHub repository van de betreffende app. Beheerders zien het gekoppelde GitHub Issue nummer en kunnen statussynchronisaties volgen.
* **Mijn Meldingen (`/my-feedback`)**:
  * Voor reguliere gebruikers: een transparant overzicht van hun eigen ingezonden tickets en de actuele voortgang.

---

## 3. Technische & Architectonische Integratiepunten

Wanneer je in het **Gemini Notebook** nadenkt over een nieuwe Spoke app, zijn dit de raakvlakken met de Hub:

| Integratiepunt | Hoe de Hub dit regelt | Wat de Spoke App moet doen |
| :--- | :--- | :--- |
| **Authenticatie** | Supabase Auth sessie in de Hub browser context. | De active Supabase client initialiseren met hetzelfde Supabase URL & Anon Key; leest direct het JWT. |
| **Autorisatie / Licentie** | Centrale tabel `public.licenses` koppelt `user_id` aan `app_id` en kent een `role` toe. | Toegang controleren via `SELECT role FROM public.licenses WHERE app_id = 'spoke_slug' AND user_id = auth.uid()`. |
| **Uiterlijk & Huisstijl** | Opslag in user metadata via `schrobbedock_theme`. | Het package importeren: `SchrobbeDockTheme.fromPreferences(...)` aanroepen voor consistente kleuren en dark mode. |
| **Feedback & Issues** | Centrale database `feedback_reports` + GitHub auto-sync. | Package `schrobbedock_feedback` toevoegen en één regel aanroepen: `SchrobbeDockFeedback.show(context, appSlug: 'nieuwe_app');`. |
| **Launchpad Navigatie** | Kaart in het Hub Dashboard met URL en metadata. | Registreren als record in `public.apps` (met naam, slug, launch URL en GitHub repo mapping). |

---

## 4. Richtlijnen voor Nieuwe Spoke Apps (Wat hoort NIET in de Spoke?)

Om het ecosysteem schoon en onderhoudbaar te houden, gelden de volgende scheidingen:

1. **Geen eigen loginschermen in Spokes**: Een Spoke app toont geen eigen registratie- of inlogformulieren. Als een gebruiker niet ingelogd is, redirect de Spoke naar de centrale Hub login met een return-URL.
2. **Geen eigen licentiebeheerders**: Het toekennen van licenties gebeurt altijd in de Hub. Een Spoke app kan hoogstens app-specifieke rollen gebruiken die door de Hub-licentie zijn verleend.
3. **Geen losse thema-opslag**: Thema-instellingen worden niet lokaal in de Spoke opgeslagen, maar worden centraal overgenomen uit het profiel in de Hub.
4. **Geen losse feedback-infrastructuur**: Elke app gebruikt het centrale meldpunt zodat alle issues en bugs op één plek binnenkomen.
