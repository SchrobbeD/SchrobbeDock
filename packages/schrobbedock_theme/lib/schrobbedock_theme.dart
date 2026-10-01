import 'package:flutter/widgets.dart';
import 'src/theme_customizer_dialog.dart';
import 'src/schrobbedock_theme_controller.dart';

export 'src/theme_preferences.dart';
export 'src/theme_presets.dart';
export 'src/app_theme.dart';
export 'src/schrobbedock_theme_controller.dart';
export 'src/schrobbedock_theme_scope.dart';
export 'src/theme_customizer_dialog.dart';

class SchrobbeDockTheme {
  /// Open het thema- en personalisatiedialoogvenster met 1 regel code
  static Future<void> showCustomizer(
    BuildContext context, {
    SchrobbeDockThemeController? controller,
  }) {
    return ThemeCustomizerDialog.show(context, controller: controller);
  }
}
