/// Persistent sidebar with hover animations, info panel, and version check.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

class Sidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Nav items
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final selected = widget.selectedIndex == i;
            final hovered = _hoveredIndex == i;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildNavTile(
                item: item,
                index: i,
                selected: selected,
                hovered: hovered,
                colorScheme: colorScheme,
                duration: duration,
              ),
            );
          }),

          const Spacer(),

          // Settings (pinned above help)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildNavTile(
              item: _settingsItem,
              index: _settingsIndex,
              selected: widget.selectedIndex == _settingsIndex,
              hovered: _hoveredIndex == _settingsIndex,
              colorScheme: colorScheme,
              duration: duration,
            ),
          ),
          const SizedBox(height: 8),

          // Bottom info section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                // Quick-help tooltip
                Tooltip(
                  message: 'QuietTrack tracks your active app,\n'
                      'idle time, media consumption,\n'
                      'and monitors.\n\n'
                      'Enable features in Settings.\n'
                      'Right-click apps to ignore them.',
                  preferBelow: false,
                  textAlign: TextAlign.center,
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),

                // Version
                Tooltip(
                  message: 'Check for updates in Settings',
                  preferBelow: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required _NavItem item,
    required int index,
    required bool selected,
    required bool hovered,
    required ColorScheme colorScheme,
    required Duration duration,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onDestinationSelected(index),
        child: AnimatedContainer(
          duration: duration,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : hovered
                    ? colorScheme.surfaceContainerHighest
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: duration,
                scale: hovered ? 1.15 : 1.0,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _items = [
  _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _NavItem(Icons.apps_outlined, Icons.apps, 'Apps'),
  _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
];

const _settingsItem = _NavItem(Icons.settings_outlined, Icons.settings, 'Settings');
const _settingsIndex = 3;
