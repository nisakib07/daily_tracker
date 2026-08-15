import 'dart:convert';

import 'package:http/http.dart' as http;

/// The build number baked into the app at compile time by CI
/// (--dart-define=APP_BUILD_NUMBER=$GITHUB_RUN_NUMBER, see
/// .github/workflows/build-android.yml). Left at 0 for any build that
/// didn't go through CI (local `flutter run`, local release builds), which
/// doubles as the signal to skip the update check entirely rather than
/// nagging during development.
const int currentAppBuildNumber = int.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: 0,
);

class AppUpdateInfo {
  const AppUpdateInfo({required this.buildNumber, required this.downloadUrl});

  final int buildNumber;
  final String downloadUrl;
}

/// Checks GitHub Releases for a newer signed APK than the one currently
/// running. This exists because the app isn't on Play Store (no $25
/// developer account) - CI publishes a release on every push to main, and
/// this is how the app finds out about it instead of the user manually
/// rebuilding and reinstalling each time.
class AppUpdateChecker {
  AppUpdateChecker({http.Client? client, int? currentBuildNumber})
    : _client = client ?? http.Client(),
      _currentBuildNumber = currentBuildNumber ?? currentAppBuildNumber;

  final http.Client _client;
  // Injectable (defaults to the compile-time constant) so tests can exercise
  // the comparison logic without needing a --dart-define on the whole suite.
  final int _currentBuildNumber;

  static const _releasesUrl =
      'https://api.github.com/repos/nisakib07/daily_tracker/releases/latest';
  static final _tagPattern = RegExp(r'build-(\d+)');

  /// Never throws - any failure (offline, rate-limited, malformed response)
  /// just means no update is reported. Nobody should see an error dialog
  /// because a background version check failed.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (_currentBuildNumber <= 0) return null;

    try {
      final response = await _client
          .get(
            Uri.parse(_releasesUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final tagName = decoded['tag_name'];
      if (tagName is! String) return null;
      final match = _tagPattern.firstMatch(tagName);
      if (match == null) return null;

      final remoteBuildNumber = int.tryParse(match.group(1)!);
      if (remoteBuildNumber == null ||
          remoteBuildNumber <= _currentBuildNumber) {
        return null;
      }

      final assets = decoded['assets'];
      if (assets is! List) return null;
      final apkAsset = assets
          .whereType<Map>()
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (asset) =>
                (asset['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
            orElse: () => const {},
          );
      final downloadUrl = apkAsset['browser_download_url'];
      if (downloadUrl is! String) return null;

      return AppUpdateInfo(
        buildNumber: remoteBuildNumber,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
