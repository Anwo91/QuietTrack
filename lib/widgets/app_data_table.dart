/// Searchable, sortable app list with collapsible window titles,
/// hover tooltips, and right-click context menu.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class AppDataTable extends StatefulWidget {
  final Map<String, int> appUsage;
  final Map<String, String> appNames;
  final Map<String, String> appCategories;
  final int totalActiveSeconds;
  final Map<String, Map<String, int>> windowTitleUsage;
  final ValueChanged<String>? onIgnoreApp;
  final void Function(String exePath, String category)? onCategoryChanged;
  final List<String> knownCategories;

  const AppDataTable({
    super.key,
    required this.appUsage,
    required this.appNames,
    required this.appCategories,
    required this.totalActiveSeconds,
    this.windowTitleUsage = const {},
    this.onIgnoreApp,
    this.onCategoryChanged,
    this.knownCategories = const [],
  });

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  String _search = '';
  int _sortColumn = 1;
  bool _sortAsc = false;
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var entries = widget.appUsage.entries.toList();

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      entries = entries.where((e) {
        final name = (widget.appNames[e.key] ?? e.key).toLowerCase();
        return name.contains(q) || e.key.toLowerCase().contains(q);
      }).toList();
    }

    entries.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = (widget.appNames[a.key] ?? a.key)
              .compareTo(widget.appNames[b.key] ?? b.key);
          break;
        case 1:
        case 2:
          cmp = a.value.compareTo(b.value);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    // Build flat list: app rows + expanded title rows
    final items = <_ListItem>[];
    for (final e in entries) {
      items.add(_ListItem(entry: e, isTitle: false));
      if (_expanded.contains(e.key)) {
        final titles = widget.windowTitleUsage[e.key];
        if (titles != null && titles.isNotEmpty) {
          final sorted = titles.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          for (final t in sorted) {
            items.add(_ListItem(
              entry: e,
              isTitle: true,
              titleText: t.key,
              titleSeconds: t.value,
            ));
          }
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search apps\u2026',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        _header(theme),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _search.isEmpty ? 'No app data yet' : 'No matches',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isTitle) {
                      return _titleRow(item, theme);
                    }
                    return _appRow(item.entry!, index, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _sortBy(0),
              child: Row(
                children: [
                  Text('APP', style: style),
                  if (_sortColumn == 0)
                    Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _sortBy(1),
              child: Row(
                children: [
                  Text('TIME', style: style),
                  if (_sortColumn == 1)
                    Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => _sortBy(2),
              child: Row(
                children: [
                  Text('%', style: style),
                  if (_sortColumn == 2)
                    Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 80, child: Text('')),
        ],
      ),
    );
  }

  Widget _appRow(MapEntry<String, int> entry, int index, ThemeData theme) {
    final name = widget.appNames[entry.key] ?? entry.key;
    final secs = entry.value;
    final pct = TimeUtils.percent(secs, widget.totalActiveSeconds);
    final cat = widget.appCategories[entry.key] ?? '';
    final hasTitles = (widget.windowTitleUsage[entry.key]?.isNotEmpty ?? false);
    final isExpanded = _expanded.contains(entry.key);
    final exePath = entry.key;

    // Directory from exe path
    final dir = exePath.contains('\\') || exePath.contains('/')
        ? exePath.substring(0, exePath.lastIndexOf(RegExp(r'[/\\]')))
        : exePath;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 20)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 6),
            child: child,
          ),
        );
      },
      child: Tooltip(
        message: '$name\n$exePath\n$dir',
        waitDuration: const Duration(milliseconds: 400),
        preferBelow: false,
        textStyle: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            _showContextMenu(context, details.globalPosition, exePath, name,
                theme);
          },
          child: InkWell(
            onTap: hasTitles
                ? () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(entry.key);
                      } else {
                        _expanded.add(entry.key);
                      }
                    })
                : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        if (hasTitles)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      TimeUtils.formatHMS(secs),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      pct,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: cat.isNotEmpty
                        ? InkWell(
                            onTap: widget.onCategoryChanged != null
                                ? () => _showCategoryPicker(context, exePath, cat)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Chip(
                              label: Text(cat, style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          )
                        : widget.onCategoryChanged != null
                            ? InkWell(
                                onTap: () => _showCategoryPicker(context, exePath, ''),
                                borderRadius: BorderRadius.circular(8),
                                child: Icon(Icons.label_outline,
                                    size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                              )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position, String exePath,
      String appName, ThemeData theme) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 'explorer',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 16,
                  color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Open in Explorer', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'ignore',
          child: Row(
            children: [
              Icon(Icons.visibility_off, size: 16,
                  color: theme.colorScheme.error),
              const SizedBox(width: 8),
              const Text('Ignore app', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'explorer') {
        _openInExplorer(exePath);
      } else if (value == 'ignore') {
        widget.onIgnoreApp?.call(exePath);
      }
    });
  }

  void _openInExplorer(String exePath) {
    final file = File(exePath);
    if (file.existsSync()) {
      Process.run('explorer', ['/select,', exePath]);
    } else {
      // Try opening the directory part
      final dir = exePath.substring(0, exePath.lastIndexOf(RegExp(r'[/\\]')));
      Process.run('explorer', [dir]);
    }
  }

  Widget _titleRow(_ListItem item, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.titleText!,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            TimeUtils.formatHMS(item.titleSeconds!),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _sortBy(int col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = false;
      }
    });
  }

  void _showCategoryPicker(BuildContext context, String exePath, String current) {
    // Gather known categories from existing assignments + common defaults
    final existing = widget.appCategories.values.toSet();
    final all = <String>{
      ...existing,
      ...widget.knownCategories,
    }..remove('');
    final sorted = all.toList()..sort();

    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Set Category'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sorted.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: sorted.map((cat) {
                      final isSelected = cat == current;
                      return ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          widget.onCategoryChanged?.call(exePath, cat);
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('Or enter a new category:', style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: sorted.isEmpty,
                        decoration: const InputDecoration(
                          hintText: 'New category…',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (v) {
                          final cat = v.trim();
                          if (cat.isEmpty) return;
                          Navigator.pop(ctx);
                          widget.onCategoryChanged?.call(exePath, cat);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final cat = ctrl.text.trim();
                        if (cat.isEmpty) return;
                        Navigator.pop(ctx);
                        widget.onCategoryChanged?.call(exePath, cat);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _ListItem {
  final MapEntry<String, int>? entry;
  final bool isTitle;
  final String? titleText;
  final int? titleSeconds;

  const _ListItem({
    this.entry,
    required this.isTitle,
    this.titleText,
    this.titleSeconds,
  });
}
