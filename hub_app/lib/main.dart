import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'router.dart';
import 'theme/schrobbedock_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
  );

  runApp(
    const ProviderScope(
      child: HubApp(),
    ),
  );
}

class HubApp extends ConsumerWidget {
  const HubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themePrefs = ref.watch(themePreferencesProvider);

    return MaterialApp.router(
      title: 'SchrobbeDock Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(themePrefs),
      darkTheme: AppTheme.buildDarkTheme(themePrefs),
      themeMode: themePrefs.themeMode,
      routerConfig: router,
    );
  }
}
