import 'package:flutter/material.dart';
import '../providers/wellness_provider.dart';
import 'package:provider/provider.dart';

// Bristol Stool Chart types mapped to -3..3 scale
class StoolType {
  final int value;     // -3 to 3
  final String emoji;  // shown until real asset is available
  final String? assetPath; // future image asset path (null = use emoji)
  final String name;
  final String desc;
  final Color color;

  const StoolType({
    required this.value,
    required this.emoji,
    this.assetPath,
    required this.name,
    required this.desc,
    required this.color,
  });
}

const wcStoolTypes = [
  StoolType(value: -3, emoji: '🪨', assetPath: 'assets/ibs/type1.webp', name: 'Sert Topaklar',    desc: 'Ayrı sert topaklar, geçirmesi zor',  color: Color(0xFFF85149)),
  StoolType(value: -2, emoji: '🥔', assetPath: 'assets/ibs/type2.webp', name: 'Topak Sosis',      desc: 'Sosis şeklinde, yüzeyi parçalı',     color: Color(0xFFFF8C42)),
  StoolType(value: -1, emoji: '🌭', assetPath: 'assets/ibs/type3.webp', name: 'Çatlak Yüzey',     desc: 'Sosis şekli, yüzeyinde çatlaklar',   color: Color(0xFFFFCC00)),
  StoolType(value:  0, emoji: '✅', assetPath: 'assets/ibs/type4.webp', name: 'Normal',            desc: 'Düzgün, yumuşak, kolay geçer',       color: Color(0xFF3FB950)),
  StoolType(value:  1, emoji: '💩', assetPath: 'assets/ibs/type5.webp', name: 'Yumuşak Topaklar', desc: 'Net kenarlı yumuşak parçalar',        color: Color(0xFFFFCC00)),
  StoolType(value:  2, emoji: '💧', assetPath: 'assets/ibs/type6.webp', name: 'Parçalı Sıvı',     desc: 'Akıcı, yumuşak parçalar',            color: Color(0xFFFF8C42)),
  StoolType(value:  3, emoji: '🌊', assetPath: 'assets/ibs/type7.webp', name: 'Sıvı',             desc: 'Tamamen sıvı, katı yok',             color: Color(0xFFF85149)),
];

// Category for each type index
String _category(int index) {
  if (index <= 1) return 'IBS-C';
  if (index <= 3) return 'NORMAL';
  return 'IBS-D';
}

// Open WC tracking as a modal bottom sheet
void showWcTrackingSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _WcTrackingSheet(),
    ),
  );
}

class _WcTrackingSheet extends StatefulWidget {
  @override
  State<_WcTrackingSheet> createState() => _WcTrackingSheetState();
}

class _WcTrackingSheetState extends State<_WcTrackingSheet> {
  late final PageController _ctrl;
  int _selectedIndex = 3; // start at Normal
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
    _ctrl = PageController(initialPage: _selectedIndex, viewportFraction: 0.60);
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
    final now = DateTime.now();
    final logTime = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    await context.read<WellnessProvider>().logWc(stoolType: wcStoolTypes[_selectedIndex].value, time: logTime);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final selected = wcStoolTypes[_selectedIndex];
    final cat = _category(_selectedIndex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Title + time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Tuvalet Takibi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const Spacer(),
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: cs.primary),
                        const SizedBox(width: 5),
                        Text(
                          _selectedTime.format(context),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // IBS-C / NORMAL / IBS-D badges — active one is larger
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CategoryBadge(label: 'IBS-C', color: const Color(0xFFF85149), active: cat == 'IBS-C'),
              const SizedBox(width: 16),
              _CategoryBadge(label: 'NORMAL', color: const Color(0xFF3FB950), active: cat == 'NORMAL'),
              const SizedBox(width: 16),
              _CategoryBadge(label: 'IBS-D', color: const Color(0xFFF85149), active: cat == 'IBS-D'),
            ],
          ),

          const SizedBox(height: 16),

          // Carousel
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: wcStoolTypes.length,
              onPageChanged: (i) => setState(() => _selectedIndex = i),
              itemBuilder: (_, i) {
                final type = wcStoolTypes[i];
                final isSelected = i == _selectedIndex;
                return AnimatedScale(
                  scale: isSelected ? 1.0 : 0.75,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTap: () => _ctrl.animateToPage(i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? type.color.withValues(alpha: isDark ? 0.18 : 0.12)
                            : (isDark ? const Color(0xFF161B22) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? type.color : type.color.withValues(alpha: 0.25),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: type.color.withValues(alpha: 0.20), blurRadius: 10)]
                            : [],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: type.assetPath != null
                            ? Image.asset(type.assetPath!, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                            : FittedBox(child: Text(type.emoji)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Selected type info (Fixed height to prevent jumping)
          SizedBox(
            height: 100, // Increased height to be safe
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(_selectedIndex),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(selected.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: selected.color)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(selected.desc,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
                  ),
                ],
              ),
            ),
          ),

          // Dot indicators
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(wcStoolTypes.length, (i) {
              final isSelected = i == _selectedIndex;
              final type = wcStoolTypes[i];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? type.color : cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: selected.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
  const _CategoryBadge({required this.label, required this.color, required this.active});

  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: active ? 15 : 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? color : color.withValues(alpha: 0.45),
          letterSpacing: active ? 0.5 : 0.2,
        ),
        child: Text(label),
      );
}

// Legacy full-screen version (kept for backward compat)
class WcTrackingScreen extends StatelessWidget {
  const WcTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tuvalet Takibi'), centerTitle: true),
        body: Center(child: _WcTrackingSheet()),
      );
}
