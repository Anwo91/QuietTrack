/// Shimmer skeleton placeholders for loading states.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';

// ShimmerWrap: crossfades between shimmer skeleton and real content

class ShimmerWrap extends StatelessWidget {
  final bool isLoading;
  final Widget shimmer;
  final Widget child;

  const ShimmerWrap({
    super.key,
    required this.isLoading,
    required this.shimmer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      child: isLoading
          ? KeyedSubtree(key: const ValueKey('shimmer'), child: shimmer)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}

// Reusable shimmer primitives

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase(brightness),
      highlightColor: AppTheme.shimmerHighlight(brightness),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase(brightness),
      highlightColor: AppTheme.shimmerHighlight(brightness),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Screen-specific shimmer skeletons

class ShimmerDashboardCard extends StatelessWidget {
  const ShimmerDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ShimmerBox(width: 120, height: 14),
            SizedBox(height: 16),
            ShimmerBox(width: 180, height: 36),
            SizedBox(height: 12),
            ShimmerBox(width: 80, height: 12),
          ],
        ),
      ),
    );
  }
}

class ShimmerPieChart extends StatelessWidget {
  const ShimmerPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ShimmerBox(width: 140, height: 14),
            const SizedBox(height: 16),
            ShimmerCircle(size: 160),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: const [
                    ShimmerBox(width: 12, height: 12, radius: 2),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerBarChart extends StatelessWidget {
  const ShimmerBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 160, height: 14),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  12,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ShimmerBox(
                        height: 40 + (i * 10.0 % 120),
                        radius: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerDataTable extends StatelessWidget {
  final int rows;
  const ShimmerDataTable({super.key, this.rows = 8});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header row
            Row(
              children: const [
                Expanded(flex: 3, child: ShimmerBox(height: 14)),
                SizedBox(width: 16),
                Expanded(flex: 2, child: ShimmerBox(height: 14)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: ShimmerBox(height: 14)),
              ],
            ),
            const Divider(height: 24),
            // Data rows
            ...List.generate(
              rows,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: const [
                    Expanded(flex: 3, child: ShimmerBox(height: 12)),
                    SizedBox(width: 16),
                    Expanded(flex: 2, child: ShimmerBox(height: 12)),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: ShimmerBox(height: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
