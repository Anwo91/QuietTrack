/// Media/entertainment seconds card with optional now-playing info.
library;

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../utils/time_utils.dart';
import 'animated_counter.dart';

class MediaCard extends StatelessWidget {
  final int mediaSeconds;
  final String? currentMediaApp;
  final String? currentMediaTitle;
  final Map<String, int> mediaAppUsage;

  const MediaCard({
    super.key,
    required this.mediaSeconds,
    this.currentMediaApp,
    this.currentMediaTitle,
    this.mediaAppUsage = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMedia = mediaSeconds > 0;
    final isPlaying = currentMediaApp != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isPlaying
                    ? Icons.play_circle_filled
                    : hasMedia
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_outline,
                key: ValueKey('$isPlaying-$hasMedia'),
                color: isPlaying
                    ? theme.colorScheme.tertiary
                    : hasMedia
                        ? theme.colorScheme.tertiary.withValues(alpha: 0.6)
                        : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media / Entertainment',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mediaSubDescription(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AnimatedTimeCounter(totalSeconds: mediaSeconds),
                ],
              ),
            ),
          ],
        ),
        // Now-playing line
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: isPlaying
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _nowPlayingLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Per-source breakdown
        if (mediaAppUsage.isNotEmpty) ..._buildSourceBreakdown(theme),
      ],
    );
  }

  List<Widget> _buildSourceBreakdown(ThemeData theme) {
    final sorted = mediaAppUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final palette = AppTheme.chartPalette;
    return [
      const SizedBox(height: 10),
      const Divider(height: 1),
      const SizedBox(height: 8),
      ...sorted.take(5).toList().asMap().entries.map((e) {
        final idx = e.key;
        final src = e.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette[idx % palette.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  src.key,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                TimeUtils.formatShort(src.value),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }

  String _nowPlayingLabel() {
    final app = currentMediaApp ?? '';
    final title = currentMediaTitle ?? '';
    if (title.isNotEmpty && app.isNotEmpty) return '$app - $title';
    if (title.isNotEmpty) return title;
    if (app.isNotEmpty) return app;
    return 'Playing';
  }

  String _mediaSubDescription() {
    final app = (currentMediaApp ?? '').trim();
    final title = (currentMediaTitle ?? '').trim();
    if (app.isEmpty && title.isEmpty) {
      return mediaAppUsage.isEmpty ? 'No active media source' : 'Top sources tracked';
    }
    if (app.isEmpty) return title;
    if (title.isEmpty) return app;

    final source = _compactSourceFromTitle(title);
    if (source.isEmpty) return app;
    return '$app -> $source';
  }

  String _compactSourceFromTitle(String title) {
    final separators = [' - ', ' - ', '|', ':'];
    for (final separator in separators) {
      if (title.contains(separator)) {
        final part = title.split(separator).first.trim();
        if (part.isNotEmpty) return part;
      }
    }
    return title;
  }
}
