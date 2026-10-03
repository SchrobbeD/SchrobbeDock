# Changelog

Alle noemenswaardige wijzigingen aan de `schrobbedock_feedback` package worden gedocumenteerd in dit bestand.

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
