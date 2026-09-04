import 'dart:async';
import 'dart:convert';

import 'package:chatdent/core/observable.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/clinic_service_url.dart';
import 'package:http/http.dart' as http;

enum WhatsAppLink { disconnected, connecting, connected }

WhatsAppLink parseEvolutionLinkState(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'open':
      return WhatsAppLink.connected;
    case 'connecting':
      return WhatsAppLink.connecting;
    default:
      return WhatsAppLink.disconnected;
  }
}

class WhatsAppStatus {
  final link = ObservableState(WhatsAppLink.connecting);
  Timer? _timer;
  bool _busy = false;

  void ensurePolling() {
    if (_timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      _set(await _fetch());
    } finally {
      _busy = false;
    }
  }

  void _set(WhatsAppLink next) {
    if (link() == next) return;
    link(next);
  }

  Future<WhatsAppLink> _fetch() async {
    final evo = EvolutionSettings.fromJsonString(
      globalSettings.evolutionSettingsJson,
    );
    final base = resolveClinicServiceUrl(
      evo.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      login.url,
    );
    final key = evo.apiKey.trim();
    final instance =
        evo.instance.trim().isEmpty ? 'clinic_default' : evo.instance.trim();
    if (base.isEmpty || key.isEmpty) return WhatsAppLink.disconnected;

    try {
      final res = await http
          .get(
            Uri.parse('$base/instance/connectionState/$instance'),
            headers: {'apikey': key},
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return WhatsAppLink.disconnected;
      }
      final decoded = jsonDecode(res.body);
      String? state;
      if (decoded is Map) {
        final inst = decoded['instance'];
        if (inst is Map) state = inst['state']?.toString();
        state ??= decoded['state']?.toString();
      }
      return parseEvolutionLinkState(state);
    } catch (_) {
      return WhatsAppLink.disconnected;
    }
  }
}

final whatsappStatus = WhatsAppStatus();
