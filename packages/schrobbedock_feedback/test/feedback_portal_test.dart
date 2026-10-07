import 'package:flutter_test/flutter_test.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

void main() {
  group('FeedbackMessage Model Tests', () {
    test('Correctly deserializes user message', () {
      final json = {
        'id': 'msg-1',
        'report_id': 'rep-1',
        'sender_id': 'user-1',
        'sender_role': 'user',
        'sender_name': 'Jan Jansen',
        'message': 'Hallo beheerder, ik heb een vraag',
        'attachment_urls': ['https://example.com/screenshot.png'],
        'github_comment_id': 12345,
        'created_at': '2026-10-07T12:00:00Z',
      };

      final msg = FeedbackMessage.fromJson(json);
      expect(msg.id, equals('msg-1'));
      expect(msg.reportId, equals('rep-1'));
      expect(msg.senderRole, equals('user'));
      expect(msg.senderName, equals('Jan Jansen'));
      expect(msg.isFromUser, isTrue);
      expect(msg.isFromAdmin, isFalse);
      expect(msg.isFromGitHub, isFalse);
      expect(msg.attachmentUrls.length, equals(1));
      expect(msg.githubCommentId, equals(12345));
    });

    test('Correctly identifies admin and GitHub messages', () {
      final adminMsg = FeedbackMessage.fromJson({
        'id': 'msg-2',
        'report_id': 'rep-1',
        'sender_role': 'admin',
        'sender_name': 'Platform Admin',
        'message': 'We kijken hiernaar!',
        'created_at': '2026-10-07T12:05:00Z',
      });

      expect(adminMsg.isFromAdmin, isTrue);
      expect(adminMsg.isFromUser, isFalse);

      final ghMsg = FeedbackMessage.fromJson({
        'id': 'msg-3',
        'report_id': 'rep-1',
        'sender_role': 'github_dev',
        'sender_name': 'octocat',
        'message': 'Fixed in commit abc',
        'created_at': '2026-10-07T12:10:00Z',
      });

      expect(ghMsg.isFromGitHub, isTrue);
      expect(ghMsg.isFromUser, isFalse);
    });
  });

  group('FeedbackReportSummary Model Tests', () {
    test('Correctly deserializes report with joined app details', () {
      final json = {
        'id': 'rep-10',
        'user_id': 'user-1',
        'app_id': 'app-99',
        'title': 'Knop werkt niet',
        'description': 'Als ik klik gebeurt er niets',
        'category': 'bug',
        'severity': 'high',
        'status': 'open',
        'attachment_urls': [],
        'github_issue_number': 42,
        'github_issue_url': 'https://github.com/SchrobbeD/SchrobbeDock/issues/42',
        'created_at': '2026-10-07T10:00:00Z',
        'last_message_at': '2026-10-07T10:30:00Z',
        'has_unread_user': true,
        'has_unread_admin': false,
        'apps': {
          'id': 'app-99',
          'name': 'Dock Planner',
          'slug': 'dock_planner',
        },
      };

      final report = FeedbackReportSummary.fromJson(json);
      expect(report.id, equals('rep-10'));
      expect(report.title, equals('Knop werkt niet'));
      expect(report.appName, equals('Dock Planner'));
      expect(report.appSlug, equals('dock_planner'));
      expect(report.isOpen, isTrue);
      expect(report.isInProgress, isFalse);
      expect(report.isResolved, isFalse);
      expect(report.hasUnreadUser, isTrue);
      expect(report.hasUnreadAdmin, isFalse);
      expect(report.githubIssueNumber, equals(42));
    });

    test('Correctly identifies status states', () {
      final resolvedRep = FeedbackReportSummary.fromJson({
        'id': 'rep-11',
        'app_id': 'app-1',
        'title': 'Vraag beantwoord',
        'description': 'Alles duidelijk',
        'category': 'question',
        'severity': 'low',
        'status': 'resolved',
        'created_at': '2026-10-07T10:00:00Z',
      });

      expect(resolvedRep.isOpen, isFalse);
      expect(resolvedRep.isResolved, isTrue);
    });
  });
}
