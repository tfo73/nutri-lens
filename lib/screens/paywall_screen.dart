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
                        'Biyolojik yaşınızı kontrol altına alın. 65 farklı besin değerini analiz ederek hücrelerinizi besleyin ve daha uzun, daha enerjik bir yaşamın kapılarını aralayın.',
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
                        title: '65+ Kritik Besin Analizi',
                        desc: 'Sadece kalori değil; vitamin, mineral ve antioksidan dengenizi tam isabetle ölçün.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.camera_rounded,
                        title: 'Sınırsız AI Tarama',
                        desc: 'Fotoğraftan anında ve sınırsız kalori takibi.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Barkoddan Analiz',
                        desc: 'Paketli gıdaların barkodunu tara, içeriğini anında öğren.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.mic_rounded,
                        title: 'Anlatarak Analiz',
                        desc: 'Yediklerini sesli veya yazılı anlat, AI senin için hesaplasın.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.auto_graph_rounded,
                        title: 'Uzun Yaşam',
                        desc: 'Beslenme düzeninizin hücresel yaşlanma ve uzun ömür üzerindeki etkisini izleyin.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildFeatureItem(
                        icon: Icons.spa_rounded,
                        title: 'Eksikliklere Özel Tarifler',
                        desc: 'Besin eksikliklerinizi gidermek için bilimsel temelli ve şef onaylı özel tarifler.',
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      
                      const SizedBox(height: 40),
                      Text(
                        'Bir Plan Seç',
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
                        title: 'Haftalık',
                        price: '₺199,99 / hafta',
                        subtitle: 'Sağlıklı yaşama hızlı bir başlangıç',
                        selected: _selectedPlanIndex == 0,
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildPlanCard(
                        index: 1,
                        title: 'Yıllık',
                        price: '₺1.749,99 / yıl',
                        oldPrice: '₺8.800', // Strikethrough price
                        subtitle: 'Uzun yaşam için en kapsamlı analiz',
                        selected: _selectedPlanIndex == 1,
                        badge: 'EN POPÜLER',
                        isBadgeTopCenter: true,
                        savingsBlue: appBlue, // Blue savings
                        appGreen: appBlue,
                        cardColor: cardColor,
                      ),
                      _buildPlanCard(
                        index: 2,
                        title: 'Ömür Boyu',
                        price: '₺4.999,99',
                        subtitle: 'Ömür boyu sağlık ve gençlik yatırımı',
                        selected: _selectedPlanIndex == 2,
                        badge: 'SINIRLI SÜRELİĞİNE TEKLİF',
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
                                const SnackBar(content: Text('Satın alma başarısız. Lütfen tekrar deneyin.')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text(
                            'Devam Et',
                            style: TextStyle(
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
                          _buildFooterLink('Satın Alımı Geri Yükle', onTap: () async {
                            final restored = await PurchaseService.instance.restorePurchases();
                            if (!mounted) return;
                            if (restored) {
                              context.read<ProfileProvider>().updatePremiumStatus(true, planName: 'restored');
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Geri yüklenecek satın alım bulunamadı.')),
                              );
                            }
                          }),
                          _buildFooterDivider(),
                          _buildFooterLink('Gizlilik'),
                          _buildFooterDivider(),
                          _buildFooterLink('Şartlar'),
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
                            '%80 tasarruf',
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
