import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_required_view.dart';
import 'no_access_view.dart';

/// Universele authenticatie- en licentie-guard voor alle Spoke apps binnen het SchrobbeDock ecosysteem.
class LicenseGate extends StatefulWidget {
  /// Unieke slug van de applicatie (bijv. 'raket').
  final String appSlug;

  /// De hoofdapplicatie / child widget die uitsluitend getoond wordt wanneer de gebruiker
  /// ingelogd is én over een actieve licentie beschikt.
  final Widget child;

  /// Weergavenaam van de app (optioneel, gebruikt in headers en uitleg).
  final String? appName;

  /// URL van de centrale SchrobbeDock Hub (standaard: https://robbedillen.be).
  final String hubUrl;

  /// Optionele custom loading widget.
  final Widget? loadingWidget;

  /// Optionele custom builder wanneer inloggen vereist is.
  final Widget Function(BuildContext context)? loginRequiredBuilder;

  /// Optionele custom builder wanneer de gebruiker geen licentie heeft.
  final Widget Function(BuildContext context, VoidCallback onRefresh)? noAccessBuilder;

  const LicenseGate({
    super.key,
    required this.appSlug,
    required this.child,
    this.appName,
    this.hubUrl = 'https://robbedillen.be',
    this.loadingWidget,
    this.loginRequiredBuilder,
    this.noAccessBuilder,
  });

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

/// Aliashulp voor ontwikkelaars die de term SchrobbeDockAuthGuard prefereren.
typedef SchrobbeDockAuthGuard = LicenseGate;

class _LicenseGateState extends State<LicenseGate> {
  bool _isLoading = true;
  bool _hasLicense = false;
  bool _hasPendingRequest = false;
  String? _licenseRole;
  String? _licenseTier;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
    _verifyAccess();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _verifyAccess();
      }
    });
  }

  Future<void> _verifyAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLicense = false;
          _hasPendingRequest = false;
        });
      }
      return;
    }

    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final supabase = Supabase.instance.client;

      // 1. Zoek actieve licentie voor deze specifieke app
      final licenseRes = await supabase
          .from('user_licenses')
          .select('tier, role, valid_until, apps!inner(id, slug, is_active)')
          .eq('user_id', user.id)
          .eq('apps.slug', widget.appSlug)
          .eq('apps.is_active', true)
          .maybeSingle();

      if (licenseRes != null) {
        final validUntilRaw = licenseRes['valid_until'] as String?;
        final validUntil = validUntilRaw != null ? DateTime.tryParse(validUntilRaw) : null;
        final isValid = validUntil == null || validUntil.isAfter(DateTime.now());

        if (isValid) {
          if (mounted) {
            setState(() {
              _hasLicense = true;
              _hasPendingRequest = false;
              _licenseRole = licenseRes['role'] as String?;
              _licenseTier = licenseRes['tier'] as String?;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 2. Indien geen actieve licentie, controleer of er een openstaande aanvraag is
      final requestRes = await supabase
          .from('license_requests')
          .select('id, status, apps!inner(slug)')
          .eq('user_id', user.id)
          .eq('apps.slug', widget.appSlug)
          .eq('status', 'pending')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasLicense = false;
          _hasPendingRequest = requestRes != null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLicense = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (widget.loginRequiredBuilder != null) {
        return widget.loginRequiredBuilder!(context);
      }
      return LoginRequiredView(
        hubUrl: widget.hubUrl,
        appName: widget.appName,
      );
    }

    if (!_hasLicense) {
      if (widget.noAccessBuilder != null) {
        return widget.noAccessBuilder!(context, _verifyAccess);
      }
      return NoAccessView(
        appSlug: widget.appSlug,
        appName: widget.appName,
        hubUrl: widget.hubUrl,
        initialHasPendingRequest: _hasPendingRequest,
        onLicenseActivated: _verifyAccess,
      );
    }

    return _LicenseScope(
      role: _licenseRole,
      tier: _licenseTier,
      child: widget.child,
    );
  }
}

/// InheritedWidget om de rol en tier binnen de app gemakkelijk uit te lezen.
class _LicenseScope extends InheritedWidget {
  final String? role;
  final String? tier;

  const _LicenseScope({
    required this.role,
    required this.tier,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LicenseScope oldWidget) {
    return role != oldWidget.role || tier != oldWidget.tier;
  }
}

/// Helper extension om gemakkelijk licentie-informatie op te vragen vanuit de context.
extension LicenseContextExtension on BuildContext {
  String? get userLicenseRole {
    final scope = dependOnInheritedWidgetOfExactType<_LicenseScope>();
    return scope?.role;
  }

  String? get userLicenseTier {
    final scope = dependOnInheritedWidgetOfExactType<_LicenseScope>();
    return scope?.tier;
  }
}
