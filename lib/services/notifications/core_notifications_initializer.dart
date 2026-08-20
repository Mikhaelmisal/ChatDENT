import 'dart:io';

import 'package:chatdent/firebase_options.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/notifications/core_firebase_messaging.dart';
import 'package:chatdent/services/notifications/core_local_notification.dart';
import 'package:chatdent/services/notifications/push_deferring.dart';
import 'package:chatdent/services/notifications/push_relay.dart';
import 'package:chatdent/services/patient_side.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:chatdent/utils/js/js_bridge.dart';

class Messaging {
  static FirebaseMessagingService? firebase;
  static LocalNotificationsService? local;
  static Future<void> initializeReceiving() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebase = FirebaseMessagingService.instance();
        await firebase!.init();
        local = LocalNotificationsService.instance();
        await local!.init();
      } catch (_) {
        // Push works after a real ChatDENT Firebase project is linked.
        // Clinic login and sync do not need Firebase.
        firebase = null;
        local = null;
      }
    }
  }

  static Future<void> identifyDevice({bool isPatient = false}) async {
    // initialize deferred push
    deferredPush.init(isPatient ? patientSide.server : login.url);

    // ensure clinic key.. which is a key needed to communicate with the relay server
    final relayKey =
        isPatient ? patientSide.relayKey : await PushRelay.ensureKey();

    if (kIsWeb) {
      // check(/fcm/fcm.js)
      // communication to javascript through js bridge
      // by setting global variables
      // once those global variables are set
      // the javascript code will get the token
      // and use it to identify itself to the relay server

      final server = isPatient ? patientSide.server : login.url;
      final id = isPatient ? patientSide.patientID : login.currentAccountID;

      JSBridge.setGlobalVariable("clinicKey", relayKey);
      JSBridge.setGlobalVariable("clinicServer", server);
      JSBridge.setGlobalVariable("accountId", id);
      JSBridge.setGlobalVariable("lang", locale.s.$code);
      JSBridge.setGlobalVariable("shouldShowPrompt", "yes");
    } else {
      // this is for android and ios
      // this identifies this device to the relay server
      if (firebase != null &&
          firebase!.authStatus == AuthorizationStatus.authorized) {
        await PushRelay.putDevice(isPatient: isPatient);
      }
    }

    // no need for windows
    // since we're not supporting it yet with notifications
  }
}
