/// Animated time counter with TweenAnimationBuilder.
library;

import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class AnimatedTimeCounter extends StatelessWidget {
  final int totalSeconds;
  final TextStyle? style;
  final bool hero; // larger font for dashboard hero card

  const AnimatedTimeCounter({
    super.key,
    required this.totalSeconds,
    this.style,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final theme = Theme.of(context);

    final defaultStyle = hero
        ? theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: -0.5,
          )
        : theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          );

    // If reduce-motion is enabled, skip animation
    if (reduceMotion) {
      return Text(
        TimeUtils.formatHMS(totalSeconds),
        style: style ?? defaultStyle,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: totalSeconds.toDouble()),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          TimeUtils.formatHMS(value.round()),
          style: style ?? defaultStyle,
        );
      },
    );
  }
}
