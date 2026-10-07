import 'web_cache_stub.dart'
    if (dart.library.js_interop) 'web_cache_web.dart' as impl;

class WebCacheHelper {
  /// Wist Service Workers en browser asset caches en herlaadt de pagina.
  static Future<void> clearCacheAndReload() => impl.clearWebCacheAndReload();
}
