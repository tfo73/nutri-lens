import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wellness_provider.dart';
import '../widgets/supplement_management_sheet.dart';
import '../l10n/app_localizations.dart';

class StoolType {
  final int value;
  final IconData icon;
  final String name;
  final String desc;
  final Color color;

  const StoolType({
    required this.value,
    required this.icon,
    required this.name,
    required this.desc,
    required this.color,
  });
}

List<StoolType> wcStoolTypes(BuildContext context) => [
  StoolType(
    value: -3,
    icon: Icons.grain_rounded,
    name: 'Sert / Yavaş Hazım',
    desc: 'Katı ve parçalı kıvam. Sıvı alımı ve lif tüketimi artırılabilir.',
    color: const Color(0xFFE57373),
  ),
  StoolType(
    value: -2,
    icon: Icons.bubble_chart_rounded,
    name: 'Yoğun Kıvamlı',
    desc: 'Hafif topaklı form. Sıvı ve lif dengesi tavsiye edilir.',
    color: const Color(0xFFFF9800),
  ),
  StoolType(
    value: -1,
    icon: Icons.spa_rounded,
    name: 'Yumuşak Form',
    desc: 'Şekilli ve konforlu sindirim kıvamı.',
    color: const Color(0xFFFFB74D),
  ),
  StoolType(
    value: 0,
    icon: Icons.check_circle_rounded,
    name: 'Pürüzsüz & İdeal',
    desc: 'Mükemmel ve dengeli bağırsak sağlığı.',
    color: const Color(0xFF34C759),
  ),
  StoolType(
    value: 1,
    icon: Icons.opacity_rounded,
    name: 'Yumuşak Kıvam',
    desc: 'Hafif hızlı geçiş. Sindirim sistemi oldukça aktif.',
    color: const Color(0xFF26C6DA),
  ),
  StoolType(
    value: 2,
    icon: Icons.blur_on_rounded,
    name: 'Püre Kıvamı',
    desc: 'Hızlı sindirim süreci. Su tüketimine özen gösterin.',
    color: const Color(0xFF42A5F5),
  ),
  StoolType(
    value: 3,
    icon: Icons.waves_rounded,
    name: 'Sıvı Form',
    desc: 'Yoğun sıvı geçişi. Elektrolit ve sıvı dengenizi koruyun.',
    color: const Color(0xFF5C6BC0),
  ),
];

String _category(int index) {
  if (index <= 1) return 'YAVAŞ SİNDİRİM';
  if (index <= 4) return 'DENGELİ SİNDİRİM';
  return 'HIZLI SİNDİRİM';
}

Future<bool?> showWcTrackingSheet(BuildContext context, {DateTime? selectedDate}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _WcTrackingSheet(selectedDate: selectedDate),
    ),
  );
}

class _WcTrackingSheet extends StatefulWidget {
  final DateTime? selectedDate;
  const _WcTrackingSheet({this.selectedDate});

  @override
  State<_WcTrackingSheet> createState() => _WcTrackingSheetState();
}

class _WcTrackingSheetState extends State<_WcTrackingSheet> {
  late final PageController _ctrl;
  int _selectedIndex = 3; // Default to Ideal
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
    _ctrl = PageController(initialPage: _selectedIndex, viewportFraction: 0.65);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    final targetDate = widget.selectedDate ?? DateTime.now();
    if (!await SupplementManagementSheet.confirmPastDateAction(context, targetDate)) return;

    final logTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final stoolValue = _selectedIndex - 3;
    await context.read<WellnessProvider>().logWcForDate(targetDate, stoolType: stoolValue, time: logTime);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final items = wcStoolTypes(context);
    final selected = items[_selectedIndex];
    final cat = _category(_selectedIndex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : const Color(0xFFF7F8FC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Header Title & Time Picker Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Tuvalet Takibi'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sindirim ve konfor takibi',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF34C759)),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF34C759),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CategoryBadge(
                label: 'YAVAŞ SİNDİRİM',
                color: const Color(0xFFE57373),
                active: cat == 'YAVAŞ SİNDİRİM',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _CategoryBadge(
                label: 'DENGELİ SİNDİRİM',
                color: const Color(0xFF34C759),
                active: cat == 'DENGELİ SİNDİRİM',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _CategoryBadge(
                label: 'HIZLI SİNDİRİM',
                color: const Color(0xFF42A5F5),
                active: cat == 'HIZLI SİNDİRİM',
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Apple-style Carousel Cards
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _selectedIndex = i),
              itemBuilder: (_, i) {
                final type = items[i];
                final isSelected = i == _selectedIndex;

                return AnimatedScale(
                  scale: isSelected ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: () => _ctrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2235) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? type.color : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? type.color.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: isSelected ? 14 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: type.color.withValues(alpha: isDark ? 0.2 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              type.icon,
                              size: 38,
                              color: type.color,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            type.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? type.color : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Selected Description Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2235) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                selected.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final isSelected = i == _selectedIndex;
              final type = items[i];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? type.color : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Save Pill Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected.color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  context.tr('Kaydet'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final bool isDark;

  const _CategoryBadge({
    required this.label,
    required this.color,
    required this.active,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: active ? 0.2 : 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.bold : FontWeight.w500,
          color: active ? color : (isDark ? Colors.white38 : Colors.black38),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class WcTrackingScreen extends StatelessWidget {
  const WcTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(context.tr('Tuvalet Takibi')),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(child: _WcTrackingSheet()),
    );
  }
}
