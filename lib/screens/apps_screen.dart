/// Apps screen: searchable, sortable table of tracked apps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracker_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/app_data_table.dart';
import '../core/constants.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackerProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final trackerNotifier = ref.read(trackerProvider.notifier);
    final theme = Theme.of(context);

    // Gather known categories from rules + existing assignments
    final knownCategories = <String>{
      ...settings.categoryRules.map((r) => r['category'] ?? ''),
      ...AppConstants.defaultCategoryRules.values,
    }..remove('');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Applications',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.appUsage.length} apps tracked today',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ShimmerWrap(
              isLoading: state.isLoading,
              shimmer: const ShimmerDataTable(),
              child: AppDataTable(
                appUsage: state.appUsage,
                appNames: state.appNames,
                appCategories:
                    settings.enableAppCategories ? state.appCategories : {},
                totalActiveSeconds: state.totalActiveSeconds,
                windowTitleUsage: settings.trackWindowTitles
                    ? state.windowTitleUsage
                    : const {},
                knownCategories: settings.enableAppCategories
                    ? knownCategories.toList()
                    : const [],
                onCategoryChanged: settings.enableAppCategories
                    ? (exePath, category) {
                        trackerNotifier.setAppCategory(exePath, category);
                      }
                    : null,
                onIgnoreApp: (exePath) {
                  notifier.addIgnoredApp(exePath);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Ignored: ${state.appNames[exePath] ?? exePath}',
                      ),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => notifier.removeIgnoredApp(exePath),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
