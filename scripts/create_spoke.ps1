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
    # Converteer CamelCase ("WinterRaket") naar snake_case ("winter_raket")
    $Slug = ($Name -replace '([a-z0-9])([A-Z])', '$1_$2').ToLower().Trim() -replace '[^a-z0-9]+', '_' -replace '^_+|_+$', ''
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
Write-Host "`n[1/5] Flutter multi-platform project aanmaken..." -ForegroundColor Green
flutter create --org be.robbedillen --platforms web,windows,android --project-name $Slug $TargetDir

# 3. pubspec.yaml Configureren met SchrobbeDock Packages
Write-Host "[2/5] pubspec.yaml configureren met centrale packages en dependencies..." -ForegroundColor Green
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
      ref: theme-v1.0.0

  schrobbedock_feedback:
    git:
      url: https://github.com/SchrobbeD/SchrobbeDock.git
      path: packages/schrobbedock_feedback
      ref: feedback-v1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
'@
$PubspecContent = $PubspecTemplate.Replace('__SLUG__', $Slug).Replace('__DESCRIPTION__', $Description)
Set-Content -Path $PubspecPath -Value $PubspecContent -Encoding UTF8

# 4. Schermen en SSO-guards genereren (lib/main.dart)
Write-Host "[3/5] Schermen, thema en SSO-guards genereren (lib/main.dart)..." -ForegroundColor Green
$MainDartPath = Join-Path $TargetDir "lib\main.dart"

$MainDartTemplate = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';
import 'package:schrobbedock_theme/schrobbedock_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://supabase.robbedillen.be'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'ANON_KEY_HERE'),
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

# 5. Functionele Specificatie & Antigravity AI-regels Aanmaken
Write-Host "[4/5] Functionele specificatie & Antigravity regels aanmaken..." -ForegroundColor Green
$DocsDir = Join-Path $TargetDir "docs"
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null

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

### 🏛️ Context & Ecosysteem Regels (Hub & Spoke):
- Deze applicatie maakt integraal deel uit van het **SchrobbeDock Ecosysteem**.
- **Authenticatie & Single Account**: Gebruikers loggen in via de centrale Hub (Supabase Auth). Bouw GEEN eigen inlog- of registratieschermen. Lees de actieve sessie of stuur niet-geauthenticeerde gebruikers door naar de centrale Hub (`https://robbedillen.be/#/login`).
- **Licenties & RLS**: Toegang tot deze app vereist een actieve licentie in `public.licenses` voor `app_id: '__SLUG__'`. Data-toegang wordt strikt beveiligd via PostgreSQL Row Level Security (RLS).
- **Thema & Styling**: Hanteer ALTIJD de officiële SchrobbeDock huisstijl via de geïmporteerde package `schrobbedock_theme` (Warm Amber `#D97706` & Deep Slate `#0F172A`). Gebruik geen ad-hoc kleuren.
- **Feedback & Foutmeldingen**: Gebruik ALTIJD de centrale package `schrobbedock_feedback` met `appSlug: '__SLUG__'`.
- **Database Schema**: Tabellen voor deze app horen logisch thuis in het PostgreSQL schema `app___SLUG__`.

### 🛡️ Git & Version Control Werkwijze:
- Push NOOIT tussentijds naar de remote repository (`origin/main`). Wijzigingen worden tijdens de sessie enkel lokaal getest en gecommit.
- `git push` is pas toegestaan wanneer de gebruiker expliciet aangeeft dat de sessie stopt of expliciet opdracht geeft om te pushen.

### 💬 Communicatiestijl:
- Denk in systemen: hou altijd rekening met licenties en centrale Supabase RLS.
- Praktische code: lever schone, modulaire code met Riverpod en GoRouter.
- Geen overbodige uitleg: de gebruiker is een ontwikkelaar. Focus op structuur, best practices en implementatie.
'@
$RoleContent = $RoleTemplate.Replace('__NAME__', $Name).Replace('__SLUG__', $Slug)
Set-Content -Path (Join-Path $AgentDir "role.md") -Value $RoleContent -Encoding UTF8

# 6. Automatisch Supabase Registratiemigratie Aanmaken in SchrobbeDock
Write-Host "[5/5] Supabase registratiemigratie genereren in SchrobbeDock..." -ForegroundColor Green
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
    description,
    launch_url,
    icon_name,
    github_repo_owner,
    github_repo_name,
    is_active
) VALUES (
    '__NAME__',
    '__SLUG__',
    '__DESCRIPTION__',
    '__LAUNCH_URL__',
    'widgets',
    'SchrobbeD',
    '__SLUG__',
    true
) ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    launch_url = EXCLUDED.launch_url;

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
'@

$MigrationSql = $MigrationTemplate.
    Replace('__NAME__', $Name).
    Replace('__SLUG__', $Slug).
    Replace('__DESCRIPTION__', $Description).
    Replace('__LAUNCH_URL__', $LaunchUrl)

Set-Content -Path $MigrationFile -Value $MigrationSql -Encoding UTF8

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "Flutter Spoke App '$Name' is succesvol gegenereerd!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "• App Locatie : $TargetDir"
Write-Host "• Specificatie: $TargetDir\docs\SPECIFICATION.md"
Write-Host "• Migratie    : $MigrationFile"
Write-Host "`nVolgende stappen:"
Write-Host "1. Plak je output uit het Gemini Notebook in: $TargetDir\docs\SPECIFICATION.md"
Write-Host "2. Open de nieuwe map in Antigravity om direct te bouwen!"
Write-Host "==========================================================" -ForegroundColor Cyan
