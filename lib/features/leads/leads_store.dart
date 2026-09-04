import 'dart:async';

import 'package:chatdent/core/observable.dart';
import 'package:chatdent/core/save_local.dart';
import 'package:chatdent/core/save_remote.dart';
import 'package:chatdent/core/store.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/login/login_controller.dart';
import 'package:chatdent/features/network_actions/network_actions_controller.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/services/notifications/static_notifications.dart';
import 'package:chatdent/utils/demo_generator.dart';
import 'package:chatdent/utils/hash.dart';
import 'package:fluent_ui/fluent_ui.dart';

const _storeName = 'leads';

class Leads extends Store<Lead> {
  Leads()
      : super(
          modeling: Lead.fromJson,
          isDemo: launch.isDemo,
          onSyncStart: () {
            networkActions.isSyncing(networkActions.isSyncing() + 1);
          },
          onSyncEnd: () {
            networkActions.isSyncing(networkActions.isSyncing() - 1);
          },
        );

  final Set<String> _knownIds = {};
  bool _alertNewLeads = false;
  Timer? _alertDebounce;
  final List<String> _pendingAlertNames = [];

  @override
  init() {
    super.init();
    observableMap.observe(_alertIfNewLead);
    onLogoutCallbacks.add(() {
      _alertNewLeads = false;
      _knownIds.clear();
      _pendingAlertNames.clear();
      _alertDebounce?.cancel();
      endSession();
    });
    login.activators[_storeName] = () async {
      _alertNewLeads = false;
      await loaded;

      await deactivatePersistenceSession();
      await local?.dispose();
      local = SaveLocal(name: _storeName, uniqueId: simpleHash(login.url));
      await deleteMemoryAndLoadFromPersistence();

      if (launch.isDemo) {
        if (docs.isEmpty) setAll(demoLeads(40));
      } else {
        remote = SaveRemote(
          pbInstance: login.pb!,
          storeName: _storeName,
          onOnlineStatusChange: (current) {
            if (network.isOnline() != current) {
              network.isOnline(current);
            }
          },
        );
      }

      return () async {
        loginCtrl.loadingIndicator('Synchronizing leads');
        await synchronize();
        _knownIds
          ..clear()
          ..addAll(docs.keys);
        _alertNewLeads = !launch.isDemo;
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;

        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
  }

  void _alertIfNewLead(List<DictEvent> events) {
    if (!_alertNewLeads) return;
    final names = <String>[];
    for (final e in events) {
      if (e.id == '__removed_all__' || e.id == '__ignore_view__') {
        _knownIds
          ..clear()
          ..addAll(docs.keys);
        continue;
      }
      if (e.type == DictEventType.remove) {
        _knownIds.remove(e.id);
        continue;
      }
      if (e.type != DictEventType.add) continue;
      if (_knownIds.contains(e.id)) continue;
      _knownIds.add(e.id);
      final lead = e.document is Lead ? e.document as Lead : get(e.id);
      if (lead == null || lead.archived == true) continue;
      final name = lead.title.trim().isNotEmpty
          ? lead.title
          : (lead.phonesString.isNotEmpty ? lead.phonesString : txt('newLead'));
      names.add(name);
    }
    if (names.isEmpty) return;
    _pendingAlertNames.addAll(names);
    _alertDebounce?.cancel();
    _alertDebounce = Timer(const Duration(milliseconds: 400), () {
      final batch = [..._pendingAlertNames];
      _pendingAlertNames.clear();
      if (batch.isEmpty) return;
      staticNotifications.dingANotification(
        title: txt('newLead'),
        body: batch.length == 1 ? batch.first : batch.join(', '),
        icon: FluentIcons.headset,
      );
    });
  }

  Set<String> get existingPhoneKeys {
    return present.values
        .map((l) => l.phonesString)
        .where((p) => p.isNotEmpty)
        .toSet();
  }

  Lead? byPhone(String phonesString) {
    if (phonesString.isEmpty) return null;
    for (final lead in present.values) {
      if (lead.phonesString == phonesString) return lead;
    }
    return null;
  }
}

final leads = Leads();
