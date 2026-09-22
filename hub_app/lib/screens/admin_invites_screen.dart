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

class _AdminInvitesScreenState extends ConsumerState<AdminInvitesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invitations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('invitations')
          .select('''
            id,
            code,
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
        _errorMessage = 'Fout bij het ophalen van uitnodigingen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  void _showCreateInviteDialog() {
    final codeController = TextEditingController(text: _generateRandomCode());
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
                              final expiresAt = DateTime.now().add(Duration(days: validityDays));

                              try {
                                final inviteInsert = await supabase
                                    .from('invitations')
                                    .insert({
                                      'code': code,
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
                                  _showCodeCreatedSuccessDialog(code);
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

  void _showCodeCreatedSuccessDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Uitnodigingscode Aangemaakt!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deel deze code met de nieuwe gebruiker:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Kopieer code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Code gekopieerd!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centraal Uitnodigingen & Toegangsbeheer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvitations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateInviteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nieuwe Invite Code'),
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
                        onPressed: _loadInvitations,
                        child: const Text('Opnieuw Proberen'),
                      ),
                    ],
                  ),
                )
              : _invitations.isEmpty
                  ? Center(
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
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      itemCount: _invitations.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final invite = _invitations[index];
                        final code = invite['code'] as String? ?? '';
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
                    ),
    );
  }
}
