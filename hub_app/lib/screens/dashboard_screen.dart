import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_license.dart';
import '../providers.dart';
import '../widgets/theme_customizer_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isCheckingPendingInvite = false;
  int _mobileNavIndex = 0;

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

  void _showAppInfoDialog(UserLicense license) {
    final app = license.app;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.layers_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app?.name ?? 'Applicatie Details',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Slug: ${app?.slug ?? license.appId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 12),
              _buildInfoRow(context, 'Licentie Tier', license.tier.toUpperCase()),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Toegewezen Rol', license.role),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Geldig Tot',
                license.validUntil != null
                    ? '${license.validUntil!.day.toString().padLeft(2, '0')}-${license.validUntil!.month.toString().padLeft(2, '0')}-${license.validUntil!.year}'
                    : 'Onbeperkt actief',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Toegang wordt centraal geverifieerd via SchrobbeDock Single Sign-On.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showUserActionMenu(BuildContext context, bool isSuperAdmin, String userEmail) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isSuperAdmin ? 'Super Administrator' : 'Ecosysteem Gebruiker'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Uiterlijk & Thema'),
                  subtitle: const Text('Kleur- en donkere modus personalisatie'),
                  onTap: () {
                    Navigator.pop(context);
                    ThemeCustomizerDialog.show(context);
                  },
                ),
                if (!isSuperAdmin)
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: const Text('Uitnodigingscode Inwisselen'),
                    onTap: () {
                      Navigator.pop(context);
                      _showClaimCodeDialog();
                    },
                  ),
                if (isSuperAdmin)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Admin Beheer'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/admin/invites');
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Uitloggen', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    final supabase = ref.read(supabaseClientProvider);
                    await supabase.auth.signOut();
                  },
                ),
              ],
            ),
          ),
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
    final isMobile = MediaQuery.of(context).size.width < 650;
    final userEmail = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.layers_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SchrobbeDock Hub',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Snelkoppeling naar Thema Modal op desktop
          if (!isMobile)
            IconButton(
              tooltip: 'Uiterlijk & Thema',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => ThemeCustomizerDialog.show(context),
            ),

          if (!isSuperAdmin && !isMobile)
            IconButton(
              tooltip: 'Uitnodigingscode inwisselen',
              icon: const Icon(Icons.vpn_key_outlined),
              onPressed: _showClaimCodeDialog,
            ),

          if (isSuperAdmin && !isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/admin/invites'),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Admin Beheer'),
              ),
            ),

          // User Avatar met Dropdown Menu
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: PopupMenuButton<String>(
              tooltip: 'Gebruikersmenu',
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                child: Text(
                  userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'theme':
                    ThemeCustomizerDialog.show(context);
                    break;
                  case 'claim':
                    _showClaimCodeDialog();
                    break;
                  case 'admin':
                    context.go('/admin/invites');
                    break;
                  case 'logout':
                    final supabase = ref.read(supabaseClientProvider);
                    await supabase.auth.signOut();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSuperAdmin ? 'Super Administrator' : 'Gebruiker',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Uiterlijk & Thema'),
                    ],
                  ),
                ),
                if (!isSuperAdmin)
                  const PopupMenuItem<String>(
                    value: 'claim',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Code Inwisselen'),
                      ],
                    ),
                  ),
                if (isSuperAdmin)
                  const PopupMenuItem<String>(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Admin Beheer'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Uitloggen', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _mobileNavIndex,
              onDestinationSelected: (idx) {
                setState(() => _mobileNavIndex = idx);
                if (idx == 1) {
                  ThemeCustomizerDialog.show(context);
                } else if (idx == 2) {
                  _showUserActionMenu(context, isSuperAdmin, userEmail);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Apps',
                ),
                NavigationDestination(
                  icon: Icon(Icons.palette_outlined),
                  selectedIcon: Icon(Icons.palette),
                  label: 'Thema',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mijn Applicaties',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecteer een applicatie om direct te starten.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
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

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth <= 0) {
                            return const SizedBox.shrink();
                          }
                          if (constraints.maxWidth < 340) {
                            return ListView.separated(
                              itemCount: licenses.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final license = licenses[index];
                                return _SimpleAppCard(
                                  license: license,
                                  onInfoTap: () => _showAppInfoDialog(license),
                                  onLaunchTap: () {
                                    final appName =
                                        license.app?.name ?? 'de applicatie';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$appName wordt gestart...',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.25,
                            ),
                            itemCount: licenses.length,
                            itemBuilder: (context, index) {
                              final license = licenses[index];
                              return _SimpleAppCard(
                                license: license,
                                onInfoTap: () => _showAppInfoDialog(license),
                                onLaunchTap: () {
                                  final appName =
                                      license.app?.name ?? 'de applicatie';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$appName wordt gestart...',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          );
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

class _SimpleAppCard extends StatelessWidget {
  final UserLicense license;
  final VoidCallback onInfoTap;
  final VoidCallback onLaunchTap;

  const _SimpleAppCard({
    required this.license,
    required this.onInfoTap,
    required this.onLaunchTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = license.app;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onLaunchTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bovenbalk van de kaart: Icoon links, Info knopje rechtsboven
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.launch_outlined,
                      size: 26,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Informatie & Licentiedetails',
                    icon: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onInfoTap,
                  ),
                ],
              ),
              const Spacer(),
              // Applicatienaam (strak, prominent)
              Text(
                app?.name ?? 'Onbekende App',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Klik om te openen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
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
      elevation: 0,
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
