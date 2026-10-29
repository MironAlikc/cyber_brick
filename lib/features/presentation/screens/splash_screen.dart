import 'package:cyber_brick/core/retro_ui.dart';
import 'package:flutter/material.dart';

import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_next);
  }

  void _next() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const MenuScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _skip() {
    _controller.stop();
    _next();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: RetroShell(
        lcdChild: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final textOpacity =
                ((t - 0.25) / 0.15).clamp(0.0, 1.0) *
                (1 - ((t - 0.85) / 0.15).clamp(0.0, 1.0));

            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _SplashPainter(t))),
                Center(
                  child: Opacity(
                    opacity: textOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: RetroColors.lcd,
                        border: Border.all(color: RetroColors.ink, width: 3),
                      ),
                      child: const Text(
                        'CYBER\nBRICK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPixelFontFamily,
                          fontSize: 34,
                          height: 1.6,
                          color: RetroColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        children: [],
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  final double t;

  _SplashPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 20;
    final cell = size.height / rows;
    final cols = (size.width / cell).floor();
    final offsetX = (size.width - cols * cell) / 2;

    // 0 … 0.55 — заполнение снизу вверх, 0.55 … 1 — гашение снизу вверх.
    final fillT = (t / 0.55).clamp(0.0, 1.0);
    final clearT = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    final fillLimit = fillT * (rows + 3);
    final clearLimit = clearT * (rows + 3);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final fromBottom = rows - 1 - r;
        final key = fromBottom + ((c * 7) % 5) * 0.3;
        final filled = key < fillLimit && !(key < clearLimit);

        paintLcdCell(
          canvas,
          Rect.fromLTWH(offsetX + c * cell, r * cell, cell, cell),
          filled ? LcdCell.filled : LcdCell.empty,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) => old.t != t;
}
