import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WhatsApp template note ids are PocketBase-safe 15 chars', () {
    const ids = [
      'wa_templates___',
      'wa_welcome_____',
      'wa_confirm_____',
      'wa_history_____',
      'wa_aftercare___',
      'wa_remind______',
      'wa_birthday____',
      'wa_review______',
      'wa_alert_new___',
      'wa_alert_back__',
      'wa_optout______',
    ];
    for (final id in ids) {
      expect(id.length, 15, reason: id);
      expect(RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(id), isTrue);
    }
  });
}
