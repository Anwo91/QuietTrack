/// Hive persistence. Settings + daily tracking data.
///
/// Boxes:
///  - quiettrack_settings: key 'config' -> Map
///  - quiettrack_tracking: key 'yyyy-MM-dd' -> Map
///
/// Data lives in %LOCALAPPDATA%\QuietTrack.
/// On first run, migrates from the old %USERPROFILE%\Documents\QuietTrack location.
library;

import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../models/settings_model.dart';

class StorageService {
  late Box _settingsBox;
  late Box _trackingBox;

  Future<void> init() async {
    final dataDir = await _resolveDataDir();
    Hive.init(dataDir.path);
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    _trackingBox = await Hive.openBox(AppConstants.trackingBox);
  }

  /// Returns the data directory, migrating from Documents if needed.
  Future<Directory> _resolveDataDir() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final newDir = Directory('$localAppData\\QuietTrack');

    // Old location: Documents\QuietTrack
    final userProfile = Platform.environment['USERPROFILE'];
    final oldDir = Directory('$userProfile\\Documents\\QuietTrack');

    if (!await newDir.exists()) {
      if (await oldDir.exists()) {
        // Move old data to new location
        await oldDir.rename(newDir.path);
      } else {
        await newDir.create(recursive: true);
      }
    }

    return newDir;
  }

  AppSettings loadSettings() {
    final raw = _settingsBox.get('config');
    if (raw == null) return AppSettings.defaults();
    return AppSettings.fromMap(Map<dynamic, dynamic>.from(raw as Map));
  }

  /// Persist settings.
  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put('config', settings.toMap());
  }

  Map<String, dynamic> loadDayData(String dateKey) {
    final raw = _trackingBox.get(dateKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> saveDayData(String dateKey, Map<String, dynamic> data) async {
    await _trackingBox.put(dateKey, data);
  }

  /// All stored date keys (for Reports view).
  List<String> getAllDateKeys() {
    return _trackingBox.keys.map((k) => k.toString()).toList()..sort();
  }

  /// Nuke all tracking data.
  Future<void> clearAll() async {
    await _trackingBox.clear();
  }

  // Last update check timestamp

  DateTime? loadLastUpdateCheck() {
    final raw = _settingsBox.get('lastUpdateCheck');
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  Future<void> saveLastUpdateCheck(DateTime dt) async {
    await _settingsBox.put('lastUpdateCheck', dt.toIso8601String());
  }

  // Last-seen app version (for What's New dialog)

  String? loadLastSeenVersion() {
    return _settingsBox.get('lastSeenVersion') as String?;
  }

  Future<void> saveLastSeenVersion(String version) async {
    await _settingsBox.put('lastSeenVersion', version);
  }
}
