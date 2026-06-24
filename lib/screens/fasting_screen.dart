import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fasting_session.dart';
import '../providers/fasting_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/achievement_provider.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  FastingMode _selectedMode = FastingMode.sixteen8;
  int _customHours = 14;
  bool _autoEnding = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ticker.addListener(() async {
      final fasting = context.read<FastingProvider>();
      fasting.tick();
      if (!_autoEnding && fasting.isFasting &&
          fasting.activeSession!.elapsed >= fasting.activeSession!.goalDuration) {
        _autoEnding = true;
        final hours = fasting.activeSession!.fastingHours;
        await fasting.endFasting(context.read<AchievementProvider>());
        NotificationService.showFastingCompleteNotification(fastingHours: hours);
        _autoEnding = false;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fasting = context.watch<FastingProvider>();
    final now = DateTime.now();

    final goalHours = fasting.isFasting
        ? fasting.activeSession!.fastingHours
        : (_selectedMode == FastingMode.custom
            ? _customHours
            : _selectedMode.defaultFastingHours);

    final fastStart = fasting.isFasting ? fasting.activeSession!.startTime : null;
    final fastEnd = fasting.isFasting
        ? fasting.activeSession!.startTime
            .add(Duration(hours: fasting.activeSession!.fastingHours))
        : now.add(Duration(hours: goalHours));

    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE8EAED);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Always-visible 24h clock ──
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: goalHours.toDouble(), end: goalHours.toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, animHours, child) {
                // Recalculate fastEnd based on animated hours for the preview
                final animFastEnd = fasting.isFasting
                    ? fasting.activeSession!.startTime.add(Duration(minutes: (animHours * 60).round()))
                    : now.add(Duration(minutes: (animHours * 60).round()));
                
                return RepaintBoundary(
                  child: FastingClockWidget(
                    now: now,
                    fastStart: fastStart ?? now,
                    fastEnd: animFastEnd,
                    goalHours: animHours.round(),
                    isActive: fasting.isFasting,
                    elapsed: fasting.isFasting ? fasting.activeSession!.elapsed : null,
                    primaryColor: primary,
                    trackColor: trackColor,
                  ),
                );
              },
            ),

            // ── Content below clock ──
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: fasting.isFasting
                    ? _ActiveContent(
                        session: fasting.activeSession!,
                        onEnd: () => _confirmEnd(context, fasting),
                        history: fasting.history,
                      )
                    : _SelectionContent(
                        selectedMode: _selectedMode,
                        customHours: _customHours,
                        onModeChanged: (m) => setState(() => _selectedMode = m),
                        onCustomHoursChanged: (h) =>
                            setState(() => _customHours = h),
                        onStart: () => fasting.startFasting(
                          _selectedMode,
                          customHours: _selectedMode == FastingMode.custom
                              ? _customHours
                              : null,
                        ),
                        history: fasting.history,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(
      BuildContext context, FastingProvider fasting) async {
    final session = fasting.activeSession!;
    final completed = session.elapsed >= session.goalDuration;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          completed ? context.tr('Tebrikler! 🎉') : context.tr('Orucu Sonlandır'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          completed
              ? context.tr('Hedefinize ulaştınız! Orucu kaydetmek istiyor musunuz?')
              : context.tr('Henüz hedefinize ulaşmadınız.'),
          style: TextStyle(
            color: Theme.of(ctx)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Vazgeç')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF85149),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(context.tr('Orucu İptal Et')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'end'),
            child: Text(context.tr('Orucu Bitir')),
          ),
        ],
      ),
    );

    if (result == 'end') {
      if (context.mounted) {
        await fasting.endFasting(context.read<AchievementProvider>());
      }
    } else if (result == 'cancel') {
      if (context.mounted) {
        await fasting.cancelFasting(context.read<AchievementProvider>());
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 24-Hour Clock Widget
// ══════════════════════════════════════════════════════════════════════════════

class FastingClockWidget extends StatelessWidget {
  final DateTime now;
  final DateTime fastStart;
  final DateTime fastEnd;
  final int goalHours;
  final bool isActive;
  final Duration? elapsed;
  final Color primaryColor;
  final Color trackColor;

  final bool compact;

  const FastingClockWidget({
    required this.now,
    required this.fastStart,
    required this.fastEnd,
    required this.goalHours,
    required this.isActive,
    required this.elapsed,
    required this.primaryColor,
    required this.trackColor,
    this.compact = false,
  });

  String _p(int n) => n.toString().padLeft(2, '0');

  String get _elapsedLongText {
    if (!isActive) return '00:00:00';
    final e = elapsed!;
    return '${_p(e.inHours)}:${_p(e.inMinutes % 60)}:${_p(e.inSeconds % 60)}';
  }

  String _remainingLongText(BuildContext context) {
    if (!isActive) return '00:00:00';
    final goal = Duration(hours: goalHours);
    final rem = goal - elapsed!;
    if (rem.isNegative) return context.tr('HEDEFE ULAŞILDI');
    return '${_p(rem.inHours)}:${_p(rem.inMinutes % 60)}:${_p(rem.inSeconds % 60)}';
  }

  String _formatTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}';

  String _startTimeFormatted(BuildContext context) {
    final nowDay = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(fastStart.year, fastStart.month, fastStart.day);
    final diff = nowDay.difference(startDay).inDays;
    
    String dayText = context.tr('Bugün');
    if (diff == 1) dayText = context.tr('Dün');
    else if (diff > 1) dayText = '$diff ${context.tr('gün önce')}';
    
    return '${_p(fastStart.hour)}:${_p(fastStart.minute)} $dayText';
  }

  String _endTimeFormatted(BuildContext context) {
    final nowDay = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(fastEnd.year, fastEnd.month, fastEnd.day);
    final diff = endDay.difference(nowDay).inDays;
    
    String dayText = context.tr('Bugün');
    if (diff == 1) dayText = context.tr('Yarın');
    
    return '${_p(fastEnd.hour)}:${_p(fastEnd.minute)} $dayText';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF00BFA5);
    final track = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    if (!isActive) {
      // Inactive: Small circle with centered goal/times
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(240, 240),
                    painter: _InactiveClockPainter(
                      fastStart: fastStart,
                      fastEnd: fastEnd,
                      goalHours: goalHours,
                      color: primary,
                      trackColor: track,
                      isDark: isDark,
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pivot: The duration text exactly in the center
                      Center(
                        child: Text(
                          '$goalHours ${context.tr('saat')}',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Details above and below
                      Positioned(
                        top: 75,
                        child: Text(
                          context.tr('Hedef Saat'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 52,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${context.tr('Başlangıç')}: ${_formatTime(fastStart)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFFFF9500), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${context.tr('Bitiş')}: ${_formatTime(fastEnd)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Active: Image-style semi-circle gauge
    final double actualProgress = (elapsed!.inSeconds / (goalHours * 3600)).clamp(0.0, 1.0);
    // Visual progress: Start at 0.25% and gradually lose the bonus as progress increases
    final double progress = actualProgress + (0.0025 * (1.0 - actualProgress));

    final Widget mainLayout = compact 
      ? Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  height: 110, // Reduced from 125
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 2,
                        child: CustomPaint(
                          size: const Size(160, 160),
                          painter: ActiveGaugePainter(
                            progress: progress,
                            color: primary,
                            trackColor: track,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 45,
                        child: Column(
                          children: [
                            Text(
                              context.tr('GEÇEN'),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            Text(
                              _elapsedLongText,
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.1,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${context.tr('KALAN')}: ${_remainingLongText(context).split(' ').first}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // No SizedBox here to keep it close
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$goalHours:${goalHours > 24 ? 0 : 24 - goalHours} ${context.tr('Orucu')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8), 
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, 
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CompactStatItem(
                    label: context.tr('BAŞLANGIÇ'), 
                    value: _startTimeFormatted(context),
                    icon: Icons.play_circle_outline,
                    color: const Color(0xFF007AFF),
                  ),
                  const SizedBox(height: 6),
                  _CompactStatItem(
                    label: context.tr('HEDEF'), 
                    value: '$goalHours ${context.tr('Saat')}', 
                    icon: Icons.flag_outlined,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 6),
                  _CompactStatItem(
                    label: context.tr('BİTİŞ'), 
                    value: _endTimeFormatted(context),
                    icon: Icons.stop_circle_outlined,
                    color: const Color(0xFFFF9500),
                  ),
                ],
              ),
            ),
          ],
        )
      : Column(
          children: [
            SizedBox(
              width: 280,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(250, 250),
                      painter: ActiveGaugePainter(
                        progress: progress,
                        color: primary,
                        trackColor: track,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 35,
                    child: Column(
                      children: [
                        Text(
                          context.tr('GEÇEN SÜRE'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                        Text(
                          _elapsedLongText,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${context.tr('KALAN')}: ${_remainingLongText(context)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatItem(
                    label: context.tr('BAŞLANGIÇ'), 
                    value: _startTimeFormatted(context),
                    valueColor: const Color(0xFF007AFF),
                  ),
                  _StatItem(
                    label: context.tr('HEDEF'), 
                    value: '$goalHours ${context.tr('Saat')}', 
                    valueColor: primaryColor,
                    isLarge: true,
                  ),
                  _StatItem(
                    label: context.tr('BİTİŞ'), 
                    value: _endTimeFormatted(context),
                    valueColor: const Color(0xFFFF9500),
                  ),
                ],
              ),
            ),
          ],
        );

    final Widget content = Container(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.only(top: 30, bottom: 20),
      child: mainLayout,
    );

    if (compact) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF1C1C0A) // Subtle yellow-dark
              : const Color(0xFFFFFDE7), // Subtle yellow-light
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: content,
      );
    }

    return content;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLarge;

  const _StatItem({
    required this.label, 
    required this.value, 
    this.valueColor,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 22 : 14,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _CompactStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        SizedBox(
          width: 85, // Fixed width for better alignment
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActiveGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  ActiveGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Semi-circle gauge (220 degrees)
    const startAngle = 160 * math.pi / 180;
    const sweepAngle = 220 * math.pi / 180;

    // Track
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(ActiveGaugePainter old) => old.progress != progress;
}

class _InactiveClockPainter extends CustomPainter {
  final DateTime fastStart;
  final DateTime fastEnd;
  final int goalHours;
  final Color color;
  final Color trackColor;
  final bool isDark;

  _InactiveClockPainter({
    required this.fastStart,
    required this.fastEnd,
    required this.goalHours,
    required this.color,
    required this.trackColor,
    required this.isDark,
  });

  double _angle(DateTime time) {
    final daySeconds = 24 * 3600;
    final seconds = (time.hour * 3600 + time.minute * 60 + time.second) % daySeconds;
    return (seconds / daySeconds) * 2 * math.pi - math.pi / 2;
  }

  void _drawMarker(Canvas canvas, Offset center, double radius, double angle, Color color, double thickness) {
    final p1 = Offset(
      center.dx + (radius + thickness / 2) * math.cos(angle),
      center.dy + (radius + thickness / 2) * math.sin(angle),
    );
    final p2 = Offset(
      center.dx + (radius - thickness / 2) * math.cos(angle),
      center.dy + (radius - thickness / 2) * math.sin(angle),
    );
    canvas.drawLine(
      p1, p2,
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    // Subtle Quarter Ticks & Numbers
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
      fontSize: 14,
      fontWeight: FontWeight.w900,
    );

    final positions = {
      -math.pi / 2: '24',
      0.0: '06',
      math.pi / 2: '12',
      math.pi: '18',
    };

    for (var entry in positions.entries) {
      final angle = entry.key;
      final label = entry.value;

      // Tick
      final isTopBottom = label == '24' || label == '12';
      final p1 = Offset(
        center.dx + (radius + 2) * math.cos(angle),
        center.dy + (radius + 2) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 18) * math.cos(angle),
        center.dy + (radius - 18) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, Paint()..color = labelStyle.color!.withValues(alpha: 0.1)..strokeWidth = 2);

      // Number
      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout();
      
      // Move 24, 06, 12, 18 closer to the circle
      final dist = isTopBottom ? radius - 32 : radius + 14;
      final textOffset = Offset(
        center.dx + dist * math.cos(angle) - textPainter.width / 2,
        center.dy + dist * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }

    // Track
    canvas.drawCircle(
      center,
      radius - 8,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Goal Arc (Teal)
    final rect = Rect.fromCircle(center: center, radius: radius - 8);
    final startAngle = _angle(fastStart);
    
    if (goalHours > 24) {
      // Background full lap (24h) with low opacity
      canvas.drawCircle(
        center,
        radius - 8,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      
      // Remainder lap
      final remainderSweep = ((goalHours % 24) / 24) * 2 * math.pi;
      canvas.drawArc(
        rect,
        startAngle,
        remainderSweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    } else {
      final endAngle = _angle(fastEnd);
      double sweep = endAngle - startAngle;
      while (sweep < 0) sweep += 2 * math.pi;

      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Start/End Markers (Full thickness)
    _drawMarker(canvas, center, radius - 8, startAngle, const Color(0xFF007AFF), strokeWidth);
    _drawMarker(canvas, center, radius - 8, _angle(fastEnd), const Color(0xFFFF9500), strokeWidth);
  }

  @override
  bool shouldRepaint(_InactiveClockPainter old) => true;
}
// Active Fasting Content (below clock)
// ══════════════════════════════════════════════════════════════════════════════

class _ActiveContent extends StatelessWidget {
  final FastingSession session;
  final VoidCallback onEnd;
  final List<FastingSession> history;

  const _ActiveContent({
    required this.session, 
    required this.onEnd,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final userWeight = profile.isProfileComplete ? profile.activeProfile?.weight : null;
    final userAge    = profile.isProfileComplete ? profile.activeProfile?.age    : null;
    final userGender = profile.isProfileComplete ? profile.activeProfile?.gender.name : null;

    final phase = FastingPhase.forElapsed(
      session.elapsed,
      weightKg: userWeight,
      age: userAge,
      gender: userGender,
    );

    final recentHistory = history.take(3).toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhaseCard(phase: phase),
                const SizedBox(height: 24),
                if (recentHistory.isNotEmpty)
                  Text(
                    context.tr('Geçmiş {} orucun').replaceAll('{}', recentHistory.length.toString()),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                const SizedBox(height: 12),
                if (recentHistory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            context.tr('Şu anlık burası boş ama doğru yoldasın,\nbir sonraki orucunda burası dolu olacak.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Icon(
                            Icons.rocket_launch_outlined,
                            size: 40,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: recentHistory.map((s) => _HistoryTile(
                      key: ValueKey(s.id),
                      session: s,
                      onDelete: () => context.read<FastingProvider>().deleteSession(s.id),
                      canDelete: false, // Yarım daire kısmındayken silmeye izin verme
                    )).toList(),
                  ),
              ],
            ),
          ),
        ),
        // Fixed end button above tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          child: FilledButton.icon(
            onPressed: onEnd,
            icon: const Icon(Icons.stop_circle_outlined, size: 20),
            label: Text(
              context.tr('Orucu Bitir'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFF85149),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mode Selection Content (below clock)
// ══════════════════════════════════════════════════════════════════════════════

class _SelectionContent extends StatelessWidget {
  final FastingMode selectedMode;
  final int customHours;
  final ValueChanged<FastingMode> onModeChanged;
  final ValueChanged<int> onCustomHoursChanged;
  final VoidCallback onStart;
  final List<FastingSession> history;

  const _SelectionContent({
    required this.selectedMode,
    required this.customHours,
    required this.onModeChanged,
    required this.onCustomHoursChanged,
    required this.onStart,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ModeCard(
                mode: FastingMode.twelvetwelve,
                title: context.tr('12:12 (Başlangıç)'),
                subtitle: context.tr('12 saat oruç, 12 saat beslenme.'),
                description: context.tr('Sirkadiyen denge için.'),
                icon: Icons.wb_sunny_outlined,
                isSelected: selectedMode == FastingMode.twelvetwelve,
                onTap: () => onModeChanged(FastingMode.twelvetwelve),
              ),
              _ModeCard(
                mode: FastingMode.sixteen8,
                title: context.tr('16:8 (Standart)'),
                subtitle: context.tr('16 saat oruç, 8 saat beslenme.'),
                description: context.tr('En popüler ve sürdürülebilir mod.'),
                icon: Icons.star_outline_rounded,
                isSelected: selectedMode == FastingMode.sixteen8,
                onTap: () => onModeChanged(FastingMode.sixteen8),
              ),
              _ModeCard(
                mode: FastingMode.eighteen6,
                title: context.tr('18:6 (İleri Seviye)'),
                subtitle: context.tr('18 saat oruç, 6 saat beslenme.'),
                description: context.tr('Daha derin otofaji için.'),
                icon: Icons.auto_awesome_outlined,
                isSelected: selectedMode == FastingMode.eighteen6,
                onTap: () => onModeChanged(FastingMode.eighteen6),
              ),
              _ModeCard(
                mode: FastingMode.custom,
                title: context.tr('Serbest'),
                subtitle: context.tr('{} saat oruç, {} saat beslenme.').replaceFirst('{}', customHours.toString()).replaceFirst('{}', (customHours > 24 ? 0 : 24 - customHours).toString()),
                description: context.tr('Hedeflerinize göre özelleştirin.'),
                icon: Icons.tune_rounded,
                isSelected: selectedMode == FastingMode.custom,
                onTap: () => onModeChanged(FastingMode.custom),
                child: selectedMode == FastingMode.custom
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.tr('Süre Seçin'), style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('$customHours ${context.tr('Saat')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF00BFA5),
                                thumbColor: const Color(0xFF00BFA5),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: customHours.toDouble(),
                                min: 8,
                                max: 36,
                                divisions: 28,
                                onChanged: (v) => onCustomHoursChanged(v.round()),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  context.tr('Orucu Başlat'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ]),
          ),
        ),

        // Past fasts
        if (history.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                context.tr('Geçmiş Oruçlar'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _HistoryTile(
                  key: ValueKey(history[i].id),
                  session: history[i],
                  onDelete: () => context.read<FastingProvider>().deleteSession(history[i].id),
                ),
                childCount: history.length,
              ),
            ),
          ),
        ] else ...[
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 180),
              child: Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(height: 12),
                      Text(context.tr('Henüz geçmiş oruç kaydı bulunmuyor.'), style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Mode Card ──────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final FastingMode mode;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? child;

  const _ModeCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF00BFA5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primary : (isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? primary : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (child != null) child!,
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(icon, size: 14, color: isSelected ? primary : Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phase Card ────────────────────────────────────────────────────────────────

class _PhaseCard extends StatelessWidget {
  final FastingPhase phase;

  const _PhaseCard({required this.phase});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(phase.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(phase.name),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(phase.description),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final FastingSession session;

  const _StatsRow({required this.session});

  String _short(BuildContext context, Duration d) {
    if (d.inHours > 0) return '${d.inHours}${context.tr('s')} ${d.inMinutes % 60}${context.tr('dk')}';
    return '${d.inMinutes}${context.tr('dk')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = session.goalDuration - session.elapsed;
    final safeRemaining =
        remaining.isNegative ? Duration.zero : remaining;
    final endTime =
        session.startTime.add(session.goalDuration);

    return Row(
      children: [
        _StatChip(
          label: context.tr('Kalan Süre'),
          value: _short(context, safeRemaining),
          icon: Icons.hourglass_bottom_rounded,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2128) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isDark
                ? const Color(0xFF30363D)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Tile ──────────────────────────────────────────────────────────────

class _HistoryTile extends StatefulWidget {
  final FastingSession session;
  final VoidCallback onDelete;
  final bool canDelete;

  const _HistoryTile({super.key, required this.session, required this.onDelete, this.canDelete = true});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _dragX = 0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX += details.delta.dx;
      if (_dragX > 0) _dragX = 0;
      if (_dragX < -80) _dragX = -80;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragX < -40) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
    setState(() {
      _dragX = -80;
      _isOpen = true;
    });
  }

  void _close() {
    _ctrl.animateTo(0.0, curve: Curves.easeOutCubic);
    setState(() {
      _dragX = 0;
      _isOpen = false;
    });
  }

  static const _months = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
  ];
  static const _days = [
    '', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];

  String _fmtDate(DateTime d) =>
      '${context.tr(_days[d.weekday])} ${d.day} ${context.tr(_months[d.month])}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '${h}${context.tr('s')} ${m}${context.tr('dk')}' : '${h}${context.tr('s')}';
  }

  Color _modeColor() {
    switch (widget.session.mode) {
      case FastingMode.twelvetwelve: return const Color(0xFF34C759);
      case FastingMode.sixteen8:    return const Color(0xFF007AFF);
      case FastingMode.eighteen6:   return const Color(0xFFFF9500);
      case FastingMode.custom:      return const Color(0xFFAF52DE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final elapsed = widget.session.elapsed;
    final modeColor = _modeColor();
    final isBroken = widget.session.wasCancelled;
    const redColor = Color(0xFFF85149);

    return Dismissible(
      key: Key(widget.session.id.toString()),
      direction: widget.canDelete ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('Kaydı Sil')),
            content: Text(context.tr('Bu oruç kaydını silmek istediğinize emin misiniz?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.tr('Vazgeç')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.tr('Sil'), style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => widget.onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2128) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isBroken
                ? redColor
                : widget.session.wasCompleted
                    ? const Color(0xFF34C759).withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0)),
            width: isBroken ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isBroken ? redColor : modeColor).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                context.tr(widget.session.mode.label),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isBroken ? redColor : modeColor,
                ),
              ),
            ),
          ),
          title: Text(
            _fmtDate(widget.session.startTime),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          subtitle: Text(
            isBroken
                ? context.tr('İptal edildi')
                : widget.session.wasCompleted
                    ? context.tr('Tamamlandı ✓')
                    : _fmtDate(widget.session.startTime.add(elapsed)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isBroken ? redColor.withValues(alpha: 0.8) : null,
                ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isBroken ? redColor : widget.session.wasCompleted ? const Color(0xFF34C759) : const Color(0xFFFF9500)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _fmtDur(elapsed),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isBroken ? redColor : widget.session.wasCompleted ? const Color(0xFF34C759) : const Color(0xFFFF9500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
