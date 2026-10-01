import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/feedback_dialog.dart';
import 'src/screenshot_service.dart';

export 'src/feedback_dialog.dart';
export 'src/crash_boundary.dart';
export 'src/feedback_overlay.dart';
export 'src/screenshot_service.dart';
export 'src/environment_service.dart';

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
      ),
    );
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
