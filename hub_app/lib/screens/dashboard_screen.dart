import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_license.dart';
import '../providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isCheckingPendingInvite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndClaimPendingInvite();
    });
  }

  Future<void> _checkAndClaimPendingInvite() async {
    if (_isCheckingPendingInvite) return;
    _isCheckingPendingInvite = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCode = prefs.getString('pending_invite_code');

      if (pendingCode != null && pendingCode.trim().isNotEmpty) {
        await prefs.remove('pending_invite_code');

        if (!mounted) return;
        final supabase = ref.read(supabaseClientProvider);
        final result = await supabase.rpc(
          'claim_invitation',
          params: {'target_code': pendingCode.trim()},
        );

        if (!mounted) return;
        ref.invalidate(userLicensesProvider);

        final apps = (result['apps'] as List<dynamic>?)?.join(', ') ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    apps.isNotEmpty
                        ? 'Welkom! Licenties succesvol geactiveerd voor: $apps'
                        : 'Uitnodigingscode succesvol gekoppeld!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: Text('Kon opgeslagen uitnodiging niet activeren: $e'),
          ),
        );
      }
    } finally {
      _isCheckingPendingInvite = false;
    }
  }

  void _showClaimCodeDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.vpn_key_outlined),
                  SizedBox(width: 8),
                  Text('Uitnodigingscode Inwisselen'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voer je uitnodigingscode in om licenties voor nieuwe applicaties te activeren op jouw account.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Uitnodigingscode (bijv. DOCK-XXXX-XXXX)',
                      border: const OutlineInputBorder(),
                      errorText: errorMsg,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              errorMsg = 'Voer een code in';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });

                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            final result = await supabase.rpc(
                              'claim_invitation',
                              params: {'target_code': code},
                            );

                            if (!context.mounted) return;
                            ref.invalidate(userLicensesProvider);
                            Navigator.pop(context);

                            final apps = (result['apps'] as List<dynamic>?)
                                    ?.join(', ') ??
                                '';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green,
                                content: Text(
                                  apps.isNotEmpty
                                      ? 'Licenties geactiveerd voor: $apps!'
                                      : 'Uitnodiging succesvol geactiveerd!',
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = e.toString().replaceFirst(
                                  'Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Activeren'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final licensesAsync = ref.watch(userLicensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SchrobbeDock Hub'),
        actions: [
          IconButton(
            tooltip: 'Uitnodigingscode inwisselen',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: _showClaimCodeDialog,
          ),
          if (isSuperAdmin)
            FilledButton.tonalIcon(
              onPressed: () => context.go('/admin/invites'),
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text('Admin Beheer'),
            ),
          if (user?.email != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  user!.email!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Uitloggen',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final supabase = ref.read(supabaseClientProvider);
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beschikbare Applicaties & Licenties',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Centraal overzicht van de applicaties waarvoor jouw account geautoriseerd is.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: licensesAsync.when(
                    data: (licenses) {
                      if (licenses.isEmpty) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: _ClaimInviteCard(
                              onSuccess: () =>
                                  ref.invalidate(userLicensesProvider),
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: licenses.length,
                        itemBuilder: (context, index) {
                          final license = licenses[index];
                          return _AppLicenseCard(license: license);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text('Fout bij ophalen van licenties: $error'),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => ref.refresh(userLicensesProvider),
                            child: const Text('Opnieuw proberen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaimInviteCard extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _ClaimInviteCard({required this.onSuccess});

  @override
  ConsumerState<_ClaimInviteCard> createState() => _ClaimInviteCardState();
}

class _ClaimInviteCardState extends ConsumerState<_ClaimInviteCard> {
  final _controller = TextEditingController();
  bool _isClaiming = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claimCode() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Voer een uitnodigingscode in.';
      });
      return;
    }

    setState(() {
      _isClaiming = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase.rpc(
        'claim_invitation',
        params: {'target_code': code},
      );

      final apps = (result['apps'] as List<dynamic>?)?.join(', ') ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              apps.isNotEmpty
                  ? 'Licenties geactiveerd voor: $apps!'
                  : 'Uitnodigingscode succesvol gekoppeld!',
            ),
          ),
        );
      }
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              e.toString().replaceFirst('Exception: ', '').replaceAll('"', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.card_membership_outlined,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Geen Actieve Licenties Gevonden',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Jouw account heeft nog geen gekoppelde applicaties. Heb je een uitnodigingscode ontvangen? Activeer hem hier direct:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Uitnodigingscode (bijv. DOCK-XXXX-XXXX)',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _isClaiming ? null : _claimCode,
              icon: _isClaiming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Licenties Activeren'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLicenseCard extends StatelessWidget {
  final UserLicense license;

  const _AppLicenseCard({required this.license});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = license.app;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app?.name ?? 'Onbekende App',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Slug: ${app?.slug ?? license.appId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Chip(
                  label: Text('Tier: ${license.tier.toUpperCase()}'),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(license.role),
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
