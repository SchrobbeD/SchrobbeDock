import 'package:flutter/material.dart';
import '../schrobbedock_feedback.dart';

class SchrobbeDockCrashBoundary extends StatefulWidget {
  final Widget child;
  final String appSlug;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  const SchrobbeDockCrashBoundary({
    super.key,
    required this.child,
    required this.appSlug,
    this.errorBuilder,
  });

  @override
  State<SchrobbeDockCrashBoundary> createState() => _SchrobbeDockCrashBoundaryState();
}

class _SchrobbeDockCrashBoundaryState extends State<SchrobbeDockCrashBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _resetError() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, _stackTrace);
      }
      return _buildDefaultErrorUI(context);
    }

    return widget.child;
  }

  Widget _buildDefaultErrorUI(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Er is iets misgegaan',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'De applicatie ondervond een onverwachte fout. Je kunt dit probleem direct melden zodat wij het kunnen onderzoeken.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _resetError,
                          child: const Text('Opnieuw Proberen'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () {
                            SchrobbeDockFeedback.show(
                              context,
                              appSlug: widget.appSlug,
                              initialCategory: 'bug',
                              initialSeverity: 'high',
                              initialTitle: 'Crash: ${_error.toString().split('\n').first}',
                              prefilledDescription: 'Onverwachte app-crash opgetreden.',
                              stackTrace: _stackTrace,
                            );
                          },
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text('Probleem Melden'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
