import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_license.dart';

/// Provider for the global SupabaseClient instance
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream of Supabase Auth state changes
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Current authenticated user (derived from authStateChangesProvider or current session)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

/// Asynchronously fetch the active user licenses with joined app details
final userLicensesProvider = FutureProvider<List<UserLicense>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const [];
  }

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('user_licenses')
      .select('id, user_id, app_id, tier, role, valid_until, created_at, apps(id, slug, name, is_active)')
      .eq('user_id', user.id);

  final dataList = response as List<dynamic>;
  return dataList
      .map((item) => UserLicense.fromJson(item as Map<String, dynamic>))
      .toList();
});

/// Convenience provider to verify if the user has access to a specific app slug
final hasAppAccessProvider = Provider.family<bool, String>((ref, appSlug) {
  final licensesAsync = ref.watch(userLicensesProvider);
  return licensesAsync.maybeWhen(
    data: (licenses) => licenses.any(
      (license) =>
          license.app?.slug == appSlug &&
          (license.app?.isActive ?? false) &&
          license.isValid,
    ),
    orElse: () => false,
  );
});

/// Check if the currently logged in user is a super admin for the Hub
final isSuperAdminProvider = Provider<bool>((ref) {
  final licensesAsync = ref.watch(userLicensesProvider);
  return licensesAsync.maybeWhen(
    data: (licenses) => licenses.any(
      (license) =>
          license.app?.slug == 'hub_admin' &&
          license.role == 'super_admin' &&
          license.isValid,
    ),
    orElse: () => false,
  );
});

/// Provider for list of all available apps (used in admin invite generator)
final allAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('apps')
      .select('id, slug, name, is_active')
      .order('name');

  return (response as List<dynamic>)
      .map((item) => AppInfo.fromJson(item as Map<String, dynamic>))
      .toList();
});
