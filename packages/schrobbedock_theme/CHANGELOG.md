# Changelog

Alle noemenswaardige wijzigingen aan de `schrobbedock_theme` package worden gedocumenteerd in dit bestand.

## [1.0.0] - 2026-10-01

### Toegevoegd
- **Framework-Agnostische Core**: Native Flutter `SchrobbeDockThemeController` (`ChangeNotifier`) en `SchrobbeDockThemeScope` voor pure Flutter apps zonder extern state management framework.
- **Riverpod Bridge**: `schrobbedock_theme_riverpod.dart` met `themePreferencesProvider` en `canAccessRobHubProvider` voor apps met Riverpod.
- **UI Component**: De complete interactieve `ThemeCustomizerDialog` en `SchrobbeDockTheme.showCustomizer(context)`.
- **Presets & RobHub**: Deep Slate dark mode tokens, templates (Warm Amber, Ocean Deep, Emerald Forest, Midnight Violet, Slate Monolith) en het exclusieve RobHub parodiethema met pitch-black contrast.
- **Supabase Realtime Sync**: Volledig gesynchroniseerd met `profiles.preferences` en `raw_user_meta_data.preferences` in de sessie-JWT.
