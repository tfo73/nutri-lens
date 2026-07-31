import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/purchase_service.dart';
import 'home_screen.dart';
import 'legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaywallScreen extends StatefulWidget {
  final bool fromOnboarding;
  final VoidCallback? onComplete;
  const PaywallScreen({super.key, this.fromOnboarding = false, this.onComplete});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly
  bool _isPurchasing = false;


  bool get _isTr => Provider.of<LanguageProvider>(context).isTurkish;
  String _t(String tr, String en) => _isTr ? tr : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/onboarding/premium.webp'), context);
  }

  String get _selectedPlanName {
    switch (_selectedPlanIndex) {
      case 0: return 'monthly';
      case 2: return 'lifetime';
      default: return 'yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final isPremium = profileProvider.isPremium;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Design System Tokens (Synced with App Colors)
    final appBlue = const Color(0xFF58A6FF);  // _iceCobalt
    
    final primaryGradient = LinearGradient(
      colors: [appBlue.withValues(alpha: 0.8), appBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    
    final surfaceColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAF9F9);
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 420,
                pinned: true,
                stretch: true,
                backgroundColor: surfaceColor,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/onboarding/premium.webp',
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              surfaceColor.withValues(alpha: 0.1),
                              surfaceColor.withValues(alpha: 0.8),
                              surfaceColor,
                            ],
                            stops: const [0.0, 0.4, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(text: 'LensEat ', style: TextStyle(color: appBlue)),
                            const TextSpan(text: 'Premium', style: TextStyle(color: Color(0xFFFFD700))), // Gold/Yellow
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Biyolojik yaşınızı kontrol altına alın. 65 farklı besin değerini analiz ederek hücrelerinizi besleyin ve daha uzun, daha enerjik bir yaşamın kapılarını aralayın.',
                          'Take control of your biological age. Analyze 65 different nutrients to feed your cells and unlock a longer, more energetic life.',
                        ),
                        style: TextStyle(
                          fontSize: 18, // Increased size from 17
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Bento Feature List
                      _buildFeatureItem(
                        icon: Icons.camera_alt_rounded,
                        title: _t('Sınırsız Görselden Analiz', 'Unlimited Image Analysis'),
                        desc: _t('Yemeğin fotoğrafını çekin, AI porsiyonu ve besin değerlerini çıkarsın.', 'Take a photo of your meal, let AI extract portion size and nutritional values.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.edit_note_rounded,
                        title: _t('Sınırsız Tarif Ederek Analiz', 'Unlimited Description Analysis'),
                        desc: _t('Yemek tariflerinizi veya yediklerinizi yazarak/anlatarak analiz edin.', 'Analyze your recipes or what you eat by writing or describing.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.qr_code_scanner_rounded,
                        title: _t('Sınırsız Barkoddan Analiz', 'Unlimited Barcode Analysis'),
                        desc: _t('Paketli gıdaların barkodlarını anında tarayın ve tüm besin değerlerini görün.', 'Instantly scan packaged food barcodes and view all nutritional values.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.chat_bubble_rounded,
                        title: _t('Sınırsız Beslenme Koçu', 'Unlimited Nutrition Coach'),
                        desc: _t('Size özel yapay zeka beslenme koçuyla dilediğiniz an sohbet edin.', 'Chat with your personal AI nutrition coach whenever you want.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.restaurant_menu_rounded,
                        title: _t('Sınırsız Günlük Tarifler', 'Unlimited Daily Recipes'),
                        desc: _t('Vücudunuzun eksiklerine ve hedeflerinize özel lezzetli tarifler alın.', 'Get delicious recipes tailored to your body\'s deficiencies and goals.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.mail_rounded,
                        title: _t('Bilgilerimi Maille Gönder', 'Send Info via Email'),
                        desc: _t('Beslenme özetlerinizi ve analizlerinizi e-posta olarak raporlayın.', 'Receive your nutrition summaries and analysis as email reports.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      
                      const SizedBox(height: 40),
                      Text(
                        _t('Bir Plan Seç', 'Choose a Plan'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Plans
                      _buildPlanCard(
                        index: 0,
                        title: _t('Aylık Plan', 'Monthly Plan'),
                        price: _t('₺99', '\$4.99'),
                        subtitle: _t('Aylık otomatik yenileme', 'Billed monthly'),
                        selected: _selectedPlanIndex == 0,
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildPlanCard(
                        index: 1,
                        title: _t('Yıllık Plan', 'Yearly Plan'),
                        price: _t('₺299', '\$29.99'),
                        oldPrice: _t('₺1188', '\$59.88'),
                        subtitle: _t('Yılda bir kez faturalandırılır', 'Billed once a year'),
                        selected: _selectedPlanIndex == 1,
                        badge: _t('EN POPÜLER', 'MOST POPULAR'),
                        isBadgeTopCenter: true,
                        savingsBlue: const Color(0xFF007AFF),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildPlanCard(
                        index: 2,
                        title: _t('Ömür Boyu', 'Lifetime'),
                        price: _t('₺4.999,99', '₺4,999.99'),
                        subtitle: _t('Ömür boyu sağlık ve gençlik yatırımı', 'Lifetime investment in health and youth'),
                        selected: _selectedPlanIndex == 2,
                        badge: _t('SINIRLI SÜRELİĞİNE TEKLİF', 'LIMITED TIME OFFER'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      
                      const SizedBox(height: 24),
                      // Google Play Promo Code Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.redeem_rounded, color: Color(0xFF34A853), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _t('Google Play Promosyon Kodu', 'Google Play Promo Code'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: TextField(
                                      controller: _promoCodeController,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _t('Kodunuzu girin', 'Enter your code'),
                                        hintStyle: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontSize: 13,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: appBlue),
                                        ),
                                        filled: true,
                                        fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                      ),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _redeemGooglePlayPromoCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF34A853), // Google Green
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: Text(
                                      _t('Kullan', 'Redeem'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t(
                                'Kodunuzu onayladıktan sonra "Satın Alımı Geri Yükle" butonuna basarak Premium\'u başlatabilirsiniz.',
                                'After redeeming your code, tap "Restore Purchase" to activate Premium.',
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action Button
                      Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: isPremium 
                              ? LinearGradient(
                                  colors: [Colors.grey.shade600, Colors.grey.shade700],
                                )
                              : primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ElevatedButton(
                          onPressed: (isPremium || _isPurchasing) ? null : _executePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            isPremium 
                                ? _t('Aktif Premium Üyeliğiniz Var', 'You Have Active Premium')
                                : _t('Devam Et', 'Continue'),
                            style: TextStyle(
                              color: isPremium ? Colors.white70 : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final hadPremium = profileProvider.activeProfile?.hadPremiumBefore ?? false;
                            final prefs = await SharedPreferences.getInstance();
                            final freeTrialShown = prefs.getBool('free_trial_shown') ?? false;

                            if (hadPremium || freeTrialShown) {
                              _closePaywall();
                            } else {
                              await prefs.setBool('free_trial_shown', true);
                              _showFreeTrialDialog();
                            }
                          },
                          child: Text(
                            _t('Premiumsuz Devam Et', 'Continue without Premium'),
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterLink(_t('Satın Alımı Geri Yükle', 'Restore Purchase'), onTap: () async {
                            _showLoadingDialog(_t('Satın alımlarınız geri yükleniyor...', 'Restoring your purchases...'));
                            try {
                              final activePurchases = await PurchaseService.instance.queryActivePurchasesSilently();
                              if (!mounted) return;
                              Navigator.pop(context); // Dismiss loading dialog
                              
                              if (activePurchases.isNotEmpty) {
                                PurchaseDetails? matchedPurchase;
                                for (final p in activePurchases) {
                                  if (p.productID == kProductMonthly || 
                                      p.productID == kProductYearly || 
                                      p.productID == kProductLifetime) {
                                    matchedPurchase = p;
                                    break;
                                  }
                                }
                                
                                if (matchedPurchase != null) {
                                  final plan = matchedPurchase.productID == kProductMonthly 
                                      ? 'monthly' 
                                      : (matchedPurchase.productID == kProductLifetime ? 'lifetime' : 'yearly');
                                  await context.read<ProfileProvider>().updatePremiumStatus(true, planName: plan);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_t('Premium başarıyla geri yüklendi!', 'Premium successfully restored!'))),
                                  );
                                  _closePaywall();
                                  return;
                                }
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_t('Aktif bir premium abonelik bulunamadı.', 'No active premium subscription found.'))),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(context); // Dismiss loading dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_t('Satın alım geri yüklenirken hata oluştu.', 'Error restoring purchase.'))),
                              );
                            }
                          }),
                          _buildFooterDivider(),
                          _buildFooterLink(_t('Gizlilik', 'Privacy'), onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                              title: _t('Gizlilik Politikası', 'Privacy Policy'),
                              trAssetPath: 'assets/legal/privacy_policy_tr.md',
                              enAssetPath: 'assets/legal/privacy_policy_en.md',
                            )));
                          }),
                          _buildFooterDivider(),
                          _buildFooterLink(_t('Şartlar', 'Terms'), onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen(
                              title: _t('Kullanım Koşulları', 'Terms of Use'),
                              trAssetPath: 'assets/legal/terms_tr.md',
                              enAssetPath: 'assets/legal/terms_en.md',
                            )));
                          }),
                        ],
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Custom Close Button if expanded height is 0 or scrolled
          // (Handled by SliverAppBar leading)
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF58A6FF)),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final TextEditingController _promoCodeController = TextEditingController();

  Future<void> _redeemGooglePlayPromoCode() async {
    final code = _promoCodeController.text.trim();
    
    // Launch Google Play redeem link using url_launcher
    final String urlStr = code.isNotEmpty
        ? 'https://play.google.com/store/redeem?code=$code'
        : 'https://play.google.com/store/redeem';
    final Uri url = Uri.parse(urlStr);

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch Play Store redeem link: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Google Play Store açılamadı.', 'Could not open Google Play Store.'))),
      );
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color appGreen,
    required Color cardColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: appGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    String? oldPrice,
    required String subtitle,
    required bool selected,
    String? badge,
    bool isBadgeTopCenter = false,
    Color? savingsBlue,
    required Color appGreen,
    required Color cardColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: isBadgeTopCenter ? 12 : 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedPlanIndex = index);
        },
        child: AnimatedScale(
          scale: selected ? 1.04 : 0.96,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? appGreen : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1)),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badge != null && !isBadgeTopCenter)
                            _buildBadge(badge, appGreen),
                          Text(
                            title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (oldPrice != null)
                          Text(
                            oldPrice,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black45,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          price,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        if (savingsBlue != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _t('%80 tasarruf', 'Save 80%'),
                              style: TextStyle(
                                fontSize: 13, // Made smaller to prevent wrapping
                                fontWeight: FontWeight.w900,
                                color: savingsBlue, // Blue
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (badge != null && isBadgeTopCenter)
                Positioned(
                  top: -10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildBadge(badge, appGreen, isPopular: true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, {bool isPopular = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isPopular ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPopular ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isPopular ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPopular ? Colors.black : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Text(
      label,
      style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black38),
    );
    if (onTap == null) return text;
    return GestureDetector(onTap: onTap, child: text);
  }

  Widget _buildFooterDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(width: 1, height: 12, color: isDark ? Colors.white10 : Colors.black12),
    );
  }


  Future<void> _executePurchase() async {
    final profileProvider = context.read<ProfileProvider>();
    final String productId;
    if (_selectedPlanIndex == 0) {
      productId = kProductMonthly;
    } else if (_selectedPlanIndex == 2) {
      productId = kProductLifetime;
    } else {
      productId = kProductYearly;
    }
    setState(() => _isPurchasing = true);
    final result = await PurchaseService.instance.purchase(productId);
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    if (result == PurchaseResult.success) {
      await profileProvider.updatePremiumStatus(true, planName: _selectedPlanName);
      _closePaywall();
    } else if (result == PurchaseResult.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Satın alma başarısız. Lütfen tekrar deneyin.', 'Purchase failed. Please try again.'))),
      );
    } else if (result == PurchaseResult.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Satın alma iptal edildi.', 'Purchase cancelled.'))),
      );
    }
  }

  void _closePaywall() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (widget.fromOnboarding) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  Future<void> _showFreeTrialDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBlue = const Color(0xFF58A6FF);
    final primaryGradient = LinearGradient(
      colors: [appBlue.withValues(alpha: 0.8), appBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bool? startTrial = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
              elevation: 24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Image.network(
                        'https://cdn-icons-png.flaticon.com/512/4213/4213958.png',
                        height: 90,
                        width: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D80).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFFF4D80),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    _t('3 Gün Ücretsiz Deneme!', '3-Day Free Trial!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'LensEat',
                          style: TextStyle(
                            color: appBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: _t(
                            ' Premium\'u 3 gün boyunca tamamen ücretsiz deneyin. Daha fazla besin analizi yapıp hücrelerinizi besleyin. Deneme süresi sonunda dilediğiniz an iptal edebilirsiniz.',
                            ' Premium completely free for 3 days. Do more nutrient analysis to feed your cells. Cancel anytime before the trial ends.',
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Disclosure
                  Text(
                    _t(
                      '3 gün ücretsiz, sonra Aylık ₺99',
                      '3 days free, then \$4.99/month',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Button
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: appBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _t('Ücretsiz Denemeyi Başlat', 'Start Free Trial'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Reject Action Button
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white54 : Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      _t('İstemiyorum, Ücretsiz Devam Et', 'No Thanks, Continue Free'),
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (startTrial == true) {
      setState(() {
        _selectedPlanIndex = 0; // Set to monthly for free trial
      });
      await _executePurchase();
    } else if (startTrial == false) {
      _closePaywall();
    }
  }
}
