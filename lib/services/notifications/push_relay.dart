import 'dart:convert';

import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/notifications/model_push_data.dart';
import 'package:chatdent/services/patient_side.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/hash.dart';
import 'package:chatdent/utils/logger.dart';
import 'package:http/http.dart' as http;

class PushRelay {
  static bool deviceIsPut = false;

  static const relayServer =
      "https://notifications.chatdent.app";
  static const relayKeyIDInCollection = "notifications_k";

  static Future<String?> _getRelayKey() async {
    try {
      final keyRecord = await login.pb!
          .collection(dataCollectionName)
          .getOne(relayKeyIDInCollection);
      return keyRecord.get<String>("data.key");
    } catch (e) {
      return null;
    }
  }

  /// This function ensures that a key specific to this server exists
  /// it tries to fetch it from the database, and if it doesn't exist, it creates it
  /// this function must be called right after a successful login occured
  static Future<String> ensureKey() async {
    final key = await _getRelayKey();
    if (key == null) {
      final String newKey = secureHash(
          "${login.url} ${login.token} ${login.email} ${DateTime.now().millisecondsSinceEpoch.toString()}");
      await login.pb!.collection(dataCollectionName).create(body: {
        "id": relayKeyIDInCollection,
        "data": jsonEncode({"key": newKey}),
      });
      return newKey;
    } else {
      return key;
    }
  }

  /// This function puts a new device into the relay database
  /// The server would add the token only if it doesn't exist
  static Future<void> putDevice({bool isPatient = false}) async {
    try {
      final relayKey = isPatient ? patientSide.relayKey : await _getRelayKey();

      final res = await http
          .post(
            Uri.parse('$relayServer/put-device'),
            body: jsonEncode({
              "clinicServer": isPatient ? patientSide.server : login.url,
              "clinicKey": relayKey,
              "deviceToken": login.pushNotificationsToken,
              "accountId":
                  isPatient ? patientSide.patientID : login.currentAccountID
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.body == "ok") {
        deviceIsPut = true;
      }
    } catch (e) {
      // Cloud push relay is optional until notifications.chatdent.app is hosted.
      logger("PushRelay.putDevice skipped: $e", null, 3);
    }
  }

  /// This function replaces an old token with a new one
  /// when FCM refreshes the token
  static Future<void> replaceToken(String oldToken, String newToken) async {
    try {
      final relayKey = await _getRelayKey();

      await http
          .post(
            Uri.parse('$relayServer/replace-token'),
            body: jsonEncode({
              "clinicServer": login.url,
              "clinicKey": relayKey,
              "oldToken": oldToken,
              "newToken": newToken,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      logger("PushRelay.replaceToken skipped: $e", null, 3);
    }
  }

  static Future<void> sendPush(List<PushData> bulkData) async {
    if (bulkData.isEmpty) return;

    try {
      final relayKey = await _getRelayKey();

      final requests = bulkData
          .map((p) {
            p.targetIDs.removeWhere((id) => id == login.currentAccountID);
            return p;
          })
          .where((p) => p.targetIDs.isNotEmpty)
          .map(
            (data) => http
                .post(
                  Uri.parse('$relayServer/push'),
                  body: jsonEncode({
                    "clinicServer": login.url,
                    "clinicKey": relayKey,
                    "accountIds": data.targetIDs,
                    "data": {"payload": jsonEncode(data.toJson())},
                  }),
                )
                .timeout(const Duration(seconds: 8)),
          );

      await Future.wait(requests);
    } catch (e) {
      // Do not block appointment/patient saves when the cloud relay DNS is missing.
      logger("PushRelay.sendPush skipped: $e", null, 3);
    }
  }
}
