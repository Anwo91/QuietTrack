/// Card wrapper with fade-in + scale entrance animation.
library;

import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index; // used to stagger the entrance animation
  final EdgeInsetsGeometry padding;

  const AnimatedCard({
    super.key,
    required this.child,
    this.index = 0,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final delay = widget.index * 0.08; // stagger
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(delay.clamp(0.0, 0.6), 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(delay.clamp(0.0, 0.6), 1.0, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return Card(
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      );
    }

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .shadowColor
                      .withValues(alpha: _hovered ? 0.12 : 0.04),
                  blurRadius: _hovered ? 12 : 4,
                  offset: Offset(0, _hovered ? 4 : 1),
                ),
              ],
            ),
            child: Card(
              elevation: 0, // shadow handled by AnimatedContainer
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
