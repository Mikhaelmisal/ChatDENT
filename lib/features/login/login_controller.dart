import 'dart:io' show Platform;

import 'package:chatdent/app/routes.dart';
import 'package:chatdent/core/observable.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/clinic_service_url.dart';
import 'package:chatdent/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class _LoginScreenState {
  final loginError = ObservableState("");
  final loadingIndicator = ObservableState("");
  final selectedTab = ObservableState(0);
  final resetInstructionsSent = ObservableState(false);
  final obscureText = ObservableState(true);
  final proceededOffline = ObservableState(true);
  final loadingPatientSide = ObservableState(false);

  void finishedLoginProcess([String error = ""]) {
    loadingIndicator("");
    loginError(error);
  }

  void resetButton(String server, String email) async {
    final pb = PocketBase(server);
    loginError("");
    loadingIndicator("Sending password reset email");
    try {
      await pb.collection("_superusers").requestPasswordReset(email);
      await pb.collection("users").requestPasswordReset(email);
    } catch (e, s) {
      logger("Error during resetting password: $e", s);
      loginError("Error while resetting password: $e.");
      loadingIndicator("");
      return;
    }
    loadingIndicator("");
    resetInstructionsSent(true);
  }

  void loginButton(String server, String email, String password,
      [bool online = true]) {
    server = server.replaceFirst(RegExp(r'/+$'), "");
    email = email.trim().toLowerCase();
    if (_isHandheld && isLoopbackServerUrl(server)) {
      finishedLoginProcess(txt("phoneNeedsLanServer"));
      return;
    }
    login.activate(server, [email, password], online);
    routes.reset();
  }

  bool get _isHandheld {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  _LoginScreenState() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (launch.isDemo) {
        loginButton("", "", "");
      }
    });
  }
}

final loginCtrl = _LoginScreenState();
