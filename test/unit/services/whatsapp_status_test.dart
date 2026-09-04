import 'package:chatdent/services/whatsapp_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Evolution connectionState values', () {
    expect(parseEvolutionLinkState('open'), WhatsAppLink.connected);
    expect(parseEvolutionLinkState('OPEN'), WhatsAppLink.connected);
    expect(parseEvolutionLinkState('connecting'), WhatsAppLink.connecting);
    expect(parseEvolutionLinkState('close'), WhatsAppLink.disconnected);
    expect(parseEvolutionLinkState('closed'), WhatsAppLink.disconnected);
    expect(parseEvolutionLinkState(null), WhatsAppLink.disconnected);
    expect(parseEvolutionLinkState(''), WhatsAppLink.disconnected);
  });
}
