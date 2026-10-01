import 'package:flutter/material.dart';
import '../schrobbedock_feedback.dart';

class SchrobbeDockFeedbackOverlay extends StatelessWidget {
  final Widget child;
  final String appSlug;
  final Alignment alignment;

  const SchrobbeDockFeedbackOverlay({
    super.key,
    required this.child,
    required this.appSlug,
    this.alignment = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton.extended(
                heroTag: 'schrobbedock_feedback_fab',
                onPressed: () {
                  SchrobbeDockFeedback.show(context, appSlug: appSlug);
                },
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Hulp & Feedback'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
