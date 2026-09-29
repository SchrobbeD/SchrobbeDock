import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';
import 'theme_preferences.dart';
import 'theme_presets.dart';

const String _localPrefsKey = 'schrobbedock_theme_preferences';

class ThemePreferencesNotifier extends Notifier<ThemePreferences> {
  SupabaseClient? get _supabase {
    try {
      return ref.read(supabaseClientProvider);
    } catch (_) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
  }

  @override
  ThemePreferences build() {
    Future.microtask(() => _initPreferences());
    return ThemePreferences.defaultPreferences;
  }

  Future<void> _initPreferences() async {
    // 1. Snelle start uit sessie metadata (0 ms latentie)
    final user = _supabase?.auth.currentUser;
    if (user != null && user.userMetadata?['preferences'] != null) {
      final metaPrefs = ThemePreferences.fromUserMetadata(user.userMetadata);
      state = metaPrefs;
      return;
    }

    // 2. Lokale SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_localPrefsKey);
      if (localJson != null) {
        final decoded = jsonDecode(localJson) as Map<String, dynamic>;
        state = ThemePreferences.fromJson(decoded);
        return;
      }
    } catch (_) {}

    // 3. Indien ingelogd maar nog niet in metadata gecached, ophalen uit database
    if (user != null && _supabase != null) {
      try {
        final response = await _supabase!
            .from('profiles')
            .select('preferences')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null && response['preferences'] != null) {
          final dbPrefs = ThemePreferences.fromJson(
              response['preferences'] as Map<String, dynamic>);
          state = dbPrefs;
          _cacheLocally(dbPrefs);
        }
      } catch (_) {}
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final updated = state.copyWith(themeMode: mode);
    await _updatePreferences(updated);
  }

  Future<void> applyPreset(ThemePresetItem preset) async {
    final updated = state.copyWith(
      primaryColor: preset.primaryColor,
      secondaryColor: preset.secondaryColor,
      preset: preset.id,
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

    final user = _supabase?.auth.currentUser;
    if (user != null && _supabase != null) {
      try {
        await _supabase!.rpc(
          'update_user_preferences',
          params: {'new_prefs': newPrefs.toJson()},
        );
      } catch (_) {
        // Fallback: update direct op de profiles tabel indien de RPC nog niet gemigreerd is
        try {
          await _supabase!
              .from('profiles')
              .update({'preferences': newPrefs.toJson()})
              .eq('id', user.id);
        } catch (_) {}
      }
    }
  }

  Future<void> _cacheLocally(ThemePreferences prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_localPrefsKey, jsonEncode(prefs.toJson()));
    } catch (_) {}
  }
}

final themePreferencesProvider =
    NotifierProvider<ThemePreferencesNotifier, ThemePreferences>(
  ThemePreferencesNotifier.new,
);
