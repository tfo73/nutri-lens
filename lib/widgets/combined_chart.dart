import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/food_entry.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/manual_entry_screen.dart';

// ─── Combined Chart Card ──────────────────────────────────────────────────────

class CombinedChartCard extends StatefulWidget {
  final NutritionProvider provider;
  final DateTime? referenceDate;
  const CombinedChartCard({super.key, required this.provider, this.referenceDate});

  @override
  State<CombinedChartCard> createState() => _CombinedChartCardState();
}

/// Mevcut görünüm modu
enum _ChartPeriod { week, month, year }

class _CombinedChartCardState extends State<CombinedChartCard>
    with TickerProviderStateMixin {
  _ChartPeriod _period = _ChartPeriod.week;
  int? _touchedIndex;
  Timer? _touchClearTimer;
  int _weekStartDay = 1;

  /// Drill-down navigasyon geçmişi (geri butonunda kullanılır).
  final List<({_ChartPeriod period, DateTime? drillDate})> _navStack = [];

  /// Mevcut görünümün çapa tarihi (null = bugün / bu hafta / bu ay).
  DateTime? _drillDownDate;

  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  // Fade animasyonu için
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const double _lm = 32.0;
  static const double _rm = 8.0;
  static const double _totalH = 220.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _fadeAnim = _fadeCtrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _animCtrl.value = 1.0;
      } else {
        _animCtrl.forward();
      }
    });
  }

  @override
  void didUpdateWidget(CombinedChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceDate != oldWidget.referenceDate) {
      if (_navStack.isEmpty) {
        setState(() {
          _drillDownDate = widget.referenceDate;
        });
      }
    }
  }

  @override
  void dispose() {
    _touchClearTimer?.cancel();
    _animCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Geçiş ─────────────────────────────────────────────────────────────────

  /// Temel geçiş — animasyon + state güncelleme.
  Future<void> _navigate(
    _ChartPeriod newPeriod,
    DateTime? newDate, {
    bool push = true,
  }) async {
    await _fadeCtrl.reverse();
    if (!mounted) return;
    if (push) {
      _navStack.add((period: _period, drillDate: _drillDownDate));
    }
    setState(() {
      _period = newPeriod;
      _drillDownDate = newDate;
    });
    _animCtrl.forward(from: 0);
    _fadeCtrl.forward();
  }

  /// Chip tıklaması — stack'i sıfırlar, drill yok.
  Future<void> _switchPeriod(_ChartPeriod newPeriod) async {
    _navStack.clear();
    await _navigate(newPeriod, null, push: false);
  }

  /// Geri butonu — önceki seviyeye döner.
  Future<void> _drillBack() async {
    if (_navStack.isEmpty) return;
    final prev = _navStack.removeLast();
    await _navigate(prev.period, prev.drillDate, push: false);
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// 7G: Drill-down tarihini (veya bugünü) içeren haftanın günlük verileri.
  Map<int, double> _getWeeklyData() {
    final anchor = _drillDownDate ?? widget.referenceDate ?? DateTime.now();
    final weekStart = _weekStartForDate(anchor);
    return {
      for (int i = 0; i < 7; i++)
        i: widget.provider
                .getLogForDate(
                    DateTime(weekStart.year, weekStart.month, weekStart.day + i))
                ?.totalNutrition
                .calories ??
            0.0,
    };
  }

  /// 1A: Drill-down tarihinin (veya bugünün) aylık günlük verileri.
  Map<int, double> _getMonthlyData() {
    final ref = _drillDownDate ?? widget.referenceDate ?? DateTime.now();
    final days = DateTime(ref.year, ref.month + 1, 0).day;
    return {
      for (int d = 0; d < days; d++)
        d: widget.provider
                .getLogForDate(DateTime(ref.year, ref.month, d + 1))
                ?.totalNutrition
                .calories ??
            0.0,
    };
  }

  /// 1Y: Son 12 ayın aylık ortalama verileri.
  Map<int, double> _getYearlyData() {
    final now = DateTime.now();
    final result = <int, double>{};
    for (int m = 0; m < 12; m++) {
      final month = DateTime(now.year, now.month - 11 + m, 1);
      double total = 0;
      int count = 0;
      for (int d = 1; d <= 31; d++) {
        try {
          final date = DateTime(month.year, month.month, d);
          if (date.month != month.month) break;
          final log = widget.provider.getLogForDate(date);
          if (log != null && log.entries.isNotEmpty) {
            total += log.totalNutrition.calories;
            count++;
          }
        } catch (_) {}
      }
      result[m] = count > 0 ? total / count : 0.0;
    }
    return result;
  }

  Map<int, double> _getData() {
    if (_period == _ChartPeriod.week) return _getWeeklyData();
    if (_period == _ChartPeriod.month) return _getMonthlyData();
    return _getYearlyData();
  }

  List<String> _getLabels(bool isTurkish) {
    if (_period == _ChartPeriod.week) {
      const trDays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz']; // Mon=0..Sun=6
      const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
      // weekday 1=Mon=index 0, ..., 7=Sun=index 6
      final startIdx = (_weekStartDay - 1) % 7;
      final days = isTurkish ? trDays : enDays;
      return List.generate(7, (i) => days[(startIdx + i) % 7]);
    }
    if (_period == _ChartPeriod.month) {
      final ref = _drillDownDate ?? DateTime.now();
      final days = DateTime(ref.year, ref.month + 1, 0).day;
      return List.generate(days, (i) => (i + 1).toString());
    }
    // Yıllık — son 12 ay
    const trM = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    const enM = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    return List.generate(12, (i) {
      final mo = DateTime(now.year, now.month - 11 + i, 1);
      return (isTurkish ? trM : enM)[mo.month - 1];
    });
  }

  int get _todayIndex {
    final now = DateTime.now();
    if (_period == _ChartPeriod.week) {
      final anchor = _drillDownDate ?? now;
      final weekStart = _weekStartForDate(anchor);
      for (int i = 0; i < 7; i++) {
        final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          return i;
        }
      }
      return -1;
    }
    if (_period == _ChartPeriod.month) {
      final ref = _drillDownDate ?? now;
      if (ref.year == now.year && ref.month == now.month) return now.day - 1;
      return -1;
    }
    return -1;
  }

  // ── Tıklama işlemleri ─────────────────────────────────────────────────────

  int _hitBar(Offset pos, int barCount, double totalW) {
    final areaW = totalW - _lm - _rm;
    final x = pos.dx - _lm;
    if (x < 0 || x > areaW || barCount == 0) return -1;
    return (x / (areaW / barCount)).floor().clamp(0, barCount - 1);
  }

  void _handleTap(int index) {
    // Single tap now only selects the bar and shows the value (handled in build via setState).
    // The previous navigation to detail sheet is removed to focus on data visualization.
  }

  void _openDayDetail(int index) {
    final anchor = _drillDownDate ?? DateTime.now();
    final weekStart = _weekStartForDate(anchor);
    final date = DateTime(weekStart.year, weekStart.month, weekStart.day + index);
    final log = widget.provider.getLogForDate(date);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) =>
            _DayDetailSheet(date: date, log: log, scrollController: ctrl),
      ),
    );
  }

  // ── Back button label ─────────────────────────────────────────────────────

  String _backLabel(bool isTurkish) {
    if (_navStack.isEmpty) return '';
    final parent = _navStack.last;
    if (parent.period == _ChartPeriod.year) {
      // 1A → geri = yıllık görünüm; tarih olarak mevcut drillDownDate yılını göster
      final ref = _drillDownDate ?? DateTime.now();
      return '← ${ref.year}';
    }
    if (parent.period == _ChartPeriod.month) {
      // 7G → geri = aylık görünüm; mevcut haftanın ait olduğu ayı göster
      final ref = _drillDownDate ?? DateTime.now();
      const trM = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
      const enM = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final name = (isTurkish ? trM : enM)[ref.month - 1];
      return '← $name ${ref.year}';
    }
    return '←';
  }

  // ── Period chip ───────────────────────────────────────────────────────────

  Widget _chip(String label, _ChartPeriod p, ColorScheme cs) {
    final sel = _period == p;
    return GestureDetector(
      onTap: () => _switchPeriod(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sel ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── Streak indices ─────────────────────────────────────────────────────���──

  Set<int> _computeStreakIndices(ProfileProvider pp) {
    final calorieGoal = pp.calorieGoal;
    if (calorieGoal <= 0) return {};
    final proteinGoal = pp.proteinGoal;
    final carbGoal = pp.carbGoal;
    final fatGoal = pp.fatGoal;
    final waterGoalMl = pp.waterGoalMl.toDouble();
    final result = <int>{};

    if (_period == _ChartPeriod.week) {
      final anchor = _drillDownDate ?? DateTime.now();
      final weekStart = _weekStartForDate(anchor);
      for (int i = 0; i < 7; i++) {
        final date = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
        if (widget.provider.isGoalMet(date,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbGoal: carbGoal,
            fatGoal: fatGoal,
            waterGoalMl: waterGoalMl)) {
          result.add(i);
        }
      }
    } else if (_period == _ChartPeriod.month) {
      final ref = _drillDownDate ?? DateTime.now();
      final days = DateTime(ref.year, ref.month + 1, 0).day;
      for (int d = 0; d < days; d++) {
        final date = DateTime(ref.year, ref.month, d + 1);
        if (widget.provider.isGoalMet(date,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbGoal: carbGoal,
            fatGoal: fatGoal,
            waterGoalMl: waterGoalMl)) {
          result.add(d);
        }
      }
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  DateTime _weekStartForDate(DateTime date) {
    int diff = (date.weekday - _weekStartDay + 7) % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: diff));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isTurkish = l10n.isTurkish;
    final profileProvider = context.watch<ProfileProvider>();
    _weekStartDay = profileProvider.weekStartDay;
    final calorieGoal = profileProvider.calorieGoal;
    final data = _getData();
    final labels = _getLabels(isTurkish);
    final todayIdx = _todayIndex;
    final streakIndices = _computeStreakIndices(profileProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_navStack.isNotEmpty)
                  GestureDetector(
                    onTap: _drillBack,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _backLabel(isTurkish),
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    isTurkish ? 'Kalori Grafiği' : 'Calorie Chart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                Row(
                  children: [
                    _chip('7G', _ChartPeriod.week, cs),
                    const SizedBox(width: 4),
                    _chip('1A', _ChartPeriod.month, cs),
                    const SizedBox(width: 4),
                    _chip('1Y', _ChartPeriod.year, cs),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chart (fade animasyonuyla)
            FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final totalW = constraints.maxWidth;
                    final provider = context.watch<NutritionProvider>();
                    final burnedToday = provider.getOrCreateLogForDate(DateTime.now()).totalBurnedFromExercises;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) {
                        _touchClearTimer?.cancel();
                        final idx = _hitBar(details.localPosition, data.length, totalW);
                        setState(() => _touchedIndex = idx);
                      },
                      onPanUpdate: (details) {
                        final idx = _hitBar(details.localPosition, data.length, totalW);
                        if (idx != _touchedIndex) {
                          setState(() => _touchedIndex = idx);
                        }
                      },
                      onPanEnd: (_) => setState(() => _touchedIndex = null),
                      onPanCancel: () => setState(() => _touchedIndex = null),
                      onTapDown: (details) {
                        _touchClearTimer?.cancel();
                        final idx = _hitBar(details.localPosition, data.length, totalW);
                        setState(() => _touchedIndex = idx);
                      },
                      onTapUp: (_) => setState(() => _touchedIndex = null),
                      onTapCancel: () => setState(() => _touchedIndex = null),
                      child: SizedBox(
                        width: totalW,
                        height: _totalH,
                        child: CustomPaint(
                          size: Size(totalW, _totalH),
                          painter: _CombinedChartPainter(
                            data: data,
                            calorieGoal: calorieGoal,
                            burnedCalories: burnedToday,
                            animValue: _anim.value,
                            todayIndex: todayIdx,
                            touchedIndex: _touchedIndex,
                            streakIndices: streakIndices.toList(),
                            period: _period,
                            primaryColor: cs.primary,
                            gridColor: cs.outline,
                            labelColor: cs.onSurfaceVariant,
                            isDark: Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painter ───────────────────────────────────────────────────────────

class _CombinedChartPainter extends CustomPainter {
  final Map<int, double> data;
  final double calorieGoal;
  final double burnedCalories;
  final double animValue;
  final int todayIndex;
  final int? touchedIndex;
  final List<int> streakIndices;
  final _ChartPeriod period;
  final Color primaryColor;
  final Color gridColor;
  final Color labelColor;
  final bool isDark;

  static const double _lm = 32.0;
  static const double _rm = 8.0;
  static const double _tm = 22.0;
  static const double _bm = 28.0;

  _CombinedChartPainter({
    required this.data,
    required this.calorieGoal,
    required this.burnedCalories,
    required this.animValue,
    required this.todayIndex,
    this.touchedIndex,
    required this.streakIndices,
    required this.period,
    required this.primaryColor,
    required this.gridColor,
    required this.labelColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _lm - _rm;
    final chartH = size.height - _tm - _bm;
    final chartBottom = _tm + chartH;

    final baseGoal = calorieGoal > 0 ? calorieGoal : 2000.0;
    final totalGoal = baseGoal + burnedCalories;
    final maxData = data.values.fold(0.0, math.max);
    
    // Compute next 25% milestone above maxData
    final pct25 = totalGoal * 0.25;
    final intervalsNeeded = (pct25 > 0 && maxData > 0)
        ? math.max(4, (maxData / pct25).ceil())
        : 4;
    final topValue = pct25 * intervalsNeeded;
    final maxY = topValue * 1.08;

    _drawYAxis(canvas, chartW, chartH, chartBottom, totalGoal, maxY);

    final barCount = data.length;
    if (barCount == 0) return;

    final slotW = chartW / barCount;
    final barW = math.min(
      slotW * 0.80,
      period == _ChartPeriod.month
          ? 13.0
          : (period == _ChartPeriod.year ? 24.0 : 40.0),
    );
    final stubH = chartH * 0.03;

    for (int i = 0; i < barCount; i++) {
      final cal = data[i] ?? 0.0;
      final barH = cal > 0
          ? ((cal / maxY) * chartH * animValue).clamp(stubH, chartH)
          : stubH;
      final bx = _lm + i * slotW + (slotW - barW) / 2;
      final barRect = Rect.fromLTWH(bx, chartBottom - barH, barW, barH);
      _drawBar(canvas, barRect, i == todayIndex, cal <= 0,
          i == touchedIndex, streakIndices.contains(i));
    }

    if (touchedIndex != null && touchedIndex! >= 0 && touchedIndex! < barCount) {
      final i = touchedIndex!;
      final cal = data[i] ?? 0.0;
      final barH = ((cal / maxY) * chartH * animValue).clamp(stubH, chartH);
      _drawValueLabel(canvas, _lm + (i + 0.5) * slotW, chartBottom - barH, cal, 1.0);
    }
  }

  int _roundedLabel(double goal, double ratio) {
    return ((goal * ratio / 10).round() * 10);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy);
    final metrics = path.computeMetrics().first;
    double dist = 0.0;
    bool drawing = true;
    final dashedPath = Path();
    while (dist < metrics.length) {
      final segLen = drawing ? dashLen : gapLen;
      final end = (dist + segLen).clamp(0.0, metrics.length);
      if (drawing) {
        dashedPath.addPath(
          metrics.extractPath(dist, end),
          Offset.zero,
        );
      }
      dist = end;
      drawing = !drawing;
    }
    canvas.drawPath(dashedPath, paint);
  }

  void _drawYAxis(Canvas canvas, double chartW, double chartH,
      double chartBottom, double goal, double maxY) {
    final tp = TextPainter(textDirection: TextDirection.ltr);

    _drawDashedLine(
      canvas,
      Offset(_lm, chartBottom),
      Offset(_lm + chartW, chartBottom),
      Paint()
        ..color = gridColor.withValues(alpha: 0.15)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    
    final pct25 = goal * 0.25;
    final maxIntervals = pct25 > 0
        ? math.max(4, ((maxY / pct25) - 1).floor())
        : 4;
    for (int i = 1; i <= maxIntervals; i++) {
      final ratio = i / 4.0;
      final val = goal * ratio;

      if (val > maxY * 0.99) continue;

      final y = chartBottom - (val / maxY).clamp(0.0, 1.0) * chartH;
      final isGoal = i == 4;
      final isHalf = i == 2;
      final isExtra = i > 4;

    final double opacity;
      final Color lineColor;

      if (isGoal) {
        opacity = 0.45;
        lineColor = primaryColor;
      } else if (isHalf) {
        opacity = 0.30;
        lineColor = gridColor;
      } else if (isExtra) {
        opacity = 0.20;
        lineColor = Colors.orangeAccent;
      } else {
        opacity = 0.25;
        lineColor = gridColor;
      }

      _drawDashedLine(
        canvas,
        Offset(_lm, y),
        Offset(_lm + chartW, y),
        Paint()
          ..color = lineColor.withValues(alpha: opacity)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      final labelVal = _roundedLabel(goal, ratio);
      tp.text = TextSpan(
        text: labelVal.toString(),
        style: TextStyle(
          color: isGoal
              ? primaryColor.withValues(alpha: 0.90)
              : (isExtra ? Colors.orangeAccent.withValues(alpha: 0.6) : labelColor.withValues(alpha: 0.50)),
          fontSize: 9.5,
          fontWeight: isGoal ? FontWeight.w600 : FontWeight.normal,
        ),
      );
      tp.layout(maxWidth: _lm - 4);
      tp.paint(canvas, Offset(_lm - tp.width - 4, y - tp.height / 2));
    }
  }

  void _drawBar(Canvas canvas, Rect r, bool isToday, bool isStub,
      bool isPressed, bool isStreak) {
    const topR = Radius.circular(6);
    final rrect = RRect.fromRectAndCorners(r, topLeft: topR, topRight: topR);

    if (isStub) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final barColor = isStreak ? const Color(0xFFFBBF24) : primaryColor;

    final alpha = isToday ? 1.0 : 0.82;
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = barColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawValueLabel(
      Canvas canvas, double cx, double topY, double cal, double fade) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: '${cal.toStringAsFixed(0)} kcal',
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
    tp.layout();
    
    final rectW = tp.width + 12;
    final rectH = tp.height + 6;
    final rect = Rect.fromCenter(center: Offset(cx, topY - rectH / 2 - 8), width: rectW, height: rectH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    
    final paint = Paint()
      ..color = (isDark ? const Color(0xFF2D333B) : Colors.white)
      ..style = PaintingStyle.fill;
    
    // Simple shadow effect
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: 0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    
    canvas.drawRRect(rrect, paint);
    
    // Border for light theme
    if (!isDark) {
      canvas.drawRRect(rrect, Paint()..color = gridColor.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    tp.paint(canvas, Offset(cx - tp.width / 2, topY - rectH - 8 + 3));
  }

  @override
  bool shouldRepaint(covariant _CombinedChartPainter old) =>
      old.animValue != animValue ||
      old.touchedIndex != touchedIndex ||
      old.streakIndices != streakIndices ||
      old.data != data ||
      old.calorieGoal != calorieGoal ||
      old.burnedCalories != burnedCalories ||
      old.todayIndex != todayIndex ||
      old.primaryColor != primaryColor ||
      old.isDark != isDark ||
      old.period != period;
}

// ─── Day Detail Bottom Sheet ──────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final DailyLog? log;
  final ScrollController scrollController;

  const _DayDetailSheet({
    required this.date,
    required this.log,
    required this.scrollController,
  });

  static const _monthNames = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const _mealLabels = {
    'kahvaltı': 'Kahvaltı',
    'öğle': 'Öğle Yemeği',
    'akşam': 'Akşam Yemeği',
    'ara öğün': 'Ara Öğün',
  };

  Future<List<String>> _loadCompletedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${date.year}_${date.month}_${date.day}';
    return prefs.getStringList('completed_titles_$key') ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateStr = '${date.day} ${_monthNames[date.month]} ${date.year}';

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              dateStr,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          Expanded(
            child: (log == null || log!.entries.isEmpty)
                ? Center(
                    child: Text(
                      'Bu gün için kayıtlı veri yok',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16),
                    ),
                  )
                : _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final mealGroups = log!.entriesByMeal;
    final total = log!.totalNutrition;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF22354D),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Günlük Toplam',
                style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                '${total.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._mealLabels.entries.map((meal) {
          final entries = mealGroups[meal.key] ?? [];
          if (entries.isEmpty) return const SizedBox.shrink();
          return _mealSection(context, meal.value, entries);
        }),
        FutureBuilder<List<String>>(
          future: _loadCompletedSuggestions(),
          builder: (ctx, snapshot) {
            final suggestions = snapshot.data ?? [];
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return _suggestionsSection(context, suggestions);
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _mealSection(BuildContext context, String label, List<FoodEntry> entries) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    // Pair entries into rows of 2
    final rows = <List<FoodEntry>>[];
    for (int i = 0; i < entries.length; i += 2) {
      rows.add(entries.sublist(i, math.min(i + 2, entries.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cs.onSurface),
          ),
        ),
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(child: _FlipFoodCard(entry: row[0])),
                  const SizedBox(width: 16),
                  row.length > 1
                      ? Expanded(child: _FlipFoodCard(entry: row[1]))
                      : const Expanded(child: SizedBox.shrink()),
                ],
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _suggestionsSection(BuildContext context, List<String> suggestions) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Tamamlanan Öneriler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cs.onSurface),
          ),
        ),
        ...suggestions.map(
          (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF7EE787), size: 22),
            title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            dense: true,
          ),
        ),
      ],
    );
  }
}

// ─── Flip Food Card ───────────────────────────────────────────────────────────

class _FlipFoodCard extends StatefulWidget {
  final FoodEntry entry;
  const _FlipFoodCard({required this.entry});

  @override
  State<_FlipFoodCard> createState() => _FlipFoodCardState();
}

class _FlipFoodCardState extends State<_FlipFoodCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flipped) { _ctrl.reverse(); } else { _ctrl.forward(); }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaled = widget.entry.nutritionData.scaleBy(widget.entry.portionSize / 100);
    final hasImage = widget.entry.imagePath != null &&
        widget.entry.imagePath!.isNotEmpty &&
        File(widget.entry.imagePath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final angle = _anim.value * math.pi;
              final showBack = angle > math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: Container(
                              color: const Color(0xFF1C222D),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  _nutriRow('Protein', '${scaled.protein.toStringAsFixed(1)}g', const Color(0xFF7EE787)),
                                  _nutriRow('Karb', '${scaled.carbohydrates.toStringAsFixed(1)}g', const Color(0xFF58A6FF)),
                                  _nutriRow('Yağ', '${scaled.fat.toStringAsFixed(1)}g', const Color(0xFFFFA726)),
                                  _nutriRow('Lif', '${scaled.fiber.toStringAsFixed(1)}g', const Color(0xFFA855F7)),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () => _showMoreNutrients(context),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          'Daha Fazla',
                                          style: TextStyle(color: Color(0xFF58A6FF), fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ManualEntryScreen(
                                              existingEntry: widget.entry,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF58A6FF)),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : hasImage
                            ? Image.file(File(widget.entry.imagePath!), fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF1C222D),
                                child: Center(
                                  child: Icon(Icons.restaurant_rounded, size: 48, color: const Color(0xFF58A6FF).withValues(alpha: 0.3)),
                                ),
                              ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.entry.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${scaled.calories.toStringAsFixed(0)} kcal',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24)),
        ),
      ],
    );
  }

  void _showMoreNutrients(BuildContext context) {
    final scaled65 = widget.entry.nutrition65per100g?.scaleBy(widget.entry.portionSize / 100);
    final scaled = widget.entry.nutritionData.scaleBy(widget.entry.portionSize / 100);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        
        Widget section(String title, Color color) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color, letterSpacing: 1.1)),
        );

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.entry.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (scaled.sugar > 0) _detailRow('Şeker', '${scaled.sugar.toStringAsFixed(1)}g', const Color(0xFFFFA726)),
                    if (scaled.sodium != null && scaled.sodium! > 0) _detailRow('Sodyum', '${scaled.sodium!.toStringAsFixed(1)}mg', const Color(0xFF58A6FF)),
                    
                    if (scaled65 != null) ...[
                      // Dynamic listing of all nutrients from toMap()
                      ...(() {
                        final entries = scaled65.toMap().entries.where((e) => 
                          e.value > 0.001 && 
                          !['Enerji', 'Protein', 'Karbonhidrat', 'Yağ', 'Lif', 'Şeker', 'Sodyum'].contains(e.key)
                        ).toList();

                        final minerals = ['Kalsiyum', 'Demir', 'Magnezyum', 'Fosfor', 'Potasyum', 'Çinko', 'Bakır', 'Manganez', 'Selenyum', 'İyot', 'Krom', 'Molibden', 'Florür'];
                        final vitamins = entries.where((e) => e.key.contains('Vitamini') || e.key == 'Folat' || e.key == 'Biotin' || e.key == 'Kolin' || e.key == 'Betain').map((e) => e.key).toList();
                        
                        final mineralEntries = entries.where((e) => minerals.contains(e.key)).toList();
                        final vitaminEntries = entries.where((e) => vitamins.contains(e.key)).toList();
                        final otherEntries = entries.where((e) => !minerals.contains(e.key) && !vitamins.contains(e.key)).toList();

                        return [
                          if (mineralEntries.isNotEmpty) ...[
                            section('MİNERALLER', const Color(0xFF58A6FF)),
                            ...mineralEntries.map((e) => _detailRow(e.key, e.value.toStringAsFixed(2), const Color(0xFF58A6FF))),
                          ],
                          if (vitaminEntries.isNotEmpty) ...[
                            section('VİTAMİNLER', const Color(0xFFFFA726)),
                            ...vitaminEntries.map((e) => _detailRow(e.key, e.value.toStringAsFixed(2), const Color(0xFFFFA726))),
                          ],
                          if (otherEntries.isNotEmpty) ...[
                            section('DİĞER BİLEŞENLER', const Color(0xFF3FB950)),
                            ...otherEntries.map((e) => _detailRow(e.key, e.value.toStringAsFixed(2), const Color(0xFF3FB950))),
                          ],
                        ];
                      })(),
                    ],
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _detailRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Widget _nutriRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}


// ─── Simple Food Card ─────────────────────────────────────────────────────────

class _SimpleFoodCard extends StatelessWidget {
  final FoodEntry entry;
  const _SimpleFoodCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
    final hasImage = entry.imagePath != null &&
        entry.imagePath!.isNotEmpty &&
        File(entry.imagePath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1,
            child: hasImage
                ? Image.file(File(entry.imagePath!), fit: BoxFit.cover)
                : Container(
                    color: cs.primary.withValues(alpha: 0.10),
                    child: Icon(Icons.restaurant,
                        size: 32, color: cs.primary.withValues(alpha: 0.4)),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          entry.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${scaled.calories.toStringAsFixed(0)} kcal',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFF6B35),
          ),
        ),
      ],
    );
  }
}
