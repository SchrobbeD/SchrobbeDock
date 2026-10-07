import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_version.dart';
import '../config/supabase_config.dart';
import '../utils/web_cache_helper.dart';

class SystemInfoDialog extends StatefulWidget {
  const SystemInfoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SystemInfoDialog(),
    );
  }

  @override
  State<SystemInfoDialog> createState() => _SystemInfoDialogState();
}

class _SystemInfoDialogState extends State<SystemInfoDialog> {
  bool _isReloading = false;

  String _getEnvironmentName(String url) {
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return 'Lokaal (Ontwikkeling)';
    }
    if (url.contains('supabase.co')) {
      return 'Cloud Productie';
    }
    return 'Aangepaste Server';
  }

  String _generateDiagnosticsText(String supabaseUrl) {
    final buffer = StringBuffer();
    buffer.writeln('=== SchrobbeDock Systeemdiagnose ===');
    buffer.writeln('App: SchrobbeDock Hub');
    buffer.writeln('Versie: ${AppVersion.appVersion}');
    buffer.writeln('Git Commit: ${AppVersion.gitCommitSha}');
    buffer.writeln('Build Tijdstip: ${AppVersion.formattedBuildTime}');
    buffer.writeln('Supabase URL: $supabaseUrl');
    buffer.writeln('Omgeving: ${_getEnvironmentName(supabaseUrl)}');
    buffer.writeln('Tijdstip: ${DateTime.now().toIso8601String()}');
    return buffer.toString();
  }

  Future<void> _handleHardReload() async {
    setState(() => _isReloading = true);
    await WebCacheHelper.clearCacheAndReload();
    if (mounted) {
      setState(() => _isReloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache gewist (in niet-web modus wordt niet herladen).'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const supabaseUrl = SupabaseConfig.url;
    final envName = _getEnvironmentName(supabaseUrl);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Systeem- & Versie-info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Applicatie & Versie
              _buildInfoTile(
                theme: theme,
                icon: Icons.layers_outlined,
                title: 'Applicatie & Versie',
                subtitle: 'SchrobbeDock Hub v${AppVersion.appVersion}',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v${AppVersion.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const Divider(height: 20),

              // Git Commit SHA
              _buildInfoTile(
                theme: theme,
                icon: Icons.commit_outlined,
                title: 'Git Commit',
                subtitle: AppVersion.shortSha,
                subtitleFontFamily: 'monospace',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kopieer Commit SHA',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: AppVersion.gitCommitSha),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Commit SHA gekopieerd naar klembord!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    if (AppVersion.githubCommitUrl != null)
                      IconButton(
                        tooltip: 'Bekijk op GitHub',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () {
                          launchUrl(
                            Uri.parse(AppVersion.githubCommitUrl!),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Build Datum & Tijd
              _buildInfoTile(
                theme: theme,
                icon: Icons.schedule_outlined,
                title: 'Build Tijdstip',
                subtitle: AppVersion.formattedBuildTime,
              ),
              const Divider(height: 20),

              // Supabase Backend Omgeving
              _buildInfoTile(
                theme: theme,
                icon: Icons.cloud_done_outlined,
                title: 'Backend Omgeving',
                subtitle: '$envName ($supabaseUrl)',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'Verbonden',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Cache Reset Kaart
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cached,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Browsercache & Service Worker',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Wist gecachte web-scripts en forceert een harde herlaadactie. Je blijft veilig ingelogd.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: _isReloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(_isReloading
                            ? 'Bezig met herladen...'
                            : 'Cache Legen & Geforceerd Herladen'),
                        onPressed: _isReloading ? null : _handleHardReload,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('Kopieer Diagnose Info'),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _generateDiagnosticsText(supabaseUrl)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Diagnose-info gekopieerd naar klembord!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    String? subtitleFontFamily,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: subtitleFontFamily,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
