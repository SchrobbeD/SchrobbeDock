import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Standaard weergave wanneer een gebruiker is ingelogd, maar geen actieve licentie heeft voor de app.
class NoAccessView extends StatefulWidget {
  /// Unieke slug van de applicatie (bijv. 'raket', 'dock_planner').
  final String appSlug;

  /// Weergavenaam van de applicatie (optioneel).
  final String? appName;

  /// URL van de centrale SchrobbeDock Hub.
  final String hubUrl;

  /// Geeft aan of er al een openstaande aanvraag is.
  final bool initialHasPendingRequest;

  /// Callback wanneer een licentie succesvol is geactiveerd (waardoor de gate opnieuw kan evalueren).
  final VoidCallback? onLicenseActivated;

  const NoAccessView({
    super.key,
    required this.appSlug,
    this.appName,
    this.hubUrl = 'https://robbedillen.be',
    this.initialHasPendingRequest = false,
    this.onLicenseActivated,
  });

  @override
  State<NoAccessView> createState() => _NoAccessViewState();
}

class _NoAccessViewState extends State<NoAccessView> {
  final _codeController = TextEditingController();
  bool _isClaiming = false;
  String? _claimError;
  bool _hasPendingRequest = false;

  @override
  void initState() {
    super.initState();
    _hasPendingRequest = widget.initialHasPendingRequest;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _claimInvitationCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _claimError = 'Voer een uitnodigingscode in.');
      return;
    }

    setState(() {
      _isClaiming = true;
      _claimError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.rpc('claim_invitation', params: {
        'target_code': code,
      });

      if (mounted) {
        final message = res['message'] as String? ?? 'Licentie succesvol geactiveerd!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(message),
          ),
        );
        widget.onLicenseActivated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _claimError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  void _showRequestAccessDialog() {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final displayAppName = widget.appName ?? widget.appSlug;

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Toegang Aanvragen voor $displayAppName')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Geen uitnodigingscode? Je kunt direct een verzoek indienen bij de beheerder.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivering / Toelichting (optioneel)',
                      hintText: 'Waarom wil je toegang tot deze applicatie?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Annuleren'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            final supabase = Supabase.instance.client;
                            final res = await supabase.rpc('request_app_access', params: {
                              'target_app_slug': widget.appSlug,
                              'request_reason': reasonController.text.trim().isEmpty
                                  ? null
                                  : reasonController.text.trim(),
                            });

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                              final message =
                                  res['message'] as String? ?? 'Toegangsaanvraag ingediend!';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(message),
                                ),
                              );
                              setState(() {
                                _hasPendingRequest = true;
                              });
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Fout bij verzenden van aanvraag: $e'),
                                ),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Verzoek Verzenden'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToHub() async {
    final targetUrl = '${widget.hubUrl}/#/dashboard';
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_self');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayAppName = widget.appName ?? widget.appSlug;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 38,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Geen Actieve Licentie',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Je bent ingelogd, maar je SchrobbeDock account heeft momenteel geen actieve licentie voor $displayAppName.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Openstaande aanvraag banner
                    if (_hasPendingRequest) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade800.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Je toegangsaanvraag is momenteel in behandeling bij de beheerder.',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Code Inwisselen Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Heb je een uitnodigingscode ontvangen?',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'bv. DOCK-XXXX-XXXX',
                                    isDense: true,
                                    errorText: _claimError,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _isClaiming ? null : _claimInvitationCode,
                                child: _isClaiming
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Inwisselen'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Knop Toegang Aanvragen (indien nog niet gedaan)
                    if (!_hasPendingRequest) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showRequestAccessDialog,
                          icon: const Icon(Icons.assignment_ind_outlined),
                          label: const Text('Toegang Aanvragen bij Beheerder'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Terug naar Hub knop
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _navigateToHub,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Terug naar SchrobbeDock Hub'),
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
