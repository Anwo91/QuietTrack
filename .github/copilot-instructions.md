# Copilot Instructions - QuietTrack

## What This Is

QuietTrack is a Windows-only Flutter desktop app that tracks user activity (foreground app, idle time, voice/meetings, monitors) via Win32 API polling. All data stays local (Hive storage). Stack: Flutter 3.38, Riverpod (StateNotifier), Hive, fl_chart, dart:ffi, window_manager, tray_manager.

## Brand & Icon

The app's personality is **presence without pressure** - it sits in the system tray, says nothing, and just remembers. The icon reflects this: a single soft ripple on still water, dark teal, barely there. You'd almost miss it in the taskbar, which is the point. Icon files live in `assets/icons/` (PNG for Flutter, ICO for the Windows runner and installer).

## Architecture & Data Flow

```
Win32 APIs (dart:ffi, 1-sec poll)
  → TrackerService (mutable accumulators, emits immutable snapshots)
    → TrackerNotifier (StateNotifier, sets state from stream)
      → Riverpod (trackerProvider)
        → UI (ConsumerWidget / ConsumerStatefulWidget)
```

- **`TrackerService`** owns the `Timer.periodic` loop and mutable state. It emits `TrackerState` via `StreamController.broadcast`. It is NOT a Riverpod provider - it's instantiated inside `TrackerNotifier`.
- **`TrackerNotifier`** bridges the service to Riverpod: listens to the stream, auto-saves to Hive every 15s, and forwards settings changes to the service via `ref.listen()`.
- **Settings propagation:** `SettingsNotifier` → Riverpod → `TrackerNotifier._ref.listen()` → `TrackerService.updateSettings()` → applied on next tick.

## Key Conventions

- **No code generation.** Hand-written `copyWith()`, `toMap()`, `fromMap()` on all models. No Freezed, no json_serializable, no Hive type adapters. Keep it that way.
- **No Navigator/Router.** Navigation is index-based via `HomeScreen`'s `AnimatedSwitcher` + custom `Sidebar`. Don't add named routes.
- **StateNotifier pattern (Riverpod v2).** All providers use `StateNotifierProvider`, not the newer Notifier/AsyncNotifier API. No `FutureProvider` or `AsyncValue` - state is synchronous once initialized.
- **Feature gating via settings.** Every advanced feature (window titles, voice detection, sessions, categories, per-monitor) is gated by a boolean in `AppSettings`. In `TrackerService._tick()`, check the flag before calling the corresponding Win32 method. In the UI, conditionally render widgets based on the same flag from `settingsProvider`.
- **All advanced features default to OFF.** `AppSettings.defaults()` sets all toggles to `false`. The app starts minimal.
- **Immutability at boundaries.** `TrackerService` uses mutable maps/ints internally for performance, but wraps them in `Map.unmodifiable()` / `List.unmodifiable()` when emitting `TrackerState`.

## Win32 FFI Pattern (`lib/services/win32_service.dart`)

All Win32 calls live in `Win32Service` - a static-only class. Follow this pattern for new bindings:

1. Open the DLL (`DynamicLibrary.open()`) at top level (already done for `kernel32` and `user32`)
2. Define a `_NativeFuncName` typedef (C signature) and `_DartFuncName` typedef (Dart signature)
3. Bind at top level: `final _funcName = _user32.lookupFunction<_NativeFuncName, _DartFuncName>('Win32FuncName');`
4. Expose as a `static` method on `Win32Service` that allocates via `calloc<>()` in a try/finally to guarantee `free()`
5. Return `null`/`false`/`0` on failure - never throw from FFI methods

## File Organization

| Directory | Contains | Example |
|---|---|---|
| `lib/core/` | Constants (`AppConstants._()` static namespace), theme (`AppTheme._()` static), route transitions | `constants.dart` |
| `lib/models/` | Immutable data classes with `copyWith()`, `toMap()`, `fromMap()` | `tracker_state.dart` |
| `lib/services/` | Business logic, FFI bindings, storage - not Riverpod providers | `tracker_service.dart` |
| `lib/providers/` | Riverpod `StateNotifierProvider` + `StateNotifier` classes | `tracker_provider.dart` |
| `lib/screens/` | Top-level pages (one per sidebar tab) | `dashboard_screen.dart` |
| `lib/widgets/` | Reusable UI components (charts, cards, sidebar) | `pie_chart_widget.dart` |

## Build & Run

```powershell
flutter pub get
flutter run -d windows          # debug
flutter build windows            # release → build\windows\x64\runner\Release\
```

Installer: compile `installer/quiettrack_setup.iss` with Inno Setup 6+.

**Requirements:** Flutter 3.38+, Windows 10/11 x64, Visual Studio 2022 with C++ desktop workload.

## Error Handling

Win32 FFI methods return safe defaults on failure (not idle → `false`, no exe → `null`). Hive deserialization uses `?? defaultValue` for every field. Tray/hotkey init is wrapped in try/catch (non-critical). No global error boundary.

## Naming

- Files: `snake_case.dart` - services: `xxx_service.dart`, providers: `xxx_provider.dart`
- Static-only classes: private constructor (`ClassName._()`)
- FFI typedefs: `_FunctionNameNative` / `_FunctionNameDart` pair
- Provider variables: `camelCaseProvider` (e.g. `trackerProvider`, `settingsProvider`)

## Code Style (Human-First)

- Keep comments short and practical. Explain *why* only when logic is non-obvious.
- Avoid numbered “tutorial-style” comments in production code.
- Prefer specific helper names (`_querySmtcSessions`) over generic names (`_query`).
- Remove template-style headers or decorative comments that add no value.
- Keep UI text concise and consistent in tone.

## Refactor Direction

- Prefer incremental refactors over broad rewrites.
- Split large files when changing them:
  - `lib/services/tracker_service.dart` → private pipeline methods by concern
  - `lib/screens/settings_screen.dart` → section widgets
  - `lib/screens/reports_screen.dart` → extract tab content widgets
  - `lib/services/win32_service.dart` → split binding groups while keeping a stable facade
- Merge duplicated update-check display logic shared between sidebar and settings.

## Assessment Snapshot

- Latest codebase review: `docs/codebase_assessment_2026-02-19.md`
- Immediate priority when touching large files:
  1. Keep behavior unchanged unless requested.
  2. Extract small private widgets/methods first.
  3. Avoid mixing refactors with feature work in the same commit.
