import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const RegisterScreen({super.key, this.initialCode});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isValidatingCode = false;
  bool _isCodeValid = false;
  List<String> _grantedAppNames = [];
  bool _isRegistering = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if (_codeController.text.trim().isNotEmpty) {
      _validateCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCode = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.rpc(
        'check_invite_code',
        params: {'target_code': code},
      );

      final resultList = response as List<dynamic>;
      if (resultList.isNotEmpty && resultList.first['is_valid'] == true) {
        final rawApps = resultList.first['app_names'] as List<dynamic>?;
        setState(() {
          _isCodeValid = true;
          _grantedAppNames =
              rawApps?.map((e) => e.toString()).toList() ?? [];
        });
      } else {
        setState(() {
          _isCodeValid = false;
          _grantedAppNames = [];
          _errorMessage =
              'Deze uitnodigingscode is ongeldig, verlopen of reeds gebruikt.';
        });
      }
    } catch (e) {
      setState(() {
        _isCodeValid = false;
        _errorMessage = 'Fout bij controleren van code: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingCode = false;
        });
      }
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isCodeValid) {
      setState(() {
        _errorMessage = 'Controleer eerst een geldige uitnodigingscode.';
      });
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'invite_code': _codeController.text.trim(),
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address_street': _streetController.text.trim(),
          'address_number': _numberController.text.trim(),
          'address_postal_code': _postalCodeController.text.trim(),
          'address_city': _cityController.text.trim(),
          'address_country': 'België',
        },
      );
      // Supabase logt de user automatisch in na signUp tenzij email confirmation vereist is
      // De router zorgt vervolgens automatisch voor redirect naar /mfa/enroll
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Er is een fout opgetreden: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    final code = _codeController.text.trim();
    if (!_isCodeValid) {
      if (code.isNotEmpty) {
        await _validateCode();
      }
      if (!_isCodeValid) {
        setState(() {
          _errorMessage = 'Verifieer eerst een geldige uitnodigingscode.';
        });
        return;
      }
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_invite_code', _codeController.text.trim());

      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.schrobbedock://login-callback/',
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google registratie mislukt: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
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
        title: const Text('Account Aanmaken'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Activeer je SchrobbeDock Toegang',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Voer je uitnodigingscode in en vul je gegevens in om je centrale account te activeren.',
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
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Stap 1: Uitnodigingscode
                      Text(
                        '1. Uitnodigingscode',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Code (bijv. DOCK-XXXX-XXXX)',
                                prefixIcon: const Icon(Icons.vpn_key_outlined),
                                border: const OutlineInputBorder(),
                                suffixIcon: _isCodeValid
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : null,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Voer een uitnodigingscode in';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: _isValidatingCode ? null : _validateCode,
                            child: _isValidatingCode
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Verifiëren'),
                          ),
                        ],
                      ),

                      if (_isCodeValid && _grantedAppNames.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified,
                                      color: Colors.green, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Geldige code! Je krijgt direct toegang tot:',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: _grantedAppNames
                                    .map(
                                      (appName) => Chip(
                                        label: Text(appName),
                                        backgroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isRegistering ? null : _registerWithGoogle,
                          icon: const Icon(Icons.account_circle, size: 22),
                          label: _isRegistering
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Direct aanmelden & registreren met Google'),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OF REGISTREER MET WACHTWOORD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stap 2: Persoonlijke gegevens
                      Text(
                        '2. Jouw Gegevens',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'Voornaam',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Achternaam',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'E-mailadres',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || !v.contains('@') ? 'Geldig e-mailadres verplicht' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefoon',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Telefoonnummer is verplicht';
                                }
                                final clean = v.trim();
                                final validCharsRegex = RegExp(r'^[+]?[0-9\s\-\.\(\)]+$');
                                if (!validCharsRegex.hasMatch(clean)) {
                                  return 'Ongeldige tekens';
                                }
                                final digitsOnly = clean.replaceAll(RegExp(r'\D'), '');
                                if (digitsOnly.length < 8 || digitsOnly.length > 15) {
                                  return 'Geldig nummer vereist (min. 8 cijfers)';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _streetController,
                              decoration: const InputDecoration(
                                labelText: 'Straatnaam',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _numberController,
                              decoration: const InputDecoration(
                                labelText: 'Nr.',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Postcode',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'Gemeente / Stad',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Stap 3: Beveiliging
                      Text(
                        '3. Wachtwoord',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Wachtwoord (min. 8 tekens)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Minimaal 8 tekens'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordConfirmController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Wachtwoord Bevestigen',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Wachtwoorden komen niet overeen';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      FilledButton(
                        onPressed:
                            _isRegistering ? null : _submitRegistration,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isRegistering
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Account Aanmaken & Doorgaan naar 2FA',
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
      ),
    );
  }
}
