import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_license.dart';
import '../providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final licensesAsync = ref.watch(userLicensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SchrobbeDock Hub'),
        actions: [
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.apps_outage_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Geen actieve licenties gevonden.',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Neem contact op met de beheerder om toegang te verkrijgen.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
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
