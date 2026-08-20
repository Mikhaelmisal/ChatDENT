import 'dart:convert';

import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dicomPatientLinksMap — JSON parsing logic', () {
    test('empty string → empty map', () {
      const raw = '';
      final result = raw.isEmpty
          ? <String, String>{}
          : Map<String, String>.from(jsonDecode(raw) as Map);
      expect(result, isEmpty);
    });

    test('empty JSON object → empty map', () {
      const raw = '{}';
      final result = Map<String, String>.from(jsonDecode(raw) as Map);
      expect(result, isEmpty);
    });

    test('single link → correct map', () {
      const raw = '{"DICOM123":"chatdent-uuid-abc"}';
      final result = Map<String, String>.from(jsonDecode(raw) as Map);
      expect(result['DICOM123'], 'chatdent-uuid-abc');
      expect(result.length, 1);
    });

    test('multiple links → correct map', () {
      const raw =
          '{"DICOM001":"chatdent-1","DICOM002":"chatdent-2","DICOM003":"chatdent-3"}';
      final result = Map<String, String>.from(jsonDecode(raw) as Map);
      expect(result.length, 3);
      expect(result['DICOM001'], 'chatdent-1');
      expect(result['DICOM002'], 'chatdent-2');
      expect(result['DICOM003'], 'chatdent-3');
    });

    test('linkPatient round-trips through JSON encode/decode', () {
      // Simulate linkPatient: add to map, encode, decode, verify
      final map = <String, String>{};
      map['DICOM123'] = 'chatdent-uuid';
      final encoded = jsonEncode(map);
      final decoded = Map<String, String>.from(jsonDecode(encoded) as Map);
      expect(decoded['DICOM123'], 'chatdent-uuid');
    });

    test('unlinkPatient round-trips through JSON encode/decode', () {
      // Start with a map containing 2 links
      final map = <String, String>{
        'DICOM123': 'chatdent-1',
        'DICOM456': 'chatdent-2',
      };
      // Remove one (unlinkPatient)
      map.remove('DICOM123');
      final encoded = jsonEncode(map);
      final decoded = Map<String, String>.from(jsonDecode(encoded) as Map);
      expect(decoded.length, 1);
      expect(decoded.containsKey('DICOM123'), isFalse);
      expect(decoded['DICOM456'], 'chatdent-2');
    });

    test('malformed JSON → empty map (graceful fallback)', () {
      const raw = '{invalid json';
      Map<String, String> result;
      try {
        result = Map<String, String>.from(jsonDecode(raw) as Map);
      } catch (_) {
        result = {};
      }
      expect(result, isEmpty);
    });
  });

  group('LocalSettings — dicomViewerPrefs JSON round-trip', () {
    test('toJson includes dicomViewerPrefs', () {
      final settings = LocalSettings();
      settings.dicomViewerPrefs =
          '{"windowCenter":40,"windowWidth":400,"colorMap":"bone","invert":true,"rotationSteps":1}';
      final json = settings.toJson();
      expect(json.containsKey('dicomViewerPrefs'), isTrue);
      expect(json['dicomViewerPrefs'], contains('"windowCenter":40'));
      expect(json['dicomViewerPrefs'], contains('"colorMap":"bone"'));
      expect(json['dicomViewerPrefs'], contains('"invert":true'));
    });

    test('fromJson restores dicomViewerPrefs', () {
      final settings = LocalSettings();
      const prefsJson =
          '{"windowCenter":40,"windowWidth":400,"colorMap":"hotIron","invert":false,"rotationSteps":2}';
      settings.fromJson({'dicomViewerPrefs': prefsJson});
      expect(settings.dicomViewerPrefs, prefsJson);
    });

    test('fromJson defaults dicomViewerPrefs to empty when missing', () {
      final settings = LocalSettings();
      settings.dicomViewerPrefs = 'should-be-overwritten';
      settings.fromJson({}); // no dicomViewerPrefs key
      expect(settings.dicomViewerPrefs, isEmpty);
    });

    test('toJson/fromJson round-trip preserves viewer prefs', () {
      final original = LocalSettings();
      original.dicomViewerPrefs =
          '{"windowCenter":80,"windowWidth":200,"colorMap":"grayscale","invert":false,"rotationSteps":0}';
      final json = original.toJson();

      final restored = LocalSettings();
      restored.fromJson(json);
      expect(restored.dicomViewerPrefs, original.dicomViewerPrefs);
    });

    test('default dicomViewerPrefs is empty (use DICOM defaults)', () {
      final settings = LocalSettings();
      expect(settings.dicomViewerPrefs, isEmpty);
    });
  });
}
