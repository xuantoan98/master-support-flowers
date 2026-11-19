import 'dart:math';

import 'package:flutter/material.dart';

import 'flower_template_theme.dart';

/// Short celebration after a new order is saved; closes itself.
Future<void> showOrderSuccess(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierLabel: 'Tạo đơn thành công',
  barrierColor: context.palette.canvas.withValues(alpha: 0.88),
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => const _OrderSuccess(),
);

class _OrderSuccess extends StatefulWidget {
  const _OrderSuccess();

  @override
  State<_OrderSuccess> createState() => _OrderSuccessState();
}

class _Particle {
  _Particle(Random random)
    : emoji = _emojis[random.nextInt(_emojis.length)],
      angle = random.nextDouble() * 2 * pi,
      speed = 0.55 + random.nextDouble() * 0.6,
      spin = (random.nextDouble() - 0.5) * 6,
      size = 18 + random.nextDouble() * 16,
      delay = random.nextDouble() * 0.15;

  static const _emojis = ['🌸', '💐', '🌷', '✨', '🎉', '🌼', '💮'];

  final String emoji;
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final double delay;
}

class _OrderSuccessState extends State<_OrderSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final List<_Particle> particles;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    particles = List.generate(26, (_) => _Particle(random));
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            Navigator.of(context).pop();
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.duration = const Duration(milliseconds: 1200);
      }
      controller.forward();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final size = MediaQuery.sizeOf(context);
          final center = Offset(size.width / 2, size.height * 0.42);
          final reach = size.shortestSide * 0.62;
          final textIn = Curves.easeOutBack.transform((t / 0.25).clamp(0, 1));
          final fadeOut = t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1.0;
          return Opacity(
            opacity: fadeOut.clamp(0.0, 1.0),
            child: Stack(
              children: [
                if (!reduceMotion)
                  for (final p in particles)
                    Builder(
                      builder: (_) {
                        final local = ((t - p.delay) / (1 - p.delay)).clamp(
                          0.0,
                          1.0,
                        );
                        final travel = Curves.easeOutCubic.transform(local);
                        final gravity = 0.5 * 900 * local * local * 0.35;
                        final position =
                            center +
                            Offset(cos(p.angle), sin(p.angle)) *
                                reach *
                                p.speed *
                                travel +
                            Offset(0, gravity);
                        return Positioned(
                          left: position.dx - p.size / 2,
                          top: position.dy - p.size / 2,
                          child: Opacity(
                            opacity: local < 0.75 ? 1 : (1 - local) * 4,
                            child: Transform.rotate(
                              angle: p.spin * local,
                              child: Text(
                                p.emoji,
                                style: TextStyle(fontSize: p.size),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: center.dy - 70,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * textIn,
                    child: Opacity(
                      opacity: textIn.clamp(0.0, 1.0),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 52)),
                            const SizedBox(height: 8),
                            Text(
                              'Tạo đơn thành công!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: FlowerTemplateTheme.headingFont,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Khách đã tin, giờ là lúc cắm thật đẹp 🌷',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
