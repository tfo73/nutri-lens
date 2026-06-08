import 'dart:ui';
import 'package:flutter/material.dart';

// ─── Fade + Slide from below ───────────────────────────────────────────────────

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slidePixels;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.slidePixels = 28.0,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slidePixels / 200),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Animated Press Scale ─────────────────────────────────────────────────────

class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleTo;

  const AnimatedPressButton({
    super.key,
    required this.child,
    this.onPressed,
    this.scaleTo = 0.93,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleTo).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return GestureDetector(onTap: widget.onPressed, child: widget.child);
    }
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse().then((_) => widget.onPressed?.call());
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─── Shimmer Loading Placeholder ──────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final highlight =
        isDark ? const Color(0xFF424242) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final start = -1.0 + t * 3;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(start, 0),
              end: Alignment(start + 1.5, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ─── Slide + Fade Page Route ──────────────────────────────────────────────────

/// Drop-in replacement for MaterialPageRoute that slides + fades the new page in.
Route<T> slidePageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 14, width: 120),
            const SizedBox(height: 12),
            const ShimmerBox(height: 10),
            const SizedBox(height: 6),
            const ShimmerBox(height: 10, width: 180),
          ],
        ),
      ),
    );
  }
}

// ─── Scanner Animation Effect ──────────────────────────────────────────────────

class ScannerEffect extends StatefulWidget {
  final Widget child;
  final bool isScanning;
  final Color scannerColor;

  const ScannerEffect({
    super.key,
    required this.child,
    this.isScanning = true,
    this.scannerColor = const Color(0xFF007AFF), // Apple Blue / LensEat Brand Blue
  });

  @override
  State<ScannerEffect> createState() => _ScannerEffectState();
}

class _ScannerEffectState extends State<ScannerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );

    if (widget.isScanning) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ScannerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isScanning)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final top = _animation.value * constraints.maxHeight;
                  return Stack(
                    children: [
                      // Scanner Line
                      Positioned(
                        top: top - 1,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: widget.scannerColor.withValues(alpha: 0.8),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: widget.scannerColor.withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                widget.scannerColor.withValues(alpha: 0.01),
                                widget.scannerColor,
                                widget.scannerColor.withValues(alpha: 0.01),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Scanner Glow Gradient (Trailing)
                      Positioned(
                        top: _ctrl.status == AnimationStatus.forward 
                            ? top - 80 
                            : top,
                        left: 0, 
                        right: 0,
                        height: 80,
                        child: Opacity(
                          opacity: 0.12,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: _ctrl.status == AnimationStatus.forward 
                                    ? Alignment.bottomCenter 
                                    : Alignment.topCenter,
                                end: _ctrl.status == AnimationStatus.forward 
                                    ? Alignment.topCenter 
                                    : Alignment.bottomCenter,
                                colors: [
                                  widget.scannerColor,
                                  widget.scannerColor.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

// ─── Border Trace Animation Painter ──────────────────────────────────────────

class BorderTracePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;
  final double strokeWidth;

  BorderTracePainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startX = size.width / 2;
    final path = Path();
    path.moveTo(startX, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.arcToPoint(Offset(size.width, borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(Offset(size.width - borderRadius, size.height), radius: Radius.circular(borderRadius));
    path.lineTo(borderRadius, size.height);
    path.arcToPoint(Offset(0, size.height - borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(0, borderRadius);
    path.arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius));
    path.lineTo(startX, 0);

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    final segmentLength = totalLength * 0.25; // 25% of the total perimeter
    final currentOffset = totalLength * progress;

    Path extract;
    if (currentOffset + segmentLength <= totalLength) {
      extract = metrics.extractPath(currentOffset, currentOffset + segmentLength);
    } else {
      extract = metrics.extractPath(currentOffset, totalLength);
      extract.addPath(metrics.extractPath(0, (currentOffset + segmentLength) % totalLength), Offset.zero);
    }
    
    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(BorderTracePainter oldDelegate) => oldDelegate.progress != progress;
}
