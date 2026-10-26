import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Standaard weergave wanneer een gebruiker niet is aangemeld in de Spoke app.
class LoginRequiredView extends StatelessWidget {
  /// URL van de centrale SchrobbeDock Hub (bijv. https://robbedillen.be).
  final String hubUrl;

  /// Optionele titel voor de applicatie.
  final String? appName;

  const LoginRequiredView({
    super.key,
    this.hubUrl = 'https://robbedillen.be',
    this.appName,
  });

  Future<void> _navigateToLogin(BuildContext context) async {
    final currentUri = Uri.base.toString();
    final redirectParam = Uri.encodeComponent(currentUri);
    final targetUrl = '$hubUrl/#/login?redirect=$redirectParam';

    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_self');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kon niet doorverwijzen naar: $targetUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayAppName = appName ?? 'deze applicatie';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_person_outlined,
                        size: 38,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Aanmelden Vereist',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Om gebruik te maken van $displayAppName moet je ingelogd zijn met je centrale SchrobbeDock account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _navigateToLogin(context),
                        icon: const Icon(Icons.login),
                        label: const Text(
                          'Aanmelden via SchrobbeDock Hub',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
