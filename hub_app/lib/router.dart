import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
import 'screens/admin_invites_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mfa_enroll_screen.dart';
import 'screens/mfa_verify_screen.dart';
import 'screens/register_screen.dart';

/// Listenable adapter converting a Stream into a Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider for the GoRouter configuration with auth-based and MFA-based redirection
final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final refreshListenable = GoRouterRefreshStream(supabase.auth.onAuthStateChange);

  ref.onDispose(() {
    refreshListenable.dispose();
  });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isAuthenticated = session != null;
      final path = state.matchedLocation;

      final isLoginRoute = path == '/login';
      final isRegisterRoute = path.startsWith('/register');
      final isPublicRoute = isLoginRoute || isRegisterRoute;

      // 1. Niet ingelogd
      if (!isAuthenticated) {
        if (!isPublicRoute) {
          return '/login';
        }
        return null;
      }

      // 2. Ingelogd: Controleer Two-Factor Authentication (MFA)
      final aal = supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      final currentLevel = aal.currentLevel?.name ?? 'aal1';
      final nextLevel = aal.nextLevel?.name ?? 'aal1';

      final user = session.user;
      final provider = user.appMetadata['provider'] as String? ?? 'email';
      final isGoogleUser = provider == 'google';
      final isAdminRoute = path.startsWith('/admin');

      // Hybride MFA Beleid:
      // - Verplicht voor e-mail/wachtwoord gebruikers (!isGoogleUser)
      // - Verplicht voor iedereen die beheerderstaken uitvoert (isAdminRoute)
      // - Verplicht indien een gebruiker reeds een TOTP factor gekoppeld heeft (nextLevel == 'aal2')
      final requiresMfa = !isGoogleUser || isAdminRoute || nextLevel == 'aal2';

      if (requiresMfa) {
        // Geval A: Nog geen MFA factor geregistreerd -> verplicht instellen
        if (currentLevel == 'aal1' && nextLevel == 'aal1') {
          if (path != '/mfa/enroll') {
            return '/mfa/enroll';
          }
          return null;
        }

        // Geval B: Factor geregistreerd, maar sessie vereist nog 2FA challenge
        if (currentLevel == 'aal1' && nextLevel == 'aal2') {
          if (path != '/mfa/verify') {
            return '/mfa/verify';
          }
          return null;
        }
      }

      // Geval C: Volledig geauthenticeerd of vrijgestelde Google gebruiker
      if (currentLevel == 'aal2' || isGoogleUser) {
        // Indien op root, auth of voltooide MFA schermen, stuur door naar dashboard
        if (path == '/' || isPublicRoute || (path.startsWith('/mfa') && currentLevel == 'aal2')) {
          return '/dashboard';
        }
      }

      // Indien ingelogd maar op ongedefinieerd root pad
      if (path == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return RegisterScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: '/mfa/enroll',
        name: 'mfa_enroll',
        builder: (context, state) => const MfaEnrollScreen(),
      ),
      GoRoute(
        path: '/mfa/verify',
        name: 'mfa_verify',
        builder: (context, state) => const MfaVerifyScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/admin/invites',
        name: 'admin_invites',
        builder: (context, state) => const AdminInvitesScreen(),
      ),
    ],
  );
});
