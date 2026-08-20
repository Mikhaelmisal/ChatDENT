import 'package:chatdent/core/save_local.dart';
import 'package:chatdent/core/save_remote.dart';
import 'package:chatdent/core/store.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/login/login_controller.dart';
import 'package:chatdent/features/network_actions/network_actions_controller.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/utils/demo_generator.dart';
import 'package:chatdent/utils/hash.dart';

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

  @override
  init() {
    super.init();
    onLogoutCallbacks.add(endSession);
    login.activators[_storeName] = () async {
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
        networkActions.syncCallbacks[_storeName] = synchronize;
        networkActions.reconnectCallbacks[_storeName] = remote!.checkOnline;

        network.onOnline[_storeName] = synchronize;
        network.onOffline[_storeName] = cancelRealtimeSub;
      };
    };
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
