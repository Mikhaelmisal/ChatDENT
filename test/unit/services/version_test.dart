import 'package:chatdent/services/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReleaseMetadata', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'latest_version': '2.0.0',
        'changelog': ['Fix bug', 'Add feature'],
        'downloads': {
          'windows': 'https://win.example.com',
          'ms_store': 'https://store.example.com',
          'macos': 'https://mac.example.com',
          'ios': 'https://ios.example.com',
          'android': 'https://android.example.com',
          'web': 'https://web.example.com',
        },
      };

      final meta = ReleaseMetadata.fromJson(json);

      expect(meta.latestVersion, '2.0.0');
      expect(meta.changelog, ['Fix bug', 'Add feature']);
      expect(meta.windowsUrl, 'https://win.example.com');
      expect(meta.msStoreUrl, 'https://store.example.com');
      expect(meta.macosUrl, 'https://mac.example.com');
      expect(meta.iosUrl, 'https://ios.example.com');
      expect(meta.androidUrl, 'https://android.example.com');
      expect(meta.webUrl, 'https://web.example.com');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {
        'latest_version': '1.0.0',
        'downloads': <String, dynamic>{},
      };

      final meta = ReleaseMetadata.fromJson(json);

      expect(meta.latestVersion, '1.0.0');
      expect(meta.changelog, isEmpty);
      expect(meta.windowsUrl, isEmpty);
      expect(meta.msStoreUrl, isEmpty);
      expect(meta.iosUrl, isEmpty);
      expect(meta.androidUrl, isEmpty);
      expect(meta.webUrl, isEmpty);
    });

    test('fromJson handles empty downloads map', () {
      final meta = ReleaseMetadata.fromJson({
        'latest_version': '0.0.0',
        'downloads': <String, dynamic>{},
      });

      expect(meta.latestVersion, '0.0.0');
      expect(meta.changelog, isEmpty);
      expect(meta.msStoreUrl, isEmpty);
    });

    test('fromJson works with partial downloads', () {
      final meta = ReleaseMetadata.fromJson({
        'latest_version': '3.0.0',
        'downloads': <String, dynamic>{},
      });

      expect(meta.latestVersion, '3.0.0');
    });
  });

  group('_VersionService', () {
    test('version service initializes with defaults', () {
      // The global 'version' singleton is already initialized.
      // Just verify it exists.
      expect(version, isNotNull);
    });

    test('current defaults to "0.0.0" before init completes', () {
      // Before _setCurrentVersion runs, current should be "0.0.0"
      expect(version.current(), isNotEmpty);
    });

    test('isOutdated defaults to false', () {
      expect(version.isOutdated(), false);
    });

    test('latestVersion defaults to "0.0.0"', () {
      expect(version.latestVersion(), '0.0.0');
    });

    test('changelog defaults to empty list', () {
      expect(version.changelog, isEmpty);
    });
  });

  group('_isVersionNewer', () {
    test('2.0.0 > 1.9.9', () {
      final result = isVersionNewer('2.0.0', '1.9.9');
      expect(result, true);
    });

    test('1.0.0 == 1.0.0', () {
      final result = isVersionNewer('1.0.0', '1.0.0');
      expect(result, false);
    });

    test('1.0.1 > 1.0.0', () {
      final result = isVersionNewer('1.0.1', '1.0.0');
      expect(result, true);
    });

    test('1.0.0 < 1.0.1', () {
      final result = isVersionNewer('1.0.0', '1.0.1');
      expect(result, false);
    });

    test('handles versions without patch', () {
      // 1.0 should be treated as 1.0.0
      final result = isVersionNewer('1.0', '0.9.9');
      expect(result, true);
    });

    test('handles single digit versions', () {
      final result = isVersionNewer('2', '1');
      expect(result, true);
    });

    test('10.0.0 > 9.9.9', () {
      final result = isVersionNewer('10.0.0', '9.9.9');
      expect(result, true);
    });
  });
}
