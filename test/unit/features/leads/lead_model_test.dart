import 'package:chatdent/features/leads/lead_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lead.fromJson', () {
    test('parses core fields', () {
      final lead = Lead.fromJson({
        'id': 'lead1',
        'title': 'Priya Nair',
        'phone': '+91 98765 43210',
        'email': 'priya@example.com',
        'source': LeadSource.facebook,
        'campaign': 'Implant ads',
        'interest': 'Implant',
        'notes': 'Called after form',
        'stage': LeadStage.contacted,
      });

      expect(lead.id, 'lead1');
      expect(lead.title, 'Priya Nair');
      expect(lead.phonesString, '919876543210');
      expect(lead.email, 'priya@example.com');
      expect(lead.source, LeadSource.facebook);
      expect(lead.campaign, 'Implant ads');
      expect(lead.interest, 'Implant');
      expect(lead.notes, 'Called after form');
      expect(lead.stage, LeadStage.contacted);
    });

    test('defaults stage and source', () {
      final lead = Lead.fromJson({'id': 'min'});
      expect(lead.stage, LeadStage.newLead);
      expect(lead.source, LeadSource.manual);
      expect(lead.phone, isEmpty);
      expect(lead.whatsappConsent, isTrue);
    });

    test('india 10-digit numbers persist as 91 plus local digits', () {
      final lead = Lead.fromJson({'phone': '9876543210'});
      expect(lead.phonesString, '919876543210');
      expect(lead.toJson()['phone'], '919876543210');
    });

    test('round-trip preserves fields', () {
      final original = Lead.fromJson({
        'id': 'rt1',
        'title': 'Asha',
        'phone': '919876543210',
        'source': LeadSource.instagram,
        'stage': LeadStage.interested,
        'nextFollowUpAt': 1700000000000,
      });
      final copy = Lead.fromJson(original.toJson());
      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.phonesString, original.phonesString);
      expect(copy.source, original.source);
      expect(copy.stage, original.stage);
      expect(copy.nextFollowUpAt, original.nextFollowUpAt);
    });

    test('called and marketing flags round-trip', () {
      final lead = Lead.fromJson({
        'id': 'c1',
        'called': true,
        'coming': true,
        'marketingQueued': true,
        'marketingImageUrl': 'https://example.com/fly.jpg',
      });
      expect(lead.called, isTrue);
      final copy = Lead.fromJson(lead.toJson());
      expect(copy.called, isTrue);
      expect(copy.coming, isTrue);
      expect(copy.marketingQueued, isTrue);
      expect(copy.marketingImageUrl, 'https://example.com/fly.jpg');
    });
  });
}
