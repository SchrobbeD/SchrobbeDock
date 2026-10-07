import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers.dart';

class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  ConsumerState<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _apps = [];

  // Filters
  String _selectedStatusFilter = 'all'; // all, open, in_progress, resolved
  String _selectedAppFilter = 'all';
  String _selectedCategoryFilter = 'all';

  // Geopende chats per rapport-ID
  final Set<String> _expandedChatReports = {};

  RealtimeChannel? _feedbackRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    try {
      _feedbackRealtimeChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final supabase = ref.read(supabaseClientProvider);
      _feedbackRealtimeChannel = supabase
          .channel('admin_feedback_rt_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'feedback_reports',
            callback: (payload) {
              final updated = payload.newRecord;
              if (updated.isNotEmpty) {
                final reportId = updated['id'] as String?;
                if (reportId != null) {
                  final idx = _reports.indexWhere((r) => r['id'] == reportId);
                  if (idx != -1 && mounted) {
                    setState(() {
                      _reports[idx]['has_unread_admin'] = updated['has_unread_admin'];
                      _reports[idx]['has_unread_user'] = updated['has_unread_user'];
                      _reports[idx]['status'] = updated['status'];
                      _reports[idx]['last_message_at'] = updated['last_message_at'];
                    });
                  } else if (idx == -1 && payload.eventType == PostgresChangeEvent.insert) {
                    _loadInitialData(silent: true);
                  }
                }
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'feedback_messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final reportId = newRecord['report_id'] as String?;
              if (reportId != null && mounted) {
                final currentUserId = supabase.auth.currentUser?.id;
                final senderId = newRecord['sender_id'] as String?;
                final isSenderMe = currentUserId != null && currentUserId == senderId;

                final idx = _reports.indexWhere((r) => r['id'] == reportId);
                if (idx != -1) {
                  setState(() {
                    if (!_expandedChatReports.contains(reportId) && !isSenderMe) {
                      _reports[idx]['has_unread_admin'] = true;
                    }
                    _reports[idx]['last_message_at'] = newRecord['created_at'];
                  });
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AdminFeedback] Realtime subscription init error: $e');
    }
  }

  Future<void> _loadInitialData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Laad apps voor de filter dropdown
      final appsRes = await supabase.from('apps').select('id, name, slug').order('name');
      _apps = List<Map<String, dynamic>>.from(appsRes);

      // Laad feedback meldingen inclusief app metadata en melder profiel
      final reportsRes = await supabase
          .from('feedback_reports')
          .select('''
            id,
            user_id,
            app_id,
            title,
            description,
            category,
            severity,
            status,
            environment_info,
            attachment_urls,
            stack_trace,
            github_issue_url,
            github_issue_number,
            has_unread_admin,
            has_unread_user,
            last_message_at,
            created_at,
            updated_at,
            apps(id, name, slug, github_repo_owner, github_repo_name),
            profiles:user_id(id, email, first_name, last_name)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(reportsRes);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fout bij het laden van feedbackmeldingen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateReportStatus(
    Map<String, dynamic> report,
    String newStatus,
  ) async {
    final reportId = report['id'] as String;
    final currentStatus = report['status'] as String;
    if (currentStatus == newStatus) return;

    // Optimistische UI update
    setState(() {
      final idx = _reports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1) {
        _reports[idx]['status'] = newStatus;
      }
    });

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Probeer Edge Function sync-feedback-status (werkt GitHub issue bij)
      bool syncedViaFn = false;
      try {
        final res = await supabase.functions.invoke(
          'sync-feedback-status',
          body: {
            'report_id': reportId,
            'new_status': newStatus,
            'comment': 'Status bijgewerkt naar $newStatus via SchrobbeDock Admin Hub.',
          },
        );
        if (res.status == 200) {
          syncedViaFn = true;
        }
      } catch (fnErr) {
        debugPrint('[AdminFeedback] Edge Function fallback: $fnErr');
      }

      // 2. Fallback: directe Postgres update als de Edge Function niet lokaal draait
      if (!syncedViaFn) {
        await supabase
            .from('feedback_reports')
            .update({
              'status': newStatus,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', reportId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status gewijzigd naar: ${_formatStatus(newStatus)}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Terugdraaien bij fout
      if (mounted) {
        setState(() {
          final idx = _reports.indexWhere((r) => r['id'] == reportId);
          if (idx != -1) {
            _reports[idx]['status'] = currentStatus;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij bijwerken van status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final reportId = report['id'] as String;
    final issueNumber = report['github_issue_number'];
    final theme = Theme.of(context);

    // Toon bevestigingsdialoog met expliciete invoer van 'VERWIJDER'
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String input = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMatch = input.trim().toUpperCase() == 'VERWIJDER';
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Melding Definitief Verwijderen'),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let op: Dit verwijdert de melding permanent uit de database, wist alle gekoppelde bijlagen in storage en verwijdert het GitHub Issue #${issueNumber ?? '-'}.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Typ "VERWIJDER" hieronder om te bevestigen:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'VERWIJDER',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        input = val;
                      });
                    },
                    onSubmitted: (val) {
                      if (val.trim().toUpperCase() == 'VERWIJDER') {
                        Navigator.pop(ctx, true);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuleren'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Definitief Verwijderen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Melding en GitHub issue worden verwijderd...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.functions.invoke(
        'delete-feedback',
        body: {'report_id': reportId},
      );

      if (res.status == 200) {
        if (mounted) {
          setState(() {
            _reports.removeWhere((r) => r['id'] == reportId);
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Melding en GitHub issue #${issueNumber ?? '-'} definitief verwijderd.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        final errorMsg = (res.data is Map && res.data['error'] != null)
            ? res.data['error'].toString()
            : 'Fout bij verwijderen (HTTP ${res.status})';
        throw Exception(errorMsg);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij verwijderen: $err'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports.where((report) {
      // Status filter
      if (_selectedStatusFilter != 'all') {
        if (_selectedStatusFilter == 'resolved') {
          if (report['status'] != 'resolved' && report['status'] != 'closed') {
            return false;
          }
        } else if (report['status'] != _selectedStatusFilter) {
          return false;
        }
      }

      // App filter
      if (_selectedAppFilter != 'all') {
        final appData = report['apps'] as Map<String, dynamic>?;
        if (appData?['slug'] != _selectedAppFilter) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategoryFilter != 'all') {
        if (report['category'] != _selectedCategoryFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Behandeling';
      case 'resolved':
      case 'closed':
        return 'Opgelost';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'bug':
        return Colors.red;
      case 'enhancement':
        return Colors.amber.shade800;
      case 'question':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  String _formatCategory(String category) {
    switch (category) {
      case 'bug':
        return 'Bug / Fout';
      case 'enhancement':
        return 'Verbetering';
      case 'question':
        return 'Vraag';
      default:
        return category;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _formatUserName(Map<String, dynamic>? profile, dynamic userId) {
    if (profile != null) {
      final firstName = (profile['first_name'] as String?)?.trim() ?? '';
      final lastName = (profile['last_name'] as String?)?.trim() ?? '';
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) return fullName;
      final email = profile['email'] as String?;
      if (email != null && email.isNotEmpty) return email;
    }
    final idStr = userId?.toString() ?? '';
    return idStr.length >= 8 ? 'Gebruiker #${idStr.substring(0, 8)}' : 'Onbekende Gebruiker';
  }

  void _showImageModal(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(32),
                  color: Colors.black87,
                  child: const Text('Afbeelding kon niet worden geladen.',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton.filled(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredReports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centraal Feedback- & Probleembeheer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          const AppVersionBadge(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Vernieuwen',
            onPressed: _isLoading ? null : _loadInitialData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: SelectableText(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Opnieuw Proberen'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Filter balk
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Status Tabs
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'all', label: Text('Alles')),
                              ButtonSegment(value: 'open', label: Text('Open')),
                              ButtonSegment(value: 'in_progress', label: Text('In Behandeling')),
                              ButtonSegment(value: 'resolved', label: Text('Opgelost')),
                            ],
                            selected: {_selectedStatusFilter},
                            onSelectionChanged: (val) {
                              setState(() => _selectedStatusFilter = val.first);
                            },
                          ),

                          // App filter
                          DropdownButton<String>(
                            value: _selectedAppFilter,
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('Alle Applicaties')),
                              ..._apps.map(
                                (app) => DropdownMenuItem(
                                  value: app['slug'] as String,
                                  child: Text(app['name'] as String? ?? app['slug']),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAppFilter = val);
                            },
                          ),

                          // Categorie filter
                          DropdownButton<String>(
                            value: _selectedCategoryFilter,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Alle Categorieën')),
                              DropdownMenuItem(value: 'bug', child: Text('Bugs & Fouten')),
                              DropdownMenuItem(value: 'enhancement', child: Text('Verbeteringen')),
                              DropdownMenuItem(value: 'question', child: Text('Vragen')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategoryFilter = val);
                            },
                          ),

                          // Teller
                          Chip(
                            label: Text('${filtered.length} meldingen'),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ),

                    // Meldingen Lijst
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 56, color: theme.colorScheme.outline),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Geen feedbackmeldingen gevonden voor deze filters.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final report = filtered[index];
                                return _buildReportCard(theme, report);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildReportCard(ThemeData theme, Map<String, dynamic> report) {
    final reportId = report['id'] as String;
    final status = report['status'] as String? ?? 'open';
    final category = report['category'] as String? ?? 'bug';
    final severity = report['severity'] as String? ?? 'medium';
    final appData = report['apps'] as Map<String, dynamic>?;
    final profileData = report['profiles'] as Map<String, dynamic>?;
    final envInfo = report['environment_info'] as Map<String, dynamic>?;
    final attachments = (report['attachment_urls'] as List<dynamic>?)?.cast<String>() ?? [];
    final stackTrace = report['stack_trace'] as String?;
    final githubIssueUrl = report['github_issue_url'] as String?;
    final githubIssueNum = report['github_issue_number'];
    final createdAt = DateTime.tryParse(report['created_at'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bovenste balk met badges en status acties
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appData?['name'] ?? report['app_id'] ?? 'Algemeen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Categorie Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getCategoryColor(category).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _formatCategory(category),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _getCategoryColor(category),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Ernst Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(severity).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ernst: ${severity.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: _getSeverityColor(severity),
                    ),
                  ),
                ),

                // Ongelezen Chat Badge
                if (report['has_unread_admin'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_chat_unread_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Nieuw chatbericht',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Status Dropdown Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withValues(alpha: 0.4),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: (status == 'closed') ? 'resolved' : status,
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(status)),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'open',
                        child: Text('🔴 Open'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('🟠 In Behandeling'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('🟢 Opgelost'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _updateReportStatus(report, val);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Knop voor definitief verwijderen (Hard delete)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                  tooltip: 'Melding en GitHub issue definitief verwijderen',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteReport(report),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Titel
            Text(
              report['title'] ?? 'Zonder titel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Beschrijving
            Text(
              report['description'] ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Bijlagen / Foto's thumbnails
            if (attachments.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: attachments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final url = entry.value;
                  final label = attachments.length == 1 ? 'Bijlage bekijken' : 'Bijlage ${idx + 1}';
                  return InkWell(
                    onTap: () => _showImageModal(url),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              url,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(label,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new, size: 14),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Omgevingsdetails & Stacktrace accordeon
            if (envInfo != null || stackTrace != null) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Diagnostische Informatie (Platform: ${envInfo?['platform'] ?? 'onbekend'}, Route: ${envInfo?['route'] ?? '-'})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (envInfo != null) ...[
                          Text('App Versie: ${envInfo['app_version'] ?? '-'}'),
                          Text('Besturingssysteem: ${envInfo['os'] ?? '-'}'),
                          Text('Schermresolutie: ${envInfo['screen_resolution'] ?? '-'}'),
                          Text('Pixel Ratio: ${envInfo['device_pixel_ratio'] ?? '-'}'),
                          Text('Tijdstip: ${envInfo['timestamp'] ?? '-'}'),
                        ],
                        if (stackTrace != null) ...[
                          const SizedBox(height: 8),
                          const Text('Stacktrace:',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 4),
                          SelectableText(
                            stackTrace,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Communicatie & Chat met de melder (Stabiele inklapbare sectie)
            Builder(
              builder: (context) {
                final isChatExpanded = _expandedChatReports.contains(reportId);
                final hasUnread = report['has_unread_admin'] == true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          if (_expandedChatReports.contains(reportId)) {
                            _expandedChatReports.remove(reportId);
                          } else {
                            _expandedChatReports.add(reportId);
                            // Markeer direct lokaal als gelezen
                            report['has_unread_admin'] = false;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isChatExpanded
                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isChatExpanded
                                ? theme.colorScheme.primary.withValues(alpha: 0.35)
                                : theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                              color: hasUnread ? Colors.blue.shade700 : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Communicatie & Chat met Melder',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasUnread ? Colors.blue.shade700 : theme.colorScheme.onSurface,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Nieuw bericht',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Knop om chat in het volledige chatvenster (Mijn Meldingen) te openen
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              tooltip: 'Open in het volledige chatvenster (Mijn Meldingen)',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              onPressed: () async {
                                await SchrobbeDockFeedback.showPortal(
                                  context,
                                  initialReportId: reportId,
                                  isAdmin: true,
                                );
                                _loadInitialData(silent: true);
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isChatExpanded ? 'Inklappen' : 'Chat Openen',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isChatExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isChatExpanded) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 380,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FeedbackChatWidget(
                          key: ValueKey(reportId),
                          reportId: reportId,
                          isAdmin: true,
                          onReportUpdated: () => _loadInitialData(silent: true),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const Divider(height: 24),

            // Footer met melder, timestamp en GitHub issue link
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  _formatUserName(profileData, report['user_id']),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),

                // GitHub Issue koppeling
                if (githubIssueUrl != null)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(githubIssueUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank',
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'GitHub Issue #${githubIssueNum ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.open_in_new, size: 13),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'Lokaal geregistreerd',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
