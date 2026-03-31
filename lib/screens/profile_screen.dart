import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/achievement_provider.dart';
import '../services/notification_service.dart' as notif_svc;
import '../widgets/animated_widgets.dart';
import 'achievements_screen.dart';
import 'export_screen.dart';
import 'profile_detail_screen.dart';

// ─── ProfileScreen ────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // Debug
    debugPrint('=== PROFİL EKRANI BUILD ===');
    debugPrint('Profil sayısı: ${profileProvider.profiles.length}');
    for (final p in profileProvider.profiles) {
      debugPrint('Profil: ${p.name}');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiller'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF4ADE80)),
            tooltip: 'Yeni Profil',
            onPressed: () => _openWizard(context, null),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Profil listesi ──────────────────────────────────────────
          if (profileProvider.profiles.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(
              child: Icon(Icons.person_add,
                  color: Color(0xFF4ADE80), size: 48),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Henüz profil yok',
                style: TextStyle(
                    color: Color(0xFF4A7060),
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                '+ butonuna basarak profil ekleyin',
                style: TextStyle(color: Color(0xFF4A7060), fontSize: 13),
              ),
            ),
          ] else ...[
            ...profileProvider.profiles.map((profile) {
              final isActive =
                  profileProvider.activeProfileId == profile.id;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  slidePageRoute(
                      (_) => ProfileDetailScreen(profile: profile)),
                ),
                onLongPress: () => _showProfileOptions(
                    context, profileProvider, profile),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF122018),
                    borderRadius: BorderRadius.circular(18),
                    border: Border(
                      left: BorderSide(
                        color: isActive
                            ? const Color(0xFF4ADE80)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? const Color(0xFF4ADE80)
                                  .withValues(alpha: 0.15)
                              : const Color(0xFF1A3020),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF1A3020),
                            width: 1.5,
                          ),
                        ),
                        child: profile.imagePath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(profile.imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Text(
                                      profile.name.isNotEmpty
                                          ? profile.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: isActive
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFFB8D4C0),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  profile.name.isNotEmpty
                                      ? profile.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFB8D4C0),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Bilgiler
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                color: Color(0xFFE8F5EC),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${profile.age} yaş · ${profile.height.toStringAsFixed(0)} cm · ${profile.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  color: Color(0xFFB8D4C0), fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3020),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${profile.goalLabel}  ·  ${profile.calorieGoal.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFB8D4C0),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Aktifse yeşil tik
                      if (isActive)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4ADE80)
                                .withValues(alpha: 0.15),
                            border: Border.all(
                              color: const Color(0xFF4ADE80),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(Icons.check,
                              size: 14, color: Color(0xFF4ADE80)),
                        )
                      else
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF4A7060), size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
          // ── Ayarlar ─────────────────────────────────────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Divider(color: Color(0xFF1A3020)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionButtons(context),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _NotificationSettingsCard(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ThemeSettingsCard(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LanguageSettingsCard(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AchievementsCard(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              slidePageRoute((_) => const ExportScreen()),
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Rapor Al'),
          ),
        ),
      ],
    );
  }

  void _showProfileOptions(
      BuildContext context, ProfileProvider provider, UserProfile profile) {
    const danger = Color(0xFFF87171);
    const textSecond = Color(0xFFB8D4C0);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF122018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3020),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                profile.name,
                style: const TextStyle(
                  color: Color(0xFFE8F5EC),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: textSecond),
              title: const Text('Profili Düzenle',
                  style: TextStyle(color: textSecond)),
              onTap: () {
                Navigator.pop(ctx);
                _openWizard(context, profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: danger),
              title:
                  const Text('Profili Sil', style: TextStyle(color: danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, provider, profile);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ProfileProvider provider, UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profili Sil'),
        content: Text(
            '${profile.name} profilini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteProfile(profile.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _openWizard(BuildContext context, UserProfile? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileWizardSheet(existing: existing),
    );
  }

}


// ─── Profile Wizard Sheet (5 adım) ───────────────────────────────────────────

class _ProfileWizardSheet extends StatefulWidget {
  final UserProfile? existing;
  const _ProfileWizardSheet({this.existing});

  @override
  State<_ProfileWizardSheet> createState() => _ProfileWizardSheetState();
}

class _ProfileWizardSheetState extends State<_ProfileWizardSheet> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 5;

  // Step 1 — Temel bilgiler
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.moderate;

  // Step 2 — Hedefler
  Goal _goal = Goal.maintain;
  String? _advancedGoal;

  // Step 3 — Sağlık profili
  final Set<String> _healthConditions = {};

  // Step 4 — Beslenme tercihleri
  final Set<String> _dietaryPrefs = {};

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age > 0 ? p.age.toString() : '';
      _heightCtrl.text = p.height > 0 ? p.height.toStringAsFixed(0) : '';
      _weightCtrl.text = p.weight > 0 ? p.weight.toStringAsFixed(1) : '';
      _gender = p.gender;
      _activityLevel = p.activityLevel;
      _goal = p.goal;
      _advancedGoal = p.advancedGoal;
      _healthConditions.addAll(p.healthConditions);
      _dietaryPrefs.addAll(p.dietaryPreferences);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    final h = double.tryParse(_heightCtrl.text) ?? 0;
    final w = double.tryParse(_weightCtrl.text) ?? 0;
    return name.isNotEmpty && age > 0 && h > 0 && w > 0;
  }

  void _next() {
    if (_step == 0 && !_validateStep1()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm alanları doldurun.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;

    await context.read<ProfileProvider>().save(
          name: name,
          age: age,
          height: height,
          weight: weight,
          gender: _gender,
          activityLevel: _activityLevel,
          goal: _goal,
          profileId: widget.existing?.id,
          advancedGoal: _advancedGoal,
          healthConditions: _healthConditions.toList(),
          dietaryPreferences: _dietaryPrefs.toList(),
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing != null
              ? 'Profil güncellendi!'
              : 'Profil oluşturuldu!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.existing != null
                      ? 'Profili Düzenle'
                      : 'Yeni Profil',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_step + 1} / $_totalSteps',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_totalSteps, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? primary
                          : primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _step = p),
              children: [
                _buildStep1(theme, primary),
                _buildStep2(theme, primary),
                _buildStep3(theme, primary),
                _buildStep4(theme, primary),
                _buildStep5(theme, primary),
              ],
            ),
          ),
          // Bottom nav
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _back,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_step == 0 ? 'İptal' : 'Geri'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _step == _totalSteps - 1 ? 'Tamamla' : 'İleri',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Adım 1: Temel Bilgiler ──────────────────────────────────────────────

  Widget _buildStep1(ThemeData theme, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Temel Bilgiler', theme),
          _stepSubtitle(
              'Kalori ve makro hedefleriniz bu bilgilere göre hesaplanır.',
              theme),
          const SizedBox(height: 20),
          _field('Ad Soyad', _nameCtrl, theme,
              hint: 'Adınız ve soyadınız',
              action: TextInputAction.next),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _field('Yaş', _ageCtrl, theme,
                    hint: '25',
                    keyboard: TextInputType.number,
                    action: TextInputAction.next)),
            const SizedBox(width: 10),
            Expanded(
                child: _field('Boy (cm)', _heightCtrl, theme,
                    hint: '170',
                    keyboard: TextInputType.number,
                    action: TextInputAction.next)),
            const SizedBox(width: 10),
            Expanded(
                child: _field('Kilo (kg)', _weightCtrl, theme,
                    hint: '70', keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          _stepLabel('Cinsiyet', theme),
          const SizedBox(height: 8),
          Row(children: [
            _genderBtn('Erkek', Gender.male, '♂', theme, primary),
            const SizedBox(width: 10),
            _genderBtn('Kadın', Gender.female, '♀', theme, primary),
          ]),
          const SizedBox(height: 20),
          _stepLabel('Aktivite Seviyesi', theme),
          const SizedBox(height: 8),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activityLevel,
            onChanged: (v) => setState(() => _activityLevel = v!),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(
                  value: ActivityLevel.sedentary,
                  child: Text('Hareketsiz (masa başı)')),
              DropdownMenuItem(
                  value: ActivityLevel.light,
                  child: Text('Az Hareketli (haftada 1-3)')),
              DropdownMenuItem(
                  value: ActivityLevel.moderate,
                  child: Text('Orta (haftada 3-5)')),
              DropdownMenuItem(
                  value: ActivityLevel.active,
                  child: Text('Çok Aktif (haftada 6-7)')),
              DropdownMenuItem(
                  value: ActivityLevel.veryActive,
                  child: Text('Sporcu (günde 2x antrenman)')),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Adım 2: Hedef Seçimi ────────────────────────────────────────────────

  Widget _buildStep2(ThemeData theme, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Hedefiniz', theme),
          _stepSubtitle(
              'Makro dağılımı ve öneriler seçtiğiniz hedefe göre kişiselleşir.',
              theme),
          const SizedBox(height: 16),
          _sectionLabel('Temel Hedefler', theme),
          const SizedBox(height: 8),
          _goalTile('🎯', 'Kilo Ver', false,
              selected: _advancedGoal == null && _goal == Goal.lose,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.lose;
              _advancedGoal = null;
            });
          }),
          _goalTile('⚖️', 'Kilonu Koru', false,
              selected: _advancedGoal == null && _goal == Goal.maintain,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.maintain;
              _advancedGoal = null;
            });
          }),
          _goalTile('📈', 'Kilo Al', false,
              selected: _advancedGoal == null && _goal == Goal.gain,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.gain;
              _advancedGoal = null;
            });
          }),
          const SizedBox(height: 16),
          _sectionLabel('Gelişmiş Hedefler', theme),
          const SizedBox(height: 8),
          ...AdvancedGoals.all.map((ag) => _goalTile(
                AdvancedGoals.emoji(ag),
                AdvancedGoals.label(ag),
                true,
                selected: _advancedGoal == ag,
                theme: theme,
                primary: primary,
                onTap: () => setState(() {
                  _advancedGoal = ag;
                  _goal = Goal.maintain;
                }),
              )),
        ],
      ),
    );
  }

  Widget _goalTile(String emoji, String label, bool isAdvanced,
      {required bool selected,
      required ThemeData theme,
      required Color primary,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? primary
                : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? primary : theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: primary, size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Adım 3: Sağlık Profili ──────────────────────────────────────────────

  Widget _buildStep3(ThemeData theme, Color primary) {
    // Kullanıcının talep ettiği kategoriler
    final categories = <String, List<String>>{
      'Sindirim': ['SIBO', 'IBS', 'Crohn', 'Çölyak', 'Laktoz İntoleransı', 'Reflü'],
      'Metabolik': ['Tip 1 Diyabet', 'Tip 2 Diyabet', 'İnsülin Direnci', 'Hipotiroidi', 'PCOS'],
      'Kardiyovasküler': ['Hipertansiyon', 'Yüksek Kolesterol'],
      'Alerji': ['Gluten İntoleransı', 'Süt Alerjisi', 'Yumurta Alerjisi', 'Fıstık Alerjisi', 'Deniz Ürünleri Alerjisi'],
      'Diğer': ['Gebelik', 'Emzirme', 'Menopoz', 'Gut Hastalığı', 'Osteoporoz'],
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Sağlık Profili', theme),
          _stepSubtitle(
              'Besin hedefleri ve öneriler sağlık durumunuza göre kişiselleşir. Uygulanabilecek olanları seçin.',
              theme),
          const SizedBox(height: 16),
          ...categories.entries.map(
              (e) => _conditionSection(e.key, e.value, theme, primary)),
        ],
      ),
    );
  }

  Widget _conditionSection(String category, List<String> items,
      ThemeData theme, Color primary) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          category,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: theme.colorScheme.onSurface),
        ),
        initiallyExpanded: _healthConditions.any(items.contains),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: items.map((c) {
              final sel = _healthConditions.contains(c);
              return FilterChip(
                label: Text(c, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (v) => setState(() =>
                    v ? _healthConditions.add(c) : _healthConditions.remove(c)),
                selectedColor: primary.withValues(alpha: 0.15),
                checkmarkColor: primary,
                labelStyle: TextStyle(color: sel ? primary : null),
                side: BorderSide(
                    color: sel
                        ? primary
                        : theme.colorScheme.outline.withValues(alpha: 0.4)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ─── Adım 4: Beslenme Tercihleri ─────────────────────────────────────────

  Widget _buildStep4(ThemeData theme, Color primary) {
    const prefs = [
      ('🌱', 'Vegan'),
      ('🥦', 'Vejetaryen'),
      ('☪️', 'Helal'),
      ('🚫', 'Gluten-Free'),
      ('🥛', 'Laktozsuz'),
      ('🏔️', 'Paleo'),
      ('⚡', 'Ketojenik'),
      ('🫒', 'Akdeniz Diyeti'),
      ('📉', 'Düşük Karbonhidrat'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Beslenme Tercihleri', theme),
          _stepSubtitle(
              'Öneriler ve uyarılar tercihlerinize göre filtrelenir.',
              theme),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: prefs.map((p) {
              final sel = _dietaryPrefs.contains(p.$2);
              return GestureDetector(
                onTap: () => setState(() =>
                    sel ? _dietaryPrefs.remove(p.$2) : _dietaryPrefs.add(p.$2)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? primary.withValues(alpha: 0.12)
                        : theme.colorScheme.surface,
                    border: Border.all(
                      color: sel
                          ? primary
                          : theme.colorScheme.outline
                              .withValues(alpha: 0.3),
                      width: sel ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        p.$2,
                        style: TextStyle(
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                              sel ? primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Adım 5: Özet ────────────────────────────────────────────────────────

  Widget _buildStep5(ThemeData theme, Color primary) {
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : '—';
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;

    // Kalori önizleme
    double? calPreview;
    if (age > 0 && height > 0 && weight > 0) {
      final bmr = _gender == Gender.male
          ? 10 * weight + 6.25 * height - 5 * age + 5
          : 10 * weight + 6.25 * height - 5 * age - 161;
      const m = {
        ActivityLevel.sedentary: 1.2,
        ActivityLevel.light: 1.375,
        ActivityLevel.moderate: 1.55,
        ActivityLevel.active: 1.725,
        ActivityLevel.veryActive: 1.9,
      };
      final tdee = bmr * (m[_activityLevel] ?? 1.2);
      calPreview = _goal == Goal.lose
          ? (tdee - 500).clamp(1200, double.infinity)
          : _goal == Goal.gain
              ? tdee + 500
              : tdee;
    }

    final goalLabel = _advancedGoal != null
        ? AdvancedGoals.label(_advancedGoal!)
        : (_goal == Goal.lose
            ? 'Kilo Ver'
            : _goal == Goal.gain
                ? 'Kilo Al'
                : 'Kilonu Koru');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Özet', theme),
          _stepSubtitle('Her şey doğru görünüyor mu? Onaylayın.', theme),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Ad Soyad', name, theme),
                  _summaryRow(
                      'Yaş / Boy / Kilo',
                      '$age yaş / ${height.toStringAsFixed(0)} cm / ${weight.toStringAsFixed(1)} kg',
                      theme),
                  _summaryRow('Cinsiyet',
                      _gender == Gender.male ? 'Erkek' : 'Kadın', theme),
                  _summaryRow('Hedef', goalLabel, theme),
                ],
              ),
            ),
          ),
          if (calPreview != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      color: primary),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Günlük Kalori Hedefi',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6))),
                      Text(
                        '${calPreview.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_healthConditions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sağlık Koşulları',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _healthConditions
                          .map((c) => Chip(
                                label: Text(c,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_dietaryPrefs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beslenme Tercihleri',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _dietaryPrefs
                          .map((p) => Chip(
                                label: Text(p,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────

  Widget _stepTitle(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _stepSubtitle(String text, ThemeData theme) => Text(text,
      style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          height: 1.5));

  Widget _stepLabel(String text, ThemeData theme) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: theme.colorScheme.onSurface));

  Widget _sectionLabel(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.55))),
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    TextInputAction action = TextInputAction.done,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textInputAction: action,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderBtn(
      String label, Gender g, String icon, ThemeData theme, Color primary) {
    final sel = _gender == g;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? primary.withValues(alpha: 0.12)
                : theme.colorScheme.surface,
            border: Border.all(
              color: sel
                  ? primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: sel ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(icon,
                  style: TextStyle(
                      fontSize: 22, color: sel ? primary : null)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sel ? primary : theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings cards (unchanged) ───────────────────────────────────────────────

class _ThemeSettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                        themeProvider.isDarkMode ? 'Karanlık Mod' : 'Aydınlık Mod',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.language,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dil / Language',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(langProvider.isTurkish ? 'Türkçe' : 'English',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('TR')),
                  ButtonSegment<bool>(value: false, label: Text('EN')),
                ],
                selected: {langProvider.isTurkish},
                onSelectionChanged: (selection) {
                  if (selection.first != langProvider.isTurkish) {
                    langProvider.toggleLanguage();
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity(
                      horizontal: VisualDensity.minimumDensity,
                      vertical: VisualDensity.minimumDensity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AchievementProvider>(
      builder: (context, provider, _) {
        final earnedCount = provider.earned.length;
        final total = AchievementProvider.achievements.length;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              slidePageRoute((_) => const AchievementsScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rozetlerim',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('$earnedCount / $total rozet kazanıldı',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (provider.newlyEarned.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${provider.newlyEarned.length} yeni',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationSettingsCard extends StatefulWidget {
  @override
  State<_NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends State<_NotificationSettingsCard> {
  notif_svc.NotificationSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await notif_svc.NotificationService.loadSettings();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _applyAndSave() async {
    if (_settings == null) return;
    await notif_svc.NotificationService.saveAndApply(_settings!);
  }

  Future<void> _pickTime(
      TimeOfDay current, void Function(TimeOfDay) onPicked) async {
    final picked =
        await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      onPicked(picked);
      await _applyAndSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())));
    }
    final s = _settings!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: 8),
                Text('Bildirim Ayarları',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final granted =
                        await notif_svc.NotificationService.requestPermissions();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(granted
                            ? 'Bildirim izni verildi'
                            : 'Bildirim izni reddedildi'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('İzin Ver'),
                ),
              ],
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.water_drop_outlined),
              title: const Text('Su Hatırlatıcısı'),
              subtitle: const Text('Her 2 saatte bir (08:00–20:00)'),
              value: s.waterEnabled,
              onChanged: (v) async {
                setState(() => s.waterEnabled = v);
                await _applyAndSave();
              },
            ),
            _MealReminderTile(
              icon: Icons.free_breakfast_outlined,
              label: 'Kahvaltı',
              enabled: s.breakfastEnabled,
              time: s.breakfastTime,
              onToggle: (v) async {
                setState(() => s.breakfastEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () => _pickTime(s.breakfastTime,
                  (t) => setState(() => s.breakfastTime = t)),
            ),
            _MealReminderTile(
              icon: Icons.lunch_dining_outlined,
              label: 'Öğle Yemeği',
              enabled: s.lunchEnabled,
              time: s.lunchTime,
              onToggle: (v) async {
                setState(() => s.lunchEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () =>
                  _pickTime(s.lunchTime, (t) => setState(() => s.lunchTime = t)),
            ),
            _MealReminderTile(
              icon: Icons.dinner_dining_outlined,
              label: 'Akşam Yemeği',
              enabled: s.dinnerEnabled,
              time: s.dinnerTime,
              onToggle: (v) async {
                setState(() => s.dinnerEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () => _pickTime(s.dinnerTime,
                  (t) => setState(() => s.dinnerTime = t)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.summarize_outlined),
              title: const Text('Günlük Özet'),
              subtitle: const Text("Her gece 21:00'de"),
              value: s.summaryEnabled,
              onChanged: (v) async {
                setState(() => s.summaryEnabled = v);
                await _applyAndSave();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MealReminderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final TimeOfDay time;
  final void Function(bool) onToggle;
  final VoidCallback onTimeTap;

  const _MealReminderTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onTimeTap,
  });

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(label),
      subtitle: GestureDetector(
        onTap: enabled ? onTimeTap : null,
        child: Text(
          _formatTime(time),
          style: TextStyle(
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            decoration: enabled ? TextDecoration.underline : null,
          ),
        ),
      ),
      value: enabled,
      onChanged: onToggle,
    );
  }
}
