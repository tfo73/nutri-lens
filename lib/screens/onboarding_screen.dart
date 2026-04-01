import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/profile_provider.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Adım 2 — Temel bilgiler
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  Gender _gender = Gender.male;

  // Adım 3 — Hedef
  Goal _goal = Goal.maintain;
  String? _advancedGoal;

  // Adım 4 — Sağlık profili
  final Set<String> _selectedConditions = {};

  // Adım 5 — Beslenme tercihleri
  final Set<String> _selectedPreferences = {};

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5)),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    final profileProvider = context.read<ProfileProvider>();

    // Profil kaydet
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : 'Kullanıcı';
    final age = int.tryParse(_ageCtrl.text) ?? 25;
    final height = double.tryParse(_heightCtrl.text) ?? 170;
    final weight = double.tryParse(_weightCtrl.text) ?? 70;

    await profileProvider.save(
      name: name,
      age: age,
      height: height,
      weight: weight,
      gender: _gender,
      activityLevel: ActivityLevel.moderate,
      goal: _goal,
      advancedGoal: _advancedGoal,
      healthConditions: _selectedConditions.toList(),
      dietaryPreferences: _selectedPreferences.toList(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const HomeScreen(),
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i == _currentPage;
                  final done = i < _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: (active || done) ? primary : primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildWelcomePage(theme, primary),
                  _buildBasicInfoPage(theme, primary),
                  _buildGoalPage(theme, primary),
                  _buildHealthProfilePage(theme, primary),
                  _buildDietaryPreferencesPage(theme, primary),
                ],
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
                      child: Text('Geri',
                          style: TextStyle(color: primary.withValues(alpha: 0.7))),
                    ),
                  if (_currentPage >= 3) ...[
                    TextButton(
                      onPressed: _skip,
                      child: Text('Atla',
                          style: TextStyle(color: primary.withValues(alpha: 0.7))),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentPage == 4 ? 'Başlayalım' : 'Devam',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Adım 1: Hoş Geldiniz ──────────────────────────────────────────────────

  Widget _buildWelcomePage(ThemeData theme, Color primary) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, _) => Opacity(
              opacity: _logoFade.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/icon/icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Metabolik Optimizasyon\nAsistanınıza Hoş Geldiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sadece kalori saymak değil — kişiye özel beslenme analizi, mikro besin takibi ve metabolik hedef optimizasyonu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureBadge('🧬', 'Mikro Besinler', theme),
              const SizedBox(width: 12),
              _featureBadge('⚕️', 'Sağlık Profili', theme),
              const SizedBox(width: 12),
              _featureBadge('⚡', 'Çakışma Tespiti', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureBadge(String emoji, String label, ThemeData theme) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ─── Adım 2: Temel Bilgiler ────────────────────────────────────────────────

  Widget _buildBasicInfoPage(ThemeData theme, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('Temel Bilgileriniz', theme),
          _pageSubtitle(
              'BMR ve TDEE hesabı için yaş, boy ve kilo bilgilerinize ihtiyacımız var.',
              theme),
          const SizedBox(height: 24),
          _inputField('Ad Soyad', _nameCtrl, theme,
              hint: 'Adınız', textInputAction: TextInputAction.next),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _inputField('Yaş', _ageCtrl, theme,
                    hint: '25',
                    keyboard: TextInputType.number,
                    textInputAction: TextInputAction.next)),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField('Boy (cm)', _heightCtrl, theme,
                    hint: '170',
                    keyboard: TextInputType.number,
                    textInputAction: TextInputAction.next)),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField('Kilo (kg)', _weightCtrl, theme,
                    hint: '70', keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          Text('Cinsiyet',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 10),
          Row(children: [
            _genderChip('Erkek', Gender.male, '♂', theme, primary),
            const SizedBox(width: 12),
            _genderChip('Kadın', Gender.female, '♀', theme, primary),
          ]),
        ],
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    ThemeData theme, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _genderChip(
      String label, Gender gender, String icon, ThemeData theme, Color primary) {
    final selected = _gender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = gender),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : theme.colorScheme.surface,
            border: Border.all(
              color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(icon,
                  style: TextStyle(
                      fontSize: 24, color: selected ? primary : null)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? primary : theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Adım 3: Hedef Seçimi ─────────────────────────────────────────────────

  Widget _buildGoalPage(ThemeData theme, Color primary) {
    final basicGoals = [
      ('🎯', 'Kilo Ver', Goal.lose, null),
      ('⚖️', 'Koru', Goal.maintain, null),
      ('📈', 'Kilo Al', Goal.gain, null),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('Hedefiniz Ne?', theme),
          _pageSubtitle('Makro dağılımı ve öneriler hedefinize göre kişiselleşir.', theme),
          const SizedBox(height: 20),
          Text('Temel Hedefler',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          ...basicGoals.map((g) {
            final selected = _advancedGoal == null && _goal == g.$3;
            return _goalTile(g.$1, g.$2, selected, theme, primary, () {
              setState(() {
                _goal = g.$3;
                _advancedGoal = null;
              });
            });
          }),
          const SizedBox(height: 20),
          Text('Gelişmiş Hedefler',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          ...AdvancedGoals.all.map((ag) {
            final selected = _advancedGoal == ag;
            return _goalTile(
              AdvancedGoals.emoji(ag),
              AdvancedGoals.label(ag),
              selected,
              theme,
              primary,
              () => setState(() {
                _advancedGoal = ag;
                _goal = Goal.maintain;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _goalTile(String emoji, String label, bool selected, ThemeData theme,
      Color primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
          border: Border.all(
            color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? primary : theme.colorScheme.onSurface)),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle, color: primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Adım 4: Sağlık Profili ───────────────────────────────────────────────

  Widget _buildHealthProfilePage(ThemeData theme, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('Sağlık Profiliniz', theme),
          _pageSubtitle(
              'Besin hedefleri ve öneriler sağlık durumunuza göre kişiselleşir. Atlamak isterseniz devam edebilirsiniz.',
              theme),
          const SizedBox(height: 16),
          ...HealthConditionCategories.all.entries.map(
            (entry) => _healthCategorySection(
                entry.key, entry.value, theme, primary),
          ),
        ],
      ),
    );
  }

  Widget _healthCategorySection(String category, List<String> conditions,
      ThemeData theme, Color primary) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(category,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.colorScheme.onSurface)),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: conditions.map((c) {
              final selected = _selectedConditions.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (v) =>
                    setState(() => v
                        ? _selectedConditions.add(c)
                        : _selectedConditions.remove(c)),
                selectedColor: primary.withValues(alpha: 0.15),
                checkmarkColor: primary,
                labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? primary : null),
                side: BorderSide(
                    color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.4)),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Adım 5: Beslenme Tercihleri ──────────────────────────────────────────

  Widget _buildDietaryPreferencesPage(ThemeData theme, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle('Beslenme Tercihleriniz', theme),
          _pageSubtitle('Öneriler tercihlerinize göre filtrelenir.', theme),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: DietaryPreferences.all.map((pref) {
              final selected = _selectedPreferences.contains(pref);
              return FilterChip(
                label: Text(pref),
                selected: selected,
                onSelected: (v) => setState(() =>
                    v
                        ? _selectedPreferences.add(pref)
                        : _selectedPreferences.remove(pref)),
                selectedColor: primary.withValues(alpha: 0.15),
                checkmarkColor: primary,
                labelStyle: TextStyle(
                    color: selected ? primary : null,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                side: BorderSide(
                    color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              );
            }).toList(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tüm bu ayarları daha sonra Profil ekranından değiştirebilirsiniz.',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Yardımcılar ──────────────────────────────────────────────────────────

  Widget _pageTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface)),
    );
  }

  Widget _pageSubtitle(String text, ThemeData theme) {
    return Text(text,
        style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5));
  }
}
