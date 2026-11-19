import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

class StepItem {
  const StepItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;

  /// Step accent; falls back to the theme's primary colour.
  final Color? color;
}

/// Row of round step icons joined by lines: finished steps show a check,
/// the current step is filled with a soft halo, later steps are muted.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.steps,
    required this.current,
    this.allDone = false,
    this.onStepTap,
    this.semanticsPrefix,
  });

  final List<StepItem> steps;

  /// Index of the active step; -1 shows every step as not reached.
  final int current;

  /// Marks every step finished (e.g. a delivered order).
  final bool allDone;

  /// Called for finished steps only, to jump back.
  final ValueChanged<int>? onStepTap;

  /// Read before the step list by screen readers, e.g. "Bước 2/4".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = allDone || i < current;
      final active = !allDone && i == current;
      final color = palette.adapt(steps[i].color ?? palette.primary);
      children.add(
        _StepDot(
          item: steps[i],
          color: color,
          done: done,
          active: active,
          onTap: done && onStepTap != null ? () => onStepTap!(i) : null,
        ),
      );
      if (i < steps.length - 1) {
        final filled = allDone || i < current;
        final nextColor = palette.adapt(steps[i + 1].color ?? palette.primary);
        children.add(
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: filled
                    ? LinearGradient(colors: [color, nextColor])
                    : null,
                color: filled ? null : palette.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
    }
    final summary = [
      ?semanticsPrefix,
      if (current >= 0 && current < steps.length) steps[current].label,
    ].join(': ');
    return Semantics(
      container: true,
      label: summary.isEmpty ? null : summary,
      child: Row(children: children),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.item,
    required this.color,
    required this.done,
    required this.active,
    this.onTap,
  });

  final StepItem item;
  final Color color;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filled = done || active;
    final foreground = palette.isDark ? palette.canvas : Colors.white;
    final state = done
        ? 'đã xong'
        : active
        ? 'đang ở bước này'
        : 'chưa tới';
    return Semantics(
      container: true,
      button: onTap != null,
      label: '${item.label}, $state',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: active ? 42 : 34,
          height: active ? 42 : 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : palette.blush.withValues(alpha: 0.6),
            border: active
                ? Border.all(color: color.withValues(alpha: 0.25), width: 5)
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              done ? Icons.check_rounded : item.icon,
              key: ValueKey(done),
              size: active ? 18 : 17,
              color: filled ? foreground : palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
