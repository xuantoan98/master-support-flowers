import 'dart:async';

import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = true,
  }) {
    _timer?.cancel();
    _entry?.remove();
    _entry?.dispose();

    final color = isError
        ? FlowerTemplateTheme.peach
        : FlowerTemplateTheme.deepSage;
    final foreground = isError ? FlowerTemplateTheme.navy : Colors.white;
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom +
        104;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: bottom,
        child: IgnorePointer(
          child: Material(
            color: color,
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: foreground,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(message, style: TextStyle(color: foreground)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 3), () {
      if (identical(_entry, entry)) {
        entry.remove();
        entry.dispose();
        _entry = null;
      }
    });
  }
}

class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      children: const [
        TextSpan(
          text: ' *',
          style: TextStyle(color: Colors.red),
        ),
      ],
    ),
  );
}
