/// Settings provider. Loads from Hive, persists on every change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings_model.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(AppSettings.defaults()) {
    _load();
  }

  void _load() {
    state = _storage.loadSettings();
  }

  Future<void> _persist() async {
    await _storage.saveSettings(state);
  }

  Future<void> resetToDefaults() async {
    state = AppSettings.defaults();
    await _persist();
  }

  // Theme
  Future<void> setThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  // Feature toggles
  Future<void> toggleTrackWindowTitles(bool v) async {
    state = state.copyWith(trackWindowTitles: v);
    await _persist();
  }

  Future<void> toggleDetectMedia(bool v) async {
    state = state.copyWith(detectMedia: v);
    await _persist();
  }

  Future<void> toggleDetailedSessions(bool v) async {
    state = state.copyWith(recordDetailedSessions: v);
    await _persist();
  }

  Future<void> toggleAppCategories(bool v) async {
    state = state.copyWith(enableAppCategories: v);
    await _persist();
  }

  Future<void> toggleTimelineView(bool v) async {
    state = state.copyWith(showTimelineView: v);
    await _persist();
  }

  Future<void> togglePerMonitor(bool v) async {
    state = state.copyWith(trackPerMonitor: v);
    await _persist();
  }

  // Media keywords
  Future<void> setMediaKeywords(List<String> kw) async {
    state = state.copyWith(mediaKeywords: kw);
    await _persist();
  }

  // Category rules
  Future<void> setCategoryRules(List<Map<String, String>> rules) async {
    state = state.copyWith(categoryRules: rules);
    await _persist();
  }

  // Idle threshold
  Future<void> setIdleThreshold(int ms) async {
    state = state.copyWith(idleThresholdMs: ms);
    await _persist();
  }

  // Ignored apps
  Future<void> setIgnoredApps(List<String> apps) async {
    state = state.copyWith(ignoredApps: apps);
    await _persist();
  }

  Future<void> addIgnoredApp(String exePath) async {
    if (state.ignoredApps.contains(exePath)) return;
    final updated = List<String>.from(state.ignoredApps)..add(exePath);
    state = state.copyWith(ignoredApps: updated);
    await _persist();
  }

  Future<void> removeIgnoredApp(String exePath) async {
    final updated = List<String>.from(state.ignoredApps)..remove(exePath);
    state = state.copyWith(ignoredApps: updated);
    await _persist();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});
