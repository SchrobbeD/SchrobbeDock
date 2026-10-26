import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

class AdminInvitesScreen extends ConsumerStatefulWidget {
  const AdminInvitesScreen({super.key});

  @override
  ConsumerState<AdminInvitesScreen> createState() => _AdminInvitesScreenState();
}

class _AdminInvitesScreenState extends ConsumerState<AdminInvitesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State voor Uitnodigingen
  bool _isLoadingInvites = true;
  List<Map<String, dynamic>> _invitations = [];
  String? _invitesError;

  // State voor Gebruikers & 2FA
  bool _isLoadingUsers = true;
  List<Map<String, dynamic>> _users = [];
  String? _usersError;

  // State voor Toegangsaanvragen
  bool _isLoadingRequests = true;
  List<Map<String, dynamic>> _licenseRequests = [];
  String? _requestsError;
  String _selectedRequestsFilter = 'pending'; // 'pending', 'approved', 'rejected', 'all'

  int get _pendingRequestsCount =>
      _licenseRequests.where((r) => r['status'] == 'pending').length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInvitations();
    _loadUsers();
    _loadLicenseRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isLoadingInvites = true;
      _invitesError = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('invitations')
          .select('''
            id,
            code,
            recipient_name,
            is_used,
            expires_at,
            created_at,
            can_access_robhub,
            initial_theme_template,
            invitation_licenses(
              app_id,
              tier,
              role,
              apps(id, name, slug)
            )
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _invitations = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      setState(() {
        _invitesError = 'Fout bij het ophalen van uitnodigingen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInvites = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.rpc('admin_get_users_with_mfa');

      setState(() {
        _users = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      setState(() {
        _usersError = 'Fout bij ophalen van gebruikers: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _confirmAndResetMfa(String userId, String userEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('2FA Resetten'),
          ],
        ),
        content: Text(
          'Weet je zeker dat je de Two-Factor Authentication voor "$userEmail" wilt resetten?\n\n'
          'Alle actieve TOTP-sleutels worden gewist. De gebruiker kan daarna inloggen met wachtwoord en wordt automatisch verplicht een nieuwe authenticator in te stellen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ja, Reset 2FA'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('admin_reset_user_mfa', params: {
        'target_user_id': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2FA voor $userEmail is succesvol gereset.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij resetten van 2FA: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteUser(String userId, String userEmail, String displayName) async {
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Je kunt je eigen administrator-account niet verwijderen via Admin Beheer.'),
        ),
      );
      return;
    }

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
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Account Definitief Verwijderen'),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weet je zeker dat je het account van "$userEmail" definitief wilt verwijderen?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Conform de AVG/GDPR ("Right to be Forgotten") heeft dit de volgende gevolgen over het GEHELE ecosysteem:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Alle gekoppelde login-methodes (Google OAuth, e-mail) worden ontkoppeld.'),
                    const Text('• Alle actieve licenties voor alle Spoke apps worden per direct ingetrokken.'),
                    const Text('• Het profiel en alle sessie-tokens worden permanent gewist.'),
                    const SizedBox(height: 16),
                    Text(
                      'Typ "VERWIJDER" in het veld hieronder om te bevestigen:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
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

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('delete_user_by_admin', params: {
        'target_user_id': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Account voor $userEmail is definitief verwijderd.'),
          ),
        );
        _loadUsers();
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

  Future<void> _toggleUserRobHubAccess(String userId, String userEmail, bool grant) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('admin_set_robhub_access', params: {
        'target_user_id': userId,
        'grant_access': grant,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: grant ? Colors.green : Colors.blueGrey,
            content: Text(grant
                ? 'RobHub-toegang toegekend aan $userEmail.'
                : 'RobHub-toegang ingetrokken voor $userEmail (thema automatisch gereset).'),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij wijzigen van RobHub-toegang: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'DOCK-$part1-$part2';
  }

  String _buildInviteMessage(String code, String? recipientName) {
    final origin = Uri.base.origin;
    final hasHash = Uri.base.toString().contains('/#/');
    final registerUrl = hasHash ? '$origin/#/register?code=$code' : '$origin/register?code=$code';
    final greeting = (recipientName != null && recipientName.isNotEmpty)
        ? 'Beste $recipientName,'
        : 'Hallo,';

    return '''$greeting

Je bent uitgenodigd voor SchrobbeDock!
Via onderstaande link kun je direct je account aanmaken:
$registerUrl

Uitnodigingscode: $code''';
  }

  void _showCreateInviteDialog() {
    final codeController = TextEditingController(text: _generateRandomCode());
    final recipientController = TextEditingController();
    final selectedAppIds = <String>{};
    int validityDays = 14;
    bool canAccessRobHub = false;
    String initialThemeTemplate = 'amber_rust';

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final appsAsync = ref.watch(allAppsProvider);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Nieuwe Uitnodigingscode Genereren'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: recipientController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Bestemd voor (naam / referentie - optioneel)',
                              hintText: 'bv. Jan Jansen of Klant XYZ',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Uitnodigingscode',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Genereer nieuwe willekeurige code',
                                onPressed: () {
                                  setDialogState(() {
                                    codeController.text = _generateRandomCode();
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: validityDays,
                            decoration: const InputDecoration(
                              labelText: 'Geldigheidsduur',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 7, child: Text('7 dagen')),
                              DropdownMenuItem(value: 14, child: Text('14 dagen')),
                              DropdownMenuItem(value: 30, child: Text('30 dagen')),
                              DropdownMenuItem(value: 90, child: Text('90 dagen')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => validityDays = val);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Koppel Toegangsrechten / Apps:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          appsAsync.when(
                            data: (apps) {
                              if (apps.isEmpty) {
                                return const Text('Geen actieve apps gevonden.');
                              }
                              return Column(
                                children: apps.map((app) {
                                  final isChecked = selectedAppIds.contains(app.id);
                                  return CheckboxListTile(
                                    title: Text(app.name),
                                    subtitle: Text('Slug: ${app.slug}'),
                                    value: isChecked,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          selectedAppIds.add(app.id);
                                        } else {
                                          selectedAppIds.remove(app.id);
                                        }
                                      });
                                    },
                                    dense: true,
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, _) => Text('Fout bij laden van apps: $e'),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Thema- en Huisstijl Configuratie:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            title: const Text('Toegang tot RobHub thema toestaan'),
                            subtitle: const Text('Exclusief parodiethema met zwart en geeloranje palet'),
                            value: canAccessRobHub,
                            onChanged: (val) {
                              setDialogState(() {
                                canAccessRobHub = val ?? false;
                                if (!canAccessRobHub && initialThemeTemplate == 'rob_hub') {
                                  initialThemeTemplate = 'amber_rust';
                                }
                              });
                            },
                            dense: true,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: initialThemeTemplate,
                            decoration: const InputDecoration(
                              labelText: 'Standaard Startthema voor Genodigde',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'amber_rust', child: Text('Warm Amber & Roest (Standaard)')),
                              DropdownMenuItem(value: 'ocean_deep', child: Text('Ocean Deep (Blauw)')),
                              DropdownMenuItem(value: 'emerald_forest', child: Text('Emerald Forest (Groen)')),
                              DropdownMenuItem(value: 'midnight_violet', child: Text('Midnight Violet (Paars)')),
                              DropdownMenuItem(value: 'slate_monolith', child: Text('Slate Monolith (Titanium)')),
                              DropdownMenuItem(value: 'rob_hub', child: Text('RobHub (Exclusief Zwart/Oranje)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  initialThemeTemplate = val;
                                  if (val == 'rob_hub') {
                                    canAccessRobHub = true;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Annuleren'),
                    ),
                    FilledButton(
                      onPressed: selectedAppIds.isEmpty
                          ? null
                          : () async {
                              final supabase = ref.read(supabaseClientProvider);
                              final code = codeController.text.trim();
                              final recipientName = recipientController.text.trim();
                              final expiresAt = DateTime.now().add(Duration(days: validityDays));
                              final effectiveRobHubAccess = canAccessRobHub || initialThemeTemplate == 'rob_hub';

                              try {
                                final inviteInsert = await supabase
                                    .from('invitations')
                                    .insert({
                                      'code': code,
                                      'recipient_name': recipientName.isEmpty ? null : recipientName,
                                      'expires_at': expiresAt.toIso8601String(),
                                      'can_access_robhub': effectiveRobHubAccess,
                                      'initial_theme_template': initialThemeTemplate,
                                    })
                                    .select('id')
                                    .single();

                                final inviteId = inviteInsert['id'] as String;

                                final licensesData = selectedAppIds.map((appId) {
                                  return {
                                    'invitation_id': inviteId,
                                    'app_id': appId,
                                    'tier': 'basic',
                                    'role': 'user',
                                  };
                                }).toList();

                                await supabase
                                    .from('invitation_licenses')
                                    .insert(licensesData);

                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  _loadInvitations();
                                  _showCodeCreatedSuccessDialog(
                                    code,
                                    recipientName.isEmpty ? null : recipientName,
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Fout: $e')),
                                  );
                                }
                              }
                            },
                      child: const Text('Aanmaken'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCodeCreatedSuccessDialog(String code, String? recipientName) {
    final inviteMessage = _buildInviteMessage(code, recipientName);
    final origin = Uri.base.origin;
    final hasHash = Uri.base.toString().contains('/#/');
    final registerUrl = hasHash ? '$origin/#/register?code=$code' : '$origin/register?code=$code';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Uitnodiging Aangemaakt!'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipientName != null && recipientName.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text(
                          'Bestemd voor: $recipientName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Kopieer het volledige bericht of alleen de link/code:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      inviteMessage,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Kopieer Volledig Bericht'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: inviteMessage));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Volledig bericht gekopieerd!')),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Kopieer Link'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: registerUrl));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Registratielink gekopieerd!')),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.vpn_key, size: 16),
                        label: const Text('Kopieer Code'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Code gekopieerd!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Sluiten'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuperAdmin = ref.watch(isSuperAdminProvider);

    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toegang Geweigerd')),
        body: const Center(
          child: Text('Je hebt geen beheerdersrechten om dit paneel te bekijken.'),
        ),
      );
    }

    final isInvitesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centraal Admin Beheer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.vpn_key), text: 'Uitnodigingen'),
            const Tab(icon: Icon(Icons.manage_accounts), text: 'Gebruikers & 2FA'),
            Tab(
              icon: Badge(
                isLabelVisible: _pendingRequestsCount > 0,
                label: Text('$_pendingRequestsCount'),
                child: const Icon(Icons.assignment_ind_outlined),
              ),
              text: 'Toegangsaanvragen',
            ),
          ],
        ),
        actions: [
          const AppVersionBadge(),
          IconButton(
            tooltip: 'Feedback & Meldingen',
            icon: const Icon(Icons.rate_review_outlined),
            onPressed: () => context.go('/admin/feedback'),
          ),
          IconButton(
            tooltip: 'Vernieuwen',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadInvitations();
              } else if (_tabController.index == 1) {
                _loadUsers();
              } else {
                _loadLicenseRequests();
              }
            },
          ),
        ],
      ),
      floatingActionButton: isInvitesTab
          ? FloatingActionButton.extended(
              onPressed: _showCreateInviteDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nieuwe Invite Code'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Uitnodigingen
          _buildInvitationsTab(theme),

          // TAB 2: Gebruikers & 2FA
          _buildUsersTab(theme),

          // TAB 3: Toegangsaanvragen
          _buildLicenseRequestsTab(theme),
        ],
      ),
    );
  }

  Widget _buildInvitationsTab(ThemeData theme) {
    if (_isLoadingInvites) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invitesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_invitesError!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadInvitations,
              child: const Text('Opnieuw Proberen'),
            ),
          ],
        ),
      );
    }

    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Nog geen uitnodigingscodes gegenereerd.'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _showCreateInviteDialog,
              child: const Text('Genereer de eerste code'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: _invitations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invite = _invitations[index];
        final code = invite['code'] as String? ?? '';
        final recipientName = invite['recipient_name'] as String?;
        final isUsed = invite['is_used'] as bool? ?? false;
        final expiresAtRaw = invite['expires_at'] as String?;
        final expiresAt = expiresAtRaw != null ? DateTime.tryParse(expiresAtRaw) : null;
        final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

        final licenses = (invite['invitation_licenses'] as List<dynamic>?) ?? [];
        final appNames = licenses.map((l) {
          final app = l['apps'] as Map<String, dynamic>?;
          return app?['name'] ?? 'Onbekend';
        }).toList();

        Color statusColor;
        String statusText;
        if (isUsed) {
          statusColor = Colors.grey;
          statusText = 'Reeds Gebruikt';
        } else if (isExpired) {
          statusColor = Colors.red;
          statusText = 'Verlopen';
        } else {
          statusColor = Colors.green;
          statusText = 'Actief & Beschikbaar';
        }

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.vpn_key, color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recipientName != null && recipientName.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 4),
                            Text(
                              recipientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          SelectableText(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Kopieer code',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code gekopieerd!')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 16),
                            tooltip: 'Kopieer uitnodigingsbericht',
                            onPressed: () {
                              final msg = _buildInviteMessage(code, recipientName);
                              Clipboard.setData(ClipboardData(text: msg));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Uitnodigingsbericht gekopieerd!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...appNames.map((name) {
                            return Chip(
                              label: Text(name.toString()),
                              backgroundColor: theme.colorScheme.surfaceContainerHigh,
                              visualDensity: VisualDensity.compact,
                              labelStyle: const TextStyle(fontSize: 11),
                            );
                          }),
                          if (invite['can_access_robhub'] == true)
                            Chip(
                              avatar: const Icon(Icons.star, size: 12, color: Colors.black),
                              label: const Text('RobHub Toegestaan'),
                              backgroundColor: const Color(0xFFFFA31A),
                              visualDensity: VisualDensity.compact,
                              labelStyle: const TextStyle(
                                fontSize: 11,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (invite['initial_theme_template'] != null &&
                              invite['initial_theme_template'] != 'amber_rust')
                            Chip(
                              avatar: const Icon(Icons.palette_outlined, size: 12),
                              label: Text('Startthema: ${invite['initial_theme_template']}'),
                              backgroundColor: theme.colorScheme.surfaceContainerHigh,
                              visualDensity: VisualDensity.compact,
                              labelStyle: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(statusText),
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (expiresAt != null)
                      Text(
                        'Verloopt: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_usersError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_usersError!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadUsers,
              child: const Text('Opnieuw Proberen'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('Geen geregistreerde gebruikers gevonden.'),
      );
    }

    final currentUserId = ref.watch(currentUserProvider)?.id;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = _users[index];
        final id = u['id'] as String;
        final email = u['email'] as String? ?? 'Geen e-mail';
        final firstName = u['first_name'] as String?;
        final lastName = u['last_name'] as String?;
        final hasMfa = u['has_mfa'] as bool? ?? false;
        final canAccessRobHub = u['can_access_robhub'] as bool? ?? false;
        final createdAtRaw = u['created_at'] as String?;
        final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;

        final fullName = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasMfa
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  child: Icon(
                    hasMfa ? Icons.verified_user : Icons.no_accounts,
                    color: hasMfa ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (fullName.isNotEmpty)
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (createdAt != null)
                        Text(
                          'Geregistreerd: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FilterChip(
                      selected: canAccessRobHub,
                      avatar: Icon(
                        canAccessRobHub ? Icons.star : Icons.star_border,
                        size: 14,
                        color: canAccessRobHub ? Colors.black : Colors.grey,
                      ),
                      label: Text(canAccessRobHub ? 'RobHub Toegestaan' : 'Geen RobHub'),
                      backgroundColor: canAccessRobHub
                          ? const Color(0xFFFFA31A)
                          : theme.colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: canAccessRobHub ? Colors.black : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) => _toggleUserRobHubAccess(id, email, val),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      avatar: Icon(
                        hasMfa ? Icons.lock : Icons.lock_open,
                        size: 14,
                        color: hasMfa ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                      label: Text(hasMfa ? '2FA Actief (TOTP)' : '2FA Niet Ingesteld'),
                      backgroundColor: hasMfa
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: hasMfa ? Colors.green.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        if (hasMfa)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(color: Colors.orange.shade800),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _confirmAndResetMfa(id, email),
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('Reset 2FA'),
                          ),
                        if (id != currentUserId)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _confirmAndDeleteUser(id, email, fullName),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Verwijder Account'),
                          )
                        else
                          Tooltip(
                            message: 'Je kunt je eigen account hier niet verwijderen',
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: null,
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Eigen Account'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadLicenseRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestsError = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('license_requests')
          .select('''
            id,
            user_id,
            app_id,
            reason,
            status,
            reviewed_at,
            created_at,
            profiles:user_id(id, email, first_name, last_name),
            apps:app_id(id, name, slug)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _licenseRequests = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      setState(() {
        _requestsError = 'Fout bij het ophalen van toegangsaanvragen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _reviewLicenseRequest(
    String requestId,
    String newStatus, {
    String tier = 'basic',
    String role = 'user',
  }) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.rpc('review_license_request', params: {
        'request_id': requestId,
        'new_status': newStatus,
        'assigned_tier': tier,
        'assigned_role': role,
      });

      final success = res['success'] == true;
      final message = res['message'] as String? ?? 'Status bijgewerkt.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success
                ? (newStatus == 'approved' ? Colors.green : Colors.orange.shade800)
                : Colors.red,
            content: Text(message),
          ),
        );
        _loadLicenseRequests();
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Fout bij beoordelen van aanvraag: $e'),
          ),
        );
      }
    }
  }

  void _showApproveRequestDialog(Map<String, dynamic> request) {
    final requestId = request['id'] as String;
    final profile = request['profiles'] as Map<String, dynamic>?;
    final app = request['apps'] as Map<String, dynamic>?;
    final userEmail = profile?['email'] as String? ?? 'Onbekend';
    final appName = app?['name'] as String? ?? 'Applicatie';

    String selectedTier = 'basic';
    String selectedRole = 'user';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Toegang Goedkeuren: $appName')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gebruiker: $userEmail', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTier,
                    decoration: const InputDecoration(
                      labelText: 'Licentie Tier',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'basic', child: Text('Basic')),
                      DropdownMenuItem(value: 'pro', child: Text('Pro')),
                      DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedTier = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol binnen App',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('Gebruiker (User)')),
                      DropdownMenuItem(value: 'manager', child: Text('Beheerder (Manager)')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrator (Admin)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuleren'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _reviewLicenseRequest(
                      requestId,
                      'approved',
                      tier: selectedTier,
                      role: selectedRole,
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Goedkeuren & Activeren'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRejectRequest(Map<String, dynamic> request) {
    final requestId = request['id'] as String;
    final profile = request['profiles'] as Map<String, dynamic>?;
    final app = request['apps'] as Map<String, dynamic>?;
    final userEmail = profile?['email'] as String? ?? 'Onbekend';
    final appName = app?['name'] as String? ?? 'Applicatie';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Toegangsaanvraag Afwijzen'),
          content: Text('Weet je zeker dat je de aanvraag van $userEmail voor $appName wilt afwijzen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                _reviewLicenseRequest(requestId, 'rejected');
              },
              child: const Text('Ja, Afwijzen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLicenseRequestsTab(ThemeData theme) {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requestsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_requestsError!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadLicenseRequests,
              child: const Text('Opnieuw Proberen'),
            ),
          ],
        ),
      );
    }

    final filteredRequests = _licenseRequests.where((r) {
      if (_selectedRequestsFilter == 'all') return true;
      return r['status'] == _selectedRequestsFilter;
    }).toList();

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'pending',
                    label: Text('In Afwachting ($_pendingRequestsCount)'),
                    icon: const Icon(Icons.pending_actions),
                  ),
                  const ButtonSegment(
                    value: 'approved',
                    label: Text('Goedgekeurd'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  const ButtonSegment(
                    value: 'rejected',
                    label: Text('Afgewezen'),
                    icon: Icon(Icons.cancel_outlined),
                  ),
                  const ButtonSegment(
                    value: 'all',
                    label: Text('Alles'),
                    icon: Icon(Icons.list_alt),
                  ),
                ],
                selected: {_selectedRequestsFilter},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedRequestsFilter = set.first;
                  });
                },
              ),
            ],
          ),
        ),

        // Requests list
        Expanded(
          child: filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _selectedRequestsFilter == 'pending'
                            ? 'Geen openstaande toegangsaanvragen!'
                            : 'Geen aanvragen gevonden in deze categorie.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = filteredRequests[index];
                    final profile = req['profiles'] as Map<String, dynamic>?;
                    final app = req['apps'] as Map<String, dynamic>?;

                    final userEmail = profile?['email'] as String? ?? 'Geen e-mail';
                    final firstName = profile?['first_name'] as String? ?? '';
                    final lastName = profile?['last_name'] as String? ?? '';
                    final fullName = '$firstName $lastName'.trim();
                    final appName = app?['name'] as String? ?? 'Onbekende App';
                    final appSlug = app?['slug'] as String? ?? '';
                    final reason = req['reason'] as String?;
                    final status = req['status'] as String? ?? 'pending';
                    final createdAtRaw = req['created_at'] as String?;
                    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;

                    Color statusColor;
                    String statusLabel;
                    IconData statusIcon;

                    switch (status) {
                      case 'approved':
                        statusColor = Colors.green;
                        statusLabel = 'Goedgekeurd';
                        statusIcon = Icons.check_circle;
                        break;
                      case 'rejected':
                        statusColor = Colors.red;
                        statusLabel = 'Afgewezen';
                        statusIcon = Icons.cancel;
                        break;
                      default:
                        statusColor = Colors.orange.shade800;
                        statusLabel = 'In Afwachting';
                        statusIcon = Icons.hourglass_top;
                        break;
                    }

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: status == 'pending'
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                                  child: Text(
                                    fullName.isNotEmpty
                                        ? fullName[0].toUpperCase()
                                        : userEmail[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userEmail,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (fullName.isNotEmpty)
                                        Text(
                                          fullName,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  avatar: Icon(statusIcon, size: 16, color: statusColor),
                                  label: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: statusColor.withValues(alpha: 0.1),
                                  side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Text('Aangevraagde App: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$appName ($appSlug)',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (createdAt != null)
                                  Text(
                                    '${createdAt.day}-${createdAt.month}-${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                            if (reason != null && reason.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Motivering van gebruiker:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      reason,
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (status == 'pending') ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    onPressed: () => _confirmRejectRequest(req),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Afwijzen'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () => _showApproveRequestDialog(req),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Toegang Goedkeuren'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
