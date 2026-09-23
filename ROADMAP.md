# SchrobbeDock - Project Status & Backlog

## Status Laatste Sessie
- **Codebase**: Hub App (Flutter) + Supabase configuratie & migraties succesvol gecommit en gepusht naar `main`.
- **MFA Recovery**: Admin 2FA Reset functionaliteit geïmplementeerd ([20260923223000_admin_mfa_reset.sql](file:///c:/Users/robbe/Documents/SchrobbeDock/supabase/migrations/20260923223000_admin_mfa_reset.sql)) inclusief Gebruikers- en 2FA-beheertab in de Hub ([admin_invites_screen.dart](file:///c:/Users/robbe/Documents/SchrobbeDock/hub_app/lib/screens/admin_invites_screen.dart)).
- **Lokale omgeving**: `supabase stop` uitgevoerd; lokale containers staan netjes uit.
- **GitHub Actions**: 
  - `production.yml` faalt momenteel omdat de GitHub Secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_ID`) van het productie-project nog ingesteld moeten worden (of de workflow tijdelijk gedisabled moet worden tot productie gewenst is).

---

## Eerstvolgende Punten voor Volgende Sessie

### 1. GitHub Action Falen Oplossen
- Keuze:
  - **Optie A**: GitHub Secrets invullen in repository settings (*Settings -> Secrets and variables -> Actions* / Environment *production*) om automatische migraties naar live Supabase mogelijk te maken.
  - **Optie B**: Deployment workflow tijdelijk op `workflow_dispatch` (handmatig) of draft zetten zolang we puur lokaal ontwikkelen.

### 2. Nieuwe Feature: Centraal Probleem- & Feedbackmeldsysteem
- **Doel**: Gebruikers moeten vanuit **elke app** (en de centrale Hub) laagdrempelig een probleem, bug of suggestie kunnen melden.
- **Architectuur (Hub & Spoke)**:
  - **Database (Supabase)**:
    - Centrale tabel `feedback_reports` (gekoppeld aan `app_id`, `user_id`, categorie, omschrijving, device/platform metadata, screenshots).
    - **RLS**: Gebruikers mogen enkel eigen reports inserten; alleen Platform Admins mogen alles inzien en status updaten (`open`, `in_investigation`, `resolved`).
  - **Frontend / Clients**:
    - Universele/modulaire Flutter feedback modal/widget die eenvoudig in elke app (Spoke) geïmporteerd kan worden.
    - Beheer-/overzichtsscherm in de centrale Hub voor admins.
