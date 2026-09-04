import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/whatsapp_status.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// 18px slot (same as app-bar icons) with a status lamp inside.
class WhatsAppStatusLight extends StatelessWidget {
  const WhatsAppStatusLight({super.key});

  static const double _slot = 18;
  static const double _lamp = 11;

  @override
  Widget build(BuildContext context) {
    final status = whatsappStatus.link();
    final Color color;
    switch (status) {
      case WhatsAppLink.connected:
        color = Colors.successPrimaryColor;
      case WhatsAppLink.connecting:
        color = Colors.warningPrimaryColor;
      case WhatsAppLink.disconnected:
        color = Colors.errorPrimaryColor;
    }
    return SizedBox(
      width: _slot,
      height: _slot,
      child: Center(
        child: Container(
          width: _lamp,
          height: _lamp,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

String whatsappStatusTooltip() {
  switch (whatsappStatus.link()) {
    case WhatsAppLink.connected:
      return txt('whatsappConnected');
    case WhatsAppLink.connecting:
      return txt('whatsappConnecting');
    case WhatsAppLink.disconnected:
      return txt('whatsappDisconnected');
  }
}
