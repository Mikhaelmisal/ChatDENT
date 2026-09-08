import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:chatdent/core/observable.dart';
import 'package:chatdent/utils/logger.dart';

class ReleaseMetadata {
  final String latestVersion;
  final List<String> changelog;
  final String windowsUrl;
  final String msStoreUrl;
  final String macosUrl;
  final String iosUrl;
  final String androidUrl;
  final String webUrl;

  ReleaseMetadata({
    required this.latestVersion,
    required this.changelog,
    required this.windowsUrl,
    required this.msStoreUrl,
    required this.macosUrl,
    required this.iosUrl,
    required this.androidUrl,
    required this.webUrl,
  });

  factory ReleaseMetadata.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'] is Map
        ? Map<String, dynamic>.from(json['downloads'] as Map)
        : <String, dynamic>{};
    return ReleaseMetadata(
      latestVersion: json['latest_version'] ?? "0.0.0",
      changelog: List<String>.from(json['changelog'] ?? []),
      windowsUrl: downloads['windows']?.toString() ?? "",
      msStoreUrl: downloads['ms_store']?.toString() ?? "",
      macosUrl: downloads['macos']?.toString() ?? "",
      iosUrl: downloads['ios']?.toString() ?? "",
      androidUrl: downloads['android']?.toString() ?? "",
      webUrl: downloads['web']?.toString() ?? "",
    );
  }
}

/// True when [latest] is a higher major.minor.patch than [current].
bool isVersionNewer(String latest, String current) {
  final latestParts =
      latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final currentParts =
      current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  while (latestParts.length < 3) {
    latestParts.add(0);
  }
  while (currentParts.length < 3) {
    currentParts.add(0);
  }

  for (var i = 0; i < 3; i++) {
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }
  return false;
}

class _VersionService {
  final current = ObservableState("0.0.0");
  final isOutdated = ObservableState(false);
  final latestVersion = ObservableState("0.0.0");

  String _windowsUrl = "";
  String _androidUrl = "";
  String _macosUrl = "";
  List<String> changelog = [];

  /// Sideloaded Windows/Android (and macOS) need an in-app prompt.
  bool get needsUpdateNotification {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isAndroid || Platform.isMacOS;
  }

  String get downloadLink {
    if (kIsWeb) return "";
    if (Platform.isAndroid) return _androidUrl;
    if (Platform.isWindows) {
      return _windowsUrl.isNotEmpty ? _windowsUrl : "";
    }
    if (Platform.isMacOS) return _macosUrl;
    return "";
  }

  /// Bump [latest.json] on `main` when you ship. Installed apps fetch this.
  final String metadataUrl =
      "https://raw.githubusercontent.com/Mikhaelmisal/ChatDENT/main/latest.json";

  _VersionService() {
    init();
  }

  Future<void> init() async {
    await _setCurrentVersion();
    await checkForUpdates();
  }

  Future<void> _setCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      current(info.version);
    } catch (e) {
      current("0.0.0");
    }
  }

  Future<void> checkForUpdates() async {
    if (metadataUrl.trim().isEmpty) return;
    try {
      final response = await http.get(Uri.parse(metadataUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch metadata: ${response.statusCode}');
      }

      final data = ReleaseMetadata.fromJson(json.decode(response.body));

      latestVersion(data.latestVersion);
      _windowsUrl = data.windowsUrl.isNotEmpty
          ? data.windowsUrl
          : data.msStoreUrl;
      _androidUrl = data.androidUrl;
      _macosUrl = data.macosUrl;
      changelog = data.changelog;

      isOutdated(isVersionNewer(data.latestVersion, current()));
    } catch (e, s) {
      logger("Version update check failed: $e", s);
    }
  }
}

final version = _VersionService();
