# SchrobbeDock Ecosysteem

[![CI/CD Web Deployment](https://github.com/SchrobbeD/SchrobbeDock/actions/workflows/deploy_web.yml/badge.svg)](https://github.com/SchrobbeD/SchrobbeDock/actions/workflows/deploy_web.yml)
[![Supabase Database CI/CD](https://github.com/SchrobbeD/SchrobbeDock/actions/workflows/production.yml/badge.svg)](https://github.com/SchrobbeD/SchrobbeDock/actions/workflows/production.yml)

SchrobbeDock is een modulair applicatie-ecosysteem gebouwd rond een **Hub & Spoke architectuur**. Het platform combineert één centrale beheerportal (de Hub) met schaalbare, opzichzelfstaande applicaties (Spokes), gecentraliseerd licentiebeheer, gedeelde design packages en een uniforme Supabase backend met strikte Row Level Security (RLS).

---

## 🏛️ Architectuur: De "Hub & Spoke" Setup

```
                     ┌─────────────────────────────┐
                     │     CENTRALE SUPABASE       │
                     │  • Auth (JWT, MFA, OAuth)   │
                     │  • Licenties & Rollen       │
                     │  • Centrale Feedback DB     │
                     │  • PostgreSQL RLS Isolatie  │
                     └──────────────┬──────────────┘
                                    │
                                    │
             ┌──────────────────────┴──────────────────────┐
             │                                             │
             ▼                                             ▼
┌───────────────────────────┐                ┌───────────────────────────┐
│     SCHROBBEDOCK HUB      │                │        SPOKE APPS         │
│     (Flutter Web App)     │                │   (Web, Mobile & Desktop) │
├───────────────────────────┤                ├───────────────────────────┤
│ • Inloggen & Registreren  │                │ • Dock Planner            │
│ • MFA/TOTP Enrollment     │── Token/SSO ──►│ • Dock Inspect            │
│ • App Launcher & Cards    │                │ • Dock Inventory          │
│ • Profiel & Thema Sync    │                │ • ... en toekomstige apps │
│ • Uitnodigingen & Beheer  │                └───────────────────────────┘
└───────────────────────────┘                              │
             ▲                                             ▼
             │                               ┌───────────────────────────┐
             └────── Gedeelde Packages ──────┤ • schrobbedock_theme      │
                     (Git Dependencies)      │ • schrobbedock_feedback   │
                                             └───────────────────────────┘
```

1. **Centrale Hub (`hub_app`)**:
   De centrale web-portal ([robbedillen.be](https://robbedillen.be)) waar gebruikers zich aanmelden, MFA doorlopen en een gepersonaliseerd dashboard zien met applicaties waarvoor zij een actieve licentie bezitten.
2. **Single Identity & Account**:
   Gebruikers bezitten 1 account over het gehele platform via Supabase Auth (E-mail/Wachtwoord & Google OAuth in productie).
3. **Licenties & RLS First**:
   Toegang tot applicaties wordt op gebruikersniveau gecontroleerd via `public.licenses` en `public.user_roles`, strikt afgedwongen via PostgreSQL Row Level Security (RLS).
4. **Data Isolatie**:
   Data van Spoke apps blijft logisch strikt gescheiden via dedicated PostgreSQL schema's (`app_<naam>`) of domeingebonden tabellen.
5. **Gedeelde Ecosysteem Packages**:
   Spoke apps leunen op gedeelde packages in de repository (`packages/`):
   * `schrobbedock_theme`: Uniform kleurenpalet (Warm Amber & Deep Slate), dynamische dark mode en realtime profielsynchronisatie.
   * `schrobbedock_feedback`: 1-regel fout- en suggestiemelder met automatische metadata, screenshots en tweeweg GitHub Issues synchronisatie.

---

## 📁 Repository Structuur

```
SchrobbeDock/
├── .agents/                      # AI assistent regels & protocollen
├── .github/workflows/            # CI/CD pipelines
│   ├── deploy_web.yml            # Automatische Flutter Web deployment naar one.com via SFTP
│   └── production.yml            # Automatische Supabase DB migraties & Edge Functions deploy
├── docs/                         # Technische documentatie & gidsen
│   ├── apps/
│   │   └── hub_app.md            # Functionele & architectonische specificatie van de Hub
│   ├── HANDLEIDING.md            # Gebruikers- en beheerdershandleiding
│   └── SPOKE_INTEGRATION_GUIDE.md# Gids voor het ontwikkelen van nieuwe Spoke apps
├── hub_app/                      # De centrale Flutter Web applicatie
│   ├── lib/
│   │   ├── config/               # Supabase & applicatieversie configuratie
│   │   ├── screens/              # Schermen (Dashboard, Login, MFA, Admin, Legal)
│   │   ├── theme/                # Thematisering & layout adapters
│   │   ├── providers.dart        # Riverpod state providers
│   │   └── router.dart           # GoRouter configuratie met Hybride MFA guards
│   └── web/                      # Web resources & .htaccess voor SPA URL rewrite
├── packages/                     # Gedeelde modulaire packages
│   ├── schrobbedock_feedback/    # Multi-platform feedback- & communicatieportaal
│   └── schrobbedock_theme/       # Framework-agnostisch design system & Riverpod bridge
├── supabase/                     # Supabase configuratie & backend logica
│   ├── functions/                # Deno Edge Functions (submit-feedback, webhook, delete)
│   └── migrations/               # PostgreSQL schema's, RLS policies en RPC functies
└── ROADMAP.md                    # Projectstatus, gerealiseerde modules & backlog
```

---

## 🚀 Lokale Installatie & Opstarten

### Vereisten
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ aanbevolen)
- [Node.js](https://nodejs.org/) (v18+)
- [Docker Desktop](https://www.docker.com/) (voor lokale Supabase instantie)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (`npm install -g supabase` of via `npx supabase`)

### 1. Repository klonen & dependencies installeren
```bash
git clone https://github.com/SchrobbeD/SchrobbeDock.git
cd SchrobbeDock

# Installeer dependencies van de packages
cd packages/schrobbedock_theme && flutter pub get && cd ../..
cd packages/schrobbedock_feedback && flutter pub get && cd ../..

# Installeer dependencies van de Hub
cd hub_app && flutter pub get && cd ..
```

### 2. Lokale Supabase stack starten
Zorg dat Docker Desktop actief is en voer uit in de repository root:
```bash
npx supabase start
```
Dit start lokaal de PostgreSQL database, Auth, Storage, Studio (`http://127.0.0.1:54323`) en past automatisch alle migraties in `supabase/migrations/` toe.

### 3. Edge Functions & Webhook Relay (optioneel voor feedback testen)
Als je lokale GitHub synchronisatie wilt testen:
```bash
# Start de Edge Functions lokaal
npx supabase functions serve --env-file ./supabase/functions/.env

# Start de Smee relay proxy voor inkomende GitHub webhooks
npx smee-client -u https://smee.io/b6SyKuPZpn26ba7B -t http://127.0.0.1:54321/functions/v1/github-webhook
```

### 4. De Hub starten in de browser
```bash
cd hub_app
flutter run -d chrome --web-port=3000
```
De Hub opent op `http://localhost:3000`.

---

## 🧪 Geautomatiseerd Testen

In de repository worden strenge kwaliteitsstandaarden gehanteerd:
```bash
# Tests uitvoeren in de Hub (21 tests)
cd hub_app
flutter analyze
flutter test

# Tests uitvoeren in de packages
cd ../packages/schrobbedock_theme
flutter test

cd ../packages/schrobbedock_feedback
flutter test
```

---

## 🚢 CI/CD & Deployment

- **Database & Edge Functions**:
  Elke push naar `main` die betrekking heeft op `supabase/**` activeert de workflow `.github/workflows/production.yml`. Deze voert automatisch migraties uit op de live Supabase Cloud instantie en deployt de serverloze Edge Functions.
- **Web App Deployment ([robbedillen.be](https://robbedillen.be))**:
  Elke push naar `main` activeert `.github/workflows/deploy_web.yml`. Deze bouwt de Flutter Web release bundle met ingebouwde Git commit hashes en versie-injectie (`--dart-define`), en deployt deze via beveiligde SFTP naar de webcluster van one.com.

---

## 🏷️ Versiebeheer & Git Release Tags

Gedeelde packages in `packages/` worden door externe Spoke apps geïmporteerd via Git tags om breaking changes te voorkomen.

| Package | Tag Conventie | Huidige Release |
| :--- | :--- | :--- |
| **`schrobbedock_theme`** | `theme-vX.Y.Z` | `theme-v1.0.0` |
| **`schrobbedock_feedback`** | `feedback-vX.Y.Z` | `feedback-v1.2.0` |

---

## 📖 Documentatie Index

* [Hub App Specificatie](docs/apps/hub_app.md) - Gedetailleerde functionele beschrijving van alle Hub modules.
* [Spoke Integratie Gids](docs/SPOKE_INTEGRATION_GUIDE.md) - Hoe start en koppel je een nieuwe Spoke app aan SchrobbeDock.
* [Gebruikers- en Beheerdershandleiding](docs/HANDLEIDING.md) - Handleiding voor onboarding, 2FA, uitnodigingen en meldingen.
* [Project Status & Roadmap](ROADMAP.md) - Overzicht van voltooide en toekomstige mijlpalen.
