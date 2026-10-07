import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Wist Service Workers en Web Cache Storage en herlaadt de pagina.
/// Behoudt LocalStorage zodat Supabase Auth sessies actief blijven.
Future<void> clearWebCacheAndReload() async {
  try {
    final swContainer = web.window.navigator.serviceWorker;
    final registrationsList = await swContainer.getRegistrations().toDart;
    final dartRegistrations = registrationsList.toDart;
    for (final reg in dartRegistrations) {
      await reg.unregister().toDart;
    }
  } catch (_) {
    // Negeer eventuele fouten als service workers niet ondersteund of actief zijn
  }

  try {
    final cacheStorage = web.window.caches;
    final keysList = await cacheStorage.keys().toDart;
    final dartKeys = keysList.toDart;
    for (final key in dartKeys) {
      await cacheStorage.delete(key.toDart).toDart;
    }
  } catch (_) {
    // Negeer eventuele fouten als CacheStorage niet beschikbaar is
  }

  // Geforceerde herlaadactie
  web.window.location.reload();
}
