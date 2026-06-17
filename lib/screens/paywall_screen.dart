import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/purchase_service.dart';
import 'home_screen.dart';

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
                leadingWidth: 60,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 24, left: 12),
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onComplete != null) {
                        widget.onComplete!();
                      } else if (widget.fromOnboarding) {
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
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
                        icon: Icons.analytics_rounded,
                        title: _t('65+ Kritik Besin Analizi', '65+ Critical Nutrient Analysis'),
                        desc: _t('Sadece kalori değil; vitamin, mineral ve antioksidan dengenizi tam isabetle ölçün.', 'Measure not just calories, but your vitamin, mineral, and antioxidant balance with full precision.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.camera_rounded,
                        title: _t('Sınırsız AI Tarama', 'Unlimited AI Scanning'),
                        desc: _t('Fotoğraftan anında ve sınırsız kalori takibi.', 'Instant and unlimited calorie tracking from photos.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.qr_code_scanner_rounded,
                        title: _t('Barkoddan Analiz', 'Barcode Analysis'),
                        desc: _t('Paketli gıdaların barkodunu tara, içeriğini anında öğren.', 'Scan packaged food barcodes, instantly learn their contents.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.mic_rounded,
                        title: _t('Anlatarak Analiz', 'Voice & Text Analysis'),
                        desc: _t('Yediklerini sesli veya yazılı anlat, AI senin için hesaplasın.', 'Describe what you eat with voice or text, let AI calculate it for you.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.auto_graph_rounded,
                        title: _t('Uzun Yaşam', 'Longevity'),
                        desc: _t('Beslenme düzeninizin hücresel yaşlanma ve uzun ömür üzerindeki etkisini izleyin.', 'Monitor the impact of your nutrition on cellular aging and longevity.'),
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.spa_rounded,
                        title: _t('Eksikliklere Özel Tarifler', 'Deficiency-Specific Recipes'),
                        desc: _t('Besin eksikliklerinizi gidermek için bilimsel temelli ve şef onaylı özel tarifler.', 'Science-based and chef-approved special recipes to address your nutrient deficiencies.'),
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
                        title: _t('Haftalık', 'Weekly'),
                        price: _t('₺199,99 / hafta', '₺199.99 / week'),
                        subtitle: _t('Sağlıklı yaşama hızlı bir başlangıç', 'A quick start to healthy living'),
                        selected: _selectedPlanIndex == 0,
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildPlanCard(
                        index: 1,
                        title: _t('Yıllık', 'Yearly'),
                        price: _t('₺1.749,99 / yıl', '₺1,749.99 / year'),
                        oldPrice: _t('₺8.800', '₺8,800'), // Strikethrough price
                        subtitle: _t('Uzun yaşam için en kapsamlı analiz', 'The most comprehensive analysis for longevity'),
                        selected: _selectedPlanIndex == 1,
                        badge: _t('EN POPÜLER', 'MOST POPULAR'),
                        isBadgeTopCenter: true,
                        savingsBlue: appBlue, // Blue savings
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
                      
                      const SizedBox(height: 32),
                      
                      // Action Button
                      Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ElevatedButton(
                          onPressed: _isPurchasing ? null : () async {
                            final profileProvider = context.read<ProfileProvider>();
                            if (widget.onComplete != null) {
                              // Onboarding path: grant temporary premium immediately
                              await profileProvider.updatePremiumStatus(true, planName: _selectedPlanName);
                              widget.onComplete!();
                              return;
                            }
                            final productId = _selectedPlanIndex == 0
                                ? kProductMonthly
                                : kProductYearly;
                            setState(() => _isPurchasing = true);
                            // Grant premium immediately for smooth UX, revert on failure
                            await profileProvider.updatePremiumStatus(true, planName: _selectedPlanName);
                            final result = await PurchaseService.instance.purchase(productId);
                            if (!mounted) return;
                            setState(() => _isPurchasing = false);
                            if (result == PurchaseResult.success) {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                            } else if (result == PurchaseResult.error) {
                              // Revert premium if purchase failed
                              profileProvider.updatePremiumStatus(false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_t('Satın alma başarısız. Lütfen tekrar deneyin.', 'Purchase failed. Please try again.'))),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            _t('Devam Et', 'Continue'),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterLink(_t('Satın Alımı Geri Yükle', 'Restore Purchase'), onTap: () async {
                            final restored = await PurchaseService.instance.restorePurchases();
                            if (!mounted) return;
                            if (restored) {
                              context.read<ProfileProvider>().updatePremiumStatus(true, planName: 'restored');
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_t('Geri yüklenecek satın alım bulunamadı.', 'No purchase found to restore.'))),
                              );
                            }
                          }),
                          _buildFooterDivider(),
                          _buildFooterLink(_t('Gizlilik', 'Privacy')),
                          _buildFooterDivider(),
                          _buildFooterLink(_t('Şartlar', 'Terms')),
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
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54),
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
        onTap: () => setState(() => _selectedPlanIndex = index),
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
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black45),
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
                              fontSize: 18, // Large
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
}
