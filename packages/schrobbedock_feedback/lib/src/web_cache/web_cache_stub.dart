/// Fallback implementatie voor niet-web omgevingen (zoals desktop, mobiel of tests).
Future<void> clearWebCacheAndReload() async {
  // Geen browser cache om te wissen in niet-web omgevingen.
}
