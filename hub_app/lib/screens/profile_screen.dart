import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Controllers voor persoonsgegevens
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _numberController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;

  // Beveiligingsstatus
  bool _hasMfa = false;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _streetController = TextEditingController();
    _numberController = TextEditingController();
    _postalCodeController = TextEditingController();
    _cityController = TextEditingController();
    _countryController = TextEditingController(text: 'België');

    _loadProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      SupabaseClient? supabase;
      try {
        supabase = ref.read(supabaseClientProvider);
      } catch (_) {
        // Supabase niet geïnitialiseerd (bijv. tijdens widget tests)
      }

      if (supabase != null) {
        // Profiel ophalen
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          _firstNameController.text = profile['first_name'] as String? ?? '';
          _lastNameController.text = profile['last_name'] as String? ?? '';
          _phoneController.text = profile['phone'] as String? ?? '';
          _streetController.text = profile['address_street'] as String? ?? '';
          _numberController.text = profile['address_number'] as String? ?? '';
          _postalCodeController.text = profile['address_postal_code'] as String? ?? '';
          _cityController.text = profile['address_city'] as String? ?? '';
          _countryController.text = profile['address_country'] as String? ?? 'België';

          final createdAtRaw = profile['created_at'] as String?;
          if (createdAtRaw != null) {
            _createdAt = DateTime.tryParse(createdAtRaw);
          }
        }

        // MFA status controleren
        try {
          final factors = await supabase.auth.mfa.listFactors();
          _hasMfa = factors.totp.any((f) => f.status.name == 'verified');
        } catch (_) {
          _hasMfa = false;
        }
      }
    } catch (e) {
      _errorMessage = 'Fout bij het laden van profiel: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Niet ingelogd.');

      final supabase = ref.read(supabaseClientProvider);

      await supabase.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address_street': _streetController.text.trim(),
        'address_number': _numberController.text.trim(),
        'address_postal_code': _postalCodeController.text.trim(),
        'address_city': _cityController.text.trim(),
        'address_country': _countryController.text.trim(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Profielgegevens succesvol bijgewerkt!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Fout bij opslaan van profiel: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmAndDeleteOwnAccount() async {
    final user = ref.read(currentUserProvider);
    final licenses = ref.read(userLicensesProvider).value ?? [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String confirmationText = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isValid = confirmationText.trim() == 'VERWIJDER';
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Account Definitief Verwijderen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Let op: dit verwijdert je centrale SchrobbeDock-account over het GEHELE ecosysteem. Deze actie is onomkeerbaar!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Conform het recht op gegevenswissing (AVG / GDPR) verlies je per direct toegang tot alle onderstaande SchrobbeDock applicaties en worden alle bijbehorende licenties en gegevens gewist:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),

                      // Dynamische App Oplijsting
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.layers_outlined, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'SchrobbeDock Hub (Centraal Profiel & Dashboard)',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                            if (licenses.isNotEmpty) ...[
                              const Divider(height: 12),
                              ...licenses.map((lic) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.apps, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          lic.app?.name ?? 'Onbekende Spoke App',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${lic.role} (${lic.tier})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Google Consent Tip
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse('https://myaccount.google.com/connections');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Log je in via Google? Trek na verwijdering ook de koppeling in via Google Gekoppelde Apps.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Typ "VERWIJDER" in het veld hieronder om definitieve accountverwijdering te bevestigen:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('delete_confirmation_input'),
                        autofocus: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'VERWIJDER',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            confirmationText = val;
                          });
                        },
                        onSubmitted: (_) {
                          if (isValid) Navigator.of(ctx).pop(true);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuleren'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isValid ? () => Navigator.of(ctx).pop(true) : null,
                  child: const Text('Ja, Definitief Verwijderen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    if (user == null) return;

    try {
      final supabase = ref.read(supabaseClientProvider);

      // RPC aanroepen
      await supabase.rpc('delete_own_account');

      // Direct afmelden
      await supabase.auth.signOut();

      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Je account en alle bijbehorende gegevens zijn definitief verwijderd conform AVG/GDPR.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Fout bij verwijderen van account: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final licensesAsync = ref.watch(userLicensesProvider);

    final userEmail = user?.email ?? 'Onbekend';
    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    final isGoogleUser = provider == 'google';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Profiel & Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: const [
          AppVersionBadge(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadProfileData,
                        child: const Text('Opnieuw Proberen'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Account & Identiteit Kaart
                          _buildAccountIdentityCard(theme, userEmail, isGoogleUser),
                          const SizedBox(height: 20),

                          // 2. Persoonsgegevens Formulier
                          _buildPersonalDetailsCard(theme),
                          const SizedBox(height: 20),

                          // 3. Actieve Licenties & Spoke Toegang
                          _buildLicensesCard(theme, licensesAsync),
                          const SizedBox(height: 28),

                          // 4. Gevarenzone (AVG / GDPR Right to be Forgotten)
                          _buildDangerZoneCard(theme),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAccountIdentityCard(ThemeData theme, String userEmail, bool isGoogleUser) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: Text(
                    userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isGoogleUser
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isGoogleUser ? Icons.g_mobiledata : Icons.email_outlined,
                                  size: 14,
                                  color: isGoogleUser ? Colors.red : Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isGoogleUser ? 'Google OAuth' : 'E-mail & Wachtwoord',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isGoogleUser ? Colors.red : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_createdAt != null)
                            Text(
                              'Lid sinds: ${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            // Beveiligingsstatus (2FA)
            Row(
              children: [
                Icon(
                  _hasMfa ? Icons.verified_user : Icons.security_outlined,
                  color: _hasMfa ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Two-Factor Authentication (2FA)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _hasMfa
                            ? 'Beveiligd met Authenticator App (TOTP)'
                            : 'Niet ingeschakeld. Schakel 2FA in voor extra veiligheid.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasMfa)
                  FilledButton.tonal(
                    onPressed: () => context.push('/mfa/enroll'),
                    child: const Text('Inschakelen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsCard(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Persoonsgegevens',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Voornaam',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Achternaam',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefoonnummer',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Adresgegevens', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Straatnaam',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: 'Huisnr / Bus',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Postcode',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Stad / Gemeente',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Land',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfileData,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Bezig met opslaan...' : 'Gegevens Opslaan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicensesCard(ThemeData theme, AsyncValue<List<dynamic>> licensesAsync) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mijn Actieve Licenties & Spoke Toegang',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Onderstaande licenties zijn gekoppeld aan jouw centrale account:',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            licensesAsync.when(
              data: (licenses) {
                if (licenses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Geen actieve applicatielicenties gevonden.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: licenses.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final lic = licenses[index];
                    final app = lic.app;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer),
                      ),
                      title: Text(
                        app?.name ?? 'Onbekende App',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Rol: ${lic.role} • Tier: ${lic.tier}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Actief',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Fout bij laden van licenties: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gevarenzone: Account Definitief Verwijderen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Conform de AVG (GDPR) kun je een formeel verzoek indienen tot volledige gegevenswissing ("Right to be Forgotten"). '
            'Hiermee worden al je persoonsgegevens, actieve licenties, gekoppelde login-methodes en sessies permanent en onherroepelijk gewist over het GEHELE SchrobbeDock ecosysteem.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _confirmAndDeleteOwnAccount,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Mijn Account Definitief Verwijderen'),
            ),
          ),
        ],
      ),
    );
  }
}
