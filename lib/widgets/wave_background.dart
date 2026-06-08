import 'dart:math';
import 'package:flutter/material.dart';

// ─── Wave Background ──────────────────────────────────────────────────────────

class WaveBackground extends StatelessWidget {
  final Widget child;
  const WaveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: WavePainter(isDark: isDark),
          ),
        ),
        child,
      ],
    );
  }
}

// ─── Wave Painter ─────────────────────────────────────────────────────────────

class WavePainter extends CustomPainter {
  final bool isDark;
  WavePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const waveCount = 5;
    for (int i = 0; i < waveCount; i++) {
      final yBase = size.height * (i + 1) / (waveCount + 1);
      final path = Path();
      path.moveTo(0, yBase);
      for (double x = 0; x <= size.width; x += 2) {
        final y = yBase + sin(x / size.width * 2 * pi) * 12;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter old) => old.isDark != isDark;
}
