import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/feedback_dialog.dart';
import 'src/feedback_portal_view.dart';
import 'src/screenshot_service.dart';

export 'src/feedback_dialog.dart';
export 'src/crash_boundary.dart';
export 'src/feedback_overlay.dart';
export 'src/screenshot_service.dart';
export 'src/environment_service.dart';
export 'src/feedback_chat_widget.dart';
export 'src/feedback_portal_view.dart';
export 'src/models/feedback_message.dart';
export 'src/models/feedback_report_summary.dart';

class SchrobbeDockFeedback {
  /// Toont het feedback- en probleemmeldingsdialoogvenster met automatische screenshot & metadata
  static Future<void> show(
    BuildContext context, {
    required String appSlug,
    String initialCategory = 'bug',
    String initialSeverity = 'medium',
    String? initialTitle,
    String? prefilledDescription,
    StackTrace? stackTrace,
    bool autoCaptureScreenshot = true,
    bool showGitHubLink = false,
  }) async {
    Uint8List? screenshot;
    if (autoCaptureScreenshot) {
      screenshot = await ScreenshotService.captureContext(context);
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FeedbackDialog(
        appSlug: appSlug,
        initialScreenshot: screenshot,
        initialCategory: initialCategory,
        initialSeverity: initialSeverity,
        initialTitle: initialTitle,
        initialDescription: prefilledDescription,
        stackTrace: stackTrace,
        showGitHubLink: showGitHubLink,
      ),
    );
  }

  /// Toont het status- en communicatieportaal ("Mijn Meldingen") in een responsive dialoog
  static Future<void> showPortal(
    BuildContext context, {
    String? appSlug,
    bool isAdmin = false,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => FeedbackPortalView(
            appSlug: appSlug,
            isAdmin: isAdmin,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } else {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 1000,
            height: 700,
            child: FeedbackPortalView(
              appSlug: appSlug,
              isAdmin: isAdmin,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      );
    }
  }

  /// Realtime stream voor ongelezen feedbackmeldingen (handig voor badge-tellers in de UI)
  static Stream<int> watchUnreadCount({
    String? appSlug,
    bool isAdmin = false,
  }) async* {
    final client = Supabase.instance.client;

    Future<int> fetchCount() async {
      try {
        final user = client.auth.currentUser;
        if (user == null) return 0;

        var query = client.from('feedback_reports').select('id');
        if (isAdmin) {
          query = query.eq('has_unread_admin', true);
        } else {
          query = query.eq('user_id', user.id).eq('has_unread_user', true);
        }

        final res = await query;
        return (res as List).length;
      } catch (_) {
        return 0;
      }
    }

    yield await fetchCount();

    // Polling interval met lage frequentie (10s) als backup naast Realtime
    await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
      yield await fetchCount();
    }
  }

  /// Hulpmethode om een onverwachte crash direct via het dialoogvenster te rapporteren
  static Future<void> reportCrash(
    Object error,
    StackTrace? stackTrace, {
    required String appSlug,
    BuildContext? context,
  }) async {
    if (context != null && context.mounted) {
      await show(
        context,
        appSlug: appSlug,
        initialCategory: 'bug',
        initialSeverity: 'high',
        initialTitle: 'Crash: ${error.toString().split('\n').first}',
        prefilledDescription: 'Onverwachte uitzondering:\n$error',
        stackTrace: stackTrace,
      );
    }
  }
}
