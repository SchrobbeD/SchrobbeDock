import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_license.dart';
import '../providers.dart';
import '../theme/schrobbedock_theme.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

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

        ref.invalidate(userLicensesProvider);
        ref.invalidate(canAccessRobHubProvider);
        await ref
            .read(themePreferencesProvider.notifier)
            .syncFromProfile(forceApply: true);

        if (!mounted) return;
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
                            ref.invalidate(canAccessRobHubProvider);
                            await ref
                                .read(themePreferencesProvider.notifier)
                                .syncFromProfile(forceApply: true);

                            if (!context.mounted) return;
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

  Future<void> _showUserActionMenu(BuildContext context, bool isSuperAdmin, String userEmail, {int unreadCount = 0}) {
    return showModalBottomSheet(
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
                  leading: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.support_agent_outlined),
                  ),
                  title: const Text('Mijn Meldingen & Status'),
                  subtitle: const Text('Bekijk je ingediende meldingen en chat'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/my-feedback');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Uiterlijk & Thema'),
                  subtitle: const Text('Kleur- en donkere modus personalisatie'),
                  onTap: () {
                    Navigator.pop(context);
                    ThemeCustomizerDialog.show(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Probleem Melden / Feedback'),
                  subtitle: const Text('Meld een bug, verbetering of vraag'),
                  onTap: () {
                    Navigator.pop(context);
                    SchrobbeDockFeedback.show(context, appSlug: 'hub_admin');
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
                if (isSuperAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Uitnodigingen & Gebruikers'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/admin/invites');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('Feedback & Bug Meldingen'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/admin/feedback');
                    },
                  ),
                ],
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
    final themePrefs = ref.watch(themePreferencesProvider);
    final isMobile = MediaQuery.of(context).size.width < 650;
    final userEmail = user?.email ?? '';
    final isRobHub = themePrefs.preset == 'rob_hub';
    final unreadUserFeedback = ref.watch(unreadUserFeedbackCountProvider).value ?? 0;
    final unreadAdminFeedback = ref.watch(unreadAdminFeedbackCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: isRobHub
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rob',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA31A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Hub',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
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
                  const Flexible(
                    child: Text(
                      'SchrobbeDock Hub',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
        actions: [
          // Mijn Meldingen knop
          IconButton(
            tooltip: 'Mijn Meldingen & Status',
            icon: Badge(
              isLabelVisible: unreadUserFeedback > 0,
              label: Text('$unreadUserFeedback'),
              child: const Icon(Icons.support_agent_outlined),
            ),
            onPressed: () => context.go('/my-feedback'),
          ),

          // Feedback knop
          IconButton(
            tooltip: 'Probleem Melden / Feedback',
            icon: const Icon(Icons.feedback_outlined),
            onPressed: () => SchrobbeDockFeedback.show(context, appSlug: 'hub_admin'),
          ),

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

          if (isSuperAdmin && !isMobile) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                isLabelVisible: unreadAdminFeedback > 0,
                label: Text('$unreadAdminFeedback'),
                alignment: const AlignmentDirectional(1.0, -1.0),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/admin/feedback'),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Feedback Beheer'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/admin/invites'),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Admin Beheer'),
              ),
            ),
          ],

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
                  case 'profile':
                    context.go('/profile');
                    break;
                  case 'my_feedback':
                    context.go('/my-feedback');
                    break;
                  case 'feedback':
                    SchrobbeDockFeedback.show(context, appSlug: 'hub_admin');
                    break;
                  case 'theme':
                    ThemeCustomizerDialog.show(context);
                    break;
                  case 'claim':
                    _showClaimCodeDialog();
                    break;
                  case 'admin':
                    context.go('/admin/invites');
                    break;
                  case 'admin_feedback':
                    context.go('/admin/feedback');
                    break;
                  case 'system_info':
                    SystemInfoDialog.show(context);
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
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Mijn Profiel & Account'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'my_feedback',
                  child: Row(
                    children: [
                      Badge(
                        isLabelVisible: unreadUserFeedback > 0,
                        label: Text('$unreadUserFeedback'),
                        child: const Icon(Icons.support_agent_outlined, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Mijn Meldingen & Status'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'feedback',
                  child: Row(
                    children: [
                      Icon(Icons.feedback_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Probleem Melden / Feedback'),
                    ],
                  ),
                ),
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
                if (isSuperAdmin) ...[
                  const PopupMenuItem<String>(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Uitnodigingen & Gebruikers'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'admin_feedback',
                    child: Row(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Feedback & Meldingen'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'system_info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 12),
                        Text('Systeem- & Versie-info'),
                      ],
                    ),
                  ),
                ],
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
              onDestinationSelected: (idx) async {
                setState(() => _mobileNavIndex = idx);
                if (idx == 1) {
                  await ThemeCustomizerDialog.show(context);
                  if (mounted) setState(() => _mobileNavIndex = 0);
                } else if (idx == 2) {
                  await _showUserActionMenu(context, isSuperAdmin, userEmail, unreadCount: unreadUserFeedback);
                  if (mounted) setState(() => _mobileNavIndex = 0);
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
                              mainAxisExtent: 165,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onLaunchTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: isBounded
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  // Bovenbalk van de kaart: Icoon links, Info knopje rechtsboven
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.launch_outlined,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Informatie & Licentiedetails',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: onInfoTap,
                      ),
                    ],
                  ),
                  if (!isBounded) const SizedBox(height: 14),
                  // Applicatienaam & openen-link
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                ],
              ),
            ),
          ),
        );
      },
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
      ref.invalidate(canAccessRobHubProvider);
      await ref
          .read(themePreferencesProvider.notifier)
          .syncFromProfile(forceApply: true);
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
