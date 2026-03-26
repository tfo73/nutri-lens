import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/daily_log.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';

class ProfileDetailScreen extends StatefulWidget {
  final UserProfile profile;

  const ProfileDetailScreen({super.key, required this.profile});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  List<DailyLog> _recentLogs = [];
  bool _loading = true;
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await NutritionProvider.loadLogsForProfile(
      _profile.id,
      days: 7,
    );
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null && mounted) {
      final updated = _profile.copyWith(imagePath: picked.path);
      await context.read<ProfileProvider>().updateProfile(updated);
      setState(() => _profile = updated);
    }
  }

  Future<void> _removeImage() async {
    final updated = _profile.copyWith(clearImagePath: true);
    await context.read<ProfileProvider>().updateProfile(updated);
    setState(() => _profile = updated);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kameradan Çek'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_profile.imagePath != null)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Fotoğrafı Kaldır',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive =
        context.watch<ProfileProvider>().activeProfileId == _profile.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Profili Düzenle',
            onPressed: () => _openEditSheet(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAvatarHeader(context, _profile, isActive),
                  const SizedBox(height: 16),
                  _buildInfoCard(context, _profile),
                  const SizedBox(height: 12),
                  _buildBmiCard(context, _profile),
                  const SizedBox(height: 12),
                  _buildMetabolismCard(context, _profile),
                  const SizedBox(height: 12),
                  _buildMacroGoalsCard(context, _profile),
                  const SizedBox(height: 12),
                  if (_recentLogs.isNotEmpty) ...[
                    _buildWeeklyChartCard(context),
                    const SizedBox(height: 12),
                    _buildWeeklySummaryCard(context),
                    const SizedBox(height: 12),
                  ],
                  _buildStatsCard(context),
                  const SizedBox(height: 24),
                  if (!isActive)
                    FilledButton.icon(
                      onPressed: () async {
                        await context
                            .read<ProfileProvider>()
                            .setActiveProfile(_profile.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${_profile.name} aktif profil yapıldı'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Bu Profili Aktif Et'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Aktif Profil'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openEditSheet(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Profili Düzenle'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarHeader(
      BuildContext context, UserProfile profile, bool isActive) {
    final initial =
        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';
    final color = _avatarColor(profile.name);
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageOptions,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: color,
                    backgroundImage: profile.imagePath != null
                        ? FileImage(File(profile.imagePath!))
                        : null,
                    onBackgroundImageError: profile.imagePath != null
                        ? (_, __) {}
                        : null,
                    child: profile.imagePath == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isActive)
            Chip(
              label: const Text('Aktif Profil'),
              avatar: const Icon(Icons.check_circle, size: 16),
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  void _showBmiDetail(
      BuildContext context, double bmi, Color bmiColor, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('BMI Detayı',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: Text(bmi.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: bmiColor)),
              ),
              Center(
                  child: Text(category,
                      style: TextStyle(
                          color: bmiColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600))),
              const SizedBox(height: 24),
              _buildBmiScale(context, bmi),
              const SizedBox(height: 24),
              _buildCategoryTable(context, bmi),
              const SizedBox(height: 20),
              _buildCategoryDetail(context, bmi),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Not: BMI kas kütlesini dikkate almaz, tek başına yeterli bir ölçüt değildir.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBmiScale(BuildContext context, double bmi) {
    // Visual BMI scale bar
    const segments = [
      (0.0, 18.5, Colors.blue, 'Zayıf'),
      (18.5, 25.0, Colors.green, 'Normal'),
      (25.0, 30.0, Colors.amber, 'Fazla Kilolu'),
      (30.0, 40.0, Colors.red, 'Obez'),
    ];
    const totalRange = 40.0;
    final clampedBmi = bmi.clamp(0.0, 40.0);
    final indicatorPos = clampedBmi / totalRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BMI Skalası',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Row(
                  children: segments.map((seg) {
                    final segWidth =
                        (seg.$2 - seg.$1) / totalRange * width;
                    return Container(
                      width: segWidth,
                      height: 16,
                      color: seg.$3.withOpacity(0.7),
                    );
                  }).toList(),
                ),
                Positioned(
                  left: (indicatorPos * width - 8).clamp(0.0, width - 16),
                  top: -4,
                  child: Icon(Icons.arrow_drop_down,
                      color: Colors.black87, size: 24),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0', style: TextStyle(fontSize: 10)),
            Text('18.5', style: TextStyle(fontSize: 10)),
            Text('25', style: TextStyle(fontSize: 10)),
            Text('30', style: TextStyle(fontSize: 10)),
            Text('40', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryTable(BuildContext context, double bmi) {
    final rows = [
      (Colors.blue, '< 18.5', 'Zayıf'),
      (Colors.green, '18.5 – 24.9', 'Normal'),
      (Colors.amber, '25.0 – 29.9', 'Fazla Kilolu'),
      (Colors.red, '≥ 30.0', 'Obez'),
    ];

    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FixedColumnWidth(16),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('BMI',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Kategori',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ...rows.map((r) {
          final isCurrentCategory = _bmiCategory(bmi) == r.$3;
          return TableRow(
            decoration: isCurrentCategory
                ? BoxDecoration(color: r.$1.withOpacity(0.1))
                : null,
            children: [
              Container(
                  width: 16,
                  color: r.$1,
                  child: const SizedBox(height: 36)),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(r.$2,
                    style: TextStyle(
                        fontWeight: isCurrentCategory
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(r.$3,
                    style: TextStyle(
                        fontWeight: isCurrentCategory
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentCategory ? r.$1 : null)),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Zayıf';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  Widget _buildCategoryDetail(BuildContext context, double bmi) {
    String detail;
    if (bmi < 18.5) {
      detail =
          'Vücut ağırlığınız sağlıklı aralığın altında. Kilo almanıza yardımcı olmak için dengeli ve kalori yoğun besinler tüketin. Bir beslenme uzmanına danışmanız önerilir.';
    } else if (bmi < 25) {
      detail =
          'Tebrikler! BMI değeriniz sağlıklı aralıkta. Mevcut beslenme ve egzersiz alışkanlıklarınızı sürdürün.';
    } else if (bmi < 30) {
      detail =
          'BMI değeriniz fazla kilolu aralığında. Düzenli egzersiz ve dengeli beslenme ile sağlıklı kiloya ulaşabilirsiniz. Günlük adım sayınızı artırın.';
    } else {
      detail =
          'BMI değeriniz obezite aralığında. Sağlık riskleri açısından bir doktora başvurmanız önerilir. Düzenli egzersiz ve kalori kısıtlı beslenme planı hazırlanması faydalı olacaktır.';
    }
    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(detail,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildBmiCard(BuildContext context, UserProfile profile) {
    final bmi = profile.bmi;
    if (bmi <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    Color bmiColor;
    String bmiLabel;
    double bmiProgress;

    if (bmi < 18.5) {
      bmiColor = Colors.blue;
      bmiLabel = 'Zayıf — Kilo almanız önerilir';
      bmiProgress = bmi / 18.5 * 0.25;
    } else if (bmi < 25) {
      bmiColor = Colors.green;
      bmiLabel = 'Normal — Sağlıklı kilodayı!';
      bmiProgress = 0.25 + (bmi - 18.5) / 6.5 * 0.25;
    } else if (bmi < 30) {
      bmiColor = Colors.amber;
      bmiLabel = 'Fazla Kilolu — Dikkat edilmeli';
      bmiProgress = 0.5 + (bmi - 25) / 5 * 0.25;
    } else {
      bmiColor = Colors.red;
      bmiLabel = 'Obez — Doktor tavsiyesi önerilir';
      bmiProgress = (0.75 + (bmi - 30) / 10 * 0.25).clamp(0.75, 1.0);
    }

    return GestureDetector(
      onTap: () => _showBmiDetail(context, bmi, bmiColor, _bmiCategory(bmi)),
      child: Card(
      color: bmiColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: bmiColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined, color: bmiColor),
                const SizedBox(width: 8),
                Text(
                  'BMI Değerlendirmesi',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  bmi.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: bmiColor,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmiLabel,
                        style: TextStyle(
                          color: bmiColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: bmiProgress),
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 1400),
                        curve: Curves.easeOut,
                        builder: (context, animProgress, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: animProgress,
                            minHeight: 8,
                            color: bmiColor,
                            backgroundColor: bmiColor.withOpacity(0.15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('18.5',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant)),
                          Text('25',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant)),
                          Text('30',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant)),
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
    ),
    );
  }

  Widget _buildInfoCard(BuildContext context, UserProfile profile) {
    return Card(
      elevation: 2,
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil Bilgileri',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(context, Icons.cake_outlined, 'Yaş', '${profile.age} yaş'),
            _infoRow(context, Icons.height, 'Boy', '${profile.height.toStringAsFixed(0)} cm'),
            _infoRow(context, Icons.monitor_weight_outlined, 'Kilo',
                '${profile.weight.toStringAsFixed(1)} kg'),
            _infoRow(context, Icons.flag_outlined, 'Hedef', profile.goalLabel),
            _infoRow(
                context, Icons.directions_run, 'Aktivite', profile.activityLabel),
            _infoRow(
                context,
                profile.gender == Gender.male ? Icons.male : Icons.female,
                'Cinsiyet',
                profile.gender == Gender.male ? 'Erkek' : 'Kadın'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetabolismCard(BuildContext context, UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metabolizma',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricTileWithTooltip(
                    context,
                    'BMR',
                    '${profile.bmr.toStringAsFixed(0)}',
                    'kcal/gün',
                    'Bazal Metabolizma Hızı — Hiç hareket etmeseydiniz vücudunuzun hayatta kalmak için yakacağı minimum kalori miktarıdır.',
                    Icons.local_fire_department_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTileWithTooltip(
                    context,
                    'TDEE',
                    '${profile.tdee.toStringAsFixed(0)}',
                    'kcal/gün',
                    'Günlük Toplam Enerji Harcaması — Aktivite seviyeniz dahil günde yaktığınız toplam kalori miktarıdır. Kalori hedefiniz bu değere göre hesaplanır.',
                    Icons.bolt_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGoalsCard(BuildContext context, UserProfile profile) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Günlük Makro Hedefleri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _macroChip(context, 'Kalori',
                    '${profile.calorieGoal.toStringAsFixed(0)} kcal'),
                _macroChip(context, 'Protein',
                    '${profile.proteinGoal.toStringAsFixed(0)}g'),
                _macroChip(context, 'Karb.',
                    '${profile.carbGoal.toStringAsFixed(0)}g'),
                _macroChip(
                    context, 'Yağ', '${profile.fatGoal.toStringAsFixed(0)}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChartCard(BuildContext context) {
    final spots = _buildChartSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son 7 Gün Kalori',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barGroups: spots,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _recentLogs.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _recentLogs[idx].date;
                          const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                          return Text(
                            days[date.weekday - 1],
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildChartSpots() {
    final color = Theme.of(context).colorScheme.primary;
    return _recentLogs.asMap().entries.map((entry) {
      final calories = entry.value.totalNutrition.calories;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: calories,
            color: color,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildWeeklySummaryCard(BuildContext context) {
    if (_recentLogs.isEmpty) return const SizedBox.shrink();

    final totalCalories =
        _recentLogs.fold(0.0, (s, l) => s + l.totalNutrition.calories);
    final avgCalories = totalCalories / _recentLogs.length;

    final foodCounts = <String, int>{};
    for (final log in _recentLogs) {
      for (final entry in log.entries) {
        foodCounts[entry.name] = (foodCounts[entry.name] ?? 0) + 1;
      }
    }
    String? topFood;
    if (foodCounts.isNotEmpty) {
      topFood = foodCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu Haftanın Özeti',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(
              context,
              Icons.local_fire_department_outlined,
              'Ortalama Kalori',
              '${avgCalories.toStringAsFixed(0)} kcal/gün',
            ),
            if (topFood != null)
              _infoRow(
                context,
                Icons.restaurant_outlined,
                'En Çok Yenen',
                topFood,
              ),
            _infoRow(
              context,
              Icons.calendar_today_outlined,
              'Kayıt Günü',
              '${_recentLogs.length} gün',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final totalEntries =
        _recentLogs.fold(0, (s, l) => s + l.entries.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İstatistikler',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(
              context,
              Icons.restaurant_menu_outlined,
              'Toplam Kayıt (7 gün)',
              '$totalEntries yemek',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTileWithTooltip(BuildContext context, String label,
      String value, String unit, String tooltipText, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const Spacer(),
              Tooltip(
                message: tooltipText,
                triggerMode: TooltipTriggerMode.tap,
                preferBelow: false,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.6),
                  ),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(unit,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }

  Widget _macroChip(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  )),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF5722),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFF009688),
      Color(0xFFE91E63),
      Color(0xFF607D8B),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  void _openEditSheet(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil listesinden uzun basarak düzenleyebilirsiniz.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
