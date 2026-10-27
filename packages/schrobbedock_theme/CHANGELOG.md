# Changelog

Alle noemenswaardige wijzigingen aan de `schrobbedock_theme` package worden gedocumenteerd in dit bestand.

## [1.1.0] - 2026-10-27

### Toegevoegd & Opgelost (Mobiele Responsiviteit)
- **Responsive Form Factor**: `ThemeCustomizerDialog.show(context)` en `SchrobbeDockTheme.showCustomizer(context)` openen op smartphones (< 600px) automatisch als een ergonomische `showModalBottomSheet` met afgeronde hoeken en drag handle i.p.v. een vaste desktop Dialog.
- **RenderFlex Overflow Preventie**:
  - `SegmentedButton`: Uitgerust met `VisualDensity.compact` en compacte labels ('Donker' i.p.v. 'Donker (Slate)' op smalle viewports).
  - *Mijn Opgeslagen Thema's* en *Colorpicker* tab headers: `Row` vervangen door `Wrap` met responsive `runSpacing` en `visualDensity: VisualDensity.compact`.
  - Colorpicker container: `ColorPicker` dynamisch ingekaderd met `LayoutBuilder` om overflow te voorkomen op schermen < 360px.
  - Dialog footer: Herstelknop omwikkeld met `Flexible` en voorzien van compacte tekst voor smalle viewports.
  - ChoiceChips voor kleurselectie voorzien van compacte labels (`Primair` en `Secundair`).
- **Geautomatiseerde Testdekking**: Nieuwe unit- en widget tests toegevoegd in `test/theme_customizer_dialog_test.dart` ter validatie van mobiele bottom sheets (380px) en desktop dialogen (1024px).

## [1.0.0] - 2026-10-01

### Toegevoegd
- **Framework-Agnostische Core**: Native Flutter `SchrobbeDockThemeController` (`ChangeNotifier`) en `SchrobbeDockThemeScope` voor pure Flutter apps zonder extern state management framework.
- **Riverpod Bridge**: `schrobbedock_theme_riverpod.dart` met `themePreferencesProvider` en `canAccessRobHubProvider` voor apps met Riverpod.
- **UI Component**: De complete interactieve `ThemeCustomizerDialog` en `SchrobbeDockTheme.showCustomizer(context)`.
- **Presets & RobHub**: Deep Slate dark mode tokens, templates (Warm Amber, Ocean Deep, Emerald Forest, Midnight Violet, Slate Monolith) en het exclusieve RobHub parodiethema met pitch-black contrast.
- **Supabase Realtime Sync**: Volledig gesynchroniseerd met `profiles.preferences` en `raw_user_meta_data.preferences` in de sessie-JWT.
