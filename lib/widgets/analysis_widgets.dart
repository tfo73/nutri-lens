import 'dart:io';
import 'package:flutter/material.dart';
import 'animated_widgets.dart';

/// A shared shimmer banner that shows "AI is analyzing" with ghost placeholders.
class ShimmerAnalysisBanner extends StatefulWidget {
  final String? title;
  const ShimmerAnalysisBanner({super.key, this.title});

  @override
  State<ShimmerAnalysisBanner> createState() => _ShimmerAnalysisBannerState();
}

class _ShimmerAnalysisBannerState extends State<ShimmerAnalysisBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1C2128) : const Color(0xFFF0F0F0);
    final highlight = isDark ? const Color(0xFF2D333B) : const Color(0xFFFFFFFF);

    Widget ghost(double w, double h, {double radius = 8}) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final slide = _ctrl.value * 3 - 1;
        return Container(
          width: w, height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(slide - 1, 0),
              end: Alignment(slide + 1, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(), // Main UI handles scrolling
        children: [
          // Animated title (shimmer text)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => ShaderMask(
              shaderCallback: (bounds) {
                final slide = _ctrl.value * 3 - 1;
                return LinearGradient(
                  begin: Alignment(slide - 1, 0),
                  end: Alignment(slide + 1, 0),
                  colors: [
                    cs.onSurface.withValues(alpha: 0.25),
                    cs.primary,
                    cs.onSurface.withValues(alpha: 0.25),
                  ],
                ).createShader(bounds);
              },
              child: child!,
            ),
            child: Text(
              widget.title ?? '🔄 Yapay zeka analiz ediyor...',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          ghost(220, 24, radius: 6),
          const SizedBox(height: 2),
          ghost(160, 18, radius: 5),
          const SizedBox(height: 6),
          Row(
            children: [
              ghost(75, 45, radius: 10),
              const SizedBox(width: 4),
              ghost(75, 45, radius: 10),
              const SizedBox(width: 4),
              ghost(75, 45, radius: 10),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ghost(100, 24, radius: 6),
              const SizedBox(width: 4),
              ghost(120, 24, radius: 6),
            ],
          ),
          const SizedBox(height: 6),
          ghost(double.infinity, 80, radius: 16),
          const SizedBox(height: 2),
          ghost(180, 16, radius: 4),
          const SizedBox(height: 6),
          ghost(double.infinity, 40, radius: 10),
          const SizedBox(height: 2),
          ghost(240, 24, radius: 8),
        ],
      ),
    );
  }
}

/// A full-screen or expanded view showing the scanner effect and shimmer banner.
class AnalysisProgressView extends StatefulWidget {
  final File? image;
  final VoidCallback? onBack;
  const AnalysisProgressView({super.key, this.image, this.onBack});

  @override
  State<AnalysisProgressView> createState() => _AnalysisProgressViewState();
}

class _AnalysisProgressViewState extends State<AnalysisProgressView> with SingleTickerProviderStateMixin {
  late final AnimationController _traceCtrl;

  @override
  void initState() {
    super.initState();
    _traceCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _traceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ScannerEffect(
                isScanning: true,
                child: widget.image != null
                    ? Image.file(widget.image!, fit: BoxFit.cover, width: double.infinity)
                    : const ColoredBox(color: Colors.black38),
              ),
              if (widget.onBack != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Expanded(flex: 45, child: ShimmerAnalysisBanner()),
      ],
    );
  }
}
