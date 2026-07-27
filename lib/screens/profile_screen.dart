import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrition_data.dart';
import '../services/device_id_service.dart';
import '../models/nutrition_data_65.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../providers/wellness_provider.dart';
import '../providers/achievement_provider.dart';
import '../widgets/wave_background.dart';
import '../services/health_service.dart';
import 'settings_screen.dart';
import 'image_crop_screen.dart';
import '../providers/fasting_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/report_generator_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

// ─── ProfileScreen ────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _gradientName(String name, double fontSize) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF58A6FF), Color(0xFF58A6FF)],
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: Text(
        name,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = profileProvider.activeProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Profil')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: WaveBackground(
        child: profile == null
            ? _buildEmptyState(context, profileProvider)
            : _buildActiveProfile(context, profileProvider, profile, cs),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ProfileProvider profileProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline,
              size: 72, color: Color(0xFF58A6FF)),
          const SizedBox(height: 16),
          Text(
            context.tr('Profil oluşturun'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Kalori ve makro hedeflerinizi takip etmek için\nbir profil oluşturun.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _openWizard(context, null),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF58A6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProfile(
    BuildContext context,
    ProfileProvider profileProvider,
    UserProfile profile,
    ColorScheme cs,
  ) {
    final useMetric = profileProvider.useMetricUnits;
    // Height display
    final String heightStr = useMetric
        ? '${profile.height.toStringAsFixed(0)} cm'
        : () {
            final totalIn = profile.height / 2.54;
            final ft = totalIn ~/ 12;
            final inches = (totalIn % 12).round();
            return "$ft'$inches\"";
          }();
    // Weight display
    final String weightStr = useMetric
        ? '${profile.weight.toStringAsFixed(1)} kg'
        : '${(profile.weight * 2.20462).toStringAsFixed(1)} lbs';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar (tıklayarak fotoğraf seç) ─────────────────────
          GestureDetector(
            onTap: () => _showPhotoOptions(context, profileProvider, profile),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                  backgroundImage: profile.imagePath != null
                      ? FileImage(File(profile.imagePath!))
                      : null,
                  child: profile.imagePath == null
                      ? Text(
                          profile.name.isNotEmpty
                              ? profile.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF58A6FF),
                          ),
                        )
                      : null,
                ),
                // Kamera ikonu rozeti
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF58A6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Gradient name ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _gradientName(profile.name, 22),
              if (profile.isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFA500).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          _buildAchievementsList(context),
          const SizedBox(height: 16),
          // ── Info card ─────────────────────────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _infoCell(
                            Icons.cake_outlined,
                            context.tr('Yaş'),
                            '${profile.age}'),
                      ),
                      Expanded(
                        child: _infoCell(
                            Icons.straighten_outlined,
                            context.tr('Boy'),
                            heightStr),
                      ),
                      Expanded(
                        child: _infoCell(
                            Icons.monitor_weight_outlined,
                            context.tr('Kilo'),
                            weightStr),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoCell(
                            Icons.flag_outlined,
                            context.tr('Hedef'),
                            context.tr(profile.goalLabel)),
                      ),
                      Expanded(
                        child: _infoCell(
                            profile.gender == Gender.female 
                                ? Icons.female 
                                : (profile.gender == Gender.male ? Icons.male : Icons.person_outline),
                            context.tr('Cinsiyet'),
                            profile.gender == Gender.female 
                                ? context.tr('Kadın') 
                                : (profile.gender == Gender.male ? context.tr('Erkek') : context.tr('Belirtilmemiş'))),
                      ),
                      Expanded(
                        child: _infoCell(
                            Icons.directions_run_outlined,
                            context.tr('Aktivite'),
                            context.tr(profile.activityLabel)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // ── BMI (VKİ) Card ──────────────────────────────────────
          _buildBMICard(context, profile, cs),
          const SizedBox(height: 12),
          // ── Kalori & Makro Hedefleri ──────────────────────────────
          _GoalsCard(profileProvider: profileProvider),
          const SizedBox(height: 12),
          // ── Weekly Flow Card ───────────────────────────────────────
          _WeeklyFlowCard(fasting: context.watch<FastingProvider>()),
          const SizedBox(height: 12),
          // ── Kilo Grafiği ──────────────────────────────────────────
          _WeightChart(wellness: context.watch<WellnessProvider>()),
          const SizedBox(height: 12),
          // ── Uyku Skoru Grafiği ────────────────────────────────────
          _SleepScoreChart(
              wellness: context.watch<WellnessProvider>()),
          const SizedBox(height: 12),
          // ── Mail ile Gönder ───────────────────────────────────────
          _EmailReportCard(),
          const SizedBox(height: 20),
        ],
        ),  // Column
      ),    // ConstrainedBox
    ),      // SingleChildScrollView
    );      // LayoutBuilder
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsList(BuildContext context) {
    final achievementProvider = context.watch<AchievementProvider>();
    final earned = achievementProvider.earned.toList();
    
    if (earned.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: earned.map((id) {
          final def = AchievementProvider.achievements.firstWhere((a) => a.id == id);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(def.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  context.tr(def.name),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF58A6FF),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBMICard(BuildContext context, UserProfile profile, ColorScheme cs) {
    final bmi = profile.weight / ((profile.height / 100) * (profile.height / 100));
    String category;
    Color statusColor;

    if (bmi < 18.5) {
      category = 'Zayıf';
      statusColor = Colors.blueAccent;
    } else if (bmi < 25) {
      category = 'Normal';
      statusColor = const Color(0xFF58A6FF);
    } else if (bmi < 30) {
      category = 'Fazla Kilolu';
      statusColor = Colors.orangeAccent;
    } else {
      category = 'Obez';
      statusColor = Colors.redAccent;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('BMI Verileri'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(bmi.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(context.tr(category),
                              style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: IconButton(
                    onPressed: () => _showBMIInfoDialog(context),
                    icon: const Icon(Icons.info_outline, color: Color(0xFF8B949E), size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBMIProgressBar(bmi),
          ],
        ),
      ),
    );
  }

Widget _buildBMIProgressBar(double bmi) {
  // Normalize BMI for 10-40 range
  double progress = (bmi - 10) / (40 - 10);
  progress = progress.clamp(0.0, 1.0);

  final labels = [
    (10.0, '10'),
    (18.5, '18.5'),
    (25.0, '25'),
    (30.0, '30'),
    (40.0, '40'),
  ];

  return Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) => Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Colors.blueAccent,   // Underweight (<18.5)
                    Color(0xFF58A6FF),   // Normal (18.5-25)
                    Colors.orangeAccent, // Overweight (25-30)
                    Colors.redAccent,    // Obese (>30)
                  ],
                  stops: [0.28, 0.5, 0.67, 1.0],
                ),
              ),
            ),
            Positioned(
              left: (constraints.maxWidth * progress) - 1,
              top: -2,
              child: Container(
                width: 2,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: labels.map((l) {
              double lp = (l.$1 - 10) / (40 - 10);
              return Positioned(
                left: constraints.maxWidth * lp - 15,
                child: SizedBox(
                  width: 30,
                  child: Text(
                    l.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ],
  );
}


  void _showBMIInfoDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        title: Text(context.tr('Vücut Kitle İndeksi (VKİ)'),
            style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('VKİ, vücut ağırlığınızın (kg) boyunuzun (m) karesine bölünmesiyle hesaplanır.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _bmiCategoryRow(context, context.tr('Zayıf'), '< 18.5', Colors.blueAccent),
            _bmiCategoryRow(context, context.tr('Normal'), '18.5 - 24.9', const Color(0xFF58A6FF)),
            _bmiCategoryRow(context, context.tr('Fazla Kilolu'), '25.0 - 29.9', Colors.orangeAccent),
            _bmiCategoryRow(context, context.tr('Obez'), '≥ 30.0', Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              context.tr('* VKİ, genel bir sağlık göstergesidir; yağ/kas oranı veya yaş gibi faktörleri dikkate almaz.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Anladım'), style: const TextStyle(color: Color(0xFF58A6FF))),
          ),
        ],
      ),
    );
  }

  Widget _bmiCategoryRow(BuildContext context, String label, String range, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(range, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }


  Future<void> _showPhotoOptions(
      BuildContext context, ProfileProvider provider, UserProfile profile) async {
    const textSecond = Color(0xFF8B949E);
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                context.tr('Profil Fotoğrafı'),
                style: const TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: textSecond),
              title: Text(context.tr('Kameradan Çek'),
                  style: const TextStyle(color: textSecond)),
              onTap: () async {
                Navigator.pop(ctx);
                final image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 512,
                );
                if (image != null && context.mounted) {
                  await provider.updateProfileImage(profile.id, image.path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: textSecond),
              title: Text(context.tr('Galeriden Seç'),
                  style: const TextStyle(color: textSecond)),
              onTap: () async {
                Navigator.pop(ctx);
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 512,
                );
                if (image != null && context.mounted) {
                  // Galeriden seçilen fotoğraf için kırpma ekranına git
                  _navigateToCropScreen(context, provider, profile.id, image.path);
                }
              },
            ),
            if (profile.imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFF85149)),
                title: Text(context.tr('Fotoğrafı Kaldır'),
                    style: const TextStyle(color: Color(0xFFF85149))),
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.updateProfileImage(profile.id, null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToCropScreen(BuildContext context, ProfileProvider provider, String profileId, String imagePath) async {
    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(imagePath: imagePath),
      ),
    );

    if (croppedPath != null) {
      await provider.updateProfileImage(profileId, croppedPath);
    }
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
  void _showFriendsNotice(BuildContext context) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FriendsPopup(
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }
}

class _FriendsPopup extends StatefulWidget {
  final VoidCallback onDismiss;
  const _FriendsPopup({required this.onDismiss});

  @override
  State<_FriendsPopup> createState() => _FriendsPopupState();
}

class _FriendsPopupState extends State<_FriendsPopup> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: const Alignment(0, 0.85), // Biraz daha aşağı aldık
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF30363D)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF58A6FF), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('Arkadaşlar yakında eklenecek'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const _AnimatedDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hesabı Düzenle sayfasını dışarıdan (örn. Settings) açmak için.
void openProfileEditSheet(BuildContext context, UserProfile profile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileEditSheet(profile: profile),
  );
}

/// Dışarıdan (örn. Dashboard'dan) yeni profil sihirbazını açmak için.
void openNewProfileWizard(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProfileWizardSheet(existing: null),
  );
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
                      ? context.tr('Profili Düzenle')
                      : context.tr('Yeni Profil'),
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
                    child: Text(_step == 0 ? context.tr('İptal') : context.tr('Geri')),
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
                        _step == _totalSteps - 1 ? context.tr('Tamamla') : context.tr('İleri'),
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
          _stepTitle(context.tr('Temel Bilgiler'), theme),
          _stepSubtitle(
              context.tr('Kalori ve makro hedefleriniz bu bilgilere göre hesaplanır.'),
              theme),
          const SizedBox(height: 20),
          _field(context.tr('Ad Soyad'), _nameCtrl, theme,
              hint: context.tr('Adınız ve soyadınız'),
              action: TextInputAction.next),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _field(context.tr('Yaş'), _ageCtrl, theme,
                    hint: '25',
                    keyboard: TextInputType.number,
                    action: TextInputAction.next)),
            const SizedBox(width: 10),
            Expanded(
                child: _field(context.tr('Boy (cm)'), _heightCtrl, theme,
                    hint: '170',
                    keyboard: TextInputType.number,
                    action: TextInputAction.next)),
            const SizedBox(width: 10),
            Expanded(
                child: _field(context.tr('Kilo (kg)'), _weightCtrl, theme,
                    hint: '70', keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          _stepLabel(context.tr('Cinsiyet'), theme),
          const SizedBox(height: 8),
          Row(children: [
            _genderBtn(context.tr('Erkek'), Gender.male, '♂', theme, primary),
            const SizedBox(width: 10),
            _genderBtn(context.tr('Kadın'), Gender.female, '♀', theme, primary),
          ]),
          const SizedBox(height: 20),
          _stepLabel(context.tr('Aktivite Seviyesi'), theme),
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
            items: [
              DropdownMenuItem(
                  value: ActivityLevel.sedentary,
                  child: Text(context.tr('Hareketsiz (masa başı)'))),
              DropdownMenuItem(
                  value: ActivityLevel.light,
                  child: Text(context.tr('Az Hareketli (haftada 1-3)'))),
              DropdownMenuItem(
                  value: ActivityLevel.moderate,
                  child: Text(context.tr('Orta (haftada 3-5)'))),
              DropdownMenuItem(
                  value: ActivityLevel.active,
                  child: Text(context.tr('Çok Aktif (haftada 6-7)'))),
              DropdownMenuItem(
                  value: ActivityLevel.veryActive,
                  child: Text(context.tr('Sporcu (günde 2x antrenman)'))),
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
          _stepTitle(context.tr('Hedefiniz'), theme),
          _stepSubtitle(
              context.tr('Makro dağılımı ve öneriler seçtiğiniz hedefe göre kişiselleşir.'),
              theme),
          const SizedBox(height: 16),
          _sectionLabel(context.tr('Temel Hedefler'), theme),
          const SizedBox(height: 8),
          _goalTile('🎯', context.tr('Kilo Ver'), false,
              selected: _advancedGoal == null && _goal == Goal.lose,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.lose;
              _advancedGoal = null;
            });
          }),
          _goalTile('⚖️', context.tr('Kilonu Koru'), false,
              selected: _advancedGoal == null && _goal == Goal.maintain,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.maintain;
              _advancedGoal = null;
            });
          }),
          _goalTile('📈', context.tr('Kilo Al'), false,
              selected: _advancedGoal == null && _goal == Goal.gain,
              theme: theme, primary: primary, onTap: () {
            setState(() {
              _goal = Goal.gain;
              _advancedGoal = null;
            });
          }),
          const SizedBox(height: 16),
          _sectionLabel(context.tr('Gelişmiş Hedefler'), theme),
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
          _stepTitle(context.tr('Sağlık Profili'), theme),
          _stepSubtitle(
              context.tr('Besin hedefleri ve öneriler sağlık durumunuza göre kişiselleşir. Uygulanabilecek olanları seçin.'),
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
          _stepTitle(context.tr('Beslenme Tercihleri'), theme),
          _stepSubtitle(
              context.tr('Öneriler ve uyarılar tercihlerinize göre filtrelenir.'),
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
      final bmr = UserProfile.calculateBmr(
        weight: weight,
        height: height,
        age: age,
        gender: _gender,
      );
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
          _stepTitle(context.tr('Özet'), theme),
          _stepSubtitle(context.tr('Her şey doğru görünüyor mu? Onaylayın.'), theme),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow(context.tr('Ad Soyad'), name, theme),
                  _summaryRow(
                      context.tr('Yaş / Boy / Kilo'),
                      '$age / ${height.toStringAsFixed(0)} cm / ${weight.toStringAsFixed(1)} kg',
                      theme),
                  _summaryRow(context.tr('Cinsiyet'),
                      _gender == Gender.male ? context.tr('Erkek') : context.tr('Kadın'), theme),
                  _summaryRow(context.tr('Hedef'), context.tr(goalLabel), theme),
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
                      Text(context.tr('Günlük Kalori Hedefi'),
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
                    Text(context.tr('Sağlık Koşulları'),
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
                    Text(context.tr('Beslenme Tercihleri'),
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


// ─── Beslenme Skoru & Besin Karnesi (artık kullanılmıyor — Dashboard'a taşındı) ───
// ignore: unused_element
class _ProfileNutritionSection extends StatelessWidget {
  const _ProfileNutritionSection();

  @override
  Widget build(BuildContext context) {
    return Consumer2<NutritionProvider, ProfileProvider>(
      builder: (context, nutrition, profile, _) {
        final today = DateTime.now();
        final log = nutrition.getLogForDate(today);
        final n = log?.totalNutrition ?? NutritionData.empty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNutritionScore(context, n, profile),
            const SizedBox(height: 8),
            _buildBesinKarnesi(context, n, profile),
          ],
        );
      },
    );
  }

  double _calcNutritionScore(NutritionData n, ProfileProvider pp) {
    final profile = pp.activeProfile;
    if (profile == null || pp.calorieGoal <= 0) return 0;

    double score(double consumed, double goal) {
      if (goal <= 0) return 100;
      return (consumed / goal).clamp(0.0, 1.0) * 100;
    }

    double scoreInverse(double consumed, double limit) {
      if (limit <= 0) return 100;
      return ((1 - consumed / limit).clamp(0.0, 1.0)) * 100;
    }

    final calScore = score(n.calories, pp.calorieGoal) * 0.20;
    final protScore = score(n.protein, pp.proteinGoal) * 0.20;
    final carbScore = score(n.carbohydrates, pp.carbGoal) * 0.10;
    final fatScore = score(n.fat, pp.fatGoal) * 0.10;

    final micros = [
      score(n.selenium ?? 0, profile.seleniumGoal),
      score(n.magnesium ?? 0, profile.magnesiumGoal),
      score(n.omega3 ?? 0, profile.omega3Goal),
      score(n.iron ?? 0, profile.ironGoal),
      score(n.zinc ?? 0, profile.zincGoal),
      score(n.vitaminD ?? 0, profile.vitaminDGoal),
      score(n.calcium ?? 0, profile.calciumGoal),
      scoreInverse(n.sodium ?? 0, profile.sodiumLimit),
    ];
    final microScore = micros.reduce((a, b) => a + b) / micros.length * 0.40;

    return (calScore + protScore + carbScore + fatScore + microScore)
        .clamp(0.0, 100.0);
  }

  Widget _buildNutritionScore(
      BuildContext context, NutritionData nutrition, ProfileProvider pp) {
    final score = _calcNutritionScore(nutrition, pp);
    final colorScheme = Theme.of(context).colorScheme;
    final Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF58A6FF);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFF0A500);
    } else {
      scoreColor = colorScheme.error;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Text(
                    score.toInt().toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Beslenme Skoru'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    score >= 80
                        ? context.tr('Harika gidiyorsunuz!')
                        : score >= 50
                            ? context.tr('Eksik besinleriniz var')
                            : context.tr('Beslenmenizi geliştirin'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildBesinKarnesi(
      BuildContext context, NutritionData n, ProfileProvider pp) {
    final profile = pp.activeProfile;
    if (profile == null) return const SizedBox.shrink();

    final items = <_MicroItem>[
      _MicroItem(context.tr('Selenyum'), n.selenium, profile.seleniumGoal, 'μg'),
      _MicroItem(context.tr('Magnezyum'), n.magnesium, profile.magnesiumGoal, 'mg'),
      _MicroItem(context.tr('Omega-3'), n.omega3, profile.omega3Goal, 'g'),
      _MicroItem(context.tr('Omega-6'), n.omega6, profile.omega6Goal, 'g'),
      _MicroItem(context.tr('Demir'), n.iron, profile.ironGoal, 'mg'),
      _MicroItem(context.tr('Çinko'), n.zinc, profile.zincGoal, 'mg'),
      _MicroItem(context.tr('D Vitamini'), n.vitaminD, profile.vitaminDGoal, 'μg'),
      _MicroItem(context.tr('B12 Vitamini'), n.vitaminB12, profile.vitaminB12Goal, 'μg'),
      _MicroItem(context.tr('Kalsiyum'), n.calcium, profile.calciumGoal, 'mg'),
      _MicroItem(context.tr('Potasyum'), n.potassium, profile.potassiumGoal, 'mg'),
      if (profile.fiberGoal > 0)
        _MicroItem(context.tr('Lif'), n.fiber, profile.fiberGoal, 'g'),
      _MicroItem(context.tr('Sodyum'), n.sodium, profile.sodiumLimit, 'mg',
          isMaxNutrient: true),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                context.tr('Besin Karnesi'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: items.map((item) => _buildMicroRow(context, item)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroRow(BuildContext context, _MicroItem item) {
    final consumed = item.consumed ?? 0;
    final ratio = item.goal > 0
        ? (item.isMaxNutrient
            ? (1 - consumed / item.goal).clamp(0.0, 1.0)
            : (consumed / item.goal).clamp(0.0, 1.0))
        : 0.0;

    final Color barColor;
    final String statusIcon;
    if (ratio >= 0.8) {
      barColor = const Color(0xFF58A6FF);
      statusIcon = '✓';
    } else if (ratio >= 0.5) {
      barColor = const Color(0xFFF0A500);
      statusIcon = '!';
    } else {
      barColor = Theme.of(context).colorScheme.error;
      statusIcon = '✗';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(item.label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusIcon,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: Text(
              item.consumed != null
                  ? '${consumed.toStringAsFixed(item.unit == 'g' || item.unit == 'μg' ? 1 : 0)} ${item.unit}'
                  : '— ${item.unit}',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroItem {
  final String label;
  final double? consumed;
  final double goal;
  final String unit;
  final bool isMaxNutrient;

  const _MicroItem(this.label, this.consumed, this.goal, this.unit,
      {this.isMaxNutrient = false});
}

// ─── Profile Edit Sheet ───────────────────────────────────────────────────────

class _ProfileEditSheet extends StatefulWidget {
  final UserProfile profile;
  const _ProfileEditSheet({required this.profile});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late Gender _gender;
  late Goal _goal;

  // Track original values to detect unsaved changes
  late String _origName;
  late String _origWeight;
  late String _origHeight;
  late String _origAge;
  late Gender _origGender;
  late Goal _origGoal;

  bool get _hasChanges =>
      _nameCtrl.text != _origName ||
      _weightCtrl.text != _origWeight ||
      _heightCtrl.text != _origHeight ||
      _ageCtrl.text != _origAge ||
      _gender != _origGender ||
      _goal != _origGoal;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.name);
    _weightCtrl = TextEditingController(text: p.weight.toStringAsFixed(1));
    _heightCtrl = TextEditingController(text: p.height.toStringAsFixed(0));
    _ageCtrl = TextEditingController(text: p.age.toString());
    _gender = p.gender;
    _goal = p.goal;
    // Store originals
    _origName = p.name;
    _origWeight = p.weight.toStringAsFixed(1);
    _origHeight = p.height.toStringAsFixed(0);
    _origAge = p.age.toString();
    _origGender = p.gender;
    _origGoal = p.goal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  // Returns: 'save', 'discard', or null (stay)
  Future<String?> _confirmDiscard() async {
    if (!_hasChanges) return 'discard';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Değişiklikler Kaydedilmedi')),
        content: Text(context.tr('Değişikliklerinizi kaydetmek istiyor musunuz?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(context.tr('İptal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(context.tr('Kaydet')),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final p = widget.profile;
    await context.read<ProfileProvider>().save(
          profileId: p.id,
          name: _nameCtrl.text.trim().isEmpty ? p.name : _nameCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text) ?? p.age,
          height: double.tryParse(_heightCtrl.text) ?? p.height,
          weight: double.tryParse(_weightCtrl.text) ?? p.weight,
          gender: _gender,
          activityLevel: p.activityLevel,
          goal: _goal,
          advancedGoal: p.advancedGoal,
          healthConditions: p.healthConditions,
          dietaryPreferences: p.dietaryPreferences,
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Profil güncellendi!')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _confirmDiscard();
        if (!context.mounted) return;
        if (action == 'save') {
          await _save();
        } else if (action == 'discard') {
          Navigator.pop(context);
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(context.tr('Hesabı Düzenle'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                   Container(
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: _save,
                      child: Text(context.tr('Kaydet'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Field rows
            _buildFieldRow(
              context,
              label: context.tr('Ad Soyad'),
              child: _inlineTextField(_nameCtrl, TextInputType.name),
            ),
            const Divider(height: 1, indent: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showNumberPicker(
                  context,
                  label: context.tr('Mevcut Kilo'),
                  unit: 'kg',
                  values: [for (double i = 40.0; i <= 200.0; i += 0.1) i],
                  initial: (double.tryParse(_weightCtrl.text) ?? 70).toDouble(),
                  onSelected: (v) => setState(
                      () => _weightCtrl.text = v.toStringAsFixed(1)),
                ),
                child: _buildFieldRow(
                  context,
                  label: context.tr('Mevcut Kilo'),
                  child: Text(
                    '${_weightCtrl.text} kg',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showNumberPicker(
                  context,
                  label: context.tr('Boy'),
                  unit: 'cm',
                  values: [for (int i = 100; i <= 230; i++) i],
                  initial: (double.tryParse(_heightCtrl.text) ?? 170).round(),
                  onSelected: (v) =>
                      setState(() => _heightCtrl.text = v.toInt().toString()),
                ),
                child: _buildFieldRow(
                  context,
                  label: context.tr('Boy'),
                  child: Text(
                    '${_heightCtrl.text} cm',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showNumberPicker(
                  context,
                  label: context.tr('Yaş'),
                  unit: context.tr('yaş'),
                  values: [for (int i = 10; i <= 100; i++) i],
                  initial: int.tryParse(_ageCtrl.text) ?? 25,
                  onSelected: (v) =>
                      setState(() => _ageCtrl.text = v.toInt().toString()),
                ),
                child: _buildFieldRow(
                  context,
                  label: context.tr('Yaş'),
                  child: Text(
                    _ageCtrl.text,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 20),
            _buildFieldRow(
              context,
              label: context.tr('Cinsiyet'),
              showEditIcon: false,
              child: _GenderToggle(
                value: _gender,
                onChanged: (g) => setState(() => _gender = g),
              ),
            ),
            const Divider(height: 1, indent: 20),
            _buildFieldRow(
              context,
              label: context.tr('Hedef'),
              showEditIcon: false,
              child: _GoalSelector(
                value: _goal,
                onChanged: (g) => setState(() => _goal = g),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ), // Container
    ); // PopScope
  }

  void _showNumberPicker<T extends num>(
    BuildContext context, {
    required String label,
    required String unit,
    required List<T> values,
    required T initial,
    required ValueChanged<T> onSelected,
  }) {
    int idx = values.indexOf(initial);
    if (idx == -1) {
      // Find closest match for double types
      double target = initial.toDouble();
      double minDiff = double.infinity;
      for (int i = 0; i < values.length; i++) {
        double d = (values[i].toDouble() - target).abs();
        if (d < minDiff) {
          minDiff = d;
          idx = i;
        }
      }
    }
    idx = idx.clamp(0, values.length - 1);
    final ctrl = FixedExtentScrollController(initialItem: idx);
    T picked = values[idx];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                scrollController: ctrl,
                itemExtent: 40,
                onSelectedItemChanged: (i) => picked = values[i],
                children: values
                    .map((v) => Center(
                          child: Text(
                              v is double
                                  ? '${v.toStringAsFixed(1)} $unit'
                                  : '$v $unit',
                              style: const TextStyle(fontSize: 20)),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    onSelected(picked);
                    Navigator.pop(context);
                  },
                  child: Text(context.tr('Tamam')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context,
      {required String label,
      required Widget child,
      bool showEditIcon = true}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 15, color: cs.onSurface)),
          const Spacer(),
          child,
          if (showEditIcon) ...[
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
          ],
        ],
      ),
    );
  }

  Widget _inlineTextField(TextEditingController ctrl, TextInputType keyboard,
      {double width = 90}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final Gender value;
  final ValueChanged<Gender> onChanged;
  const _GenderToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(context, context.tr('Erkek'), Gender.male, cs),
        const SizedBox(width: 6),
        _chip(context, context.tr('Kadın'), Gender.female, cs),
        const SizedBox(width: 6),
        _chip(context, context.tr('Belirtmek İstemiyorum'), Gender.other, cs),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, Gender g, ColorScheme cs) {
    final selected = value == g;
    return GestureDetector(
      onTap: () => onChanged(g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _GoalSelector extends StatelessWidget {
  final Goal value;
  final ValueChanged<Goal> onChanged;
  const _GoalSelector({required this.value, required this.onChanged});

  static Map<Goal, String> _labels(BuildContext context) => {
    Goal.lose: context.tr('Kilo Ver'),
    Goal.maintain: context.tr('Koru'),
    Goal.gain: context.tr('Kilo Al'),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: Goal.values.map((g) {
        final selected = value == g;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onChanged(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labels(context)[g]!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Goals Card ───────────────────────────────────────────────────────────────

class _GoalsCard extends StatelessWidget {
  final ProfileProvider profileProvider;
  const _GoalsCard({required this.profileProvider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pp = profileProvider;

    Widget goalRow(String label, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.7))),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_outlined,
                    size: 18, color: Color(0xFF58A6FF)),
                const SizedBox(width: 8),
                Text(context.tr('Günlük Hedefler'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            goalRow(context.tr('Kalori'),
                '${pp.calorieGoal.toStringAsFixed(0)} kcal',
                const Color(0xFFFF6B35)), // Orange
            const Divider(height: 1),
            goalRow(context.tr('Protein'), '${pp.proteinGoal.toStringAsFixed(0)} g',
                const Color(0xFF7EE787)), // Green
            const Divider(height: 1),
            goalRow(context.tr('Karbonhidrat'),
                '${pp.carbGoal.toStringAsFixed(0)} g',
                const Color(0xFF58A6FF)),
            const Divider(height: 1),
            goalRow(context.tr('Yağ'), '${pp.fatGoal.toStringAsFixed(0)} g',
                const Color(0xFFFFA726)),
            const Divider(height: 1),
            goalRow(context.tr('Lif'), '${pp.fiberGoal.toStringAsFixed(0)} g',
                const Color(0xFF9B59B6)),
          ],
        ),
      ),
    );
  }
}

// ─── Değer Karnesi Card ───────────────────────────────────────────────────────

class _BesinKarnesiCard extends StatelessWidget {
  final NutritionData nutrition;
  final NutritionData65? nutrition65;
  final ProfileProvider profileProvider;
  const _BesinKarnesiCard({
    required this.nutrition,
    required this.profileProvider,
    this.nutrition65,
  });

  double _calcScore() {
    final pp = profileProvider;
    final profile = pp.activeProfile;
    if (profile == null || pp.calorieGoal <= 0) return 0;
    double s(double c, double g) =>
        g <= 0 ? 100 : (c / g).clamp(0.0, 1.0) * 100;
    double si(double c, double l) =>
        l <= 0 ? 100 : ((1 - c / l).clamp(0.0, 1.0)) * 100;
    final cal = s(nutrition.calories, pp.calorieGoal) * 0.20;
    final prot = s(nutrition.protein, pp.proteinGoal) * 0.20;
    final carb = s(nutrition.carbohydrates, pp.carbGoal) * 0.10;
    final fat = s(nutrition.fat, pp.fatGoal) * 0.10;
    final micros = [
      s(nutrition.selenium ?? 0, profile.seleniumGoal),
      s(nutrition.magnesium ?? 0, profile.magnesiumGoal),
      s(nutrition.omega3 ?? 0, profile.omega3Goal),
      s(nutrition.iron ?? 0, profile.ironGoal),
      s(nutrition.zinc ?? 0, profile.zincGoal),
      s(nutrition.vitaminD ?? 0, profile.vitaminDGoal),
      s(nutrition.calcium ?? 0, profile.calciumGoal),
      si(nutrition.sodium ?? 0, profile.sodiumLimit),
    ];
    final micro =
        micros.reduce((a, b) => a + b) / micros.length * 0.40;
    return (cal + prot + carb + fat + micro).clamp(0.0, 100.0);
  }

  void _showDetail(
      BuildContext context, double score, Color scoreColor) {
    final pp = profileProvider;
    final profile = pp.activeProfile;
    final cs = Theme.of(context).colorScheme;
    final n65 = nutrition65;

    double pct(double c, double g) => (c <= 0) ? 0.0 : (g <= 0 ? 1.0 : (c / g).clamp(0.0, 1.0));

    String fmtG(double v, [int d = 1]) => '${v.toStringAsFixed(d)} g';
    String fmtMg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mg';
    String fmtMcg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mcg';
    String fmtKcal(double v) => '${v.toStringAsFixed(0)} kcal';

    _NutrientItem row(String icon, String label, String value, double p, Color c) =>
        _NutrientItem(icon, label, value, p, c);

    // List<Object>: either _SectionHeader or _NutrientItem
    final items = <Object>[];

    // ── MAKROLAR ─────────────────────────────────────────────────────────────
    items.add(_SectionHeader(context.tr('⚡ Makrolar')));
    items.add(row('🔥', context.tr('Kalori'), fmtKcal(nutrition.calories),
        pct(nutrition.calories, pp.calorieGoal), const Color(0xFFFF6B35)));
    items.add(row('🍗', context.tr('Protein'), fmtG(nutrition.protein),
        pct(nutrition.protein, pp.proteinGoal), const Color(0xFF7EE787)));
    items.add(row('🌾', context.tr('Karbonhidrat'), fmtG(nutrition.carbohydrates),
        pct(nutrition.carbohydrates, pp.carbGoal), const Color(0xFF58A6FF)));
    items.add(row('🧈', context.tr('Yağ'), fmtG(nutrition.fat),
        pct(nutrition.fat, pp.fatGoal), const Color(0xFFFFA726)));
    if (profile != null) {
      items.add(row('🫁', context.tr('Lif'), fmtG(nutrition.fiber),
          pct(nutrition.fiber, profile.fiberGoal), const Color(0xFF9B59B6)));
    }
    if (n65 != null) {
      items.add(row('🐓', context.tr('Kolesterol'), fmtMg(n65.cholesterol),
          pct(n65.cholesterol, 300.0), const Color(0xFFFF9F0A)));
      items.add(row('💧', context.tr('Su'), fmtG(n65.water),
          pct(n65.water, 50.0), const Color(0xFF64D2FF)));
    }

    // ── MİNERALLER ───────────────────────────────────────────────────────────
    if (n65 != null) {
      items.add(_SectionHeader(context.tr('💎 Mineraller')));
      final caG  = profile?.calciumGoal   ?? 1000.0;
      final feG  = profile?.ironGoal      ?? 14.0;
      final mgG  = profile?.magnesiumGoal ?? 350.0;
      final znG  = profile?.zincGoal      ?? 10.0;
      final kG   = profile?.potassiumGoal ?? 4700.0;
      final naL  = profile?.sodiumLimit   ?? 2300.0;
      final seG  = profile?.seleniumGoal  ?? 55.0;
      items.add(row('🦴', context.tr('Kalsiyum'),   fmtMg(n65.calcium),    pct(n65.calcium,    caG),  const Color(0xFF1ABC9C)));
      items.add(row('🩸', context.tr('Demir'),      fmtMg(n65.iron),       pct(n65.iron,       feG),  const Color(0xFFE74C3C)));
      items.add(row('⚡', context.tr('Magnezyum'),  fmtMg(n65.magnesium),  pct(n65.magnesium,  mgG),  const Color(0xFF0A84FF)));
      items.add(row('🔵', context.tr('Fosfor'),     fmtMg(n65.phosphorus), pct(n65.phosphorus, 700.0),const Color(0xFF5856D6)));
      items.add(row('🫀', context.tr('Potasyum'),   fmtMg(n65.potassium),  pct(n65.potassium,  kG),   const Color(0xFFFF9F0A)));
      items.add(row('🧂', context.tr('Sodyum'),     fmtMg(n65.sodium),     pct(n65.sodium,  naL),  const Color(0xFFD4A017)));
      items.add(row('🔩', context.tr('Çinko'),      fmtMg(n65.zinc),       pct(n65.zinc,       znG),  const Color(0xFF64D2FF)));
      items.add(row('🔶', context.tr('Bakır'),      fmtMg(n65.copper),     pct(n65.copper,     0.9),  const Color(0xFFBF5AF2)));
      items.add(row('🔘', context.tr('Manganez'),   fmtMg(n65.manganese),  pct(n65.manganese,  2.3),  const Color(0xFF8E8E93)));
      items.add(row('🌟', context.tr('Selenyum'),   fmtMcg(n65.selenium),  pct(n65.selenium,   seG),  const Color(0xFFFFCC00)));
      if (n65.iodine > 0)
        items.add(row('💧', context.tr('İyot'),     fmtMcg(n65.iodine),    pct(n65.iodine,     150.0),const Color(0xFF30B0C7)));
      if (n65.chromium > 0)
        items.add(row('🔷', context.tr('Krom'),     fmtMcg(n65.chromium),  pct(n65.chromium,   35.0), const Color(0xFF636366)));
      if (n65.molybdenum > 0)
        items.add(row('⚙️', context.tr('Molibden'), fmtMcg(n65.molybdenum),pct(n65.molybdenum, 45.0), const Color(0xFF8E8E93)));

      // ── VİTAMİNLER ─────────────────────────────────────────────────────────
      items.add(_SectionHeader(context.tr('🌈 Vitaminler')));
      final vdG   = profile?.vitaminDGoal  ?? 15.0;
      final vb12G = profile?.vitaminB12Goal ?? 2.4;
      items.add(row('🍊', context.tr('C Vitamini'),        fmtMg(n65.vitC),      pct(n65.vitC,      90.0),  const Color(0xFFFF9F0A)));
      items.add(row('☀️', context.tr('D Vitamini'),        fmtMcg(n65.vitD_mcg), pct(n65.vitD_mcg,  vdG),   const Color(0xFFF39C12)));
      items.add(row('🥑', context.tr('E Vitamini'),        fmtMg(n65.vitE),      pct(n65.vitE,      15.0),  const Color(0xFF58A6FF)));
      items.add(row('🥬', context.tr('K Vitamini'),        fmtMcg(n65.vitK),     pct(n65.vitK,      120.0), const Color(0xFF34C759)));
      items.add(row('🥕', context.tr('A Vitamini (RAE)'),  fmtMcg(n65.vitA_RAE), pct(n65.vitA_RAE,  900.0), const Color(0xFFFF6B35)));
      items.add(row('🌾', context.tr('B1 (Tiamin)'),       fmtMg(n65.thiamine),  pct(n65.thiamine,  1.2),   const Color(0xFFBF5AF2)));
      items.add(row('🥛', context.tr('B2 (Riboflavin)'),   fmtMg(n65.riboflavin),pct(n65.riboflavin,1.3),   const Color(0xFFFF2D55)));
      items.add(row('🐟', context.tr('B3 (Niasin)'),       fmtMg(n65.niacin),    pct(n65.niacin,    16.0),  const Color(0xFF0A84FF)));
      items.add(row('🥦', context.tr('B5 (Pantotenik)'),   fmtMg(n65.pantothenic),pct(n65.pantothenic,5.0), const Color(0xFF5856D6)));
      items.add(row('🐔', context.tr('B6 Vitamini'),       fmtMg(n65.vitB6),     pct(n65.vitB6,     1.7),   const Color(0xFF64D2FF)));
      items.add(row('🌿', context.tr('Folat'),             fmtMcg(n65.folate),   pct(n65.folate,    400.0), const Color(0xFF58A6FF)));
      items.add(row('🥩', context.tr('B12 Vitamini'),      fmtMcg(n65.vitB12),   pct(n65.vitB12,    vb12G), const Color(0xFFE74C3C)));
      if (n65.choline > 0)
        items.add(row('🧠', context.tr('Kolin'),  fmtMg(n65.choline),  pct(n65.choline,  550.0), const Color(0xFFFF9F0A)));
      if (n65.biotin > 0)
        items.add(row('💊', context.tr('Biotin'), fmtMcg(n65.biotin),  pct(n65.biotin,   30.0),  const Color(0xFFBF5AF2)));

      // ── YAĞ ASİTLERİ ───────────────────────────────────────────────────────
      items.add(_SectionHeader(context.tr('🐠 Yağ Asitleri')));
      final o3G = profile?.omega3Goal ?? 1.6;
      final o6G = profile?.omega6Goal ?? 17.0;
      items.add(row('🐟', context.tr('Omega-3'),         fmtG(n65.omega3), pct(n65.omega3,  o3G),  const Color(0xFF0A84FF)));
      items.add(row('🌻', context.tr('Omega-6'),         fmtG(n65.omega6), pct(n65.omega6,  o6G),  const Color(0xFFFF9F0A)));
      if (n65.epa > 0)
        items.add(row('🦈', context.tr('EPA'),           fmtG(n65.epa, 2), pct(n65.epa,    0.25), const Color(0xFF30B0C7)));
      if (n65.dha > 0)
        items.add(row('🐬', context.tr('DHA'),           fmtG(n65.dha, 2), pct(n65.dha,    0.25), const Color(0xFF5856D6)));
      items.add(row('🥑', context.tr('ALA'),             fmtG(n65.ala, 2), pct(n65.ala,    1.6),  const Color(0xFF58A6FF)));
      items.add(row('🍳', context.tr('Doymuş Yağ'),      fmtG(n65.satFat), pct(n65.satFat, 20.0), const Color(0xFFFF6B35)));
      items.add(row('🫒', context.tr('Tekli Doymamış'),  fmtG(n65.monoFat),pct(n65.monoFat, 25.0), const Color(0xFF34C759)));

      // ── AMİNO ASİTLER ──────────────────────────────────────────────────────
      if (n65.leucine > 0 || n65.lysine > 0) {
        items.add(_SectionHeader(context.tr('🧬 Amino Asitler')));
        void aa(String i, String l, double v, double ref, Color c) {
          if (v > 0) items.add(row(i, l, fmtG(v, 2), pct(v, ref), c));
        }
        aa('💪', context.tr('Lösin'),       n65.leucine,      2.7,  const Color(0xFF58A6FF));
        aa('🔗', context.tr('Lizin'),       n65.lysine,       2.1,  const Color(0xFF0A84FF));
        aa('🏃', context.tr('Valin'),       n65.valine,       1.8,  const Color(0xFFFF9F0A));
        aa('⚡', context.tr('İzolösin'),    n65.isoleucine,   1.4,  const Color(0xFFBF5AF2));
        aa('🌱', context.tr('Treonin'),     n65.threonine,    1.0,  const Color(0xFF5856D6));
        aa('🔸', context.tr('Metionin'),    n65.methionine,   0.7,  const Color(0xFFFF6B35));
        aa('🔹', context.tr('Fenilalanin'), n65.phenylalanine,1.4,  const Color(0xFF64D2FF));
        aa('😴', context.tr('Triptofan'),   n65.tryptophan,   0.28, const Color(0xFFFF2D55));
        aa('🔬', context.tr('Histidin'),    n65.histidine,    0.7,  const Color(0xFFD4A017));
        aa('🧪', context.tr('Sistin'),      n65.cystine,      0.5,  const Color(0xFF636366));
        aa('🌀', context.tr('Tirozin'),     n65.tyrosine,     1.1,  const Color(0xFF8E8E93));
      }
    } else {
      // Fallback: show what NutritionData has
      if (profile != null) {
        items.add(_SectionHeader(context.tr('💊 Mikro Besinler')));
        items.add(row('🩸', context.tr('Demir'),      fmtMg(nutrition.iron ?? 0),
            pct(nutrition.iron ?? 0, profile.ironGoal), const Color(0xFFE74C3C)));
        items.add(row('☀️', context.tr('D Vitamini'), fmtMcg(nutrition.vitaminD ?? 0),
            pct(nutrition.vitaminD ?? 0, profile.vitaminDGoal), const Color(0xFFF39C12)));
        items.add(row('🦴', context.tr('Kalsiyum'),   fmtMg(nutrition.calcium ?? 0),
            pct(nutrition.calcium ?? 0, profile.calciumGoal), const Color(0xFF1ABC9C)));
        items.add(row('🧂', context.tr('Sodyum'),     fmtMg(nutrition.sodium ?? 0),
            pct(nutrition.sodium ?? 0, profile.sodiumLimit), const Color(0xFFD4A017)));
        if (nutrition.magnesium != null)
          items.add(row('⚡', context.tr('Magnezyum'), fmtMg(nutrition.magnesium!),
              pct(nutrition.magnesium!, profile.magnesiumGoal), const Color(0xFF0A84FF)));
        if (nutrition.zinc != null)
          items.add(row('🔩', context.tr('Çinko'),    fmtMg(nutrition.zinc!),
              pct(nutrition.zinc!, profile.zincGoal), const Color(0xFF64D2FF)));
        if (nutrition.vitaminC != null)
          items.add(row('🍊', context.tr('C Vitamini'), fmtMg(nutrition.vitaminC!),
              pct(nutrition.vitaminC!, 90.0), const Color(0xFFFF9F0A)));
        if (nutrition.vitaminB12 != null)
          items.add(row('🥩', context.tr('B12 Vitamini'), fmtMcg(nutrition.vitaminB12!),
              pct(nutrition.vitaminB12!, profile.vitaminB12Goal), const Color(0xFFE74C3C)));
        if (nutrition.potassium != null)
          items.add(row('🫀', context.tr('Potasyum'),  fmtMg(nutrition.potassium!),
              pct(nutrition.potassium!, profile.potassiumGoal), const Color(0xFFFF9F0A)));
        if (nutrition.omega3 != null)
          items.add(row('🐟', context.tr('Omega-3'),   fmtG(nutrition.omega3!),
              pct(nutrition.omega3!, profile.omega3Goal), const Color(0xFF0A84FF)));
        if (nutrition.selenium != null)
          items.add(row('🌟', context.tr('Selenyum'),  fmtMcg(nutrition.selenium!),
              pct(nutrition.selenium!, profile.seleniumGoal), const Color(0xFFFFCC00)));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 4,
                            backgroundColor: cs.outlineVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                scoreColor),
                          ),
                        ),
                        Text(score.toInt().toString(),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scoreColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Değer Karnesi'),
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (n65 != null)
                          Text('${items.whereType<_NutrientItem>().length} ${context.tr('besin')}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is _SectionHeader) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 6),
                      child: Text(
                        item.title,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            letterSpacing: 0.5),
                      ),
                    );
                  }
                  final r = item as _NutrientItem;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Text(r.icon,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface)),
                                  Text(r.value,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: r.pct >= 0.8
                                              ? r.color
                                              : cs.onSurfaceVariant)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: r.pct,
                                  minHeight: 3,
                                  color: r.color,
                                  backgroundColor:
                                      cs.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = _calcScore();
    final scoreColor = score >= 80
        ? const Color(0xFF58A6FF)
        : score >= 50
            ? const Color(0xFFF0A500)
            : cs.error;

    return GestureDetector(
      onTap: () => _showDetail(context, score, scoreColor),
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 5,
                        backgroundColor: cs.outlineVariant,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Text(score.toInt().toString(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: scoreColor)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Değer Karnesi'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 4,
                        color: scoreColor,
                        backgroundColor: cs.outlineVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      score >= 80
                          ? context.tr('Harika gidiyorsunuz!')
                          : score >= 50
                              ? context.tr('Eksik besinleriniz var')
                              : context.tr('Beslenmenizi geliştirin'),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface
                              .withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Değer Karnesi list item types ───────────────────────────────────────────

class _SectionHeader {
  final String title;
  const _SectionHeader(this.title);
}

class _NutrientItem {
  final String icon;
  final String label;
  final String value;  // display string, e.g. "31.5 g"
  final double pct;    // 0.0–1.0
  final Color color;
  const _NutrientItem(this.icon, this.label, this.value, this.pct, this.color);
}


// ─── Besin Karnesi Accordion Widget ──────────────────────────────────────────

class NutrientKarneWidget extends StatelessWidget {
  final NutritionData65? data65;
  final NutritionData data;
  const NutrientKarneWidget({super.key, required this.data, this.data65});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _nutrientGroup(context.tr('🥩 Makrolar'), [
        _nutrientRow(context.tr('Protein'),       data.protein,                'g',   50),
        _nutrientRow(context.tr('Karbonhidrat'),  data.carbohydrates,          'g',   260),
        _nutrientRow(context.tr('Yağ'),           data.fat,                    'g',   65),
        _nutrientRow(context.tr('Lif'),           data.fiber,                  'g',   28),
        _nutrientRow(context.tr('Şeker'),         data65?.sugar ?? 0,          'g',   50),
        _nutrientRow(context.tr('Doymuş Yağ'),    data65?.satFat ?? 0,         'g',   20),
        _nutrientRow(context.tr('Kolesterol'),    data65?.cholesterol ?? 0,    'mg',  300),
      ]),
      _nutrientGroup(context.tr('🔬 Mineraller'), [
        _nutrientRow(context.tr('Kalsiyum'),   data65?.calcium ?? 0,    'mg',  1000),
        _nutrientRow(context.tr('Demir'),      data65?.iron ?? 0,       'mg',  18),
        _nutrientRow(context.tr('Magnezyum'),  data65?.magnesium ?? 0,  'mg',  420),
        _nutrientRow(context.tr('Fosfor'),     data65?.phosphorus ?? 0, 'mg',  700),
        _nutrientRow(context.tr('Potasyum'),   data65?.potassium ?? 0,  'mg',  4700),
        _nutrientRow(context.tr('Sodyum'),     data65?.sodium ?? 0,     'mg',  2300),
        _nutrientRow(context.tr('Çinko'),      data65?.zinc ?? 0,       'mg',  11),
        _nutrientRow(context.tr('Selenyum'),   data65?.selenium ?? 0,   'mcg', 55),
        _nutrientRow(context.tr('Bakır'),      data65?.copper ?? 0,     'mg',  0.9),
        _nutrientRow(context.tr('Manganez'),   data65?.manganese ?? 0,  'mg',  2.3),
        _nutrientRow(context.tr('İyot'),       data65?.iodine ?? 0,     'mcg', 150),
      ]),
      _nutrientGroup(context.tr('☀️ Vitaminler'), [
        _nutrientRow(context.tr('Vitamin A'),  data65?.vitA_RAE ?? 0,   'mcg', 900),
        _nutrientRow(context.tr('Vitamin C'),  data65?.vitC ?? 0,       'mg',  90),
        _nutrientRow(context.tr('Vitamin D'),  data65?.vitD_mcg ?? 0,   'mcg', 20),
        _nutrientRow(context.tr('Vitamin E'),  data65?.vitE ?? 0,       'mg',  15),
        _nutrientRow(context.tr('Vitamin K'),  data65?.vitK ?? 0,       'mcg', 120),
        _nutrientRow(context.tr('B1'),         data65?.thiamine ?? 0,   'mg',  1.2),
        _nutrientRow(context.tr('B2'),         data65?.riboflavin ?? 0, 'mg',  1.3),
        _nutrientRow(context.tr('B3'),         data65?.niacin ?? 0,     'mg',  16),
        _nutrientRow(context.tr('B6'),         data65?.vitB6 ?? 0,      'mg',  1.7),
        _nutrientRow(context.tr('B12'),        data65?.vitB12 ?? 0,     'mcg', 2.4),
        _nutrientRow(context.tr('Folat'),      data65?.folate ?? 0,     'mcg', 400),
        _nutrientRow(context.tr('Kolin'),      data65?.choline ?? 0,    'mg',  550),
      ]),
      _nutrientGroup(context.tr('🫀 Yağ Asitleri'), [
        _nutrientRow(context.tr('Omega-3'),  data65?.omega3 ?? 0, 'g',  1.6),
        _nutrientRow(context.tr('Omega-6'),  data65?.omega6 ?? 0, 'g',  17),
        _nutrientRow(context.tr('EPA'),      data65?.epa ?? 0,    'g',  0.25),
        _nutrientRow(context.tr('DHA'),      data65?.dha ?? 0,    'g',  0.25),
      ]),
      _nutrientGroup(context.tr('🧬 Amino Asitler'), [
        _nutrientRow(context.tr('Lösin'),       data65?.leucine ?? 0,      'g', 2.7),
        _nutrientRow(context.tr('Lizin'),       data65?.lysine ?? 0,       'g', 2.1),
        _nutrientRow(context.tr('Valin'),       data65?.valine ?? 0,       'g', 1.8),
        _nutrientRow(context.tr('İzolösin'),    data65?.isoleucine ?? 0,   'g', 1.4),
        _nutrientRow(context.tr('Triptofan'),   data65?.tryptophan ?? 0,   'g', 0.28),
        _nutrientRow(context.tr('Metionin'),    data65?.methionine ?? 0,   'g', 0.73),
        _nutrientRow(context.tr('Histidin'),    data65?.histidine ?? 0,    'g', 0.7),
        _nutrientRow(context.tr('Fenilalanin'), data65?.phenylalanine ?? 0,'g', 1.3),
        _nutrientRow(context.tr('Treonin'),     data65?.threonine ?? 0,    'g', 1.0),
      ]),
    ]);
  }
}

Widget _nutrientGroup(String title, List<Widget> rows) => Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              iconColor: cs.onSurface,
              collapsedIconColor: cs.onSurfaceVariant,
              children: rows,
            ),
          ),
        );
      },
    );

Widget _nutrientRow(String label, double value, String unit, double target) {
  final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
  final color = pct >= 1.0
      ? const Color(0xFF58A6FF)
      : pct >= 0.5
          ? const Color(0xFFF0A500)
          : const Color(0xFF58A6FF);
  return Builder(builder: (context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: cs.onSurface))),
        Expanded(
            flex: 2,
            child: Text('${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface))),
        Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('%${(pct * 100).round()}',
                    style: TextStyle(fontSize: 11, color: color)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: cs.outline.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 3,
                  ),
                ),
              ],
            )),
      ]),
    );
  });
}

// ─── Email Report Card ────────────────────────────────────────────────────────

class _EmailReportCard extends StatefulWidget {
  const _EmailReportCard();

  @override
  State<_EmailReportCard> createState() => _EmailReportCardState();
}

class _EmailReportCardState extends State<_EmailReportCard> {
  BuildContext? _loadingDlgCtx;

  void _showLoadingDialog(BuildContext context, String message) {
    _dismissLoadingDialog();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _loadingDlgCtx = ctx;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  void _dismissLoadingDialog() {
    if (_loadingDlgCtx != null && _loadingDlgCtx!.mounted) {
      Navigator.of(_loadingDlgCtx!).pop();
    }
    _loadingDlgCtx = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEmailFlow(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF58A6FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined,
                    color: Color(0xFF58A6FF), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Bilgilerimi Mail ile Gönder'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                        context.tr('Kalori, besin ve adım verilerini e-posta ile al'),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailFlow(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF58A6FF)),
            const SizedBox(width: 10),
            Text(context.tr('Rapor Gönder')),
          ],
        ),
        content: Text(
          context.tr('Kalori, besin değerleri ve adım verileriniz kayıtlı e-posta adresinize gönderilecek. Devam etmek istiyor musunuz?'),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('İptal')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startReauthFlow(context);
            },
            child: Text(context.tr('Devam Et')),
          ),
        ],
      ),
    );
  }

  void _startReauthFlow(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _generateAndUpload(context);
      return;
    }

    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('password')) {
      _showPasswordStep(context);
    } else {
      _generateAndUpload(context);
    }
  }

  void _showPasswordStep(BuildContext context) {
    final ctrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(context.tr('Şifre Doğrulama')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Güvenlik için hesap şifrenizi girin'),
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr('Şifre'),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20),
                    onPressed: () =>
                        setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('İptal')),
            ),
            FilledButton(
              onPressed: () async {
                final password = ctrl.text.trim();
                if (password.isEmpty) return;

                Navigator.pop(ctx);
                _showLoadingDialog(context, context.tr('Güvenlik için doğrulanıyor...'));

                try {
                  final res = await AuthService().reauthenticateWithEmail(password: password);
                  _dismissLoadingDialog();

                  if (!mounted) return;

                  if (res.success) {
                    _generateAndUpload(context);
                  } else {
                    _showError(context, res.errorMessage ?? context.tr('Kimlik doğrulama başarısız.'));
                  }
                } catch (e) {
                  _dismissLoadingDialog();
                  if (!mounted) return;
                  _showError(context, e.toString());
                }
              },
              child: Text(context.tr('Gönder')),
            ),
          ],
        ),
      ),
    );
  }

  void _generateAndUpload(BuildContext context) async {
    _showLoadingDialog(context, context.tr('Rapor oluşturuluyor...'));

    try {
      await context.read<NutritionProvider>().forceCloudSync();

      final profile = context.read<ProfileProvider>().activeProfile;
      if (profile == null) {
        throw Exception(context.tr('Aktif profil bulunamadı.'));
      }
      final dailyLogs = context.read<NutritionProvider>().allLogs;
      final wellnessLogs = context.read<WellnessProvider>().allLogs;

      // Read supplements from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final answersStr = prefs.getString('onboarding_answers');
      List<String> supplements = [];
      if (answersStr != null) {
        try {
          final answers = jsonDecode(answersStr);
          final list = answers['supplements'] as List?;
          if (list != null) {
            supplements = list.cast<String>().toList();
          }
          final other = answers['supplementsOther'] as String?;
          if (other != null && other.trim().isNotEmpty) {
            supplements.add(other.trim());
          }
        } catch (e) {
          debugPrint('Error parsing onboarding supplements: $e');
        }
      }

      final url = await ReportGeneratorService.generateAndUploadReport(
        profile: profile,
        dailyLogs: dailyLogs,
        wellnessLogs: wellnessLogs,
        supplements: supplements,
      );

      _dismissLoadingDialog();
      if (!mounted) return;
      _showSuccessDialog(context, url);
    } catch (e) {
      _dismissLoadingDialog();
      if (!mounted) return;
      _showError(context, e.toString());
    }
  }

  void _showSuccessDialog(BuildContext context, String url) {
    final linkController = TextEditingController(text: url);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34C759)),
            const SizedBox(width: 10),
            Text(context.tr('Rapor Bağlantısı Hazır')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Bağlantıyı kopyalayarak tarayıcınızda açabilir ve raporunuzu inceleyebilirsiniz.'),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: linkController,
              readOnly: true,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Bağlantı kopyalandı!')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('*Bu bağlantı güvenlik nedeniyle 12 saat boyunca geçerlidir.'),
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('İptal')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(url);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Could not launch URL: $e');
              }
            },
            child: Text(context.tr('Tarayıcıda Aç')),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Sleep Score Chart ────────────────────────────────────────────────────────

enum _SleepPeriod { week, month, year }

class _SleepScoreChart extends StatefulWidget {
  final WellnessProvider wellness;
  const _SleepScoreChart({required this.wellness});

  @override
  State<_SleepScoreChart> createState() => _SleepScoreChartState();
}

class _SleepScoreChartState extends State<_SleepScoreChart> {
  _SleepPeriod _period = _SleepPeriod.week;

  Color _scoreColor(double? score, ColorScheme cs) {
    if (score == null) return cs.outline.withValues(alpha: 0.12);
    if (score >= 4.5) return const Color(0xFF3FB950);
    if (score >= 3.5) return const Color(0xFF7EE787);
    if (score >= 2.5) return const Color(0xFFFFCC00);
    if (score >= 1.5) return const Color(0xFFFF8C42);
    return const Color(0xFFF85149);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    // Build chart data depending on period
    List<double?> values;
    List<String> labels;
    int? todayIndex;

    if (_period == _SleepPeriod.week) {
      // Son 7 gün, bugün dahil
      final now = DateTime.now();
      todayIndex = 6;
      values = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return widget.wellness.allLogs[key]?.sleepScore?.toDouble();
      });
      labels = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        if (i == 6) return context.tr('Bugün');
        const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
        return context.tr(days[d.weekday - 1]);
      });
    } else if (_period == _SleepPeriod.month) {
      // Son 30 gün, bugün dahil
      final now = DateTime.now();
      todayIndex = 29;
      values = List.generate(30, (i) {
        final d = now.subtract(Duration(days: 29 - i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return widget.wellness.allLogs[key]?.sleepScore?.toDouble();
      });
      labels = List.generate(30, (i) {
        final d = now.subtract(Duration(days: 29 - i));
        // Requirement: "remove today's date in monthly part"
        return (i == 0 || i % 7 == 0) && (i != 29) ? '${d.day}/${d.month}' : '';
      });
    } else {
      // Last 12 months — monthly average
      final avgs = widget.wellness.sleepAvgForMonths(12);
      values = avgs;
      const monthLabels = [
        'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
      ];
      final now = DateTime.now();
      labels = List.generate(12, (i) {
        final monthIndex = (now.month - 12 + i) % 12;
        return context.tr(monthLabels[monthIndex < 0 ? monthIndex + 12 : monthIndex]);
      });
      todayIndex = 11;
    }

    final nonNull = values.whereType<double>().toList();
    final lineColor = const Color(0xFF7EE787);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Uyku Puanı Grafiği'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              _PeriodChip(label: '7G', selected: _period == _SleepPeriod.week, onTap: () => setState(() => _period = _SleepPeriod.week), cs: cs),
              const SizedBox(width: 6),
              _PeriodChip(label: '1A', selected: _period == _SleepPeriod.month, onTap: () => setState(() => _period = _SleepPeriod.month), cs: cs),
              const SizedBox(width: 6),
              _PeriodChip(label: '1Y', selected: _period == _SleepPeriod.year, onTap: () => setState(() => _period = _SleepPeriod.year), cs: cs),
            ],
          ),
          const SizedBox(height: 16),
          if (nonNull.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(context.tr('Henüz uyku verisi yok'), style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 5,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 0.8),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (val, _) {
                          if ((val - 3).abs() < 0.1 || (val - 5).abs() < 0.1) {
                            return Text(val.toInt().toString(),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurface.withValues(alpha: 0.5)));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (x, _) {
                          final i = x.toInt();
                          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                          final showLabel = _period == _SleepPeriod.week ||
                              (_period == _SleepPeriod.month && labels[i].isNotEmpty) ||
                              _period == _SleepPeriod.year;
                          if (!showLabel) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[i],
                              style: TextStyle(fontSize: 8,
                                color: i == todayIndex ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                                fontWeight: i == todayIndex ? FontWeight.w700 : FontWeight.w400)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final val = rod.toY;
                        // Requirement: "if value is 0.5 show as 0, but if 1 and above show the number"
                        return BarTooltipItem(
                          val <= 0.6 ? '0' : val.toStringAsFixed(1),
                          TextStyle(color: cs.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i] ?? 0.5,
                            color: values[i] == null 
                                ? cs.onSurface.withValues(alpha: 0.1)
                                : _scoreColor(values[i]!, cs).withValues(alpha: i == todayIndex ? 1.0 : 0.7),
                            width: _period == _SleepPeriod.week ? 24 : (_period == _SleepPeriod.month ? 7 : 20), // Reduced width for monthly and annual for better spacing
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 5,
                              color: cs.outlineVariant.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                          y: 3,
                          color: cs.primary.withValues(alpha: 0.08), // Lower visibility
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                      HorizontalLine(
                          y: 5,
                          color: cs.primary.withValues(alpha: 0.25), // Higher than line 3
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : cs.primary,
            ),
          ),
        ),
      );
}

// ─── Weight Chart ──────────────────────────────────────────────────────────────

enum _WeightPeriod { weeks, year }

class _WeightChart extends StatefulWidget {
  final WellnessProvider wellness;
  const _WeightChart({required this.wellness});

  @override
  State<_WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<_WeightChart> {
  _WeightPeriod _period = _WeightPeriod.weeks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    List<double?> values;
    List<String> labels;
    int todayIndex;

    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.activeProfile;
    final startWeight = profile?.startingWeight;
    final startDate = profile?.createdAt;
    final weeklyDelta = profile?.weeklyWeightDelta ?? 0.0;

    if (_period == _WeightPeriod.weeks) {
      final raw = widget.wellness.weightForWeeks(
        8,
        weeklyDelta: weeklyDelta,
        startWeight: startWeight,
        startDate: startDate,
      );
      values = raw.map((r) => r.$1).toList();
      final now = DateTime.now();
      labels = List.generate(8, (i) {
        final d = now.subtract(Duration(days: (7 - i) * 7));
        return i == 7 ? 'Bu H' : '${d.day}/${d.month}';
      });
      todayIndex = 7;
    } else {
      values = widget.wellness.weightAvgForMonths(
        12,
        weeklyDelta: weeklyDelta,
        startWeight: startWeight,
        startDate: startDate,
      );
      const monthLabels = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
      final now = DateTime.now();
      labels = List.generate(12, (i) {
        final idx = (now.month - 12 + i + 12) % 12;
        return monthLabels[idx];
      });
      todayIndex = 11;
    }

    final nonNull = values.whereType<double>().toList();
    // Use the latest logged weight for chart labels if available
    final currentWeight = nonNull.isNotEmpty ? nonNull.last : (profile?.weight ?? 70.0);
    double lowerB5 = (currentWeight / 5).floor() * 5.0;
    double upperB5 = (currentWeight / 5).ceil() * 5.0;
    if (lowerB5 == upperB5) {
      lowerB5 -= 5;
      upperB5 += 5;
    }

    final minVal = nonNull.isEmpty 
        ? lowerB5 
        : [nonNull.reduce((a, b) => a < b ? a : b), lowerB5].reduce((a, b) => a < b ? a : b) - 2;
    final maxVal = nonNull.isEmpty 
        ? upperB5 
        : [nonNull.reduce((a, b) => a > b ? a : b), upperB5].reduce((a, b) => a > b ? a : b) + 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('Kilo Grafiği'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              _PeriodChip(label: '8H', selected: _period == _WeightPeriod.weeks, onTap: () => setState(() => _period = _WeightPeriod.weeks), cs: cs),
              const SizedBox(width: 6),
              _PeriodChip(label: '1Y', selected: _period == _WeightPeriod.year, onTap: () => setState(() => _period = _WeightPeriod.year), cs: cs),
            ],
          ),
          const SizedBox(height: 16),
          if (nonNull.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Icon(Icons.monitor_weight_outlined, size: 36, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(context.tr('Henüz kilo girişi yok'), style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                ],
              ),
            )
          else
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  minY: minVal,
                  maxY: maxVal,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (val, _) {
                          if ((val - lowerB5).abs() < 0.1 || (val - upperB5).abs() < 0.1) {
                            return Text(val.toInt().toString(),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurface.withValues(alpha: 0.5)));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (x, _) {
                          final i = x.toInt();
                          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[i],
                              style: TextStyle(fontSize: 8,
                                color: i == todayIndex ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                                fontWeight: i == todayIndex ? FontWeight.w700 : FontWeight.w400)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(1)} kg',
                          TextStyle(color: cs.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i] ?? currentWeight, // Fallback to onboarding weight
                            color: values[i] == null 
                                ? cs.onSurface.withValues(alpha: 0.1)
                                : cs.primary.withValues(alpha: i == todayIndex ? 1.0 : 0.6),
                            width: _period == _WeightPeriod.weeks ? 24 : 16, // Thicker bars
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                          y: lowerB5,
                          color: cs.primary.withValues(alpha: 0.08), // Match Line 3 of Sleep Chart
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                      HorizontalLine(
                          y: upperB5,
                          color: cs.primary.withValues(alpha: 0.08), // Match Line 3 of Sleep Chart
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showWeightPicker(context),
              icon: const Icon(Icons.monitor_weight_outlined, size: 16),
              label: Text(widget.wellness.weightEnteredThisWeek
                  ? '${context.tr('Bu haftaki kilo:')} ${widget.wellness.thisWeekWeight!.toStringAsFixed(1)} kg'
                  : context.tr('Bu haftanın kilosunu gir')),
              style: FilledButton.styleFrom(
                backgroundColor: widget.wellness.weightEnteredThisWeek
                    ? cs.primary.withValues(alpha: 0.12)
                    : cs.primary,
                foregroundColor: widget.wellness.weightEnteredThisWeek ? cs.primary : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeightPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = widget.wellness.thisWeekWeight ?? 70.0;
    double selected = current;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(context.tr('Bu Haftanın Kilosu'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 48,
                  perspective: 0.003,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(initialItem: ((selected - 30) * 10).round()),
                  onSelectedItemChanged: (i) => setSheetState(() => selected = 30 + i / 10),
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (_, i) {
                      final v = 30 + i / 10;
                      final isSel = ((v - selected).abs() < 0.05);
                      return Center(
                        child: Text(
                          '${v.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: isSel ? 22 : 16,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w400,
                            color: isSel ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    },
                    childCount: 1201, // 30.0 to 150.0 in 0.1 steps
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    await context.read<WellnessProvider>().logWeight(selected);
                    // Sync with profile so info card and goals update
                    final pp = context.read<ProfileProvider>();
                    if (pp.activeProfile != null) {
                      await pp.updateProfile(pp.activeProfile!.copyWith(weight: selected));
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('${selected.toStringAsFixed(1)} kg ${context.tr('Kaydet')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _WeeklyFlowCard extends StatelessWidget {
  final FastingProvider fasting;
  const _WeeklyFlowCard({required this.fasting});

  @override
  Widget build(BuildContext context) {
    final weeklyHours = fasting.getWeeklyFastingHours();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("Haftalık Oruç"),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  context.tr("Son 7 günde tamamlanan toplam süre"),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.tr("TOPLAM"),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFF00BFA5),
                  ),
                ),
                Text(
                  "${weeklyHours.toStringAsFixed(0)} ${context.tr('sa')}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00BFA5), // Brighter teal
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double opacity = ((_controller.value * 3 - index).clamp(0.0, 1.0));
            return Opacity(
              opacity: opacity,
              child: Text(
                '.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
