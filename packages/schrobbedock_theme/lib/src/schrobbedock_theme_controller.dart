import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_preferences.dart';
import 'theme_presets.dart';

const String kSchrobbeDockLocalPrefsKey = 'schrobbedock_theme_preferences';

/// Framework-agnostische Theme Controller gebaseerd op Flutter's native ChangeNotifier.
/// Werkt standalone met pure Flutter (bijv. met ListenableBuilder of SchrobbeDockThemeScope),
/// maar kan ook naadloos gekoppeld worden met Riverpod, Bloc of Provider.
class SchrobbeDockThemeController extends ChangeNotifier {
  ThemePreferences _preferences = ThemePreferences.defaultPreferences;
  bool _canAccessRobHub = false;
  SharedPreferences? _prefs;
  SupabaseClient? _supabase;
  StreamSubscription<AuthState>? _authSubscription;

  ThemePreferences get preferences => _preferences;
  bool get canAccessRobHub => _canAccessRobHub;
  SupabaseClient? get supabaseClient => _supabase;

  SchrobbeDockThemeController({
    SharedPreferences? prefs,
    SupabaseClient? supabaseClient,
    ThemePreferences initialPreferences = ThemePreferences.defaultPreferences,
  })  : _prefs = prefs,
        _supabase = supabaseClient,
        _preferences = initialPreferences {
    _init();
  }

  void _init() {
    if (_prefs != null) {
      _loadFromLocalPrefs();
    } else {
      SharedPreferences.getInstance().then((sp) {
        _prefs = sp;
        _loadFromLocalPrefs();
        if (_supabase != null) {
          _setupSupabaseSync();
        }
      });
    }

    if (_supabase != null) {
      _setupSupabaseSync();
    }
  }

  void _loadFromLocalPrefs() {
    final sp = _prefs;
    if (sp == null) return;

    final localJson = sp.getString(kSchrobbeDockLocalPrefsKey);
    if (localJson != null) {
      try {
        final decoded = jsonDecode(localJson) as Map<String, dynamic>;
        _preferences = ThemePreferences.fromJson(decoded);
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Koppel een actieve Supabase client voor realtime sync en autorisatiechecks
  void attachSupabase(SupabaseClient client) {
    _supabase = client;
    _setupSupabaseSync();
  }

  void _setupSupabaseSync() {
    final client = _supabase;
    if (client == null) return;

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated) {
        syncFromProfile(forceApply: true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        _preferences = ThemePreferences.defaultPreferences;
        _canAccessRobHub = false;
        notifyListeners();
      }
    });

    if (client.auth.currentUser != null) {
      syncFromProfile();
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

      if (response != null) {
        _canAccessRobHub = response['can_access_robhub'] as bool? ?? false;
        if (response['preferences'] != null) {
          var dbPrefs = ThemePreferences.fromJson(
              response['preferences'] as Map<String, dynamic>);

          if (!_canAccessRobHub && dbPrefs.preset == 'rob_hub') {
            dbPrefs = dbPrefs.copyWith(
              preset: 'amber_rust',
              primaryColor: const Color(0xFFEA580C),
              secondaryColor: const Color(0xFFB45309),
            );
          }

          if (forceApply || _preferences != dbPrefs) {
            _preferences = dbPrefs;
            await _cacheLocally(dbPrefs);
            notifyListeners();
            return;
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_preferences.preset == 'rob_hub') return;
    final updated = _preferences.copyWith(themeMode: mode);
    await _updatePreferences(updated);
  }

  Future<void> applyPreset(ThemePresetItem preset) async {
    final updated = _preferences.copyWith(
      primaryColor: preset.primaryColor,
      secondaryColor: preset.secondaryColor,
      preset: preset.id,
      themeMode: preset.id == 'rob_hub' ? ThemeMode.dark : _preferences.themeMode,
    );
    await _updatePreferences(updated);
  }

  Future<void> setCustomColors({
    required Color primary,
    required Color secondary,
  }) async {
    final updated = _preferences.copyWith(
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
      primaryColor: _preferences.primaryColor,
      secondaryColor: _preferences.secondaryColor,
      themeMode: _preferences.themeMode,
    );

    final updatedList = List<SavedTheme>.from(_preferences.savedThemes)
      ..add(newSaved);
    final updated = _preferences.copyWith(
      preset: 'saved_$newId',
      savedThemes: updatedList,
    );
    await _updatePreferences(updated);
  }

  Future<void> applySavedTheme(SavedTheme saved) async {
    final updated = _preferences.copyWith(
      primaryColor: saved.primaryColor,
      secondaryColor: saved.secondaryColor,
      themeMode: saved.themeMode,
      preset: 'saved_${saved.id}',
    );
    await _updatePreferences(updated);
  }

  Future<void> deleteSavedTheme(String id) async {
    final updatedList =
        _preferences.savedThemes.where((t) => t.id != id).toList();
    String newPreset = _preferences.preset;
    if (_preferences.preset == 'saved_$id') {
      newPreset = 'custom';
    }
    final updated = _preferences.copyWith(
      preset: newPreset,
      savedThemes: updatedList,
    );
    await _updatePreferences(updated);
  }

  Future<void> _updatePreferences(ThemePreferences newPrefs) async {
    _preferences = newPrefs;
    notifyListeners();
    await _cacheLocally(newPrefs);

    final client = _supabase;
    final user = client?.auth.currentUser;
    if (user != null && client != null) {
      try {
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

      try {
        await client.auth.updateUser(
          UserAttributes(data: {'preferences': newPrefs.toJson()}),
        );
      } catch (_) {}
    }
  }

  Future<void> _cacheLocally(ThemePreferences prefs) async {
    try {
      final sp = _prefs ?? await SharedPreferences.getInstance();
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
