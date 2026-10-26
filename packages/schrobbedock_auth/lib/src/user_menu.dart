import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Herbruikbare gebruikersmenu-knop (Avatar + Dropdown) voor in de AppBar van elke Spoke app.
class SchrobbeDockUserMenu extends StatelessWidget {
  /// URL van de centrale SchrobbeDock Hub.
  final String hubUrl;

  /// Optionele actie wanneer de gebruiker uitlogt.
  final VoidCallback? onSignedOut;

  const SchrobbeDockUserMenu({
    super.key,
    this.hubUrl = 'https://robbedillen.be',
    this.onSignedOut,
  });

  Future<void> _openUrl(String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_self');
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      onSignedOut?.call();
      _openUrl('$hubUrl/#/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij uitloggen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final email = user.email ?? 'Gebruiker';
    final metadata = user.userMetadata ?? {};
    final firstName = metadata['first_name'] as String? ?? '';
    final lastName = metadata['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : email;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      tooltip: 'Account & Profiel',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(
          initial,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      itemBuilder: (context) => [
        // Header met gebruikersinfo
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (fullName.isNotEmpty)
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              const Divider(),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20),
              SizedBox(width: 12),
              Text('Mijn Profiel & 2FA'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'hub',
          child: Row(
            children: [
              Icon(Icons.dashboard_outlined, size: 20),
              SizedBox(width: 12),
              Text('Centrale Hub Dashboard'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Uitloggen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'profile':
            _openUrl('$hubUrl/#/profile');
            break;
          case 'hub':
            _openUrl('$hubUrl/#/dashboard');
            break;
          case 'logout':
            _handleSignOut(context);
            break;
        }
      },
    );
  }
}
