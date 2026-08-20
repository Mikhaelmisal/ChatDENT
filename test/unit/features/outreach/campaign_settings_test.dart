import 'package:chatdent/features/leads/whatsapp_templates.dart';
import 'package:chatdent/features/outreach/campaign_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('campaign and flyer ids are PocketBase-safe 15 chars', () {
    expect(WhatsAppCampaign.settingId.length, 15);
    expect(WhatsAppCampaign.flyerRecordId.length, 15);
    expect(WhatsAppTemplateIds.settingId.length, 15);
    expect(RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(WhatsAppCampaign.settingId),
        isTrue);
    expect(RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(WhatsAppCampaign.flyerRecordId),
        isTrue);
  });

  test('campaign JSON round-trip', () {
    const c = WhatsAppCampaign(
      googleReviewUrl: 'https://g.page/r/demo/review',
      sendFlyerWithChat: false,
      flyerFile: 'flyer.jpg',
      marketingImageUrl: 'https://cdn.example.com/ad.jpg',
    );
    final back = WhatsAppCampaign.fromJsonString(c.toJsonString());
    expect(back.googleReviewUrl, 'https://g.page/r/demo/review');
    expect(back.sendFlyerWithChat, isFalse);
    expect(back.flyerFile, 'flyer.jpg');
    expect(back.marketingImageUrl, 'https://cdn.example.com/ad.jpg');
  });

  test('daysUntilBirthday uses the next occurrence', () {
    expect(daysUntilBirthday(DateTime(1990, 8, 19), DateTime(2026, 8, 19)), 0);
    expect(daysUntilBirthday(DateTime(1990, 8, 20), DateTime(2026, 8, 19)), 1);
    expect(daysUntilBirthday(DateTime(1990, 8, 18), DateTime(2026, 8, 19)),
        greaterThan(300));
    expect(daysUntilBirthday(DateTime(90, 8, 19), DateTime(2026, 8, 19)), isNull);
  });
}
