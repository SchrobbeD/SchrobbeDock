import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_version.dart';
import 'web_cache/web_cache_helper.dart';

class SystemInfoDialog extends StatefulWidget {
  final String appName;
  final String? customBackendUrl;
  final String githubRepoUrl;

  const SystemInfoDialog({
    super.key,
    this.appName = 'SchrobbeDock',
    this.customBackendUrl,
    this.githubRepoUrl = 'https://github.com/SchrobbeD/SchrobbeDock',
  });

  static Future<void> show(
    BuildContext context, {
    String appName = 'SchrobbeDock',
    String? customBackendUrl,
    String githubRepoUrl = 'https://github.com/SchrobbeD/SchrobbeDock',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SystemInfoDialog(
        appName: appName,
        customBackendUrl: customBackendUrl,
        githubRepoUrl: githubRepoUrl,
      ),
    );
  }

  @override
  State<SystemInfoDialog> createState() => _SystemInfoDialogState();
}

class _SystemInfoDialogState extends State<SystemInfoDialog> {
  bool _isReloading = false;

  String _resolveBackendUrl() {
    if (widget.customBackendUrl != null && widget.customBackendUrl!.isNotEmpty) {
      return widget.customBackendUrl!;
    }
    try {
      final client = Supabase.instance.client;
      final rawUrl = client.rest.url;
      final uri = Uri.tryParse(rawUrl);
      return uri?.origin ?? rawUrl;
    } catch (_) {
      return 'http://127.0.0.1:54321';
    }
  }

  String _getEnvironmentName(String url) {
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return 'Lokaal (Ontwikkeling)';
    }
    if (url.contains('supabase.co')) {
      return 'Cloud Productie';
    }
    return 'Aangepaste Server';
  }

  String _generateDiagnosticsText(String backendUrl) {
    final buffer = StringBuffer();
    buffer.writeln('=== ${widget.appName} Systeemdiagnose ===');
    buffer.writeln('App: ${widget.appName}');
    buffer.writeln('Versie: ${AppVersion.appVersion}');
    buffer.writeln('Git Commit: ${AppVersion.gitCommitSha}');
    buffer.writeln('Build Tijdstip: ${AppVersion.formattedBuildTime}');
    buffer.writeln('Backend URL: $backendUrl');
    buffer.writeln('Omgeving: ${_getEnvironmentName(backendUrl)}');
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backendUrl = _resolveBackendUrl();
    final envName = _getEnvironmentName(backendUrl);
    final githubCommitUrl = AppVersion.githubCommitUrl(repoUrl: widget.githubRepoUrl);

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
                subtitle: '${widget.appName} v${AppVersion.appVersion}',
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
                subtitle: AppVersion.isLocalDev
                    ? 'dev-local (ongecompileerde sessie)'
                    : AppVersion.shortSha,
                subtitleFontFamily: 'monospace',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kopieer Commit SHA',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: AppVersion.gitCommitSha),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Commit SHA gekopieerd naar klembord!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: githubCommitUrl != null
                          ? 'Bekijk commit op GitHub'
                          : 'Bekijk repository op GitHub',
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => _openUrl(githubCommitUrl ?? widget.githubRepoUrl),
                    ),
                  ],
                ),
              ),
              if (AppVersion.isLocalDev)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 4),
                  child: Text(
                    'Tip: Start met --dart-define=GIT_COMMIT_SHA=... voor statische commit tracking.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
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

              // Supabase Backend Omgeving (KLIKBAAR)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openUrl(backendUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildInfoTile(
                    theme: theme,
                    icon: Icons.cloud_done_outlined,
                    title: 'Backend Omgeving (Klik om te openen)',
                    subtitle: '$envName\n$backendUrl',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Kopieer Backend URL',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: backendUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backend URL gekopieerd naar klembord!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Open Backend in browser',
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () => _openUrl(backendUrl),
                        ),
                        const SizedBox(width: 4),
                        Container(
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
                      ],
                    ),
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
              ClipboardData(text: _generateDiagnosticsText(backendUrl)),
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
