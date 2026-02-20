/// GitHub release checker + auto-updater.
///
/// Checks `https://api.github.com/repos/<owner>/<repo>/releases/latest`
/// for a newer version, downloads the asset, and replaces the running exe.
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';

enum UpdateStatus { idle, checking, available, downloading, ready, error }

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final int sizeBytes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes = '',
    this.sizeBytes = 0,
  });
}

class UpdateService {
  UpdateService._();

  static const _owner = 'Anwo91';
  static const _repo = 'QuietTrack';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Check GitHub for a newer release.
  /// Returns null if already up to date or on error.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      final remoteVersion = tagName.replaceAll(RegExp(r'^v'), '');

      if (!_isNewer(remoteVersion, AppConstants.appVersion)) return null;

      // Find the Windows exe/zip asset
      final assets = (data['assets'] as List?) ?? [];
      String? downloadUrl;
      int sizeBytes = 0;
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.toLowerCase().contains('windows') ||
            name.toLowerCase().contains('quiettrack') ||
            name.toLowerCase().endsWith('.zip') ||
            name.toLowerCase().endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          sizeBytes = (asset['size'] as int?) ?? 0;
          break;
        }
      }

      if (downloadUrl == null) return null;

      final body = (data['body'] as String?) ?? '';

      return UpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        releaseNotes: body,
        sizeBytes: sizeBytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Download the update asset and prepare for installation.
  /// Returns the path to the downloaded file, or null on failure.
  static Future<String?> downloadUpdate(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = info.downloadUrl.split('/').last;
      final savePath = '${tempDir.path}\\quiettrack_update_$fileName';

      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      final streamedResponse = await request.send().timeout(
            const Duration(minutes: 5),
          );

      if (streamedResponse.statusCode != 200) return null;

      final totalBytes = streamedResponse.contentLength ?? info.sizeBytes;
      int receivedBytes = 0;
      final sink = File(savePath).openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      return savePath;
    } catch (_) {
      return null;
    }
  }

  /// Apply the update: copy the downloaded file over the current exe
  /// using a batch script that waits for this process to exit, then
  /// replaces the exe and relaunches.
  static Future<bool> applyUpdate(String downloadedPath) async {
    try {
      final currentExe = Platform.resolvedExecutable;
      final currentDir = File(currentExe).parent.path;
      final tempDir = await getTemporaryDirectory();
      final batchPath = '${tempDir.path}\\quiettrack_update.bat';

      // If it's a zip, extract first; if it's an exe, just copy
      final isZip = downloadedPath.toLowerCase().endsWith('.zip');

      String batchContent;
      if (isZip) {
        // Use PowerShell to extract the zip, then copy contents over
        batchContent = '''
@echo off
echo Updating QuietTrack...
timeout /t 2 /nobreak > nul
powershell -Command "Expand-Archive -Path '$downloadedPath' -DestinationPath '${tempDir.path}\\quiettrack_extracted' -Force"
xcopy /s /y "${tempDir.path}\\quiettrack_extracted\\*" "$currentDir\\"
rmdir /s /q "${tempDir.path}\\quiettrack_extracted"
del "$downloadedPath"
start "" "$currentExe"
del "%~f0"
''';
      } else {
        // Direct exe replacement
        batchContent = '''
@echo off
echo Updating QuietTrack...
timeout /t 2 /nobreak > nul
copy /y "$downloadedPath" "$currentExe"
del "$downloadedPath"
start "" "$currentExe"
del "%~f0"
''';
      }

      await File(batchPath).writeAsString(batchContent);

      // Launch the batch script detached and exit this process
      await Process.start(
        'cmd.exe',
        ['/c', batchPath],
        mode: ProcessStartMode.detached,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Compare semantic versions. Returns true if remote > current.
  static bool _isNewer(String remote, String current) {
    final rParts = remote.split('.').map(int.tryParse).toList();
    final cParts = current.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final r = i < rParts.length ? (rParts[i] ?? 0) : 0;
      final c = i < cParts.length ? (cParts[i] ?? 0) : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false; // equal
  }
}
