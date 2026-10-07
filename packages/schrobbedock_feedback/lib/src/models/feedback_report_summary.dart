class FeedbackReportSummary {
  final String id;
  final String? userId;
  final String appId;
  final String? appName;
  final String? appSlug;
  final String title;
  final String description;
  final String category; // bug, enhancement, question, other
  final String severity; // low, medium, high, critical
  final String status; // open, in_progress, resolved, closed
  final List<String> attachmentUrls;
  final int? githubIssueNumber;
  final String? githubIssueUrl;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final bool hasUnreadUser;
  final bool hasUnreadAdmin;

  const FeedbackReportSummary({
    required this.id,
    this.userId,
    required this.appId,
    this.appName,
    this.appSlug,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    this.attachmentUrls = const [],
    this.githubIssueNumber,
    this.githubIssueUrl,
    required this.createdAt,
    this.lastMessageAt,
    this.hasUnreadUser = false,
    this.hasUnreadAdmin = false,
  });

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved' || status == 'closed';

  factory FeedbackReportSummary.fromJson(Map<String, dynamic> json) {
    String? appName;
    String? appSlug;
    if (json['apps'] is Map<String, dynamic>) {
      appName = json['apps']['name'] as String?;
      appSlug = json['apps']['slug'] as String?;
    }

    return FeedbackReportSummary(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      appId: json['app_id'] as String,
      appName: appName,
      appSlug: appSlug,
      title: (json['title'] as String?) ?? 'Zonder titel',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      severity: (json['severity'] as String?) ?? 'medium',
      status: (json['status'] as String?) ?? 'open',
      attachmentUrls: (json['attachment_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      githubIssueNumber: json['github_issue_number'] is int
          ? json['github_issue_number'] as int
          : (json['github_issue_number'] != null
              ? int.tryParse(json['github_issue_number'].toString())
              : null),
      githubIssueUrl: json['github_issue_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      hasUnreadUser: (json['has_unread_user'] as bool?) ?? false,
      hasUnreadAdmin: (json['has_unread_admin'] as bool?) ?? false,
    );
  }
}
