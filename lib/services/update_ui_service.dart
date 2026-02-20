import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'update_service.dart';

class UpdateUiService {
  UpdateUiService._();

  static String availableVersionMessage(
    String version, {
    bool compact = false,
  }) {
    return compact ? 'v$version available!' : 'Version $version available';
  }

  static String checkResultMessage(
    UpdateInfo? info, {
    bool compact = false,
  }) {
    if (info != null) return availableVersionMessage(info.version, compact: compact);
    return compact ? 'Up to date' : latestVersionMessage();
  }

  static String sidebarResultMessage(UpdateInfo? info) {
    return checkResultMessage(info, compact: true);
  }

  static bool isAvailableMessage(String message) {
    return message.toLowerCase().contains('available');
  }

  static String formatLastChecked(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return 'Checked $d $t';
  }

  static String latestVersionMessage() {
    return "You're on the latest version (${AppConstants.appVersion}).";
  }

  static String idleHint(UpdateStatus status) {
    if (status == UpdateStatus.idle) return 'No updates checked yet.';
    if (status == UpdateStatus.checking) return 'Checking...';
    return '';
  }

  static Color statusColor({
    required ThemeData theme,
    required String message,
  }) {
    return isAvailableMessage(message)
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
  }
}
