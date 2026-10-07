class AppVersion {
  /// SemVer versienummer gecombineerd met optioneel buildnummer (bijv. '1.0.0+42').
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+dev',
  );

  /// Volledige Git commit SHA geïnjecteerd door GitHub Actions of build scripts.
  static const String gitCommitSha = String.fromEnvironment(
    'GIT_COMMIT_SHA',
    defaultValue: 'dev-local',
  );

  /// ISO 8601 UTC timestamp van het build-moment (bijv. '2026-10-07T20:45:00Z').
  static const String buildTimestamp = String.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: '',
  );

  /// Geeft aan of de app in actieve lokale ontwikkelmodus draait (zonder statische build-defines).
  static bool get isLocalDev =>
      gitCommitSha == 'dev-local' || gitCommitSha.isEmpty;

  /// Korte 7-teken commit hash (bijv. '0832cf6').
  static String get shortSha {
    if (gitCommitSha.length > 7) {
      return gitCommitSha.substring(0, 7);
    }
    return gitCommitSha;
  }

  /// Compacte weergave voor badges in de AppBar (bijv. 'v1.0.0 (0832cf6)' of 'v1.0.0 (dev)').
  static String get badgeDisplay {
    final cleanVersion = appVersion.contains('+')
        ? appVersion.split('+').first
        : appVersion;
    final shaDisplay = isLocalDev ? 'dev' : shortSha;
    return 'v$cleanVersion ($shaDisplay)';
  }

  /// Volledige versieweergave (bijv. 'v1.0.0+42 (0832cf6)').
  static String get fullDisplay => 'v$appVersion ($shortSha)';

  /// Directe GitHub URL naar de specifieke commit.
  static String? githubCommitUrl({
    String repoUrl = 'https://github.com/SchrobbeD/SchrobbeDock',
  }) {
    if (isLocalDev) return null;
    return '$repoUrl/commit/$gitCommitSha';
  }

  /// Geformatteerde buildtijdstip weergave in de lokale tijdzone.
  static String get formattedBuildTime {
    if (buildTimestamp.isEmpty) {
      return 'Lokale Ontwikkelmodus (geen statische build)';
    }
    try {
      final parsed = DateTime.parse(buildTimestamp).toLocal();
      final year = parsed.year;
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    } catch (_) {
      return buildTimestamp;
    }
  }
}
