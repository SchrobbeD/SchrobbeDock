class AppInfo {
  final String id;
  final String slug;
  final String name;
  final bool isActive;

  const AppInfo({
    required this.id,
    required this.slug,
    required this.name,
    required this.isActive,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'is_active': isActive,
    };
  }
}

class UserLicense {
  final String id;
  final String userId;
  final String appId;
  final String tier;
  final String role;
  final DateTime? validUntil;
  final DateTime createdAt;
  final AppInfo? app;

  const UserLicense({
    required this.id,
    required this.userId,
    required this.appId,
    required this.tier,
    required this.role,
    this.validUntil,
    required this.createdAt,
    this.app,
  });

  bool get isValid {
    if (validUntil == null) return true;
    return validUntil!.isAfter(DateTime.now());
  }

  factory UserLicense.fromJson(Map<String, dynamic> json) {
    AppInfo? appInfo;
    if (json['apps'] is Map<String, dynamic>) {
      appInfo = AppInfo.fromJson(json['apps'] as Map<String, dynamic>);
    }

    return UserLicense(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      tier: json['tier'] as String? ?? 'basic',
      role: json['role'] as String? ?? 'user',
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      app: appInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'app_id': appId,
      'tier': tier,
      'role': role,
      'valid_until': validUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (app != null) 'apps': app!.toJson(),
    };
  }
}
