import 'package:flutter/widgets.dart';
import 'schrobbedock_theme_controller.dart';
import 'theme_preferences.dart';

/// InheritedNotifier die een [SchrobbeDockThemeController] beschikbaar stelt
/// in de widget tree zonder externe state management libraries.
class SchrobbeDockThemeScope extends InheritedNotifier<SchrobbeDockThemeController> {
  const SchrobbeDockThemeScope({
    super.key,
    required SchrobbeDockThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static SchrobbeDockThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SchrobbeDockThemeScope>()
        ?.notifier;
  }

  static SchrobbeDockThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'Geen SchrobbeDockThemeScope gevonden in de context. '
      'Wikkel je App in een SchrobbeDockThemeScope(controller: ...) of gebruik SchrobbeDockThemeScope.maybeOf(context).',
    );
    return controller!;
  }

  static ThemePreferences preferencesOf(BuildContext context) {
    return of(context).preferences;
  }
}
