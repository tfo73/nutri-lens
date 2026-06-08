import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/achievement_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/health_service.dart';
import '../widgets/wave_background.dart';
import 'achievements_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart' show openProfileEditSheet;
import 'package:device_info_plus/device_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  bool _isSendingFeedback = false;
  final TextEditingController _feedbackController = TextEditingController();
  final _authService = AuthService();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingFeedback = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final packageInfo = await PackageInfo.fromPlatform();
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }

      await FirebaseFirestore.instance.collection('feedbacks').add({
        'isim': profileProvider.activeProfile?.name ?? user?.displayName ?? 'İsimsiz Kullanıcı',
        'id': user?.uid ?? 'anonymous',
        'mail': user?.email ?? 'E-posta yok',
        'tarih': FieldValue.serverTimestamp(),
        'versiyon': packageInfo.version,
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'model': deviceModel,
        'osversiyon': osVersion,
        'language': langProvider.isTurkish ? 'Türkçe' : 'English',
        'feedback': text,
      });

      if (!mounted) return;
      _feedbackController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geri bildiriminiz iletildi. Teşekkürler!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingFeedback = false);
    }
  }

  Future<void> _runHealthDiagnosis(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final results = await HealthService.performDeepDiagnosis();

    if (!mounted) return;
    Navigator.pop(context); // close loading

    final perms = results['permissions'] as Map<String, bool>? ?? {};
    final sources = results['sources'] as Map<String, int>? ?? {};

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.troubleshoot, size: 20),
            SizedBox(width: 8),
            Text('Tanılama Sonucu', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _diagRow('SDK Durumu', '${results['sdkStatus'] ?? '?'}'),
              _diagRow('Bugün Adım', '${results['todaySteps'] ?? 0}'),
              _diagRow('7 Gün Adım', '${results['weekSteps'] ?? 0}'),
              _diagRow('7 Gün Veri', '${results['dataCount'] ?? 0}'),
              const Divider(height: 20),
              const Text('İzinler:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ...perms.entries.map((e) => _diagRow(
                e.key, e.value ? '✅' : '❌',
                isError: !e.value,
              )),
              if (sources.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('Veri Kaynakları:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...sources.entries.map((e) => _diagRow(e.key, '${e.value} veri')),
              ],
              if (results['error'] != null) ...[
                const Divider(height: 20),
                Text('Hata: ${results['error']}', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await HealthService.initialize();
              await HealthService.requestPermissions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('İzinler yenilendi. Tekrar deneyin.')),
                );
              }
            },
            child: const Text('İzinleri Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isError ? Colors.red : null,
          )),
        ],
      ),
    );
  }

  // ── Hesap Silme Ana Akışı ──────────────────────────────────────────────────

  Future<void> _handleDeleteAccount() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    final reauth = await _handleReauth();
    if (reauth == null || !mounted) return;
    if (!reauth.success) {
      _showError(reauth.errorMessage ?? 'Kimlik doğrulama başarısız.');
      return;
    }

    setState(() => _isDeleting = true);
    final result = await _authService.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (!result.success) {
      _showError(result.errorMessage ?? 'Hesap silinemedi.');
      return;
    }

    await _clearLocalData();
    if (!mounted) return;
    _navigateToOnboarding();
  }

  Future<AuthResult?> _handleReauth() async {
    final providers = FirebaseAuth.instance.currentUser?.providerData
            .map((p) => p.providerId)
            .toList() ??
        [];

    if (providers.contains('google.com')) {
      return await _authService.reauthenticateWithGoogle();
    }

    final password = await _showPasswordDialog();
    if (password == null || !mounted) return null;

    return await _authService.reauthenticateWithEmail(password: password);
  }

  Future<void> _clearLocalData() async {
    await DatabaseService.instance.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  Future<void> _handleSignOut() async {
    final isAnonymous = FirebaseAuth.instance.currentUser == null ||
        FirebaseAuth.instance.currentUser!.isAnonymous;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAnonymous ? 'Yeni Başlat' : 'Hesaptan Çık'),
        content: Text(
          isAnonymous
              ? 'Mevcut ilerlemeniz temizlenecek ve yeni bir oturum başlayacak.'
              : 'Hesabınızdan çıkmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAnonymous ? 'Başlat' : 'Çık'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Clear onboarding progress and local cache for everyone on logout
    // so the next entry starts from the beginning as requested.
    context.read<ProfileProvider>().clearAll();
    await _clearLocalData();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    _navigateToOnboarding();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // ── Diyaloglar ────────────────────────────────────────────────────────────

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF85149), size: 24),
                SizedBox(width: 10),
                Text(
                  'Hesabı Sil',
                  style: TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Hesabınızı silmek istediğinizden emin misiniz?\n\n'
              'Bu işlem geri alınamaz. Tüm verileriniz silinecek.',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF58A6FF)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF85149),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Hesabı Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool obscure = true;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Güvenlik Doğrulaması',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Güvenlik için şifrenizi girin',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                style: const TextStyle(color: Color(0xFFE6EDF3)),
                decoration: InputDecoration(
                  hintText: 'Şifre',
                  hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF8B949E),
                      size: 20,
                    ),
                    onPressed: () => setLocal(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text(
                'İptal',
                style: TextStyle(color: Color(0xFF58A6FF)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF85149),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
      ),
      body: WaveBackground(child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            children: [
              const SizedBox(height: 8),

              // ── Kişiselleştirme ───────────────────────────────────────
              _SectionLabel(label: 'Kişiselleştirme'),
              _SettingsCard(
                children: [
                  // Hesabı Düzenle
                  GestureDetector(
                    onTap: () {
                      final profile = profileProvider.activeProfile;
                      if (profile != null) {
                        openProfileEditSheet(context, profile);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.manage_accounts_outlined,
                              color: Color(0xFF58A6FF), size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text('Hesabı Düzenle',
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right,
                              color: cs.onSurfaceVariant, size: 20),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Ölçü birimi
                  Row(
                    children: [
                      const Icon(Icons.straighten_outlined,
                          color: Color(0xFF58A6FF), size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Ölçü Birimi',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SegmentedToggle(
                        options: const ['Metrik', 'Imperial'],
                        selectedIndex:
                            profileProvider.useMetricUnits ? 0 : 1,
                        onChanged: (i) =>
                            profileProvider.setUseMetricUnits(i == 0),
                      ),
                    ],
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Mikro besin gösterimi
                  Row(
                    children: [
                      const Icon(Icons.biotech_outlined,
                          color: Color(0xFF58A6FF), size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Mikro Besin Birimi',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SegmentedToggle(
                        options: const ['Değer', '%'],
                        selectedIndex: profileProvider.showMicroPercentage ? 1 : 0,
                        onChanged: (i) =>
                            profileProvider.setShowMicroPercentage(i == 1),
                      ),
                    ],
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Hafta başlangıcı
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: Color(0xFF58A6FF), size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Hafta Başlangıcı',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SegmentedToggle(
                        options: const ['Pazartesi', 'Pazar'],
                        selectedIndex: profileProvider.weekStartDay == 1 ? 0 : 1,
                        onChanged: (i) =>
                            profileProvider.setWeekStartDay(i == 0 ? 1 : 7),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Hedefler ──────────────────────────────────────────────
              _SectionLabel(label: 'Hedefler'),
              _SettingsCard(
                children: [
                  // Besin hedefi
                  GestureDetector(
                    onTap: () => _showNutritionGoalsSheet(context, profileProvider),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant_outlined,
                            color: Color(0xFF58A6FF), size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('Günlük Besin',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Su hedefi
                  GestureDetector(
                    onTap: () => _showWaterPicker(context, profileProvider),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            color: Color(0xFF58A6FF), size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('Günlük Su',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${profileProvider.waterGoalMl} ml',
                          style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Adım hedefi
                  GestureDetector(
                    onTap: () => _showStepPicker(context, profileProvider),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk_outlined,
                            color: Color(0xFF58A6FF), size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('Günlük Adım',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${profileProvider.stepGoal}',
                          style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Rozetler ──────────────────────────────────────────────
              _SectionLabel(label: 'Rozetler'),
              Consumer<AchievementProvider>(
                builder: (ctx, achieveProvider, _) {
                  final earned = achieveProvider.earned;
                  final total = AchievementProvider.achievements.length;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AchievementsScreen()),
                    ),
                    child: _SettingsCard(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_outlined,
                                color: Color(0xFF58A6FF), size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${earned.length} / $total rozet kazanıldı',
                                    style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (earned.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: earned.take(8).map((id) {
                                        final def = AchievementProvider
                                            .achievements
                                            .firstWhere((a) => a.id == id,
                                                orElse: () =>
                                                    const AchievementDef(
                                                        id: '',
                                                        emoji: '🏅',
                                                        name: '',
                                                        description: '',
                                                        requirement: 1,
                                                        progressKey: '',
                                                        unit: ''));
                                        return Text(def.emoji,
                                            style: const TextStyle(
                                                fontSize: 22));
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: cs.onSurfaceVariant, size: 20),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Özel Ayarlar (Tema + Dil) ─────────────────────────────
              _SectionLabel(label: 'Özel Ayarlar'),
              _SettingsCard(
                children: [
                  // Tema
                  Row(
                    children: [
                      Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: const Color(0xFF58A6FF),
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Tema',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SegmentedToggle(
                        options: const ['Karanlık', 'Aydınlık'],
                        selectedIndex: themeProvider.isDarkMode ? 0 : 1,
                        onChanged: (i) {
                          if ((i == 0) != themeProvider.isDarkMode) {
                            themeProvider.toggleTheme();
                          }
                        },
                      ),
                    ],
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  // Dil
                  Row(
                    children: [
                      const Icon(Icons.language_outlined,
                          color: Color(0xFF58A6FF), size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Dil',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SegmentedToggle(
                        options: const ['Türkçe', 'English'],
                        selectedIndex: langProvider.isTurkish ? 0 : 1,
                        onChanged: (i) {
                          if ((i == 0) != langProvider.isTurkish) {
                            langProvider.toggleLanguage();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Entegrasyonlar ──────────────────────────────────────────
              _SectionLabel(label: 'Entegrasyonlar'),
              _SettingsCard(
                children: [
                  Row(
                    children: [
                      Icon(
                        Platform.isAndroid ? Icons.health_and_safety_outlined : Icons.favorite_border,
                        color: const Color(0xFFFAFBFC),
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sağlık Verilerini Senkronize Et',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Adım, yakılan kalori vb. verileri telefonunuzdan otomatik olarak aktarır.',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: profileProvider.healthSyncEnabled,
                        onChanged: (value) async {
                          if (value) {
                            await HealthService.initialize();
                            final granted = await HealthService.requestPermissions();
                            if (granted) {
                              await profileProvider.setHealthSyncEnabled(true);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sağlık erişimi izni verilmedi.')),
                                );
                              }
                            }
                          } else {
                            await profileProvider.setHealthSyncEnabled(false);
                          }
                        },
                        activeColor: const Color(0xFF58A6FF),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Geri Bildirim ──────────────────────────────────────────
              _SectionLabel(label: 'Geri Bildirim'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Uygulama hakkındaki düşüncelerinizi buraya yazabilirsiniz...',
                        hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSendingFeedback ? null : _submitFeedback,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF58A6FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSendingFeedback 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Gönder', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Yasal ───────────────────────────────────────────────────
              _SectionLabel(label: 'Yasal'),
              _SettingsCard(
                children: [
                  GestureDetector(
                    onTap: () {}, // TODO: Terms
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Kullanım Koşulları', 
                                style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 16),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: cs.outlineVariant, height: 20),
                  GestureDetector(
                    onTap: () {}, // TODO: Privacy
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Gizlilik Politikası', 
                                style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 12),

              // ── Hesap ─────────────────────────────────────────────────
              _SectionLabel(label: 'Hesap'),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _handleSignOut,
                  icon: const Icon(Icons.logout,
                      color: Color(0xFF58A6FF), size: 20),
                  label: const Text('Hesaptan Çık',
                      style: TextStyle(
                          color: Color(0xFF58A6FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(
                        color: Color(0xFF58A6FF), width: 1),
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Center(
                      child: Text(
                        'Versiyon ${snapshot.data!.version}',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
          // Yükleme kaplaması
          if (_isDeleting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF58A6FF)),
                    SizedBox(height: 16),
                    Text('Hesap siliniyor...',
                        style: TextStyle(
                            color: Color(0xFFE6EDF3), fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      )),  // Stack + WaveBackground
    );
  }

  // ── Show Nutrition Goals Sheet ──────────────────────────────────────────────
  void _showNutritionGoalsSheet(BuildContext context, ProfileProvider pp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      useSafeArea: true,
      builder: (_) => _NutritionGoalsSheet(profileProvider: pp),
    );
  }

  // ── Water drum picker ──────────────────────────────────────────────────────

  void _showWaterPicker(BuildContext context, ProfileProvider pp) {
    const minMl = 500;
    const maxMl = 5000;
    const stepMl = 100;
    final values = [for (int v = minMl; v <= maxMl; v += stepMl) v];
    final initial = ((pp.waterGoalMl - minMl) ~/ stepMl).clamp(0, values.length - 1);
    final ctrl = FixedExtentScrollController(initialItem: initial);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Günlük Su Hedefi',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: _drumPicker(
                controller: ctrl,
                items: values
                    .map((v) => Text('$v ml',
                        style: TextStyle(
                            fontSize: 20,
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500)))
                    .toList(),
                onChanged: (i) => pp.setCustomWaterGoal(values[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStepPicker(BuildContext context, ProfileProvider pp) {
    const min = 1000;
    const max = 30000;
    const step = 500;
    final values = [for (int v = min; v <= max; v += step) v];
    final initial = ((pp.stepGoal - min) ~/ step).clamp(0, values.length - 1);
    final ctrl = FixedExtentScrollController(initialItem: initial);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Günlük Adım Hedefi',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: _drumPicker(
                controller: ctrl,
                items: values
                    .map((v) => Text(
                          v >= 1000
                              ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K adım'
                              : '$v adım',
                          style: TextStyle(
                              fontSize: 20,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500),
                        ))
                    .toList(),
                onChanged: (i) => pp.setCustomStepGoal(values[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drumPicker({
    required FixedExtentScrollController controller,
    required List<Widget> items,
    required ValueChanged<int> onChanged,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.transparent, Colors.transparent, Colors.black],
        stops: [0.0, 0.25, 0.75, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstOut,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onChanged(i);
        },
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        children: items.map((w) => Center(child: w)).toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

// ── Goal override field ───────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: Duration.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: const Color(0xFF58A6FF), width: 1)
                    : null,
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF58A6FF)
                      : cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Nutrition Goals Sheet ─────────────────────────────────────────────────────

class _NutritionGoalsSheet extends StatefulWidget {
  final ProfileProvider profileProvider;
  const _NutritionGoalsSheet({required this.profileProvider});

  @override
  State<_NutritionGoalsSheet> createState() => _NutritionGoalsSheetState();
}

class _NutritionGoalsSheetState extends State<_NutritionGoalsSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _calAnim;
  late Animation<double> _protAnim;
  late Animation<double> _carbAnim;
  late Animation<double> _fatAnim;

  double _displayCal = 0;
  double _displayProt = 0;
  double _displayCarb = 0;
  double _displayFat = 0;
  double _displayFiber = 0;

  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    final pp = widget.profileProvider;
    _displayCal = pp.calorieGoal;
    _displayProt = pp.proteinGoal;
    _displayCarb = pp.carbGoal;
    _displayFat = pp.fatGoal;
    _displayFiber = pp.getMicroGoal('fiber', pp.activeProfile?.fiberGoal ?? 25.0);

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    // Initially static animations
    _calAnim = AlwaysStoppedAnimation(_displayCal);
    _protAnim = AlwaysStoppedAnimation(_displayProt);
    _carbAnim = AlwaysStoppedAnimation(_displayCarb);
    _fatAnim = AlwaysStoppedAnimation(_displayFat);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _startRecalculateAnimation() {
    final pp = widget.profileProvider;
    pp.autoGenerateNutritionGoals();
    
    final newCal = pp.calorieGoal;
    final newProt = pp.proteinGoal;
    final newCarb = pp.carbGoal;
    final newFat = pp.fatGoal;

    setState(() {
      _isCalculating = true;
      _displayCal = newCal;
      _displayProt = newProt;
      _displayCarb = newCarb;
      _displayFat = newFat;
      _displayFiber = pp.activeProfile?.fiberGoal ?? 25.0;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    });
  }
  void _editValue(
    String title,
    String unit,
    double initial,
    ValueChanged<double> onSaved,
  ) {
    final TextEditingController textCtrl = TextEditingController(text: initial.toString());
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni hedef değerini girin ($unit):', style: TextStyle(color: cs.onSurface, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixText: unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(textCtrl.text);
              if (val != null) {
                onSaved(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }


  Widget _buildRow(
    String title,
    String iconStr,
    String valueStr,
    Color color,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                color: Colors.transparent, 
              ),
              child: Center(
                child: Text(iconStr, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 13, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(valueStr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroGridItem(
    String title,
    String valueStr,
    Color color,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            const SizedBox(height: 2),
            Text(valueStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pp = widget.profileProvider;
    final profile = pp.activeProfile;
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: cs.onSurface),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Besin Hedeflerini Düzenle',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Stack(
                children: [
                  ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, _) => Column(
                          children: [
                            _buildRow('Kalori hedefi', '🔥', '${_displayCal.toInt()}', const Color(0xFFFF6B35), () {
                              _editValue('Kalori', 'kcal', pp.calorieGoal, (val) {
                                pp.setCustomCalorieGoal(val.toInt());
                                setState(() { _displayCal = val; });
                              });
                            }),
                            _buildRow('Protein hedefi', '🍗', '${_displayProt.toInt()}', const Color(0xFF7EE787), () {
                              _editValue('Protein', 'g', pp.proteinGoal, (val) {
                                pp.setCustomProteinGoal(val.toInt());
                                setState(() { _displayProt = val; });
                              });
                            }),
                            _buildRow('Karbohidrat hedefi', '🌾', '${_displayCarb.toInt()}', const Color(0xFF58A6FF), () {
                              _editValue('Karbonhidrat', 'g', pp.carbGoal, (val) {
                                pp.setCustomCarbGoal(val.toInt());
                                setState(() { _displayCarb = val; });
                              });
                            }),
                            _buildRow('Yağ hedefi', '🥑', '${_displayFat.toInt()}', const Color(0xFFFFA726), () {
                              _editValue('Yağ', 'g', pp.fatGoal, (val) {
                                pp.setCustomFatGoal(val.toInt());
                                setState(() { _displayFat = val; });
                              });
                            }),
                            _buildRow('Lif hedefi', '🍎', '${_displayFiber.toInt()}', const Color(0xFF9B59B6), () {
                              _editValue('Lif', 'g', _displayFiber, (val) {
                                pp.setCustomMicroGoal('fiber', val);
                                setState(() { _displayFiber = val; });
                              });
                            }),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Center(
                              child: Text(
                                'Daha Fazla',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            children: [
                              _buildMicroGrid(pp, profile),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isCalculating)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                          child: Container(
                            color: cs.surface.withValues(alpha: 0.3),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text('Hesaplanıyor...', 
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewPadding.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.tonal(
                  onPressed: _isCalculating ? null : _startRecalculateAnimation,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Tekrardan Hesapla',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMicroGrid(ProfileProvider pp, UserProfile? profile) {
    final categories = {
      'Mineraller': [
        ('calcium', 'Kalsiyum', 'mg', profile?.calciumGoal ?? 1000.0, const Color(0xFF1ABC9C)),
        ('iron', 'Demir', 'mg', profile?.ironGoal ?? 14.0, const Color(0xFFE74C3C)),
        ('magnesium', 'Magnezyum', 'mg', profile?.magnesiumGoal ?? 350.0, const Color(0xFF0A84FF)),
        ('zinc', 'Çinko', 'mg', profile?.zincGoal ?? 10.0, const Color(0xFF64D2FF)),
        ('potassium', 'Potasyum', 'mg', profile?.potassiumGoal ?? 4700.0, const Color(0xFFFF9F0A)),
        ('sodium', 'Sodyum', 'mg', profile?.sodiumLimit ?? 2300.0, const Color(0xFFD4A017)),
        ('selenium', 'Selenyum', 'mcg', profile?.seleniumGoal ?? 55.0, const Color(0xFFFFCC00)),
        ('phosphorus', 'Fosfor', 'mg', 700.0, const Color(0xFF5856D6)),
        ('copper', 'Bakır', 'mg', 0.9, const Color(0xFFBF5AF2)),
        ('manganese', 'Manganez', 'mg', 2.3, const Color(0xFF8E8E93)),
        ('iodine', 'İyot', 'mcg', 150.0, const Color(0xFF30B0C7)),
        ('chromium', 'Krom', 'mcg', 35.0, const Color(0xFF636366)),
        ('molybdenum', 'Molibden', 'mcg', 45.0, const Color(0xFF8F8F8F)),
      ],
      'Vitaminler': [
        ('vitC', 'C Vitamini', 'mg', 90.0, const Color(0xFFFF9F0A)),
        ('vitD', 'D Vitamini', 'mcg', profile?.vitaminDGoal ?? 15.0, const Color(0xFFF39C12)),
        ('vitE', 'E Vitamini', 'mg', 15.0, const Color(0xFF58A6FF)),
        ('vitK', 'K Vitamini', 'mcg', 120.0, const Color(0xFF34C759)),
        ('vitA', 'A Vitamini', 'mcg', 900.0, const Color(0xFFFF6B35)),
        ('thiamine', 'B1 (Tiamin)', 'mg', 1.2, const Color(0xFFBF5AF2)),
        ('riboflavin', 'B2 (Riboflavin)', 'mg', 1.3, const Color(0xFFFF2D55)),
        ('niacin', 'B3 (Niasin)', 'mg', 16.0, const Color(0xFF0A84FF)),
        ('pantothenic', 'B5 (Pantotenik)', 'mg', 5.0, const Color(0xFF5856D6)),
        ('vitB6', 'B6 Vitamini', 'mg', 1.7, const Color(0xFF64D2FF)),
        ('folate', 'Folat', 'mcg', 400.0, const Color(0xFF58A6FF)),
        ('vitB12', 'B12 Vitamini', 'mcg', profile?.vitaminB12Goal ?? 2.4, const Color(0xFFE74C3C)),
        ('choline', 'Kolin', 'mg', 550.0, const Color(0xFFFF9F0A)),
        ('biotin', 'Biotin', 'mcg', 30.0, const Color(0xFFBF5AF2)),
      ],
      'Yağ Asitleri': [
        ('omega3', 'Omega-3', 'g', profile?.omega3Goal ?? 1.6, const Color(0xFF0A84FF)),
        ('omega6', 'Omega-6', 'g', profile?.omega6Goal ?? 17.0, const Color(0xFFFF9F0A)),
        ('epa', 'EPA', 'g', 0.25, const Color(0xFF30B0C7)),
        ('dha', 'DHA', 'g', 0.25, const Color(0xFF5856D6)),
        ('ala', 'ALA', 'g', 1.6, const Color(0xFF58A6FF)),
        ('satFat', 'Doymuş Yağ', 'g', 20.0, const Color(0xFFFF6B35)),
      ],
      'Diğer': [
        ('sugar', 'Şeker', 'g', 50.0, const Color(0xFFFF2D55)),
        ('cholesterol', 'Kolesterol', 'mg', 300.0, const Color(0xFFFF9F0A)),
      ],
    };

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: categories.entries.map((entry) {
          final title = entry.key;
          final items = entry.value;
          final color = items.first.$5; // Use the first item's color for the header

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w900, 
                        color: color, 
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final m = items[index];
                  final currentVal = pp.getMicroGoal(m.$1, m.$4);
                  return _buildMicroGridItem(m.$2, '${currentVal.toStringAsFixed(m.$3 == 'g' ? 2 : 1)} ${m.$3}', m.$5, () {
                    _editValue(m.$2, m.$3, currentVal, (val) {
                      pp.setCustomMicroGoal(m.$1, val);
                      setState(() {});
                    });
                  });
                },
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

