import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/achievement_provider.dart';
import '../services/notification_service.dart'
    as notif_svc;
import '../widgets/animated_widgets.dart';
import 'achievements_screen.dart';
import 'export_screen.dart';
import 'profile_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiller'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Profil',
            onPressed: () => _openProfileForm(context, null),
          ),
        ],
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, _) {
          if (provider.profiles.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ...provider.profiles.map((profile) => _ProfileCard(
                    profile: profile,
                    isActive: provider.activeProfileId == profile.id,
                    onTap: () => Navigator.push(
                      context,
                      slidePageRoute(
                        (_) => ProfileDetailScreen(profile: profile),
                      ),
                    ),
                    onLongPress: () =>
                        _showProfileOptions(context, provider, profile),
                  )),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildActionButtons(context),
              const SizedBox(height: 16),
              _NotificationSettingsCard(),
              const SizedBox(height: 16),
              _ThemeSettingsCard(),
              const SizedBox(height: 16),
              _LanguageSettingsCard(),
              const SizedBox(height: 16),
              _AchievementsCard(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Henüz profil yok',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Başlamak için bir profil oluşturun.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openProfileForm(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Profil Oluştur'),
          ),
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
    final isActive = provider.activeProfileId == profile.id;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _avatarColor(profile.name),
                backgroundImage: profile.imagePath != null
                    ? FileImage(File(profile.imagePath!))
                    : null,
                child: profile.imagePath == null
                    ? Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(profile.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${profile.weight.toStringAsFixed(1)} kg • ${profile.goalLabel}'),
            ),
            const Divider(height: 1),
            if (!isActive)
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
                title: const Text('Aktif Yap'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.setActiveProfile(profile.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${profile.name} aktif profil yapıldı'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(ctx);
                _openProfileForm(context, profile);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Sil',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, provider, profile);
              },
            ),
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

  void _openProfileForm(BuildContext context, UserProfile? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ProfileFormSheet(existing: existing),
    );
  }

  static Color _avatarColor(String name) {
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
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  static Color _avatarColor(String name) {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial =
        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(profile.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: avatarColor,
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
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colorScheme.surface, width: 2),
                        ),
                        child: const Icon(Icons.check,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.age} yaş  •  ${profile.height.toStringAsFixed(0)}cm  •  ${profile.weight.toStringAsFixed(1)}kg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _GoalBadge(label: profile.goalLabel),
                        const SizedBox(width: 6),
                        Text(
                          '${profile.calorieGoal.toStringAsFixed(0)} kcal/gün',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  final String label;
  const _GoalBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Profile create/edit form sheet
class _ProfileFormSheet extends StatefulWidget {
  final UserProfile? existing;
  const _ProfileFormSheet({this.existing});

  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late Gender _gender;
  late ActivityLevel _activityLevel;
  late Goal _goal;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ageCtrl = TextEditingController(
        text: p != null && p.age > 0 ? p.age.toString() : '');
    _heightCtrl = TextEditingController(
        text: p != null && p.height > 0
            ? p.height.toStringAsFixed(0)
            : '');
    _weightCtrl = TextEditingController(
        text: p != null && p.weight > 0
            ? p.weight.toStringAsFixed(1)
            : '');
    _gender = p?.gender ?? Gender.male;
    _activityLevel = p?.activityLevel ?? ActivityLevel.sedentary;
    _goal = p?.goal ?? Goal.maintain;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  double? _computeCaloriePreview() {
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    if (weight <= 0 || height <= 0 || age <= 0) return null;

    double bmr;
    if (_gender == Gender.male) {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    const multipliers = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.active: 1.725,
      ActivityLevel.veryActive: 1.9,
    };
    final tdee = bmr * (multipliers[_activityLevel] ?? 1.2);
    switch (_goal) {
      case Goal.lose:
        return (tdee - 500).clamp(1200, double.infinity);
      case Goal.maintain:
        return tdee;
      case Goal.gain:
        return tdee + 500;
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;

    if (name.isEmpty || age <= 0 || height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen tüm alanları doldurun.'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await context.read<ProfileProvider>().save(
          name: name,
          age: age,
          height: height,
          weight: weight,
          gender: _gender,
          activityLevel: _activityLevel,
          goal: _goal,
          profileId: widget.existing?.id,
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
    final caloriePreview = _computeCaloriePreview();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Scaffold(
        appBar: AppBar(
          title: Text(
              widget.existing != null ? 'Profili Düzenle' : 'Yeni Profil'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('Kaydet'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kişisel Bilgiler',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ageCtrl,
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Yaş',
                                border: OutlineInputBorder(),
                                suffixText: 'yıl',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _heightCtrl,
                              onChanged: (_) => setState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Boy',
                                border: OutlineInputBorder(),
                                suffixText: 'cm',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _weightCtrl,
                              onChanged: (_) => setState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Kilo',
                                border: OutlineInputBorder(),
                                suffixText: 'kg',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Cinsiyet',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      SegmentedButton<Gender>(
                        segments: const [
                          ButtonSegment(
                            value: Gender.male,
                            label: Text('Erkek'),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment(
                            value: Gender.female,
                            label: Text('Kadın'),
                            icon: Icon(Icons.female),
                          ),
                        ],
                        selected: {_gender},
                        onSelectionChanged: (s) =>
                            setState(() => _gender = s.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aktivite Seviyesi',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ActivityLevel>(
                        value: _activityLevel,
                        onChanged: (v) =>
                            setState(() => _activityLevel = v!),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.directions_run),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ActivityLevel.sedentary,
                            child: Text('Hareketsiz (masa başı iş)'),
                          ),
                          DropdownMenuItem(
                            value: ActivityLevel.light,
                            child: Text('Az Hareketli (haftada 1-3 gün)'),
                          ),
                          DropdownMenuItem(
                            value: ActivityLevel.moderate,
                            child: Text('Orta (haftada 3-5 gün)'),
                          ),
                          DropdownMenuItem(
                            value: ActivityLevel.active,
                            child: Text('Çok Hareketli (haftada 6-7 gün)'),
                          ),
                          DropdownMenuItem(
                            value: ActivityLevel.veryActive,
                            child: Text('Sporcu (günde 2 kez antrenman)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hedef',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SegmentedButton<Goal>(
                        segments: const [
                          ButtonSegment(
                            value: Goal.lose,
                            label: Text('Kilo Ver'),
                            icon: Icon(Icons.trending_down),
                          ),
                          ButtonSegment(
                            value: Goal.maintain,
                            label: Text('Koru'),
                            icon: Icon(Icons.balance),
                          ),
                          ButtonSegment(
                            value: Goal.gain,
                            label: Text('Kilo Al'),
                            icon: Icon(Icons.trending_up),
                          ),
                        ],
                        selected: {_goal},
                        onSelectionChanged: (s) =>
                            setState(() => _goal = s.first),
                      ),
                    ],
                  ),
                ),
              ),
              if (caloriePreview != null) ...[
                const SizedBox(height: 12),
                Card(
                  color:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hesaplanan Günlük Hedef',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${caloriePreview.toStringAsFixed(0)} kcal/gün',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(widget.existing != null
                    ? 'Güncelle'
                    : 'Profil Oluştur'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Theme settings card
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
                    Text(
                      'Tema',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      themeProvider.isDarkMode
                          ? 'Karanlık Mod'
                          : 'Aydınlık Mod',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
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

// Language settings card
class _LanguageSettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dil / Language',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      langProvider.isTurkish ? 'Türkçe' : 'English',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
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

// Achievements card
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
                      color:
                          Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '🏆',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rozetlerim',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$earnedCount / $total rozet kazanıldı',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.newlyEarned.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${provider.newlyEarned.length} yeni',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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

// Notification settings card
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

  Future<void> _pickTime(TimeOfDay current,
      void Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
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
          child: Center(child: CircularProgressIndicator()),
        ),
      );
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
                Text(
                  'Bildirim Ayarları',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final granted = await notif_svc.NotificationService
                        .requestPermissions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(granted
                              ? 'Bildirim izni verildi'
                              : 'Bildirim izni reddedildi'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('İzin Ver'),
                ),
              ],
            ),
            const Divider(),
            // Water reminder
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
            // Breakfast
            _MealReminderTile(
              icon: Icons.free_breakfast_outlined,
              label: 'Kahvaltı',
              enabled: s.breakfastEnabled,
              time: s.breakfastTime,
              onToggle: (v) async {
                setState(() => s.breakfastEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () => _pickTime(s.breakfastTime, (t) {
                setState(() => s.breakfastTime = t);
              }),
            ),
            // Lunch
            _MealReminderTile(
              icon: Icons.lunch_dining_outlined,
              label: 'Öğle Yemeği',
              enabled: s.lunchEnabled,
              time: s.lunchTime,
              onToggle: (v) async {
                setState(() => s.lunchEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () => _pickTime(s.lunchTime, (t) {
                setState(() => s.lunchTime = t);
              }),
            ),
            // Dinner
            _MealReminderTile(
              icon: Icons.dinner_dining_outlined,
              label: 'Akşam Yemeği',
              enabled: s.dinnerEnabled,
              time: s.dinnerTime,
              onToggle: (v) async {
                setState(() => s.dinnerEnabled = v);
                await _applyAndSave();
              },
              onTimeTap: () => _pickTime(s.dinnerTime, (t) {
                setState(() => s.dinnerTime = t);
              }),
            ),
            // Daily summary
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.summarize_outlined),
              title: const Text('Günlük Özet'),
              subtitle: const Text('Her gece 21:00\'de'),
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

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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
