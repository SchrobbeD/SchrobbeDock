# SchrobbeDock Spoke Generator - Maakt met 1 commando een nieuwe Flutter Spoke app aan.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [string]$Slug,

    [Parameter(Mandatory = $false)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [string]$LaunchUrl,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# 1. Bepaal Slug en Mappen
if ([string]::IsNullOrWhiteSpace($Slug)) {
    # Converteer CamelCase ("WinterRaket") naar snake_case ("winter_raket") via case-sensitive -creplace
    $Slug = ($Name -creplace '([a-z0-9])([A-Z])', '$1_$2').ToLower().Trim() -replace '[^a-z0-9]+', '_' -replace '^_+|_+$', ''
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Spoke applicatie $Name binnen het SchrobbeDock ecosysteem."
}

if ([string]::IsNullOrWhiteSpace($LaunchUrl)) {
    $LaunchUrl = "https://$($Slug -replace '_', '-').robbedillen.be"
}

$RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$ParentDir = (Get-Item $RepoRoot).Parent.FullName
# Behoud de exacte naam van de app voor de foldernaam (bijv. "WinterRaket")
$TargetDir = Join-Path $ParentDir $Name

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "SchrobbeDock Flutter Spoke Generator" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "• App Naam     : $Name"
Write-Host "• Slug         : $Slug"
Write-Host "• Doelmap      : $TargetDir"
Write-Host "• Launch URL   : $LaunchUrl"
Write-Host "==========================================================" -ForegroundColor Cyan

if (Test-Path $TargetDir) {
    # Zorg dat de casing op Windows NTFS exact overeenkomt met $Name
    $actualDir = Get-Item $TargetDir
    if ($actualDir.Name -cne $Name) {
        $tempDirName = "${Name}_temp_casing"
        Rename-Item -Path $actualDir.FullName -NewName $tempDirName -ErrorAction SilentlyContinue
        Rename-Item -Path (Join-Path $ParentDir $tempDirName) -NewName $Name -ErrorAction SilentlyContinue
    }

    $existingItems = Get-ChildItem -Path $TargetDir -Force
    if ($existingItems.Count -gt 0 -and -not $Force) {
        Write-Error "Map '$TargetDir' bestaat al en is niet leeg! Gebruik -Force om te overschrijven of kies een andere naam."
        exit 1
    }
    if ($Force) {
        Write-Host "⚠️ Map '$TargetDir' bestaat al: overschrijven geforceerd (-Force)..." -ForegroundColor Yellow
        Remove-Item -Path "$TargetDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 2. Flutter Project Initialisatie
Write-Host "`n[1/7] Flutter multi-platform project aanmaken..." -ForegroundColor Green
flutter create --org be.robbedillen --platforms web,windows,android --project-name $Slug $TargetDir

# 3. pubspec.yaml Configureren met SchrobbeDock Packages
Write-Host "[2/7] pubspec.yaml configureren met centrale packages en dependencies..." -ForegroundColor Green
$PubspecPath = Join-Path $TargetDir "pubspec.yaml"

$PubspecTemplate = @'
name: __SLUG__
description: "__DESCRIPTION__"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  supabase_flutter: ^2.8.0
  shared_preferences: ^2.2.3

  # SchrobbeDock Gedeelde Packages (Git Dependencies)
  schrobbedock_theme:
    git:
      url: https://github.com/SchrobbeD/SchrobbeDock.git
      path: packages/schrobbedock_theme
      ref: theme-v1.1.0

  schrobbedock_feedback:
    git:
      url: https://github.com/SchrobbeD/SchrobbeDock.git
      path: packages/schrobbedock_feedback
      ref: feedback-v1.2.0

  schrobbedock_auth:
    git:
      url: https://github.com/SchrobbeD/SchrobbeDock.git
      path: packages/schrobbedock_auth
      ref: auth-v1.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
'@
$PubspecContent = $PubspecTemplate.Replace('__SLUG__', $Slug).Replace('__DESCRIPTION__', $Description)
Set-Content -Path $PubspecPath -Value $PubspecContent -Encoding UTF8

# 4. Secrets, .env & Supabase Configuratie
Write-Host "[3/7] Secrets, .env.example en SupabaseConfig aanmaken..." -ForegroundColor Green

# .env.example
$EnvExampleContent = @'
# ==============================================================================
# SchrobbeDock Spoke - Centrale Supabase Configuratie
# ==============================================================================
# De openbare anon key is veilig voor client-side gebruik dankzij PostgreSQL RLS.
# Geef NOOIT de service_role secret aan deze client app!

SUPABASE_URL=https://supabase.robbedillen.be
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
'@
Set-Content -Path (Join-Path $TargetDir ".env.example") -Value $EnvExampleContent -Encoding UTF8
Set-Content -Path (Join-Path $TargetDir ".env") -Value $EnvExampleContent -Encoding UTF8

# .gitignore (zorgt dat .env nooit lekt)
$GitignorePath = Join-Path $TargetDir ".gitignore"
$GitignoreAdditions = @'

# Environment & Secrets (Nooit committen!)
.env
.env.*
!.env.example

# IDE & OS files
.DS_Store
Thumbs.db
*.iml
.idea/
.vscode/
'@
Add-Content -Path $GitignorePath -Value $GitignoreAdditions -Encoding UTF8

# lib/config/supabase_config.dart
$ConfigDir = Join-Path $TargetDir "lib\config"
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
$SupabaseConfigPath = Join-Path $ConfigDir "supabase_config.dart"

$SupabaseConfigContent = @'
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  /// Bepaalt dynamisch het juiste Supabase endpoint:
  /// - Expliciete --dart-define=SUPABASE_URL heeft altijd voorrang
  /// - In Debug mode: Android Emulator gebruikt 10.0.2.2, Web/Desktop gebruikt 127.0.0.1
  /// - In Release mode: Cloud productie (https://supabase.robbedillen.be)
  static String get url {
    const configured = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (configured.isNotEmpty) return configured;

    if (kDebugMode) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:54321';
      }
      return 'http://127.0.0.1:54321';
    }

    return 'https://supabase.robbedillen.be';
  }

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );
}
'@
Set-Content -Path $SupabaseConfigPath -Value $SupabaseConfigContent -Encoding UTF8

# 5. Schermen en SSO-guards genereren (lib/main.dart)
Write-Host "[4/7] Schermen, thema en SSO-guards genereren (lib/main.dart)..." -ForegroundColor Green
$MainDartPath = Join-Path $TargetDir "lib\main.dart"

$MainDartTemplate = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';
import 'package:schrobbedock_theme/schrobbedock_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: SpokeApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        // Indien niet ingelogd: redirect naar de centrale Hub
        return '/login-required';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SpokeHomeScreen(),
      ),
      GoRoute(
        path: '/login-required',
        builder: (context, state) => const LoginRequiredScreen(),
      ),
    ],
  );
});

class SpokeApp extends ConsumerWidget {
  const SpokeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '__NAME__',
      debugShowCheckedModeBanner: false,
      theme: SchrobbeDockTheme.buildLightTheme(),
      darkTheme: SchrobbeDockTheme.buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

class SpokeHomeScreen extends StatefulWidget {
  const SpokeHomeScreen({super.key});

  @override
  State<SpokeHomeScreen> createState() => _SpokeHomeScreenState();
}

class _SpokeHomeScreenState extends State<SpokeHomeScreen> {
  bool _isLoading = true;
  bool _hasLicense = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('licenses')
          .select('role, is_active')
          .eq('app_id', '__SLUG__')
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _hasLicense = response != null && response['is_active'] == true;
        _userRole = response?['role'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('__NAME__'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Probleem of suggestie melden',
            onPressed: () => SchrobbeDockFeedback.show(context, appSlug: '__SLUG__'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasLicense
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Geen actieve licentie', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text(
                            'Je account heeft momenteel geen geldige licentie voor deze app.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Welkom in __NAME__', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text('Rol: ${_userRole ?? "Gebruiker"}'),
                    ],
                  ),
                ),
    );
  }
}

class LoginRequiredScreen extends StatelessWidget {
  const LoginRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('Aanmelden Vereist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Log eerst in via de centrale SchrobbeDock Hub.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // In web context: redirect naar Hub login
              },
              icon: const Icon(Icons.login),
              label: const Text('Naar Centrale Hub Login'),
            ),
          ],
        ),
      ),
    );
  }
}
'@
$MainDartContent = $MainDartTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path $MainDartPath -Value $MainDartContent -Encoding UTF8

# 6. Documentatie (SPECIFICATION.md & GITHUB_SETUP.md) & Antigravity Regels
Write-Host "[5/7] Documentatie & Antigravity regels genereren..." -ForegroundColor Green
$DocsDir = Join-Path $TargetDir "docs"
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null

# docs/SPECIFICATION.md
$SpecTemplate = @'
# __NAME__ - Functionele Specificatie & PoC Briefing

> **Herkomst**: Uitgewerkt via het Gemini Notebook (SchrobbeDock Product Owner)  
> **Status**: Concept / Proof-of-Concept (PoC)  
> **Ecosysteem**: SchrobbeDock Spoke App (`__SLUG__`)

---

## 1. Doel van de PoC & Probleemstelling
<!-- Plak hier uit Gemini wat het kernprobleem is dat deze app oplost -->
- **Doel**: 
- **Doelgroep**: 

---

## 2. Functionele Scope (MVP / PoC)
<!-- Plak hier de concrete must-have functionaliteiten en de minimale user journey -->
### Must-Haves voor de eerste werkende versie:
1. 
2. 
3. 

### Bewust buiten scope voor PoC:
- 

---

## 3. Schermen & Gebruikerservaring (UX)
<!-- Plak hier welke schermen en flows de gebruiker doorloopt -->
1. **Hoofdscherm (Dashboard)**: 
2. **Detail / Bewerk-flow**: 

---

## 4. Rollen & Permissies (Licentieniveau)
- **Gebruiker (`user`)**: 
- **Beheerder (`admin`)**: 
'@
$SpecContent = $SpecTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path (Join-Path $DocsDir "SPECIFICATION.md") -Value $SpecContent -Encoding UTF8

# docs/GITHUB_SETUP.md
$GithubSetupTemplate = @'
# GitHub Repository & Secrets Handleiding: __NAME__

Deze handleiding legt uit hoe je deze Spoke app koppelt aan een eigen GitHub repository.

---

## 1. Repository Aanmaken op GitHub
1. Ga in je browser naar: **https://github.com/new**
2. Vul in:
   - **Repository name**: `__NAME__` (of `__SLUG__`)
   - **Owner**: `SchrobbeD` (of jouw persoonlijke account)
   - **Visibility**: Kies *Private* of *Public*
   - Vink *“Add a README”* en *“.gitignore”* **UIT** (deze zijn lokaal al aangemaakt).
3. Klik op **Create repository**.

---

## 2. Eerste Push naar GitHub
Omdat Git lokaal al geïnitialiseerd is, hoef je enkel de remote te koppelen en te pushen:

```powershell
cd c:\Users\robbe\Documents\__NAME__
git remote add origin https://github.com/SchrobbeD/__NAME__.git
git push -u origin main
```

---

## 3. Hoe zit het met Secrets?
Binnen het SchrobbeDock ecosysteem hoef je in deze Spoke app **GEEN geheime tokens** op te slaan:
- **Authenticatie**: Gebeurt via de centrale Hub (geen eigen Google OAuth client nodig).
- **Feedback & Issues**: Worden verwerkt door de centrale Supabase Edge Function (`submit-feedback`). De GitHub API-token staat veilig op de Supabase server.
- **Supabase Anon Key**: De sleutel in `lib/config/supabase_config.dart` is een openbare sleutel en is beveiligd via PostgreSQL Row Level Security (RLS).

---

## 4. CI/CD & Automatische Web Deployment (One.com / SFTP)
Deze Spoke applicatie is standaard voorzien van een **kant-en-klare GitHub Actions workflow** (`.github/workflows/deploy_web.yml`) en een Apache SPA rewrite configuratie (`web/.htaccess`).

### Hoe activeer je automatische deployment?
Zodra je code naar de `main` branch pusht, bouwt en test GitHub Actions de web-app automatisch en deployt deze via SFTP naar jouw subdomein.

Voeg hiervoor de volgende secrets toe in GitHub (**Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**):

| Secret Naam | Beschrijving | Voorbeeldwaarde |
| :--- | :--- | :--- |
| `ONE_SFTP_SERVER` | SFTP host van je hostingprovider | `ssh.c49x8am1a.service.one` |
| `ONE_SFTP_USER` | SFTP gebruikersnaam / SSH login | `robbedillen.be` |
| `ONE_SFTP_PASSWORD` | SFTP wachtwoord van je hosting | `*********` |
| `ONE_REMOTE_PATH` | Doelmap op de hosting voor het subdomein | `/www/__SLUG__.robbedillen.be` |
| `PROD_SUPABASE_URL` | Supabase Cloud API URL | `https://supabase.robbedillen.be` |
| `PROD_SUPABASE_ANON_KEY` | Publieke Supabase Anon JWT key | `eyJhbGciOiJIUzI1Ni...` |

> [!NOTE]
> De `.htaccess` zorgt ervoor dat GoRouter SPA URLs direct herladen kunnen worden zonder 404-foutmeldingen op de server.
'@
$GithubSetupContent = $GithubSetupTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path (Join-Path $DocsDir "GITHUB_SETUP.md") -Value $GithubSetupContent -Encoding UTF8

# docs/TESTING.md
$TestingTemplate = @'
# Lokale Testgids & Testgebruikers: __NAME__

Deze gids beschrijft hoe je de Spoke app **__NAME__** (`__SLUG__`) lokaal test binnen het SchrobbeDock ecosysteem.

---

## 🏛️ Hoe werkt lokale architectuur (Hub & Spoke)?

1. **Supabase is het centrale backend**:
   - Supabase draait niet "in" een specifieke app, maar als een centrale Docker stack via de SchrobbeDock hoofdrepository (`npx supabase start`).
   - Alle authenticatie, licenties, RLS policies en data wonen in deze centrale backend.
2. **Netwerkrouting naar Supabase**:
   - **Web & Windows Desktop**: Verbindt automatisch met `http://127.0.0.1:54321`.
   - **Android Emulator**: Verbindt automatisch met `http://10.0.2.2:54321` (het gateway-adres naar je host PC).
   - *Alternatief voor emulator*: Voer via PowerShell `adb reverse tcp:54321 tcp:54321` uit.

---

## 👥 Beschikbare Seed Testgebruikers

In `supabase/seed.sql` van SchrobbeDock zijn de volgende testaccounts voorgeconfigureerd.  
Het wachtwoord voor **alle accounts** is: `password123`.

| Gebruiker | E-mail | Standaard Rol in __NAME__ | Testscenario |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `admin@hub.local` | `super_admin` | Beheer, licentietoekenning en inspectie in de Hub. |
| **Test User 1** *(Jan Jansen)* | `user1@hub.local` | `pro` / `user` | **Happy Path**: Hoofdgebruiker met actieve licentie. |
| **Test User 2** *(Sophie Peeters)* | `user2@hub.local` | `pro` / `user` | Multi-app licenties, manager rol, donker thema (`ocean_deep`). |
| **Test User 3** *(Thomas De Smet)* | `user3@hub.local` | `pro` / `user` | Derde actieve gebruiker (groen thema). |
| **Test User 4** *(Lukas Vermeulen)* | `user4@hub.local` | `pro` / `user` | Vierde actieve gebruiker (paars thema). |
| **Test User 5** *(Emma Claes)* | `user5@hub.local` | `basic` / `user` | Reservespeler / Basic licentietier. |
| **Test User 6** *(Dries Wouters)* | `user6@hub.local` | `basic` / `user` | Tweede reserve / Basic tier. |
| **Test User 7** *(Sanne Jacobs)* | `user7@hub.local` | **GEEN** | **Unhappy Path**: Geen licentie. Test de `NoAccessView`, code-claim en "Toegang Aanvragen". |

> [!NOTE]
> Accounts die eindigen op `@hub.local` zijn in de centrale Hub en Spoke guards automatisch vrijgesteld van de verplichte MFA challenge.

---

## 🧪 De 4 Verplichte Autorisatiestatussen

Controleer altijd of `LicenseGate` de 4 toestanden correct afhandelt:
1. **Niet Aangemeld**: Toont `LoginRequiredView` met doorverwijzing naar Hub login.
2. **Ingelogd Zonder Licentie**: Log in als `user7@hub.local`. Toont `NoAccessView` met veld voor invite code en knop "Toegang Aanvragen".
3. **Openstaande Aanvraag**: Vraag toegang aan via de UI; status schakelt over naar pending banner.
4. **Ingelogd Met Actieve Licentie**: Log in als `user1@hub.local` t/m `user4@hub.local`. Het volledige hoofdscherm opent en het profielthema wordt geladen.

---

## ⚡ Snelle Inloghelper voor Flutter

Om tijdens debuggen op Android of desktop snel te wisselen tussen gebruikers zonder handmatige web redirects:

```dart
// Wissel van gebruiker:
await Supabase.instance.client.auth.signInWithPassword(
  email: 'user1@hub.local',
  password: 'password123',
);
```
'@
$TestingContent = $TestingTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path (Join-Path $DocsDir "TESTING.md") -Value $TestingContent -Encoding UTF8

# Antigravity Rules (.agents/rules/role.md)
$AgentDir = Join-Path $TargetDir ".agents\rules"
New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null

$RoleTemplate = @'
# Rol & Doel: Spoke App Developer (__NAME__)
Je bent een Senior Flutter & Full-Stack Developer voor de Spoke applicatie '__NAME__'.
Jouw taak is om deze applicatie te bouwen, te onderhouden en te laten integreren binnen het SchrobbeDock ecosysteem.

### 🎯 VERPLICHTE STARTPROCEDURE BIJ ELKE SESSIE:
1. **Specificatie Inlezen**: Lees ALTIJD eerst het bestand `docs/SPECIFICATION.md`. Dit bevat de functionele beschrijving, user stories en PoC-doelen die zijn ontworpen in het Gemini Notebook. Bouw uitsluitend functionaliteiten die binnen deze specificatie passen.
2. **Roadmap Eerst (Voortgangsbewaking)**:
   - Controleer of er al een `ROADMAP.md` aanwezig is in het project.
   - **Indien er nog géén `ROADMAP.md` is**: Bied direct proactief aan om een gestructureerde `ROADMAP.md` op te zetten op basis van `docs/SPECIFICATION.md`, opgedeeld in logische fasen (bijv. Fase 1: Datamodel & RLS, Fase 2: Navigatie & Basis UI, Fase 3: Core PoC functionaliteiten, Fase 4: Validatie & Tests).
   - **Indien er wél een `ROADMAP.md` is**: Controleer welke punten openstaan en werk de status actief bij na het afronden van taken.

### 🚨 SPOKE-TO-HUB ECOSYSTEEM ALERT RULE (VERPLICHT):
Zodra je tijdens de ontwikkeling van deze Spoke app stuit op nieuwe centrale behoeften (zoals ontbrekende Supabase RPC's, nieuwe centrale Hub tabellen, permissie-aanpassingen, of uitbreidingen van de centrale packages `schrobbedock_theme`, `schrobbedock_feedback` of `schrobbedock_auth`), mag je deze NOOIT lokaal 'hacken', omzeilen of dupliceren!
Je moet dit **altijd direct, automatisch en proactief melden** aan de gebruiker met een kant-en-klaar overdrachtsbericht dat de gebruiker direct kan voorleggen in de SchrobbeDock Hub sessie.

### 🏛️ Context & Ecosysteem Regels (Hub & Spoke):
- Deze applicatie maakt integraal deel uit van het **SchrobbeDock Ecosysteem**.
- **Authenticatie & Single Account**: Gebruikers loggen in via de centrale Hub (Supabase Auth). Bouw GEEN eigen inlog- of registratieschermen. Gebruik ALTIJD `schrobbedock_auth` (`LicenseGate` / `SchrobbeDockAuthGuard` en `SchrobbeDockUserMenu`).
- **Licenties, Uitnodigingen & Aanvragen**: Toegang tot deze app vereist een actieve licentie in `public.user_licenses` voor `app_id` (slug: '__SLUG__'). `LicenseGate` handelt automatisch login-redirects, het inwisselen van invite-codes (`claim_invitation`) en het indienen van toegangsaanvragen (`request_app_access`) af.
- **Thema & Styling**: Hanteer ALTIJD de officiële SchrobbeDock huisstijl via de geïmporteerde package `schrobbedock_theme` (Warm Amber `#D97706` & Deep Slate `#0F172A`). Gebruik geen ad-hoc kleuren.
- **Feedback & Foutmeldingen**: Gebruik ALTIJD de centrale package `schrobbedock_feedback` met `appSlug: '__SLUG__'`.
- **Database Schema**: Tabellen voor deze app horen logisch thuis in het PostgreSQL schema `app___SLUG__`.

### 🛡️ Git & Version Control Werkwijze:
- Push NOOIT tussentijds naar de remote repository (`origin/main`). Wijzigingen worden tijdens de sessie enkel lokaal getest en gecommit.
- `git push` is pas toegestaan wanneer de gebruiker expliciet aangeeft dat de sessie stopt of expliciet opdracht geeft om te pushen.
- Raadpleeg `docs/GITHUB_SETUP.md` voor de initiële koppeling met de remote repository.

### 🌙 Sessie-einde & Afsluitprotocol (bij 'we stoppen voor de avond / sessie'):
Wanneer de gebruiker aangeeft dat de sessie stopt (bijv. *"we stoppen voor de avond"*, *"we sluiten af"*, *"sessie afronden"*), voer dan ALTIJD autonoom en gestructureerd de volgende stappen uit:
1. **Kwaliteits- en Lintercontrole**:
   - Controleer of er geen syntaxfouten of achtergebleven testbestanden zijn. Draai indien nodig `flutter analyze` om zeker te zijn van een gezonde codebase.
2. **Roadmap & Voortgang Bijwerken**:
   - Werk `ROADMAP.md` direct bij: vink alle voltooide taken af en markeer waar we gebleven zijn.
   - Noteer openstaande punten of aandachtspunten voor de volgende sessie.
3. **Lokale Git Commit**:
   - Controleer gewijzigde bestanden via `git status`.
   - Voeg alle relevante bestanden toe en maak een duidelijke, conventionele commit (bijv. `feat: ...`, `fix: ...` of `chore: ...`).
4. **Git Push naar Remote**:
   - Push alle commits naar de remote repository (`git push origin main`). Omdat de gebruiker de sessie afsluit, is dit nu expliciet toegestaan en verplicht.
5. **Hub Overdrachtscheck (Spoke-to-Hub)**:
   - Evalueer of er tijdens deze sessie vereisten zijn ontstaan voor de centrale SchrobbeDock Hub (bijv. database-migraties in `app___SLUG__`, ontbrekende RPC's, package updates).
   - Zo ja, lever een kant-en-klaar overdrachtsbericht dat direct in de SchrobbeDock sessie geplakt kan worden.
6. **Beknopt Eindrapport**:
   - Sluit af met een helder, beknopt overzicht:
     * Wat is er voltooid?
     * Bevestiging van commit en push hash/status.
     * Het concrete en logische startpunt voor de volgende sessie.

### 💬 Communicatiestijl:
- Denk in systemen: hou altijd rekening met licenties en centrale Supabase RLS.
- Praktische code: lever schone, modulaire code met Riverpod en GoRouter.
- Geen overbodige uitleg: de gebruiker is een ontwikkelaar. Focus op structuur, best practices en implementatie.
'@
$RoleContent = $RoleTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path (Join-Path $AgentDir "role.md") -Value $RoleContent -Encoding UTF8

# Web Apache SPA Routing (.htaccess)
$WebDir = Join-Path $TargetDir "web"
New-Item -ItemType Directory -Path $WebDir -Force | Out-Null
$HtaccessPath = Join-Path $WebDir ".htaccess"

$HtaccessContent = @'
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /
  
  # Serveer bestaande bestanden en directories direct (bijv. main.dart.js, favicon.png, assets)
  RewriteCond %{REQUEST_FILENAME} -f [OR]
  RewriteCond %{REQUEST_FILENAME} -d
  RewriteRule ^ - [L]
  
  # Leid alle overige paden door naar index.html (voor GoRouter SPA routing)
  RewriteRule ^ index.html [L]
</IfModule>

# Cache-control: voorkom dat browsers verouderde versies van index.html cachen na een deploy
<Files "index.html">
  FileETag None
  Header unset ETag
  Header set Cache-Control "max-age=0, no-cache, no-store, must-revalidate"
  Header set Pragma "no-cache"
  Header set Expires "Wed, 11 Jan 1984 05:00:00 GMT"
</Files>
'@
Set-Content -Path $HtaccessPath -Value $HtaccessContent -Encoding UTF8

# GitHub Actions CI/CD Workflow (.github/workflows/deploy_web.yml)
$WorkflowsDir = Join-Path $TargetDir ".github\workflows"
New-Item -ItemType Directory -Path $WorkflowsDir -Force | Out-Null
$DeployWebPath = Join-Path $WorkflowsDir "deploy_web.yml"

$DeployWebTemplate = @'
name: Deploy Flutter Web to one.com

on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'
      - '.github/workflows/deploy_web.yml'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run Static Analysis & Tests
        run: |
          flutter analyze
          flutter test

      - name: Build Web Release
        run: |
          BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
          flutter build web --release \
            --dart-define=SUPABASE_URL="${{ secrets.PROD_SUPABASE_URL }}" \
            --dart-define=SUPABASE_ANON_KEY="${{ secrets.PROD_SUPABASE_ANON_KEY }}" \
            --dart-define=APP_VERSION="1.0.0+${{ github.run_number }}" \
            --dart-define=GIT_COMMIT_SHA="${{ github.sha }}" \
            --dart-define=BUILD_TIMESTAMP="$BUILD_TIME"

      - name: Copy .htaccess to build output
        run: cp web/.htaccess build/web/.htaccess

      - name: Deploy via SFTP to one.com
        uses: wlixcc/SFTP-Deploy-Action@v1.2.6
        with:
          username: ${{ secrets.ONE_SFTP_USER }}
          server: ${{ secrets.ONE_SFTP_SERVER }}
          password: ${{ secrets.ONE_SFTP_PASSWORD }}
          port: 22
          local_path: './build/web/*'
          remote_path: ${{ secrets.ONE_REMOTE_PATH }}
          sftp_only: true
'@
Set-Content -Path $DeployWebPath -Value $DeployWebTemplate -Encoding UTF8

# 7. Git Initialisatie & Initial Commit in de nieuwe Spoke
Write-Host "[6/7] Git initialiseren en initiële commit aanmaken..." -ForegroundColor Green
Push-Location $TargetDir
try {
    git init -b main 2>$null
    if ($LASTEXITCODE -ne 0) {
        git init
        git branch -M main
    }
    git add .
    git commit -m "feat: initial spoke scaffold for $Name from SchrobbeDock generator"
} catch {
    Write-Warning "Git init waarschuwing: $_"
} finally {
    Pop-Location
}

# 8. Automatisch Supabase Registratiemigratie Aanmaken in SchrobbeDock
Write-Host "[7/7] Supabase registratiemigratie genereren in SchrobbeDock..." -ForegroundColor Green
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$MigrationFile = Join-Path $RepoRoot "supabase\migrations\${Timestamp}_register_${Slug}.sql"

$MigrationTemplate = @'
-- ============================================================================
-- Registratie van Spoke App: __NAME__ (__SLUG__)
-- ============================================================================

-- 1. App registreren in centrale catalogus
INSERT INTO public.apps (
    name,
    slug,
    github_repo_owner,
    github_repo_name,
    is_active
) VALUES (
    '__NAME__',
    '__SLUG__',
    'SchrobbeD',
    '__SLUG__',
    true
) ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    github_repo_owner = EXCLUDED.github_repo_owner,
    github_repo_name = EXCLUDED.github_repo_name,
    is_active = EXCLUDED.is_active;

-- 2. Dedicated PostgreSQL schema aanmaken voor data-isolatie
CREATE SCHEMA IF NOT EXISTS app___SLUG__;

-- Geef rechten aan geauthenticeerde gebruikers
GRANT USAGE ON SCHEMA app___SLUG__ TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA app___SLUG__ TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app___SLUG__ TO authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA app___SLUG__ TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA app___SLUG__ GRANT ALL ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app___SLUG__ GRANT ALL ON SEQUENCES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA app___SLUG__ GRANT ALL ON ROUTINES TO authenticated, service_role;

-- 3. Standaard testlicenties toekennen aan seed testusers (Happy Path testen)
INSERT INTO public.user_licenses (user_id, app_id, tier, role)
SELECT u.id, a.id, 'pro', 'user'
FROM auth.users u, public.apps a
WHERE a.slug = '__SLUG__' 
  AND u.email IN ('user1@hub.local', 'user2@hub.local', 'user3@hub.local', 'user4@hub.local')
ON CONFLICT (user_id, app_id) DO NOTHING;

-- Let op: user7@hub.local blijft bewust zonder licentie voor NoAccessView tests.
'@

$MigrationSql = $MigrationTemplate.
    Replace('__NAME__', $Name).
    Replace('__SLUG__', $Slug).
    Replace('__DESCRIPTION__', $Description).
    Replace('__LAUNCH_URL__', $LaunchUrl)

Set-Content -Path $MigrationFile -Value $MigrationSql -Encoding UTF8

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Flutter Spoke App '$Name' is 100% klaar!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "• App Locatie  : $TargetDir"
Write-Host "• Specificatie : $TargetDir\docs\SPECIFICATION.md"
Write-Host "• Testgids     : $TargetDir\docs\TESTING.md"
Write-Host "• GitHub Gids  : $TargetDir\docs\GITHUB_SETUP.md"
Write-Host "• CI/CD Workfl : $TargetDir\.github\workflows\deploy_web.yml"
Write-Host "• Apache SPA   : $TargetDir\web\.htaccess"
Write-Host "• DB Migratie  : $MigrationFile"
Write-Host "`nVolgende stappen:"
Write-Host "1. Plak je output uit het Gemini Notebook in: $TargetDir\docs\SPECIFICATION.md"
Write-Host "2. Raadpleeg $TargetDir\docs\TESTING.md voor de 4 testscenario's en 8 seed testaccounts"
Write-Host "3. Maak een lege repo aan op GitHub (https://github.com/new) genaamd '$Name'"
Write-Host "4. Push direct via: cd $TargetDir; git remote add origin https://github.com/SchrobbeD/$Name.git; git push -u origin main"
Write-Host "5. Open de map in Antigravity om direct met de Roadmap en PoC te starten!"
Write-Host "6. CI/CD: Voeg de 6 secrets toe op GitHub voor automatische web deployment (zie docs/GITHUB_SETUP.md)"
Write-Host "==========================================================" -ForegroundColor Cyan
