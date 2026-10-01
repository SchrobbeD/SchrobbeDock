import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/theme_preferences.dart';
import 'src/theme_presets.dart';
import 'src/schrobbedock_theme_controller.dart';

export 'src/theme_preferences.dart';
export 'src/theme_presets.dart';
export 'src/app_theme.dart';
export 'src/schrobbedock_theme_controller.dart';
export 'src/schrobbedock_theme_scope.dart';

/// Provider voor SharedPreferences instantie, geïnjecteerd via ProviderScope in main()
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class ThemePreferencesNotifier extends Notifier<ThemePreferences> {
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  ThemePreferences build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    final prefs = ref.watch(sharedPreferencesProvider);
    ThemePreferences initial = ThemePreferences.defaultPreferences;

    // 1. Direct synchroon inladen vanuit SharedPreferences (0 ms FOUC-vrije start op F5)
    if (prefs != null) {
      final localJson = prefs.getString(kSchrobbeDockLocalPrefsKey);
      if (localJson != null) {
        try {
          final decoded = jsonDecode(localJson) as Map<String, dynamic>;
          initial = ThemePreferences.fromJson(decoded);
        } catch (_) {}
      }
    }

    // 2. Setup auth luisteraar en achtergrond synchronisatie met Supabase
    Future.microtask(() => _setupSync(hasLocalCache: initial != ThemePreferences.defaultPreferences));

    return initial;
  }

  void _setupSync({required bool hasLocalCache}) {
    final client = _supabase;
    if (client == null) return;

    // Luister naar auth veranderingen (bijv. inloggen van een andere gebruiker of switch)
    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated) {
        syncFromProfile(forceApply: true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = ThemePreferences.defaultPreferences;
        ref.invalidate(canAccessRobHubProvider);
      }
    });

    // Haal altijd de meest actuele profiel-voorkeuren op van de server
    if (client.auth.currentUser != null) {
      syncFromProfile(forceApply: !hasLocalCache);
    }
  }

  Future<void> syncFromProfile({bool forceApply = false}) async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;

    try {
      final response = await client
          .from('profiles')
          .select('preferences, can_access_robhub')
          .eq('id', user.id)
          .maybeSingle();

      ref.invalidate(canAccessRobHubProvider);

      if (response != null) {
        final canAccessRobHub = response['can_access_robhub'] as bool? ?? false;
        if (response['preferences'] != null) {
          var dbPrefs = ThemePreferences.fromJson(
              response['preferences'] as Map<String, dynamic>);

          // Als RobHub toegang is ingetrokken maar thema staat nog op RobHub:
          // val automatisch terug naar Warm Amber
          if (!canAccessRobHub && dbPrefs.preset == 'rob_hub') {
            dbPrefs = dbPrefs.copyWith(
              preset: 'amber_rust',
              primaryColor: const Color(0xFFEA580C),
              secondaryColor: const Color(0xFFB45309),
            );
          }

          if (forceApply || state != dbPrefs) {
            state = dbPrefs;
            await _cacheLocally(dbPrefs);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.preset == 'rob_hub') return;
    final updated = state.copyWith(themeMode: mode);
    await _updatePreferences(updated);
  }

  Future<void> applyPreset(ThemePresetItem preset) async {
    final updated = state.copyWith(
      primaryColor: preset.primaryColor,
      secondaryColor: preset.secondaryColor,
      preset: preset.id,
      themeMode: preset.id == 'rob_hub' ? ThemeMode.dark : state.themeMode,
    );
    await _updatePreferences(updated);
  }

  Future<void> setCustomColors({
    required Color primary,
    required Color secondary,
  }) async {
    final updated = state.copyWith(
      primaryColor: primary,
      secondaryColor: secondary,
      preset: 'custom',
    );
    await _updatePreferences(updated);
  }

  Future<void> saveCurrentAsCustomTheme(String name) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSaved = SavedTheme(
      id: newId,
      name: name.trim().isEmpty ? 'Aangepast Thema' : name.trim(),
      primaryColor: state.primaryColor,
      secondaryColor: state.secondaryColor,
      themeMode: state.themeMode,
    );

    final updatedList = List<SavedTheme>.from(state.savedThemes)..add(newSaved);
    final updated = state.copyWith(
      preset: 'saved_$newId',
      savedThemes: updatedList,
    );
    await _updatePreferences(updated);
  }

  Future<void> applySavedTheme(SavedTheme saved) async {
    final updated = state.copyWith(
      primaryColor: saved.primaryColor,
      secondaryColor: saved.secondaryColor,
      themeMode: saved.themeMode,
      preset: 'saved_${saved.id}',
    );
    await _updatePreferences(updated);
  }

  Future<void> deleteSavedTheme(String id) async {
    final updatedList = state.savedThemes.where((t) => t.id != id).toList();
    String newPreset = state.preset;
    if (state.preset == 'saved_$id') {
      newPreset = 'custom';
    }
    final updated = state.copyWith(
      preset: newPreset,
      savedThemes: updatedList,
    );
    await _updatePreferences(updated);
  }

  Future<void> _updatePreferences(ThemePreferences newPrefs) async {
    state = newPrefs;
    await _cacheLocally(newPrefs);

    final client = _supabase;
    final user = client?.auth.currentUser;
    if (user != null && client != null) {
      try {
        // 1. Update in profiles tabel (centrale bron in Supabase)
        await client.rpc(
          'update_user_preferences',
          params: {'new_prefs': newPrefs.toJson()},
        );
      } catch (_) {
        try {
          await client
              .from('profiles')
              .update({'preferences': newPrefs.toJson()})
              .eq('id', user.id);
        } catch (_) {}
      }

      // 2. Synchroniseer user metadata in auth sessie zodat het JWT direct up-to-date is
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'preferences': newPrefs.toJson()}),
        );
      } catch (_) {}
    }
  }

  Future<void> _cacheLocally(ThemePreferences prefs) async {
    try {
      final sp = ref.read(sharedPreferencesProvider) ?? await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(prefs.toJson());
      final modeStr = prefs.themeMode == ThemeMode.light
          ? 'light'
          : (prefs.themeMode == ThemeMode.dark ? 'dark' : 'system');
      final primaryHex = colorToHex(prefs.primaryColor);
      final secondaryHex = colorToHex(prefs.secondaryColor);

      await sp.setString(kSchrobbeDockLocalPrefsKey, jsonStr);
      await sp.setString('theme_mode', modeStr);
      await sp.setString('primary_color', primaryHex);
      await sp.setString('secondary_color', secondaryHex);
    } catch (_) {}
  }
}

final themePreferencesProvider =
    NotifierProvider<ThemePreferencesNotifier, ThemePreferences>(
  ThemePreferencesNotifier.new,
);

/// Provider om te controleren of de huidige ingelogde gebruiker geautoriseerd is voor het exclusieve RobHub thema
final canAccessRobHubProvider = FutureProvider<bool>((ref) async {
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;

    final response = await client
        .from('profiles')
        .select('can_access_robhub')
        .eq('id', user.id)
        .maybeSingle();

    return response?['can_access_robhub'] as bool? ?? false;
  } catch (_) {
    return false;
  }
});
