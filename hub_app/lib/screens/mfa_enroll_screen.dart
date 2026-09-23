import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';

class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _codeController = TextEditingController();

  bool _isLoading = true;
  bool _isVerifying = false;
  String? _factorId;
  String? _totpUri;
  String? _secret;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // 1. Ruim eventuele afgebroken / onbevestigde factoren van eerdere sessies op
      try {
        await supabase.rpc('cleanup_unverified_mfa_factors');
      } catch (_) {}

      // 2. Controleer of er al een geverifieerde factor is
      final factors = await supabase.auth.mfa.listFactors();
      for (final factor in factors.totp) {
        if (factor.status.name == 'verified') {
          if (mounted) {
            context.go('/mfa/verify');
            return;
          }
        }
      }

      final response = await supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: 'SchrobbeDock Hub',
      );

      setState(() {
        _factorId = response.id;
        _totpUri = response.totp?.uri;
        _secret = response.totp?.secret;
      });
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fout bij starten van 2FA setup: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Voer een geldige 6-cijferige code in.';
      });
      return;
    }

    if (_factorId == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.mfa.challengeAndVerify(
        factorId: _factorId!,
        code: code,
      );

      if (mounted) {
        // Router stuurt automatisch door naar /dashboard door de aal2 status
        context.go('/dashboard');
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Verificatie mislukt: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Tweeledige Verificatie (2FA) Instellen'),
        actions: [
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.security,
                            size: 52,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Verplichte 2FA Beveiliging',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan onderstaande QR-code met je Authenticator app (zoals Google Authenticator of 1Password).',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Foutmelding
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // QR Code Container
                          if (_totpUri != null) ...[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: _totpUri!,
                                  version: QrVersions.auto,
                                  size: 200,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Handmatige code optie
                          if (_secret != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sleutel: $_secret',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: 'Kopieer geheime sleutel',
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _secret!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sleutel gekopieerd!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Code input
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              labelText: '6-cijferige verificatiecode',
                              hintText: '000000',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onChanged: (val) {
                              if (val.trim().length == 6 && !_isVerifying) {
                                _verifyAndActivate();
                              }
                            },
                            onFieldSubmitted: (_) => _verifyAndActivate(),
                          ),
                          const SizedBox(height: 20),

                          FilledButton(
                            onPressed:
                                _isVerifying ? null : _verifyAndActivate,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '2FA Activeren & Inloggen',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
