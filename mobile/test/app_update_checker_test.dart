import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_master/data/app_update_checker.dart';

void main() {
  group('AppUpdateChecker.checkForUpdate', () {
    test('reports an update when the release build number is newer', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.github.com/repos/nisakib07/daily_tracker/releases/latest',
        );
        return http.Response(
          jsonEncode({
            'tag_name': 'build-42',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url':
                    'https://github.com/nisakib07/daily_tracker/releases/download/build-42/app-release.apk',
              },
            ],
          }),
          200,
        );
      });
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      final info = await checker.checkForUpdate();

      expect(info, isNotNull);
      expect(info!.buildNumber, 42);
      expect(
        info.downloadUrl,
        'https://github.com/nisakib07/daily_tracker/releases/download/build-42/app-release.apk',
      );
    });

    test('reports nothing when already on the latest build', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'tag_name': 'build-10', 'assets': []}),
          200,
        ),
      );
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });

    test('reports nothing when the remote build is older', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'tag_name': 'build-3', 'assets': []}),
          200,
        ),
      );
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });

    test(
      'skips the check entirely for non-CI builds (build number 0)',
      () async {
        var requested = false;
        final client = MockClient((request) async {
          requested = true;
          return http.Response('{}', 200);
        });
        final checker = AppUpdateChecker(client: client, currentBuildNumber: 0);

        final info = await checker.checkForUpdate();

        expect(info, isNull);
        expect(requested, isFalse);
      },
    );

    test('fails silently on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });

    test('fails silently on a non-200 response', () async {
      final client = MockClient(
        (request) async => http.Response('Not Found', 404),
      );
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });

    test('fails silently when the release has no APK asset', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'tag_name': 'build-42',
            'assets': [
              {
                'name': 'source.zip',
                'browser_download_url': 'https://example.com/source.zip',
              },
            ],
          }),
          200,
        ),
      );
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });

    test('fails silently on a malformed tag name', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'tag_name': 'v1.2.3'}), 200),
      );
      final checker = AppUpdateChecker(client: client, currentBuildNumber: 10);

      expect(await checker.checkForUpdate(), isNull);
    });
  });
}
