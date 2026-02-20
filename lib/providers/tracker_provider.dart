/// Riverpod StateNotifier for tracker state. Owns the TrackerService,
/// listens to its stream, auto-saves to Hive every 15s.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tracker_state.dart';
import '../services/tracker_service.dart';
import '../services/storage_service.dart';
import '../utils/time_utils.dart';
import 'settings_provider.dart';

class TrackerNotifier extends StateNotifier<TrackerState> {
  final TrackerService _tracker = TrackerService();
  final StorageService _storage;
  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _saveTimer;

  TrackerNotifier(this._storage, this._ref)
      : super(TrackerState.initial()) {
    _init();
  }

  Future<void> _init() async {
    // Restore today's data from Hive
    final dateKey = TimeUtils.dateKey(DateTime.now());
    final saved = _storage.loadDayData(dateKey);
    final settings = _ref.read(settingsProvider);

    // Populate tracker service with any previously saved state
    _tracker.start(
      settings: settings,
      initialActive: (saved['totalActiveSeconds'] as int?) ?? 0,
      initialMedia: (saved['mediaSeconds'] as int?) ??
          (saved['videoSeconds'] as int?) ?? 0,
      initialAppUsage: saved['appUsage'] != null
          ? Map<String, int>.from(saved['appUsage'] as Map)
          : null,
      initialAppNames: saved['appNames'] != null
          ? Map<String, String>.from(saved['appNames'] as Map)
          : null,
      initialHourly: saved['hourlyActive'] != null
          ? (saved['hourlyActive'] as Map)
              .map((k, v) => MapEntry(int.parse(k.toString()), (v as int?) ?? 0))
          : null,
      initialMonitor: saved['monitorUsage'] != null
          ? (saved['monitorUsage'] as Map)
              .map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0))
          : null,
      initialCategories: saved['appCategories'] != null
          ? Map<String, String>.from(saved['appCategories'] as Map)
          : null,
      initialSessions: saved['sessions'] != null
          ? (saved['sessions'] as List)
              .map((e) => SessionEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList()
          : null,
      initialWindowTitleUsage: _restoreNestedMap(saved['windowTitleUsage']),
      initialMonitorAppUsage: _restoreNestedMap(saved['monitorAppUsage']),
      initialMediaAppUsage: saved['mediaAppUsage'] != null
          ? Map<String, int>.from(
              (saved['mediaAppUsage'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as int?) ?? 0),
              ),
            )
          : null,
    );

    // Listen to tracker stream
    _sub = _tracker.stateStream.listen((s) {
      state = s;
    });

    // Forward settings changes to service
    _ref.listen<dynamic>(settingsProvider, (_, next) {
      _tracker.updateSettings(next);
    });

    // Auto-save every 15s
    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) => _save());
  }

  Future<void> _save() async {
    final key = _tracker.dateKey;
    await _storage.saveDayData(key, _tracker.exportState());
  }

  /// Force-save (app close / minimize).
  Future<void> forceSave() async => _save();

  /// Manually set/override a single app's category.
  void setAppCategory(String exePath, String category) {
    _tracker.setAppCategory(exePath, category);
  }

  /// Delete all tracking history and reset today's state.
  Future<void> deleteAllHistory() async {
    await _storage.clearAll();
    _tracker.stop();
    final settings = _ref.read(settingsProvider);
    _tracker.start(settings: settings);
    // Re-subscribe
    _sub?.cancel();
    _sub = _tracker.stateStream.listen((s) {
      state = s;
    });
  }

  /// Deserialize nested `Map<String, Map<String, int>>` from Hive.
  static Map<String, Map<String, int>>? _restoreNestedMap(dynamic raw) {
    if (raw == null) return null;
    return (raw as Map).map((k, v) => MapEntry(
          k.toString(),
          Map<String, int>.from((v as Map).map(
            (mk, mv) => MapEntry(mk.toString(), (mv as int?) ?? 0),
          )),
        ));
  }

  @override
  void dispose() {
    _save();
    _saveTimer?.cancel();
    _sub?.cancel();
    _tracker.dispose();
    super.dispose();
  }
}

/// Main tracker state provider.
final trackerProvider =
    StateNotifierProvider<TrackerNotifier, TrackerState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TrackerNotifier(storage, ref);
});
