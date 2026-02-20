/// Per-monitor usage breakdown.
library;

import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class MonitorBreakdown extends StatelessWidget {
  final Map<String, int> monitorUsage;

  const MonitorBreakdown({super.key, required this.monitorUsage});

  @override
  Widget build(BuildContext context) {
    if (monitorUsage.isEmpty) {
      return Text(
        'No monitor data yet.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    final sorted = monitorUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        monitorUsage.values.fold<int>(0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.map((entry) {
        final fraction = total > 0 ? entry.value / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    TimeUtils.formatShort(entry.value),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
