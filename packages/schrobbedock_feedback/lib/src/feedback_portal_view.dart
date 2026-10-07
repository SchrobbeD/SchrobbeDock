import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../schrobbedock_feedback.dart';

class FeedbackPortalView extends StatefulWidget {
  final String? appSlug;
  final String? initialReportId;
  final bool isAdmin;
  final VoidCallback? onClose;

  const FeedbackPortalView({
    super.key,
    this.appSlug,
    this.initialReportId,
    this.isAdmin = false,
    this.onClose,
  });

  @override
  State<FeedbackPortalView> createState() => _FeedbackPortalViewState();
}

class _FeedbackPortalViewState extends State<FeedbackPortalView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<FeedbackReportSummary> _allReports = [];
  FeedbackReportSummary? _selectedReport;

  // Filters
  late bool _filterByCurrentApp;
  String _selectedStatusFilter = 'all'; // all, open, in_progress, resolved

  RealtimeChannel? _reportsChannel;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _filterByCurrentApp = widget.appSlug != null;
    _loadReports();
    _subscribeReportsRealtime();
  }

  @override
  void dispose() {
    _reportsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeReportsRealtime() {
    _reportsChannel = _client
        .channel('fb_portal_reports_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'feedback_reports',
          callback: (_) {
            _loadReports(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final query = _client.from('feedback_reports').select('''
        id,
        user_id,
        app_id,
        title,
        description,
        category,
        severity,
        status,
        attachment_urls,
        github_issue_number,
        github_issue_url,
        created_at,
        last_message_at,
        has_unread_user,
        has_unread_admin,
        apps(id, name, slug)
      ''').order('last_message_at', ascending: false);

      final res = await query;
      final reports = (res as List<dynamic>)
          .map((r) => FeedbackReportSummary.fromJson(r as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _allReports = reports;
        _isLoading = false;

        // Als er een geselecteerd rapport was, refresh de instantie; anders initieel id of bovenste melding
        if (_selectedReport != null) {
          final idx = reports.indexWhere((r) => r.id == _selectedReport!.id);
          if (idx != -1) {
            _selectedReport = reports[idx];
          } else if (_filteredReports.isNotEmpty) {
            _selectedReport = _filteredReports.first;
          }
        } else if (widget.initialReportId != null) {
          final idx = reports.indexWhere((r) => r.id == widget.initialReportId);
          if (idx != -1) {
            _selectedReport = reports[idx];
          } else if (_filteredReports.isNotEmpty) {
            _selectedReport = _filteredReports.first;
          }
        } else if (_filteredReports.isNotEmpty) {
          _selectedReport = _filteredReports.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Fout bij het laden van rapporten: $e';
        _isLoading = false;
      });
    }
  }

  List<FeedbackReportSummary> get _filteredReports {
    return _allReports.where((r) {
      // App filter
      if (_filterByCurrentApp && widget.appSlug != null) {
        if (r.appSlug != widget.appSlug) return false;
      }

      // Status filter
      if (_selectedStatusFilter == 'open' && r.status != 'open') return false;
      if (_selectedStatusFilter == 'in_progress' && r.status != 'in_progress') return false;
      if (_selectedStatusFilter == 'resolved' && (r.status != 'resolved' && r.status != 'closed')) return false;

      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.orange.shade700;
      case 'resolved':
      case 'closed':
        return Colors.green.shade700;
      case 'open':
      default:
        return Colors.red.shade700;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In behandeling';
      case 'resolved':
      case 'closed':
        return 'Opgelost';
      case 'open':
      default:
        return 'Open';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'bug':
        return Icons.bug_report_outlined;
      case 'enhancement':
        return Icons.lightbulb_outline;
      case 'question':
        return Icons.help_outline;
      default:
        return Icons.feedback_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Mijn Meldingen',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Verversen',
            onPressed: () => _loadReports(),
          ),
          FilledButton.icon(
            onPressed: () async {
              await SchrobbeDockFeedback.show(
                context,
                appSlug: widget.appSlug ?? 'hub_admin',
              );
              _loadReports(silent: true);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nieuwe melding'),
          ),
          const SizedBox(width: 8),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filterbalk
          _buildFilterBar(context),
          const Divider(height: 1),

          // Hoofdinhoud: Split-view op desktop, master-detail op mobiel
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView(theme)
                    : isDesktop
                        ? _buildSplitView(context)
                        : _buildMobileView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // App filter chips indien appSlug opgegeven is
            if (widget.appSlug != null) ...[
              FilterChip(
                label: Text('Deze app (${widget.appSlug})'),
                selected: _filterByCurrentApp,
                onSelected: (val) {
                  setState(() {
                    _filterByCurrentApp = true;
                  });
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Alle apps'),
                selected: !_filterByCurrentApp,
                onSelected: (val) {
                  setState(() {
                    _filterByCurrentApp = false;
                  });
                },
              ),
              const SizedBox(width: 16),
              const VerticalDivider(width: 1, thickness: 1),
              const SizedBox(width: 16),
            ],

            // Status filter chips
            ChoiceChip(
              label: const Text('Alles'),
              selected: _selectedStatusFilter == 'all',
              onSelected: (val) => setState(() => _selectedStatusFilter = 'all'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.circle, size: 10, color: Colors.red),
              label: const Text('Open'),
              selected: _selectedStatusFilter == 'open',
              onSelected: (val) => setState(() => _selectedStatusFilter = 'open'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.circle, size: 10, color: Colors.orange),
              label: const Text('In behandeling'),
              selected: _selectedStatusFilter == 'in_progress',
              onSelected: (val) => setState(() => _selectedStatusFilter = 'in_progress'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.circle, size: 10, color: Colors.green),
              label: const Text('Opgelost'),
              selected: _selectedStatusFilter == 'resolved',
              onSelected: (val) => setState(() => _selectedStatusFilter = 'resolved'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitView(BuildContext context) {
    final theme = Theme.of(context);
    final reports = _filteredReports;

    return Row(
      children: [
        // Linkerkant: Lijst met meldingen
        SizedBox(
          width: 380,
          child: reports.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final isSelected = _selectedReport?.id == report.id;
                    return _buildReportTile(context, report, isSelected);
                  },
                ),
        ),
        const VerticalDivider(width: 1),

        // Rechterkant: Geselecteerde melding details & chat (standaard de bovenste)
        Expanded(
          child: Builder(
            builder: (context) {
              final activeReport = _selectedReport ?? (reports.isNotEmpty ? reports.first : null);
              if (activeReport == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Geen meldingen beschikbaar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _buildReportDetailPane(context, activeReport);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView(BuildContext context) {
    final theme = Theme.of(context);
    final reports = _filteredReports;

    if (_selectedReport != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedReport = null;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    _selectedReport!.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildReportDetailPane(context, _selectedReport!)),
        ],
      );
    }

    if (reports.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.separated(
      itemCount: reports.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final report = reports[index];
        return _buildReportTile(context, report, false);
      },
    );
  }

  Widget _buildReportTile(BuildContext context, FeedbackReportSummary report, bool isSelected) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(report.status);
    final unread = widget.isAdmin ? report.hasUnreadAdmin : report.hasUnreadUser;

    final dateStr = report.lastMessageAt != null
        ? '${report.lastMessageAt!.day}-${report.lastMessageAt!.month} ${report.lastMessageAt!.hour}:${report.lastMessageAt!.minute.toString().padLeft(2, '0')}'
        : '${report.createdAt.day}-${report.createdAt.month}';

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      onTap: () {
        setState(() {
          _selectedReport = report;
        });
      },
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            foregroundColor: statusColor,
            child: Icon(_getCategoryIcon(report.category), size: 20),
          ),
          if (unread)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              report.title,
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            dateStr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            report.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusLabel(report.status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              if (report.appName != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    report.appName!,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetailPane(BuildContext context, FeedbackReportSummary report) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(report.status);

    return Column(
      children: [
        // Detail Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusLabel(report.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (report.appName != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'App: ${report.appName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                            if (report.githubIssueNumber != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Issue #${report.githubIssueNumber}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),

        // Universele Chat Thread
        Expanded(
          child: FeedbackChatWidget(
            key: ValueKey(report.id),
            reportId: report.id,
            isAdmin: widget.isAdmin,
            onReportUpdated: () {
              _loadReports(silent: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'Geen meldingen gevonden',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Je hebt nog geen feedback of foutmeldingen ingediend, of ze voldoen niet aan de huidige filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _loadReports(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Opnieuw laden'),
            ),
          ],
        ),
      ),
    );
  }
}
