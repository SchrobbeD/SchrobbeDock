# Changelog

Alle noemenswaardige wijzigingen aan de `schrobbedock_feedback` package worden gedocumenteerd in dit bestand.

## [1.3.0] - 2026-10-07

### Toegevoegd
- **Centrale Versie- & Systeeminfo (`AppVersion`, `SystemInfoDialog`, `AppVersionBadge`)**: Biedt een universele klikbare chip en dialoogvenster voor live softwarevalidatie in Spoke apps en de centrale Hub.
- **Klikbare Backend Omgeving**: Directe koppeling naar de actieve Supabase backend URL met knoppen om te openen in de browser of de URL te kopiëren naar het klembord.
- **Web Cache & Service Worker Reset (`WebCacheHelper`)**: Unregisters actieve Service Workers en schoont de browser `CacheStorage` API op voor een gegarandeerde harde asset-reload zonder de actieve login-sessie te verliezen (`localStorage` blijft behouden).
- **Universele API**: Toegankelijk via `SchrobbeDockFeedback.showSystemInfo(context)` en de herbruikbare widget `AppVersionBadge`.

## [1.2.0] - 2026-10-07

### Toegevoegd
- **Status- & Communicatieportaal ("Mijn Meldingen")**: Gebruikers kunnen via `SchrobbeDockFeedback.showPortal(context)` of de widget `FeedbackPortalView` hun eerdere meldingen inzien en filteren per app of globaal.
- **Universele Realtime Chat (`FeedbackChatWidget`)**: Tweeweg chatdraad tussen melder en platformbeheerder, aangedreven door Supabase Realtime channel subscriptions.
- **Tweeweg GitHub Issue Comment Sync**: Chatberichten vanuit de Hub worden automatisch gespiegeld naar GitHub Issue comments, en reacties van GitHub developers worden direct ingeladen in de chat (`sender_role: 'github_dev'`).
- **Ongelezen Notificatiestream (`watchUnreadCount`)**: Biedt een realtime stream voor dynamische notificatiebadges in navigatiebalken van Spokes en de Hub.
- **Responsive Split-View**: Master-detail weergave op desktop/tablet en frictieloze navigatie op mobiele schermen.


## [1.1.0] - 2026-10-03

### Toegevoegd
- **Meerdere Bijlagen (0 tot 5)**: Gebruikers kunnen nu 0, 1 of meerdere bijlagen per melding toevoegen.
- **Handmatige Foto-Upload**: Integratie met `image_picker` waarmee gebruikers zelf afbeeldingen/foto's kunnen selecteren vanaf hun apparaat.
- **Volledig Verwijderbaar**: De automatische schermopname kan eenvoudig worden verwijderd om meldingen zonder beeldmateriaal te versturen.
- **Interactieve Miniatuurweergave & Lightbox Preview**: Horizontale fotostrip met labels, verwijderknoppen per foto en een fullscreen voorvertoningsdialoog.

## [1.0.0] - 2026-10-01

### Toegevoegd
- **1-Regel Integratie**: `SchrobbeDockFeedback.show(context, appSlug: '...')` voor directe rapportage vanuit elke Spoke app of Hub.
- **Automatische Schermafbeeldingen**: Native render tree capture via `RenderRepaintBoundary` met preview en verwijderoptie.
- **Privacyvriendelijke Metadata**: Verzamelt automatisch platform, OS, browser, schermresolutie, pixel ratio en actieve route.
- **Crash Boundary (`SchrobbeDockCrashBoundary`)**: Vangt ongepaste applicatiefouten op en laat gebruikers de crash met 1 klik melden inclusief foutdetails en stacktrace.
- **Floating Feedback Overlay**: Zwevende knop (`SchrobbeDockFeedbackOverlay`) voor Spoke apps.
- **Volledige Tweeweg Synchronisatie (GitHub REST API & Webhooks)**:
  - Koppelt automatisch aan GitHub Issues met labels (`bug`, `in-progress`, `severity:...`).
  - Status wijzigen in de Hub past direct het GitHub Issue aan en plaatst audit comments.
  - Issue sluiten of heropenen in GitHub (manueel of via `closes #1` in commit messages) synchroniseert direct terug naar het SchrobbeDock Admin Dashboard via GitHub Webhooks.
