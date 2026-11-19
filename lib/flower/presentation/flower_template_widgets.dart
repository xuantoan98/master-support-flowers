import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

class TemplateSectionHeading extends StatelessWidget {
  const TemplateSectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!,
                style: TextStyle(
                  color: context.palette.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: TextStyle(
                fontFamily: FlowerTemplateTheme.headingFont,
                color: context.palette.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class TemplateIconBadge extends StatelessWidget {
  const TemplateIconBadge({super.key, required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.palette.blush.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: context.palette.primary, size: size * 0.52),
  );
}

class TemplateEmptyState extends StatelessWidget {
  const TemplateEmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TemplateIconBadge(icon: icon, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted),
          ),
        ],
      ),
    ),
  );
}

/// Floating bottom actions for form screens: an optional round back button
/// and a pill-shaped primary button, both casting a shadow over the content.
class FloatingFormBar extends StatelessWidget {
  const FloatingFormBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.arrow_forward_rounded,
    this.showBack = false,
    this.onBack,
  });

  final String primaryLabel;

  /// Shown after the label, e.g. an arrow for "next" or a check to confirm.
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final bool showBack;
  final VoidCallback? onBack;

  /// Space to leave under scrolling content so the bar never hides it.
  static const reservedHeight = 96.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shadow = Colors.black.withValues(alpha: palette.isDark ? 0.5 : 0.22);
    return Row(
      children: [
        if (showBack)
          Material(
            color: palette.card,
            shape: CircleBorder(side: BorderSide(color: palette.line)),
            elevation: 6,
            shadowColor: shadow,
            child: IconButton(
              tooltip: 'Quay lại',
              iconSize: 24,
              constraints: const BoxConstraints.tightFor(width: 54, height: 54),
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: palette.ink),
            ),
          ),
        if (showBack) const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              elevation: 6,
              shadowColor: shadow,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (primaryIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(primaryIcon, size: 20),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
