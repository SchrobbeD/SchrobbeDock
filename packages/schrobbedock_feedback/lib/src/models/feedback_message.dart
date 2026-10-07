class FeedbackMessage {
  final String id;
  final String reportId;
  final String? senderId;
  final String senderRole; // 'user', 'admin', 'github_dev'
  final String senderName;
  final String message;
  final List<String> attachmentUrls;
  final int? githubCommentId;
  final DateTime createdAt;

  const FeedbackMessage({
    required this.id,
    required this.reportId,
    this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.message,
    this.attachmentUrls = const [],
    this.githubCommentId,
    required this.createdAt,
  });

  bool get isFromUser => senderRole == 'user';
  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromGitHub => senderRole == 'github_dev';

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) {
    return FeedbackMessage(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      senderId: json['sender_id'] as String?,
      senderRole: (json['sender_role'] as String?) ?? 'user',
      senderName: (json['sender_name'] as String?) ?? 'Onbekend',
      message: (json['message'] as String?) ?? '',
      attachmentUrls: (json['attachment_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      githubCommentId: json['github_comment_id'] is int
          ? json['github_comment_id'] as int
          : (json['github_comment_id'] != null
              ? int.tryParse(json['github_comment_id'].toString())
              : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'message': message,
      'attachment_urls': attachmentUrls,
      if (githubCommentId != null) 'github_comment_id': githubCommentId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
