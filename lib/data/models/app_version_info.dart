import 'json_utils.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.platform,
    required this.minVersion,
    required this.latestVersion,
    required this.storeUrl,
  });

  final String platform;
  final String minVersion;
  final String latestVersion;
  final String storeUrl;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      platform: parseString(json['platform'], field: 'platform'),
      minVersion: parseString(
        json['min_version'] ?? json['minVersion'],
        field: 'min_version',
      ),
      latestVersion: parseString(
        json['latest_version'] ?? json['latestVersion'],
        field: 'latest_version',
      ),
      storeUrl: parseString(
        json['store_url'] ?? json['storeUrl'],
        field: 'store_url',
      ),
    );
  }
}
