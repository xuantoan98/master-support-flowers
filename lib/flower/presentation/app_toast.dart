import 'dart:async';

import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _key;
  static Timer? _timer;

  static const visibleFor = Duration(seconds: 3);

  /// Longer, so there is time to reach the action button.
  static const visibleWithActionFor = Duration(seconds: 5);

  static void show(
    BuildContext context,
    String message, {
    bool isError = true,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _timer?.cancel();
    _dismissCurrent();

    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom +
        104;
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_ToastViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      // Near full width (lined up with the bottom dock); height follows the
      // message.
      builder: (_) => Positioned(
        left: 16,
        right: 16,
        bottom: bottom,
        child: _ToastView(
          key: key,
          message: message,
          isError: isError,
          actionLabel: onAction == null ? null : actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  _timer?.cancel();
                  _dismissCurrent();
                  onAction();
                },
          onHidden: () {
            if (entry.mounted) {
              entry.remove();
            }
            entry.dispose();
            if (identical(_entry, entry)) {
              _entry = null;
              _key = null;
            }
          },
        ),
      ),
    );
    _entry = entry;
    _key = key;
    overlay.insert(entry);
    _timer = Timer(
      onAction == null ? visibleFor : visibleWithActionFor,
      _dismissCurrent,
    );
  }

  static void _dismissCurrent() {
    final key = _key;
    final entry = _entry;
    _key = null;
    _entry = null;
    if (key?.currentState case final state?) {
      state.hide();
    } else if (entry != null) {
      if (entry.mounted) {
        entry.remove();
      }
      entry.dispose();
    }
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.isError,
    required this.onHidden,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onHidden;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();

  late final Animation<double> curve = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  bool hiding = false;

  Future<void> hide() async {
    if (hiding) {
      return;
    }
    hiding = true;
    if (mounted) {
      await controller.reverse();
    }
    widget.onHidden();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError
        ? FlowerTemplateTheme.peach
        : FlowerTemplateTheme.deepSage;
    final foreground = widget.isError ? FlowerTemplateTheme.navy : Colors.white;
    return IgnorePointer(
      ignoring: widget.onAction == null,
      child: FadeTransition(
        opacity: controller,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(curve),
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curve),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: color,
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: foreground,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(color: foreground),
                        ),
                      ),
                      if (widget.onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: widget.onAction,
                          // Shrink-wrapped: the default 48 px tap target
                          // made the toast much taller than its text.
                          style: TextButton.styleFrom(
                            foregroundColor: foreground,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          child: Text(widget.actionLabel ?? 'Hoàn tác'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
