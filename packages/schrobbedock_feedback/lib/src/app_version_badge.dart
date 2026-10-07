import 'package:flutter/material.dart';
import 'app_version.dart';
import 'system_info_dialog.dart';

class AppVersionBadge extends StatelessWidget {
  final String appName;
  final String? customBackendUrl;
  final String githubRepoUrl;

  const AppVersionBadge({
    super.key,
    this.appName = 'SchrobbeDock',
    this.customBackendUrl,
    this.githubRepoUrl = 'https://github.com/SchrobbeD/SchrobbeDock',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Center(
        child: Tooltip(
          message: 'Systeem- & Versie-informatie bekijken',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => SystemInfoDialog.show(
              context,
              appName: appName,
              customBackendUrl: customBackendUrl,
              githubRepoUrl: githubRepoUrl,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppVersion.badgeDisplay,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
