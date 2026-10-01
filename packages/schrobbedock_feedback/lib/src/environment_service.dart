import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class EnvironmentService {
  /// Verzamelt omgevings- en device-informatie op een privacy-veilige manier
  static Map<String, dynamic> collect(
    BuildContext? context, {
    String appVersion = '1.0.0',
    String? currentRoute,
  }) {
    final info = <String, dynamic>{
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'is_web': kIsWeb,
      'app_version': appVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    if (context != null) {
      try {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery != null) {
          info['screen_resolution'] =
              '${mediaQuery.size.width.toInt()}x${mediaQuery.size.height.toInt()}';
          info['device_pixel_ratio'] = mediaQuery.devicePixelRatio;
          info['orientation'] = mediaQuery.orientation.name;
        }

        final route = currentRoute ??
            ModalRoute.of(context)?.settings.name ??
            '/';
        info['route'] = route;
      } catch (_) {}
    }

    if (kIsWeb) {
      info['os'] = 'Web Client';
      info['browser'] = defaultTargetPlatform.name;
    } else {
      info['os'] = defaultTargetPlatform.name;
    }

    return info;
  }
}
