class AppVersion {
  /// SemVer versienummer gecombineerd met buildnummer (bijv. '1.0.0+42').
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+dev',
  );

  /// Volledige Git commit SHA geïnjecteerd door GitHub Actions.
  static const String gitCommitSha = String.fromEnvironment(
    'GIT_COMMIT_SHA',
    defaultValue: 'dev-local',
  );

  /// ISO 8601 UTC timestamp van het build-moment (bijv. '2026-10-07T20:45:00Z').
  static const String buildTimestamp = String.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: '',
  );

  /// Korte 7-teken commit hash (bijv. '0832cf6').
  static String get shortSha {
    if (gitCommitSha.length > 7) {
      return gitCommitSha.substring(0, 7);
    }
    return gitCommitSha;
  }

  /// Compacte weergave voor badges in de AppBar (bijv. 'v1.0.0 (0832cf6)').
  static String get badgeDisplay {
    final cleanVersion = appVersion.contains('+')
        ? appVersion.split('+').first
        : appVersion;
    return 'v$cleanVersion ($shortSha)';
  }

  /// Volledige versieweergave (bijv. 'v1.0.0+42 (0832cf6)').
  static String get fullDisplay => 'v$appVersion ($shortSha)';

  /// Directe GitHub URL naar de specifieke commit.
  static String? get githubCommitUrl {
    if (gitCommitSha == 'dev-local' || gitCommitSha.isEmpty) return null;
    return 'https://github.com/SchrobbeD/SchrobbeDock/commit/$gitCommitSha';
  }

  /// Geformatteerde buildtijdstip weergave in de lokale tijdzone.
  static String get formattedBuildTime {
    if (buildTimestamp.isEmpty) return 'Lokale Ontwikkelbuild';
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
