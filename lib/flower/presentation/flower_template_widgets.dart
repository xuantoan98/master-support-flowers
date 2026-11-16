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
                style: const TextStyle(
                  color: FlowerTemplateTheme.deepSage,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: const TextStyle(
                fontFamily: FlowerTemplateTheme.headingFont,
                color: FlowerTemplateTheme.ink,
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
      color: FlowerTemplateTheme.hydrangea.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: FlowerTemplateTheme.navy, size: size * 0.52),
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
            style: const TextStyle(color: FlowerTemplateTheme.muted),
          ),
        ],
      ),
    ),
  );
}
