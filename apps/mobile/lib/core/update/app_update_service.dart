import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  const AppUpdateService({http.Client? client}) : _client = client;

  static const manifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
    defaultValue: 'https://masjidmanager-saas-sujon.web.app/app-update.json',
  );

  final http.Client? _client;

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (manifestUrl.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    final client = _client ?? http.Client();

    try {
      final response = await client
          .get(Uri.parse(manifestUrl), headers: {'cache-control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final manifest = AppUpdateManifest.fromJson(json);
      if (!manifest.enabled ||
          manifest.latestBuildNumber <= currentBuildNumber) {
        return null;
      }

      return AppUpdateInfo(
        currentVersionName: packageInfo.version,
        currentBuildNumber: currentBuildNumber,
        manifest: manifest,
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersionName,
    required this.currentBuildNumber,
    required this.manifest,
  });

  final String currentVersionName;
  final int currentBuildNumber;
  final AppUpdateManifest manifest;

  bool get isRequired => currentBuildNumber < manifest.minimumBuildNumber;
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.enabled,
    required this.latestVersionName,
    required this.latestBuildNumber,
    required this.minimumBuildNumber,
    required this.apkUrl,
    required this.title,
    required this.body,
    required this.releaseNotes,
  });

  final bool enabled;
  final String latestVersionName;
  final int latestBuildNumber;
  final int minimumBuildNumber;
  final String apkUrl;
  final String title;
  final String body;
  final List<String> releaseNotes;

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    return AppUpdateManifest(
      enabled: json['enabled'] as bool? ?? true,
      latestVersionName: json['latestVersionName'] as String? ?? '1.0.0',
      latestBuildNumber: _asInt(json['latestBuildNumber']),
      minimumBuildNumber: _asInt(json['minimumBuildNumber']),
      apkUrl: json['apkUrl'] as String? ?? '',
      title: json['title'] as String? ?? 'A new version is ready',
      body:
          json['body'] as String? ??
          'Update now to get the latest improvements.',
      releaseNotes: (json['releaseNotes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
