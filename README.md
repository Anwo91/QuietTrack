# QuietTrack

A quiet little Windows app that tracks where your time goes. Which apps you use, when you're actually at the keyboard, what's playing in the background. No cloud, no accounts, no telemetry - everything stays on your machine.

![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Platform-Windows_10%2F11-0078D6?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

## What it does

Once a second, QuietTrack quietly checks a few things:

- **Active time** - looks at the last time you moved the mouse or pressed a key. If nothing happens for longer than the idle threshold (default 30s, adjustable), it stops counting active time until you come back.
- **App tracking** - reads which window is focused and adds one second to that app's total, with optional window title logging. Apps can be individually ignored.
- **Media detection** (optional) - asks Windows what media is currently active - Spotify, YouTube in a browser, VLC, etc. Each source is tracked separately, so overlapping streams are all logged.
- **App categories** (optional) - matches the app name and window title against keyword rules to sort it into a category like Browser, Development, or Communication. You can also override any app's category manually from the Apps tab.
- **Sessions** (optional) - every time you switch apps, it records the transition with a timestamp, which feeds the Timeline view in Reports.
- **Per-monitor tracking** (optional) - checks which display the active window is on, so you can see how your time splits across screens.

Everything is saved locally every 15 seconds. Nothing is sent anywhere.

## Screens

| Screen | What's there |
|---|---|
| **Dashboard** | Pie chart, hourly bar chart, active time counter, media card, monitor breakdown |
| **Apps** | Searchable/sortable app list with window title drilldown, category chips (clickable to reassign), right-click to ignore or open in Explorer |
| **Reports** | Tabbed: **Timeline** (zoomable session bars per day), **Graph** (stacked bar chart of daily app usage with range picker), **Categories** (pie chart + expandable list by category), **Monitors** (per-display time with app breakdown) |
| **Settings** | Theme, idle threshold, feature toggles, media keyword editor, category rule editor, ignored apps, data management, update checker |

Everything beyond basic app + idle tracking is optional - flip toggles on in Settings.

## Install

Download the installer from [Releases](https://github.com/Anwo91/QuietTrack/releases) and run it.
Note - The installer is not signed, so you will get a warning when running. Just run anyway

## Settings

All advanced features default to **off**. The app starts minimal.

| Toggle | What it does |
|---|---|
| Track window titles | Record the title bar of the active window |
| Detect media | Use SMTC to detect playing media (keywords are editable) |
| Record detailed sessions | Log app transitions with timestamps - enables Timeline in Reports |
| Enable app categories | Auto-categorize apps using keyword rules - enables Categories tab in Reports; per-app overrides available in Apps |
| Track per-monitor | Track which display the foreground window is on - enables Monitors tab |

You can also: ignore specific apps (right-click in Apps), adjust idle threshold (5-120s. 30s default), manage category rules, and reset settings or delete all history.

## Data & privacy

All data lives locally in Hive boxes under `%LOCALAPPDATA%\QuietTrack\`.

The only network call is the optional update check, which hits the GitHub Releases API. Nothing else leaves your machine. Ever.

## License

MIT
