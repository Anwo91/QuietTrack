// SMTC polling service for currently playing media sessions.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One SMTC media session snapshot.
class MediaInfo {
  final String? sourceAppId;
  final String? title;
  final String? artist;
  final String? album;
  final bool isPlaying;

  const MediaInfo({
    this.sourceAppId,
    this.title,
    this.artist,
    this.album,
    this.isPlaying = false,
  });

  /// Friendly app name derived from [sourceAppId].
  String get appName {
    if (sourceAppId == null || sourceAppId!.isEmpty) return 'Unknown';
    final id = sourceAppId!;
    if (id.contains('!')) {
      final after = id.split('!').last;
      return _friendlyName(after.split('.').last);
    }
    if (id.endsWith('.exe')) {
      return id.replaceAll('.exe', '');
    }
    if (id.contains('_')) {
      final parts = id.split('_').first.split('.');
      return _friendlyName(parts.last);
    }
    return _friendlyName(id);
  }

  static String _friendlyName(String raw) {
    const map = {
      'ZuneMusic': 'Groove Music',
      'ZuneVideo': 'Movies & TV',
      'SpotifyMusic': 'Spotify',
      'AppleMusic': 'Apple Music',
      'AppleInc': 'Apple Music',
    };
    return map[raw] ?? raw;
  }

  @override
  String toString() =>
      'MediaInfo(app=$sourceAppId, title=$title, artist=$artist, playing=$isPlaying)';
}

/// Polls SMTC via PowerShell and caches results.
class MediaService {
  MediaService._();

  static MediaInfo? _cached;
  static Timer? _pollTimer;
  static bool _querying = false;
  static bool _hasSessions = false;

  static const int pollInterval = 2;

  /// Output format: `STATUS|APP_ID|TITLE|ARTIST|ALBUM`, else `None`/`Paused`.
  static const String _psScript = r'''
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(3000) | Out-Null
  $netTask.Result
}
try {
  [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime] | Out-Null
  $mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
  $sessions = $mgr.GetSessions()
  if ($sessions.Count -eq 0) { Write-Output "None"; exit }
  $anyPlaying = $false
  foreach ($s in $sessions) {
    $pb = $s.GetPlaybackInfo()
    $status = $pb.PlaybackStatus.ToString()
    if ($status -ne "Playing") { continue }
    $anyPlaying = $true
    $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    $app = $s.SourceAppUserModelId
    $title = $props.Title -replace '\|','-'
    $artist = $props.Artist -replace '\|','-'
    $album = $props.AlbumTitle -replace '\|','-'
    Write-Output "$status|$app|$title|$artist|$album"
  }
  if (-not $anyPlaying -and $sessions.Count -gt 0) { Write-Output "Paused" }
} catch {
  Write-Output "None"
}
''';

  /// Current primary media info (null when nothing is playing).
  static MediaInfo? get current => _cached;

  /// True when SMTC reports any session (playing or paused).
  static bool get hasSessions => _hasSessions;

  static List<MediaInfo> _allSessions = [];
  static List<MediaInfo> get allSessions => _allSessions;

  /// Start polling.
  static void start() {
    _pollTimer?.cancel();
    // Query immediately, then every N seconds.
    _query();
    _pollTimer = Timer.periodic(
      Duration(seconds: pollInterval),
      (_) => _query(),
    );
  }

  /// Stop polling.
  static void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> _query() async {
    if (_querying) return;
    _querying = true;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _psScript],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final lines = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isEmpty || (lines.length == 1 && lines.first == 'None')) {
        _cached = null;
        _allSessions = [];
        _hasSessions = false;
        return;
      }

      if (lines.length == 1 && lines.first == 'Paused') {
        _cached = null;
        _allSessions = [];
        _hasSessions = true;
        return;
      }

      final sessions = <MediaInfo>[];
      for (final line in lines) {
        if (line == 'None' || line == 'Paused') continue;
        final parts = line.split('|');
        if (parts.length < 5) continue;
        sessions.add(MediaInfo(
          sourceAppId: parts[1].isNotEmpty ? parts[1] : null,
          title: parts[2].isNotEmpty ? parts[2] : null,
          artist: parts[3].isNotEmpty ? parts[3] : null,
          album: parts[4].isNotEmpty ? parts[4] : null,
          isPlaying: parts[0] == 'Playing',
        ));
      }

      _allSessions = sessions;
      _cached = sessions.isNotEmpty ? sessions.first : null;
      _hasSessions = sessions.isNotEmpty;
    } catch (_) {
      _cached = null;
      _allSessions = [];
      _hasSessions = false;
    } finally {
      _querying = false;
    }
  }
}
