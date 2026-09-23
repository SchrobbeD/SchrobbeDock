import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInvitations();
    _loadUsers();
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

                              try {
                                final inviteInsert = await supabase
                                    .from('invitations')
                                    .insert({
                                      'code': code,
                                      'recipient_name': recipientName.isEmpty ? null : recipientName,
                                      'expires_at': expiresAt.toIso8601String(),
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
          tabs: const [
            Tab(icon: Icon(Icons.vpn_key), text: 'Uitnodigingen'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Gebruikers & 2FA'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadInvitations();
              } else {
                _loadUsers();
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
                        children: appNames.map((name) {
                          return Chip(
                            label: Text(name.toString()),
                            backgroundColor: theme.colorScheme.surfaceContainerHigh,
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 11),
                          );
                        }).toList(),
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
                    const SizedBox(height: 6),
                    if (hasMfa)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _confirmAndResetMfa(id, email),
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset 2FA'),
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
}
