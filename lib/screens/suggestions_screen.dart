import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import 'coach_screen.dart';

// ─── Öğün zamanı ─────────────────────────────────────────────────────────────

enum _Period { kahvalti, ogle, araOgun, aksam }

extension _PeriodX on _Period {
  static _Period fromHour(int h) {
    if (h >= 5 && h < 10) return _Period.kahvalti;
    if (h >= 10 && h < 14) return _Period.ogle;
    if (h >= 14 && h < 17) return _Period.araOgun;
    if (h >= 17 && h < 21) return _Period.aksam;
    return _Period.araOgun;
  }

  String get baslik {
    switch (this) {
      case _Period.kahvalti: return 'Günaydın!';
      case _Period.ogle:     return 'Öğle Vakti';
      case _Period.araOgun:  return 'Ara Öğün';
      case _Period.aksam:    return 'Akşam Yemeği';
    }
  }

  String get altyazi {
    switch (this) {
      case _Period.kahvalti: return 'Güne enerjik başla';
      case _Period.ogle:     return 'Öğle arası güç yemeği';
      case _Period.araOgun:  return 'Enerjini canlı tut';
      case _Period.aksam:    return 'Güne güzel bir kapanış';
    }
  }

  String get dbKey {
    switch (this) {
      case _Period.kahvalti: return 'kahvalti';
      case _Period.ogle:     return 'ogle';
      case _Period.araOgun:  return 'araOgun';
      case _Period.aksam:    return 'aksam';
    }
  }
}

// ─── Tarif modeli ─────────────────────────────────────────────────────────────

class _Tarif {
  final String ad;
  final String aciklama;
  final int kalori;
  final double protein;
  final double karb;
  final double yag;
  final double lif;
  final int gramaj; // 1 porsiyon gram ağırlığı
  final double? demir;
  final double? magnezyum;
  final double? kalsiyum;
  final double? vitaminA;
  final double? vitaminC;
  final double? vitaminD;
  final double? vitaminE;
  final double? vitaminB12;
  final double? vitaminB6;
  final double? vitaminB1;
  final double? zinc;
  final double? potasyum;
  final double? omega3;
  final int dakika;
  final List<String> etiketler;
  final List<String> ogunler;
  final List<String> diyetler;
  final List<String> zenginOldugu;
  final Color renk;
  final String gorselUrl;
  final List<String> malzemeler;
  final List<String> adimlar;

  const _Tarif({
    required this.ad,
    required this.aciklama,
    required this.kalori,
    required this.protein,
    required this.karb,
    required this.yag,
    required this.lif,
    this.gramaj = 300,
    this.demir,
    this.magnezyum,
    this.kalsiyum,
    this.vitaminA,
    this.vitaminC,
    this.vitaminD,
    this.vitaminE,
    this.vitaminB12,
    this.vitaminB6,
    this.vitaminB1,
    this.zinc,
    this.potasyum,
    this.omega3,
    required this.dakika,
    required this.etiketler,
    required this.ogunler,
    required this.diyetler,
    required this.zenginOldugu,
    required this.renk,
    required this.gorselUrl,
    required this.malzemeler,
    required this.adimlar,
  });
}

// ─── Tarif veritabanı ─────────────────────────────────────────────────────────

const _db = <_Tarif>[
  // ── KAHVALTI ──────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Gecelik Yulaf', aciklama: 'Meyveli, chia tohumlu kremsi yulaf', kalori: 320, protein: 12.0, karb: 45.0, yag: 8.0, lif: 10.0,
    demir: 2.5, magnezyum: 150, kalsiyum: 200, vitaminA: 50, vitaminC: 15, vitaminB1: 0.3, vitaminB6: 0.2, zinc: 2.0, potasyum: 380, omega3: 2.5, dakika: 5,
    etiketler: ['YÜKSEK LİF', 'VEGAN'], ogunler: ['kahvalti'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'magnezyum', 'omega3'], renk: Color(0xFFE8A04B),
    gorselUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['½ su bardağı yulaf', '1 su bardağı badem sütü', '1 yemek kaşığı chia tohumu', 'Taze meyveler', '1 tatlı kaşığı bal'],
    adimlar: ['Yulaf, süt ve chiayı bir kavanozda karıştırın.', 'Kapağını kapatıp gece boyu buzdolabında bekletin.', 'Sabah üzerine meyveleri ve balı ekleyerek servis yapın.'],
  ),
  _Tarif(
    ad: 'Ispanaklı Omlet', aciklama: 'Taze ıspanak ve beyaz peynirli omlet', kalori: 310, protein: 18.0, karb: 5.0, yag: 22.0, lif: 3.0,
    demir: 4.5, magnezyum: 60, kalsiyum: 180, vitaminA: 450, vitaminC: 25, vitaminD: 2.5, vitaminB12: 1.8, vitaminB6: 0.3, zinc: 2.5, potasyum: 420, dakika: 12,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK KARBONHİDRAT'], ogunler: ['kahvalti'],
    diyetler: ['vejetaryen', 'keto', 'glutensiz'], zenginOldugu: ['protein', 'demir', 'vitaminA'], renk: Color(0xFF5A9F5A),
    gorselUrl: 'https://images.unsplash.com/photo-1588168333986-5078d3ae3976?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 adet yumurta', '1 avuç ıspanak', '30g beyaz peynir', '1 tatlı kaşığı zeytinyağı'],
    adimlar: ['Ispanakları zeytinyağında hafifçe soteleyin.', 'Yumurtaları çırpıp ıspanakların üzerine dökün.', 'Peyniri ekleyip kısık ateşte pişirin.'],
  ),
  _Tarif(
    ad: 'Yunan Yoğurdu Parfesi', aciklama: 'Granola ve bal katmanlı parfait', kalori: 280, protein: 15.0, karb: 30.0, yag: 6.0, lif: 4.0,
    demir: 1.2, magnezyum: 50, kalsiyum: 350, vitaminC: 10, vitaminD: 1.5, vitaminB12: 1.2, zinc: 1.5, potasyum: 320, dakika: 5,
    etiketler: ['YÜKSEK PROTEİN'], ogunler: ['kahvalti', 'araOgun'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'kalsiyum', 'magnezyum'], renk: Color(0xFF7BBFEA),
    gorselUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 kase süzme yoğurt', '3 yemek kaşığı granola', 'Yaban mersini', '1 tatlı kaşığı bal'],
    adimlar: ['Yoğurdu bir kaseye alın.', 'Üzerine granolayı ve meyveleri ekleyin.', 'Bal gezdirerek servis yapın.'],
  ),
  _Tarif(
    ad: 'Avokadolu Tost', aciklama: 'Ekşi mayalı ekmek üzerine avokado', kalori: 450, protein: 14.0, karb: 40.0, yag: 25.0, lif: 12.0,
    demir: 1.5, magnezyum: 58, kalsiyum: 55, vitaminC: 20, vitaminE: 4.0, vitaminB6: 0.5, vitaminB12: 0.6, zinc: 1.3, potasyum: 550, omega3: 0.8, dakika: 15,
    etiketler: ['SAĞLIKLI YAĞ', 'YÜKSEK PROTEİN'], ogunler: ['kahvalti', 'araOgun'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'lif', 'omega3'], renk: Color(0xFF4CAF76),
    gorselUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 dilim ekşi mayalı ekmek', 'Yarım avokado', '1 haşlanmış yumurta', 'Çörek otu'],
    adimlar: ['Ekmeği kızartın.', 'Avokadoyu üzerine ezin ve limon sıkın.', 'Yumurtayı dilimleyip üzerine ekleyin.'],
  ),
  _Tarif(
    ad: 'Muzlu Smoothie Bowl', aciklama: 'Enerji dolu kahvaltı kasesi', kalori: 350, protein: 8.0, karb: 60.0, yag: 10.0, lif: 7.0,
    demir: 1.0, magnezyum: 65, kalsiyum: 30, vitaminC: 15, vitaminB6: 0.7, zinc: 0.8, potasyum: 690, dakika: 5,
    etiketler: ['ENERJİ', 'POTASYUM'], ogunler: ['kahvalti'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['potasyum', 'lif'], renk: Color(0xFFFFEB3B),
    gorselUrl: 'https://images.unsplash.com/photo-1590301157890-4810ed352733?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Muz', 'Yaban mersini', 'Hindistan cevizi sütü'],
    adimlar: ['Muz ve sütü blenderdan geçirin.', 'Meyvelerle süsleyin.'],
  ),
  _Tarif(
    ad: 'Chia Puding', aciklama: 'Meyveli ve hindistan cevizli', kalori: 190, protein: 6.0, karb: 15.0, yag: 14.0, lif: 11.0,
    demir: 2.2, magnezyum: 140, kalsiyum: 180, vitaminC: 12, vitaminE: 1.5, zinc: 1.5, potasyum: 280, omega3: 5.5, dakika: 5,
    etiketler: ['HAFİF', 'LİF'], ogunler: ['kahvalti', 'araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'omega3', 'magnezyum'], renk: Color(0xFF9C27B0),
    gorselUrl: 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['3 yemek kaşığı chia', '1 su bardağı hindistan cevizi sütü', 'Meyve'],
    adimlar: ['Chia ve sütü karıştırıp buzdolabında bekletin.', 'Kıvam alınca meyvelerle süsleyin.'],
  ),
  _Tarif(
    ad: 'Tam Buğdaylı Pankek', aciklama: 'Lifli ve tok tutan kahvaltı pankeki', kalori: 290, protein: 10.0, karb: 48.0, yag: 7.0, lif: 6.0,
    demir: 2.0, magnezyum: 55, kalsiyum: 120, vitaminB1: 0.3, vitaminB6: 0.2, zinc: 1.2, potasyum: 300, dakika: 15,
    etiketler: ['LİF', 'ENERJİ'], ogunler: ['kahvalti'],
    diyetler: ['vejetaryen'], zenginOldugu: ['lif', 'protein'], renk: Color(0xFFD4A056),
    gorselUrl: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 su bardağı tam buğday unu', '1 yumurta', '1 su bardağı süt', '1 tatlı kaşığı kabartma tozu', 'Çilek veya muz'],
    adimlar: ['Unu, yumurta ve sütü karıştırın.', 'Kısık ateşte her iki yüzünü pişirin.', 'Meyvelerle servis yapın.'],
  ),
  _Tarif(
    ad: 'Fıstık Ezmeli Muz Tost', aciklama: 'Protein ve potasyum dolu kahvaltı', kalori: 370, protein: 12.0, karb: 42.0, yag: 16.0, lif: 5.0,
    magnezyum: 60, potasyum: 520, vitaminB6: 0.5, zinc: 1.5, dakika: 5,
    etiketler: ['ENERJİ', 'PROTEİN'], ogunler: ['kahvalti', 'araOgun'],
    diyetler: ['vegan', 'vejetaryen'], zenginOldugu: ['protein', 'potasyum'], renk: Color(0xFFD4A056),
    gorselUrl: 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 dilim ekmek', '2 yemek kaşığı fıstık ezmesi', '1 muz', 'Bal'],
    adimlar: ['Ekmeği kızartın.', 'Fıstık ezmesini sürün.', 'İnce dilimlenmiş muzı üzerine dizin, bal gezdirin.'],
  ),
  _Tarif(
    ad: 'Sebzeli Yumurta Haşlama', aciklama: 'Düşük kalorili doyurucu kahvaltı', kalori: 220, protein: 14.0, karb: 12.0, yag: 12.0, lif: 4.0,
    demir: 3.0, magnezyum: 35, kalsiyum: 80, vitaminA: 320, vitaminC: 30, vitaminD: 2.0, vitaminB12: 1.0, zinc: 1.8, potasyum: 380, dakika: 15,
    etiketler: ['DÜŞÜK KALORİ', 'PROTEİN'], ogunler: ['kahvalti'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'demir', 'vitaminA'], renk: Color(0xFF8BC34A),
    gorselUrl: 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 yumurta', '1 domates', '½ biber', 'Maydanoz', 'Zeytinyağı'],
    adimlar: ['Sebzeleri ince doğrayın.', 'Zeytinyağında sebzeleri kavurun.', 'Üzerine yumurtaları kırıp pişirin.'],
  ),
  _Tarif(
    ad: 'Yeşil Smoothie', aciklama: 'Detoks ve enerji veren içecek', kalori: 180, protein: 5.0, karb: 28.0, yag: 5.0, lif: 6.0,
    demir: 2.5, magnezyum: 55, kalsiyum: 100, vitaminA: 800, vitaminC: 60, zinc: 0.8, potasyum: 520, dakika: 5,
    etiketler: ['DETOKS', 'VEGAN'], ogunler: ['kahvalti', 'araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['vitaminC', 'vitaminA', 'lif'], renk: Color(0xFF4CAF50),
    gorselUrl: 'https://images.unsplash.com/photo-1610970881699-44a5587cabec?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 avuç ıspanak', '1 muz', '½ elma', '1 su bardağı su', '1 tatlı kaşığı zencefil'],
    adimlar: ['Tüm malzemeleri blendere koyun.', 'Pürüzsüz olana kadar blenderdan geçirin.', 'Hemen tüketin.'],
  ),
  // ── ÖĞLE ──────────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Izgara Tavuklu Kinoa', aciklama: 'Protein dolu egzersiz sonrası tabak', kalori: 520, protein: 42.0, karb: 35.0, yag: 12.0, lif: 8.0,
    demir: 5.5, magnezyum: 110, kalsiyum: 60, vitaminC: 15, vitaminB6: 0.8, vitaminB12: 0.5, zinc: 3.5, potasyum: 620, dakika: 25,
    etiketler: ['YÜKSEK PROTEİN', 'TOPARLANMA'], ogunler: ['ogle'],
    diyetler: ['glutensiz'], zenginOldugu: ['protein', 'demir', 'magnezyum'], renk: Color(0xFFE6A44A),
    gorselUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['150g tavuk göğsü', 'Yarım su bardağı kinoa', 'Brokoli', 'Zeytinyağı'],
    adimlar: ['Kinoayı haşlayın.', 'Tavukları ızgara yapın.', 'Buharda pişmiş brokoli ile servis edin.'],
  ),
  _Tarif(
    ad: 'Mercimek Çorbası', aciklama: 'Demir açısından zengin ısıtıcı çorba', kalori: 310, protein: 18.0, karb: 45.0, yag: 4.0, lif: 15.0,
    demir: 7.2, magnezyum: 80, kalsiyum: 60, vitaminA: 1200, vitaminC: 30, vitaminB1: 0.5, vitaminB6: 0.6, zinc: 2.8, potasyum: 730, dakika: 30,
    etiketler: ['YÜKSEK DEMİR', 'VEGAN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['demir', 'lif', 'vitaminA'], renk: Color(0xFFB05C1A),
    gorselUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 su bardağı kırmızı mercimek', '1 adet soğan', '1 adet havuç', 'Zerdeçal'],
    adimlar: ['Sebzeleri soteleyin.', 'Mercimeği ekleyip suyunu koyun.', 'Pişince blenderdan geçirin.'],
  ),
  _Tarif(
    ad: 'Ton Balıklı Salata', aciklama: 'Hızlı ve proteinli öğle yemeği', kalori: 320, protein: 28.0, karb: 10.0, yag: 15.0, lif: 4.0,
    demir: 1.5, magnezyum: 40, kalsiyum: 30, vitaminD: 6.0, vitaminB12: 2.5, vitaminB6: 0.5, zinc: 1.2, potasyum: 350, omega3: 1.8, dakika: 10,
    etiketler: ['YÜKSEK PROTEİN', 'OMEGA-3'], ogunler: ['ogle'],
    diyetler: ['keto', 'glutensiz'], zenginOldugu: ['protein', 'omega3', 'vitaminD'], renk: Color(0xFF03A9F4),
    gorselUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Ton balığı', 'Mevsim yeşillikleri', 'Mısır', 'Limon'],
    adimlar: ['Yeşillikleri doğrayın, ton balığını ekleyin.'],
  ),
  _Tarif(
    ad: 'Kinoalı Akdeniz Salatası', aciklama: 'Ferahlatıcı ve doyurucu', kalori: 290, protein: 10.0, karb: 40.0, yag: 8.0, lif: 7.0,
    demir: 4.0, magnezyum: 95, kalsiyum: 110, vitaminA: 600, vitaminC: 35, vitaminE: 2.5, vitaminB6: 0.3, zinc: 1.5, potasyum: 450, dakika: 10,
    etiketler: ['VEGAN', 'HAFİF'], ogunler: ['ogle', 'araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'demir', 'magnezyum'], renk: Color(0xFF009688),
    gorselUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Kinoa', 'Domates', 'Salatalık', 'Zeytinyağı'],
    adimlar: ['Haşlanmış kinoayı doğranmış sebzelerle karıştırın.'],
  ),
  _Tarif(
    ad: 'Fırın Falafel', aciklama: 'Yağsız ve çıtır falafel topları', kalori: 250, protein: 12.0, karb: 35.0, yag: 8.0, lif: 9.0,
    demir: 5.2, magnezyum: 100, kalsiyum: 90, vitaminC: 10, vitaminB1: 0.3, vitaminB6: 0.4, zinc: 2.2, potasyum: 390, dakika: 35,
    etiketler: ['VEGAN', 'YÜKSEK LİF'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'protein', 'demir'], renk: Color(0xFF8BC34A),
    gorselUrl: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Nohut', 'Maydanoz', 'Sarımsak', 'Baharatlar'],
    adimlar: ['Malzemeleri robottan geçirin.', 'Toplar şekline getirip fırında 200°C\'de 25 dakika pişirin.'],
  ),
  _Tarif(
    ad: 'Tofu Sote', aciklama: 'Sebzeli çıtır tofu', kalori: 340, protein: 22.0, karb: 10.0, yag: 18.0, lif: 5.0,
    demir: 4.5, magnezyum: 90, kalsiyum: 450, vitaminC: 15, vitaminB1: 0.4, vitaminB6: 0.3, zinc: 2.0, potasyum: 400, dakika: 20,
    etiketler: ['VEGAN', 'PROTEİN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'kalsiyum', 'demir'], renk: Color(0xFF4CAF50),
    gorselUrl: 'https://images.unsplash.com/photo-1546069901-d5bfd2cbfb1f?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['200g sert tofu', 'Biber', 'Kabak', 'Soya sosu'],
    adimlar: ['Tofuları küp küp doğrayıp kızartın.', 'Sebzeleri ekleyip soteleyin.', 'Soya sosu ile tatlandırın.'],
  ),
  _Tarif(
    ad: 'Karabuğday Pilavı', aciklama: 'Glutensiz ve sağlıklı karbonhidrat', kalori: 310, protein: 10.0, karb: 55.0, yag: 4.0, lif: 8.0,
    demir: 3.5, magnezyum: 180, kalsiyum: 40, vitaminB1: 0.4, vitaminB6: 0.3, zinc: 2.0, potasyum: 460, dakika: 20,
    etiketler: ['YÜKSEK LİF', 'GLUTENSİZ'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'magnezyum', 'demir'], renk: Color(0xFF795548),
    gorselUrl: 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Karabuğday', 'Soğan', 'Mantar', 'Zeytinyağı'],
    adimlar: ['Karabuğdayı haşlayın.', 'Soğan ve mantarı zeytinyağında soteleyin.', 'Karıştırıp servis yapın.'],
  ),
  _Tarif(
    ad: 'Tavuklu Wrap', aciklama: 'Lifli tortiyaya sarılı protein', kalori: 430, protein: 32.0, karb: 38.0, yag: 14.0, lif: 6.0,
    demir: 2.0, magnezyum: 45, kalsiyum: 60, vitaminA: 400, vitaminC: 25, vitaminB6: 0.6, zinc: 2.2, potasyum: 480, dakika: 15,
    etiketler: ['YÜKSEK PROTEİN', 'PRATIK'], ogunler: ['ogle'],
    diyetler: ['glutensiz'], zenginOldugu: ['protein', 'vitaminA'], renk: Color(0xFFE6A44A),
    gorselUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 adet tam buğday tortiya', '120g tavuk göğsü', 'Marul', 'Domates', 'Yoğurt sosu'],
    adimlar: ['Tavuğu baharatlarla ızgara yapın.', 'Tortiyaya tüm malzemeleri dizin.', 'Sıkıca sarıp servis yapın.'],
  ),
  _Tarif(
    ad: 'Nohutlu Ispanaklı Yemek', aciklama: 'Demir ve protein dolu sıcak yemek', kalori: 360, protein: 16.0, karb: 44.0, yag: 10.0, lif: 12.0,
    demir: 6.8, magnezyum: 90, kalsiyum: 140, vitaminA: 900, vitaminC: 35, vitaminB6: 0.5, zinc: 2.5, potasyum: 680, dakika: 25,
    etiketler: ['YÜKSEK DEMİR', 'VEGAN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['demir', 'lif', 'vitaminA'], renk: Color(0xFF388E3C),
    gorselUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 kutu nohut', '2 avuç ıspanak', '1 soğan', 'Sarımsak', 'Zerdeçal', 'Domates'],
    adimlar: ['Soğanı soteleyin, sarımsak ekleyin.', 'Domates ve baharatları ekleyip pişirin.', 'Nohut ve ıspanağı ekleyip 10 dakika daha pişirin.'],
  ),
  _Tarif(
    ad: 'Tam Buğday Makarna', aciklama: 'Domates soslu sağlıklı makarna', kalori: 420, protein: 14.0, karb: 68.0, yag: 8.0, lif: 9.0,
    demir: 3.0, magnezyum: 70, kalsiyum: 50, vitaminA: 300, vitaminC: 20, vitaminB1: 0.4, vitaminB6: 0.3, zinc: 1.5, potasyum: 420, dakika: 20,
    etiketler: ['YÜKSEK LİF', 'ENERJİ'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen'], zenginOldugu: ['lif', 'demir'], renk: Color(0xFFE53935),
    gorselUrl: 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Tam buğday makarna', 'Domates sosu', 'Sarımsak', 'Fesleğen', 'Zeytinyağı'],
    adimlar: ['Makarnayı al dente pişirin.', 'Sarımsağı zeytinyağında kavurun, domates sosunu ekleyin.', 'Makarna ile harmanlayıp servis edin.'],
  ),
  _Tarif(
    ad: 'Sebzeli Kuskus', aciklama: 'Akdeniz usulü hafif kuskus tabağı', kalori: 330, protein: 11.0, karb: 52.0, yag: 7.0, lif: 7.0,
    demir: 3.5, magnezyum: 60, kalsiyum: 45, vitaminA: 500, vitaminC: 40, vitaminB6: 0.3, zinc: 1.2, potasyum: 450, dakika: 15,
    etiketler: ['VEGAN', 'HAFİF'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen'], zenginOldugu: ['lif', 'vitaminA', 'demir'], renk: Color(0xFFF9A825),
    gorselUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 su bardağı kuskus', 'Kabak', 'Biber', 'Domates', 'Zeytinyağı', 'Nane'],
    adimlar: ['Kuskusu kaynar suda bekletin.', 'Sebzeleri zeytinyağında soteleyin.', 'Kuskusu sebzelerle karıştırıp nane ekleyin.'],
  ),
  // ── AKŞAM ─────────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Somon Izgara', aciklama: 'Omega-3 bombası akşam yemeği', kalori: 520, protein: 38.0, karb: 0.0, yag: 35.0, lif: 2.0,
    demir: 1.2, magnezyum: 45, kalsiyum: 40, vitaminA: 100, vitaminD: 25.0, vitaminB12: 4.8, vitaminB6: 0.9, zinc: 1.0, potasyum: 480, omega3: 3.5, dakika: 30,
    etiketler: ['OMEGA-3', 'YÜKSEK PROTEİN'], ogunler: ['aksam'],
    diyetler: ['glutensiz', 'karnivor'], zenginOldugu: ['omega3', 'protein', 'vitaminD'], renk: Color(0xFF4A8ECC),
    gorselUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 dilim somon', 'Kuşkonmaz', 'Limon', 'Biberiye'],
    adimlar: ['Somonu baharatlayın.', 'Fırın tepsisine somon ve kuşkonmazları dizin.', '200 derecede 20 dakika pişirin.'],
  ),
  _Tarif(
    ad: 'Biftek ve Kuşkonmaz', aciklama: 'Mükemmel pişirilmiş biftek', kalori: 480, protein: 45.0, karb: 0.0, yag: 28.0, lif: 3.0,
    demir: 6.5, magnezyum: 40, kalsiyum: 25, vitaminC: 5, vitaminB12: 3.5, vitaminB6: 0.7, zinc: 8.0, potasyum: 560, dakika: 25,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK KARBONHİDRAT'], ogunler: ['aksam'],
    diyetler: ['keto', 'glutensiz', 'karnivor'], zenginOldugu: ['protein', 'demir', 'zinc'], renk: Color(0xFF8B3A3A),
    gorselUrl: 'https://images.unsplash.com/photo-1546241072-48010ad28c2c?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['200g biftek', 'Kuşkonmaz', 'Tereyağı', 'Sarımsak'],
    adimlar: ['Tavayı iyice ısıtın.', 'Bifteği her iki taraflı 4-5 dakika pişirin.', 'Son dakikada tereyağı ve sarımsak ekleyip soslayın.'],
  ),
  _Tarif(
    ad: 'Fırın Sebze Dizmesi', aciklama: 'Hafif ve sağlıklı sebze tabağı', kalori: 180, protein: 4.0, karb: 30.0, yag: 6.0, lif: 5.0,
    demir: 1.8, magnezyum: 45, kalsiyum: 35, vitaminA: 400, vitaminC: 30, vitaminE: 2.0, vitaminB6: 0.4, zinc: 0.8, potasyum: 520, dakika: 40,
    etiketler: ['DÜŞÜK KALORİ', 'VEGAN'], ogunler: ['aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'vitaminA'], renk: Color(0xFFFF9800),
    gorselUrl: 'https://images.unsplash.com/photo-1564834724105-918b73d1b9e0?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Patlıcan', 'Kabak', 'Domates', 'Zeytinyağı'],
    adimlar: ['Sebzeleri dilimleyip fırınlayın.'],
  ),
  _Tarif(
    ad: 'Sebzeli Tavuk Sote', aciklama: 'Renkli biberli tavuk göğsü', kalori: 380, protein: 35.0, karb: 10.0, yag: 12.0, lif: 4.0,
    demir: 2.5, magnezyum: 50, kalsiyum: 40, vitaminA: 800, vitaminC: 95, vitaminB6: 0.7, zinc: 2.8, potasyum: 510, dakika: 20,
    etiketler: ['DÜŞÜK KALORİ', 'YÜKSEK PROTEİN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['keto', 'glutensiz'], zenginOldugu: ['protein', 'vitaminC', 'vitaminA'], renk: Color(0xFFFF5722),
    gorselUrl: 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Tavuk', 'Biber', 'Soğan', 'Baharatlar'],
    adimlar: ['Tavukları soteleyin.', 'Sebzeleri ekleyip pişirin.'],
  ),
  _Tarif(
    ad: 'Hindi Köfte', aciklama: 'Hafif ve yüksek proteinli köfte', kalori: 350, protein: 38.0, karb: 8.0, yag: 14.0, lif: 2.0,
    demir: 3.5, magnezyum: 40, kalsiyum: 30, vitaminB6: 0.7, vitaminB12: 1.5, zinc: 4.5, potasyum: 490, dakika: 25,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK YAĞ'], ogunler: ['aksam'],
    diyetler: ['glutensiz'], zenginOldugu: ['protein', 'zinc', 'demir'], renk: Color(0xFF795548),
    gorselUrl: 'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['300g hindi kıyması', 'Soğan', 'Maydanoz', 'Yumurta', 'Baharatlar'],
    adimlar: ['Tüm malzemeleri yoğurun.', 'Köfte şeklinde hazırlayın.', 'Izgara veya fırında pişirin.'],
  ),
  _Tarif(
    ad: 'Balık Tava', aciklama: 'Çıtır zeytinyağlı balık', kalori: 390, protein: 34.0, karb: 5.0, yag: 22.0, lif: 1.5,
    demir: 1.5, magnezyum: 50, kalsiyum: 40, vitaminD: 12.0, vitaminB12: 3.0, vitaminB6: 0.5, zinc: 1.5, potasyum: 450, omega3: 2.0, dakika: 20,
    etiketler: ['OMEGA-3', 'PROTEİN'], ogunler: ['aksam'],
    diyetler: ['glutensiz', 'karnivor'], zenginOldugu: ['protein', 'omega3', 'vitaminD'], renk: Color(0xFF1976D2),
    gorselUrl: 'https://images.unsplash.com/photo-1535399831218-d5bd36d1a6b3?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Levrek ya da çipura', 'Limon', 'Zeytinyağı', 'Taze otlar'],
    adimlar: ['Balığı yıkayıp kurulayın.', 'Zeytinyağı ve limonla marine edin.', 'Tavada ya da fırında pişirin.'],
  ),
  _Tarif(
    ad: 'Sebzeli Güveç', aciklama: 'Düşük kalorili besleyici güveç', kalori: 270, protein: 9.0, karb: 38.0, yag: 8.0, lif: 10.0,
    demir: 4.5, magnezyum: 65, kalsiyum: 80, vitaminA: 1100, vitaminC: 55, vitaminB6: 0.5, zinc: 1.8, potasyum: 750, dakika: 45,
    etiketler: ['DÜŞÜK KALORİ', 'VEGAN'], ogunler: ['aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'vitaminA', 'vitaminC'], renk: Color(0xFFD32F2F),
    gorselUrl: 'https://images.unsplash.com/photo-1548943487-a2e4e43b4853?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Patlıcan', 'Patates', 'Biber', 'Domates', 'Soğan', 'Zeytinyağı'],
    adimlar: ['Sebzeleri doğrayın.', 'Güveç kabına dizin.', '180°C fırında 40 dakika pişirin.'],
  ),
  _Tarif(
    ad: 'Fırın Tavuk Baget', aciklama: 'Baharatlı çıtır tavuk baget', kalori: 440, protein: 40.0, karb: 4.0, yag: 24.0, lif: 1.0,
    demir: 2.0, magnezyum: 35, kalsiyum: 30, vitaminB6: 0.8, vitaminB12: 0.7, zinc: 3.5, potasyum: 440, dakika: 40,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK KARBONHİDRAT'], ogunler: ['aksam'],
    diyetler: ['glutensiz', 'keto', 'karnivor'], zenginOldugu: ['protein', 'zinc'], renk: Color(0xFFF57F17),
    gorselUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Tavuk baget', 'Sarımsak tozu', 'Pul biber', 'Zeytinyağı', 'Limon'],
    adimlar: ['Tavukları baharatlarla ovun.', 'Üzerine zeytinyağı ve limon sıkın.', '200°C fırında 35 dakika pişirin.'],
  ),
  // ── ARA ÖĞÜN ──────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Humus Tabağı', aciklama: 'Nohut humusu ve çıtır sebzeler', kalori: 180, protein: 8.0, karb: 22.0, yag: 10.0, lif: 6.0,
    demir: 3.0, magnezyum: 70, kalsiyum: 80, vitaminA: 500, vitaminC: 45, vitaminB6: 0.4, zinc: 1.8, potasyum: 350, dakika: 5,
    etiketler: ['VEGAN', 'YÜKSEK LİF'], ogunler: ['araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'protein', 'demir'], renk: Color(0xFFE6742A),
    gorselUrl: 'https://images.unsplash.com/photo-1541518763669-27fef04b14ea?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 kase humus', 'Havuç çubukları', 'Salatalık', 'Tam buğday lavaş'],
    adimlar: ['Sebzeleri dilimleyin.', 'Humusu tabağın ortasına alın.', 'Zeytinyağı ve pul biber ekleyerek servis edin.'],
  ),
  _Tarif(
    ad: 'Lor Peynirli Salata', aciklama: 'Kas dostu hafif öğün', kalori: 240, protein: 20.0, karb: 10.0, yag: 12.0, lif: 3.0,
    demir: 1.5, magnezyum: 35, kalsiyum: 150, vitaminA: 120, vitaminC: 8, vitaminB12: 0.8, zinc: 1.5, potasyum: 280, omega3: 1.2, dakika: 5,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK YAĞ'], ogunler: ['ogle', 'araOgun'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'kalsiyum'], renk: Color(0xFFE91E63),
    gorselUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Lor peyniri', 'Roka', 'Ceviz', 'Nar ekşisi'],
    adimlar: ['Roka üzerine lor ve cevizi ekleyip soslayın.'],
  ),
  _Tarif(
    ad: 'Fıstık Ezmeli Elma', aciklama: 'Lif ve sağlıklı yağ bir arada', kalori: 200, protein: 5.0, karb: 26.0, yag: 9.0, lif: 5.0,
    magnezyum: 25, potasyum: 240, vitaminC: 8, zinc: 0.8, dakika: 3,
    etiketler: ['HAFİF', 'SAĞLIKLI YAĞ'], ogunler: ['araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'protein'], renk: Color(0xFFE53935),
    gorselUrl: 'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 elma', '2 yemek kaşığı fıstık ezmesi', 'Tarçın'],
    adimlar: ['Elmayı dilimleyin.', 'Fıstık ezmesine batırarak servis yapın.'],
  ),
  _Tarif(
    ad: 'Karışık Kuruyemiş', aciklama: 'Sağlıklı yağ ve mineral deposu', kalori: 170, protein: 5.0, karb: 8.0, yag: 14.0, lif: 3.0,
    magnezyum: 55, kalsiyum: 30, vitaminE: 4.0, zinc: 1.5, potasyum: 200, omega3: 1.5, dakika: 1,
    etiketler: ['SAĞLIKLI YAĞ', 'MİNERAL'], ogunler: ['araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['magnezyum', 'omega3', 'vitaminE'], renk: Color(0xFF8D6E63),
    gorselUrl: 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Ceviz', 'Badem', 'Fındık', 'Kabak çekirdeği'],
    adimlar: ['Kuruyemişleri karıştırıp servis yapın. 30g porsiyon önerilir.'],
  ),
  _Tarif(
    ad: 'Protein Topu', aciklama: 'Spor sonrası çikolatalı enerji topu', kalori: 130, protein: 8.0, karb: 14.0, yag: 5.0, lif: 3.0,
    magnezyum: 40, zinc: 1.2, potasyum: 180, omega3: 0.5, dakika: 10,
    etiketler: ['PROTEİN', 'SPOR'], ogunler: ['araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'magnezyum'], renk: Color(0xFF6D4C41),
    gorselUrl: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Yulaf', 'Fıstık ezmesi', 'Kakao tozu', 'Bal', 'Protein tozu (isteğe bağlı)'],
    adimlar: ['Tüm malzemeleri karıştırın.', 'Toplar şekline getirin.', 'Buzdolabında 30 dakika soğutun.'],
  ),
  _Tarif(
    ad: 'Meyve ve Yoğurt', aciklama: 'Probiyotik ve taze meyveli atıştırmalık', kalori: 160, protein: 8.0, karb: 22.0, yag: 3.0, lif: 3.0,
    kalsiyum: 200, vitaminC: 30, vitaminB12: 0.8, zinc: 1.0, potasyum: 350, dakika: 3,
    etiketler: ['PROBİYOTİK', 'DÜŞÜK KALORİ'], ogunler: ['araOgun', 'kahvalti'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['kalsiyum', 'protein', 'vitaminC'], renk: Color(0xFFFF7043),
    gorselUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 kase Yunan yoğurdu', 'Çilek', 'Yaban mersini', 'Muz'],
    adimlar: ['Yoğurdu kaseye alın.', 'Taze meyveleri üzerine ekleyin.', 'Hemen servis yapın.'],
  ),
  // ── EK KAHVALTI ───────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Peynirli Gözleme', aciklama: 'İnce hamurda beyaz peynirli geleneksel lezzet', kalori: 380, protein: 14.0, karb: 44.0, yag: 16.0, lif: 3.0,
    demir: 1.8, magnezyum: 30, kalsiyum: 260, vitaminA: 120, vitaminB12: 0.6, vitaminB1: 0.2, zinc: 1.4, potasyum: 220, dakika: 20,
    etiketler: ['GELENEKSEL', 'PROTEİN'], ogunler: ['kahvalti'],
    diyetler: ['vejetaryen'], zenginOldugu: ['protein', 'kalsiyum'], renk: Color(0xFFD4A056),
    gorselUrl: 'https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 adet yufka', '100g beyaz peynir', 'Maydanoz', 'Zeytinyağı'],
    adimlar: ['Yufkayı hafif yağlayın.', 'Peynir ve maydanozu koyun, katlayın.', 'Yapışmaz tavada her iki yüzünü altın rengi olana dek kızartın.'],
  ),
  _Tarif(
    ad: 'Tarhana Çorbası', aciklama: 'Fermente tahıllı geleneksel sabah çorbası', kalori: 210, protein: 9.0, karb: 32.0, yag: 5.0, lif: 4.0,
    demir: 2.5, magnezyum: 40, kalsiyum: 80, vitaminA: 200, vitaminC: 12, vitaminB1: 0.2, vitaminB6: 0.3, zinc: 1.5, potasyum: 310, dakika: 15,
    etiketler: ['PROBİYOTİK', 'GELENEKSEL'], ogunler: ['kahvalti', 'ogle'],
    diyetler: ['vejetaryen'], zenginOldugu: ['demir', 'lif', 'protein'], renk: Color(0xFFB05C1A),
    gorselUrl: 'https://images.unsplash.com/photo-1603105037880-880cd4edfb0d?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['4 yemek kaşığı tarhana', '3 su bardağı su', 'Tereyağı', 'Pul biber', 'Nane'],
    adimlar: ['Tarhanayı soğuk suda eritin.', 'Kısık ateşte karıştırarak pişirin.', 'Tereyağında nane ve pul biber kavurup üzerine dökün.'],
  ),
  _Tarif(
    ad: 'Tahin Pekmez', aciklama: 'Geleneksel ve besleyici kahvaltı ikilisi', kalori: 260, protein: 7.0, karb: 30.0, yag: 13.0, lif: 2.5,
    demir: 2.8, magnezyum: 70, kalsiyum: 110, vitaminB1: 0.3, vitaminB6: 0.1, zinc: 1.8, potasyum: 380, dakika: 3,
    etiketler: ['ENERJİ', 'MİNERAL'], ogunler: ['kahvalti'],
    diyetler: ['vegan', 'vejetaryen'], zenginOldugu: ['demir', 'magnezyum', 'kalsiyum'], renk: Color(0xFF8D6E63),
    gorselUrl: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 yemek kaşığı tahin', '2 yemek kaşığı üzüm pekmezi', 'Tam buğday ekmek'],
    adimlar: ['Tahini tabağa alın.', 'Üzerine pekmezi gezdirin.', 'Tost ya da ekmekle servis edin.'],
  ),
  // ── EK ÖĞLE ──────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Bulgur Pilavı', aciklama: 'Şehriyeli bol mineralli pilav', kalori: 320, protein: 10.0, karb: 58.0, yag: 5.0, lif: 8.0,
    demir: 3.0, magnezyum: 85, kalsiyum: 30, vitaminB1: 0.4, vitaminB6: 0.3, zinc: 1.8, potasyum: 360, dakika: 20,
    etiketler: ['YÜKSEK LİF', 'ENERJİ'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen'], zenginOldugu: ['lif', 'magnezyum', 'demir'], renk: Color(0xFFD4A056),
    gorselUrl: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 su bardağı iri bulgur', '1 soğan', 'Şehriye', 'Domates salçası', 'Zeytinyağı'],
    adimlar: ['Soğanı zeytinyağında kavurun.', 'Salça ve bulguru ekleyip kavurun.', 'Sıcak su ekleyip kısık ateşte demleyin.'],
  ),
  _Tarif(
    ad: 'Zeytinyağlı Taze Fasulye', aciklama: 'Geleneksel zeytinyağlı Türk yemeği', kalori: 240, protein: 5.0, karb: 28.0, yag: 12.0, lif: 7.0,
    demir: 2.2, magnezyum: 45, kalsiyum: 55, vitaminA: 600, vitaminC: 25, vitaminB6: 0.2, zinc: 0.8, potasyum: 420, dakika: 35,
    etiketler: ['VEGAN', 'DÜŞÜK KALORİ'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'vitaminA'], renk: Color(0xFF4CAF50),
    gorselUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['500g taze fasulye', '2 domates', '1 soğan', 'Zeytinyağı', 'Şeker'],
    adimlar: ['Soğanı zeytinyağında kavurun.', 'Domates ve fasulyeleri ekleyin.', 'Kısık ateşte 30 dakika pişirin, soğuk servis yapın.'],
  ),
  _Tarif(
    ad: 'Patlıcan Musakka', aciklama: 'Fırınlanmış kıymalı patlıcan musakka', kalori: 410, protein: 24.0, karb: 20.0, yag: 22.0, lif: 6.0,
    demir: 4.5, magnezyum: 50, kalsiyum: 50, vitaminA: 500, vitaminC: 20, vitaminB12: 1.5, vitaminB6: 0.5, zinc: 4.0, potasyum: 620, dakika: 50,
    etiketler: ['GELENEKSEL', 'YÜKSEK PROTEİN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['glutensiz'], zenginOldugu: ['protein', 'demir', 'zinc'], renk: Color(0xFF6D4C41),
    gorselUrl: 'https://images.unsplash.com/photo-1576866209830-589e1bfbaa4d?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 patlıcan', '300g kıyma', '1 soğan', 'Domates sosu', 'Zeytinyağı'],
    adimlar: ['Patlıcanları dilimleyip tuzlayın, hafif kızartın.', 'Kıymayı soğanla kavurun, domates sosunu ekleyin.', 'Katmanlar halinde dizin, fırında 35 dakika pişirin.'],
  ),
  _Tarif(
    ad: 'Sarımsaklı Karides', aciklama: 'Tereyağlı çıtır karides kavurma', kalori: 290, protein: 28.0, karb: 4.0, yag: 16.0, lif: 0.5,
    demir: 2.5, magnezyum: 40, kalsiyum: 80, vitaminD: 4.0, vitaminB12: 1.8, vitaminB6: 0.3, zinc: 2.0, potasyum: 350, omega3: 0.6, dakika: 15,
    etiketler: ['YÜKSEK PROTEİN', 'OMEGA-3'], ogunler: ['ogle', 'aksam'],
    diyetler: ['glutensiz', 'keto', 'karnivor'], zenginOldugu: ['protein', 'vitaminD', 'zinc'], renk: Color(0xFFFF7043),
    gorselUrl: 'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['300g karides', '3 diş sarımsak', 'Tereyağı', 'Limon', 'Maydanoz'],
    adimlar: ['Sarımsağı tereyağında kavurun.', 'Karidesler pembeye dönünce limon sıkın.', 'Maydanoz ekleyip servis yapın.'],
  ),
  _Tarif(
    ad: 'Nohut Çorbası', aciklama: 'Doyurucu ve protein dolu sıcak çorba', kalori: 290, protein: 14.0, karb: 40.0, yag: 7.0, lif: 10.0,
    demir: 4.0, magnezyum: 60, kalsiyum: 70, vitaminA: 100, vitaminC: 8, vitaminB1: 0.3, vitaminB6: 0.4, zinc: 2.0, potasyum: 480, dakika: 30,
    etiketler: ['YÜKSEK LİF', 'VEGAN'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'demir', 'protein'], renk: Color(0xFFD4A056),
    gorselUrl: 'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['2 su bardağı haşlanmış nohut', '1 soğan', 'Zerdeçal', 'Kimyon', 'Zeytinyağı'],
    adimlar: ['Soğanı zeytinyağında kavurun.', 'Nohut ve baharatları ekleyin, suyunu koyun.', 'Kıvam alınca servis yapın.'],
  ),
  // ── EK AKŞAM ─────────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Levrek Buğulama', aciklama: 'Sebzeli buharda pişirilmiş levrek', kalori: 340, protein: 36.0, karb: 6.0, yag: 16.0, lif: 2.0,
    demir: 1.8, magnezyum: 55, kalsiyum: 60, vitaminD: 18.0, vitaminB12: 3.5, vitaminB6: 0.7, zinc: 1.5, potasyum: 550, omega3: 2.8, dakika: 30,
    etiketler: ['OMEGA-3', 'DÜŞÜK KALORİ'], ogunler: ['aksam'],
    diyetler: ['glutensiz', 'karnivor'], zenginOldugu: ['omega3', 'protein', 'vitaminD'], renk: Color(0xFF4A8ECC),
    gorselUrl: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 levrek (400g)', 'Zeytinyağı', 'Limon', 'Havuç', 'Kereviz', 'Defne yaprağı'],
    adimlar: ['Levreği ve sebzeleri tencereye dizin.', 'Limon suyu ve zeytinyağı ekleyin.', 'Kapağı kapalı 20 dakika buharda pişirin.'],
  ),
  _Tarif(
    ad: 'Dana Güveci', aciklama: 'Yavaş pişirilmiş sebzeli dana eti', kalori: 460, protein: 38.0, karb: 22.0, yag: 22.0, lif: 5.0,
    demir: 6.0, magnezyum: 45, kalsiyum: 40, vitaminA: 400, vitaminB12: 2.5, vitaminB6: 0.6, zinc: 7.0, potasyum: 680, dakika: 90,
    etiketler: ['YÜKSEK PROTEİN', 'GELENEKSEL'], ogunler: ['aksam'],
    diyetler: ['glutensiz', 'karnivor'], zenginOldugu: ['protein', 'demir', 'zinc'], renk: Color(0xFF8B3A3A),
    gorselUrl: 'https://images.unsplash.com/photo-1551881192-002c429f5a03?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['400g dana kuşbaşı', 'Patates', 'Havuç', 'Biber', 'Domates', 'Soğan', 'Zeytinyağı'],
    adimlar: ['Eti zeytinyağında sote edin.', 'Sebzeleri ekleyip kavurun.', 'Sıcak su koyup 75 dakika kısık ateşte pişirin.'],
  ),
  _Tarif(
    ad: 'Zeytinyağlı Enginar', aciklama: 'Baharatlı zeytinyağlı soğuk meze', kalori: 190, protein: 4.5, karb: 18.0, yag: 11.0, lif: 7.0,
    demir: 1.5, magnezyum: 50, kalsiyum: 40, vitaminC: 15, vitaminB6: 0.2, zinc: 0.6, potasyum: 380, dakika: 40,
    etiketler: ['VEGAN', 'DÜŞÜK KALORİ'], ogunler: ['ogle', 'aksam'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['lif', 'magnezyum'], renk: Color(0xFF558B2F),
    gorselUrl: 'https://images.unsplash.com/photo-1596547609652-9cf5d8c10616?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['4 adet enginar', 'Zeytinyağı', 'Limon', 'Soğan', 'Bezelye', 'Şeker'],
    adimlar: ['Enginarları limonlu suda bekletin.', 'Soğan ve bezelyeyle tencereye koyun.', 'Zeytinyağı ve limon ekleyip 30 dakika pişirin, soğutun.'],
  ),
  // ── EK ARA ÖĞÜN ──────────────────────────────────────────────────────────
  _Tarif(
    ad: 'Taze Meyve Salatası', aciklama: 'Vitamin bombası renkli meyve salatası', kalori: 120, protein: 2.0, karb: 28.0, yag: 0.5, lif: 4.0,
    magnezyum: 20, kalsiyum: 30, vitaminC: 60, vitaminA: 150, potasyum: 380, dakika: 8,
    etiketler: ['DÜŞÜK KALORİ', 'VİTAMİN'], ogunler: ['araOgun', 'kahvalti'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['vitaminC', 'vitaminA', 'lif'], renk: Color(0xFFFF7043),
    gorselUrl: 'https://images.unsplash.com/photo-1464305795204-6f5bbfc7fb81?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['Çilek', 'Kavun', 'Karpuz', 'Üzüm', 'Nane', 'Limon suyu'],
    adimlar: ['Tüm meyveleri küp küp doğrayın.', 'Limon suyu ve nane ekleyin.', 'Soğuk servis yapın.'],
  ),
  _Tarif(
    ad: 'Lor Peyniri ve Domates', aciklama: 'Hafif ve protein dolu sağlıklı atıştırmalık', kalori: 150, protein: 12.0, karb: 6.0, yag: 8.0, lif: 1.5,
    demir: 0.8, magnezyum: 20, kalsiyum: 180, vitaminA: 250, vitaminC: 15, vitaminB12: 0.5, zinc: 1.2, potasyum: 280, dakika: 5,
    etiketler: ['YÜKSEK PROTEİN', 'DÜŞÜK KALORİ'], ogunler: ['araOgun', 'kahvalti'],
    diyetler: ['vejetaryen', 'glutensiz'], zenginOldugu: ['protein', 'kalsiyum'], renk: Color(0xFFE91E63),
    gorselUrl: 'https://images.unsplash.com/photo-1505253758473-96b7015fcd40?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['150g lor peyniri', '2 domates', 'Zeytinyağı', 'Kekik', 'Tuz'],
    adimlar: ['Domatesleri dilimleyin.', 'Lor peyniri ile tabağa dizin.', 'Zeytinyağı ve kekik gezdirerek servis edin.'],
  ),
  _Tarif(
    ad: 'Mercimekli Köfte', aciklama: 'Soğuk servis edilen geleneksel mercimek köftesi', kalori: 280, protein: 13.0, karb: 38.0, yag: 8.0, lif: 11.0,
    demir: 5.5, magnezyum: 75, kalsiyum: 50, vitaminA: 300, vitaminC: 18, vitaminB1: 0.4, vitaminB6: 0.4, zinc: 2.2, potasyum: 490, dakika: 30,
    etiketler: ['VEGAN', 'YÜKSEK DEMİR'], ogunler: ['ogle', 'araOgun'],
    diyetler: ['vegan', 'vejetaryen', 'glutensiz'], zenginOldugu: ['demir', 'lif', 'protein'], renk: Color(0xFFB05C1A),
    gorselUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=600',
    malzemeler: ['1 su bardağı kırmızı mercimek', '½ su bardağı ince bulgur', '1 soğan', 'Salça', 'Zeytinyağı', 'Maydanoz', 'Limon'],
    adimlar: ['Mercimeği haşlayın, suyunu süzün.', 'Bulgur, salça ve yağı ekleyip yoğurun.', 'Köfte şekli verip maydanoz ve limonla servis yapın.'],
  ),
];



// ─── Ana ekran ────────────────────────────────────────────────────────────────

class SuggestionsScreen extends StatefulWidget {
  final VoidCallback? onNavigateBack;
  final VoidCallback? onNavigateForward;

  const SuggestionsScreen({
    super.key,
    this.onNavigateBack,
    this.onNavigateForward,
  });

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        FocusScope.of(context).unfocus();
      }
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        title: null,
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _tabController.animateTo(index, duration: const Duration(milliseconds: 150), curve: Curves.easeOutQuad);
          },
          tabs: const [
            Tab(text: 'Günlük Tarifler'),
            Tab(text: 'Beslenme Koçu'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicatorWeight: 3,
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 300) {
            // Right swipe
            if (_tabController.index == 0) {
              widget.onNavigateBack?.call();
            } else {
              _tabController.animateTo(0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutQuad);
            }
          } else if (velocity < -300) {
            // Left swipe
            if (_tabController.index == _tabController.length - 1) {
              widget.onNavigateForward?.call();
            } else {
              _tabController.animateTo(1, duration: const Duration(milliseconds: 150), curve: Curves.easeOutQuad);
            }
          }
        },
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildRecipesTab(context, cs, isDark),
            const CoachScreen(isEmbedded: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesTab(BuildContext context, ColorScheme cs, bool isDark) {
    final hour = DateTime.now().hour;
    final currentPeriod = _PeriodX.fromHour(hour);
    final nutrition = context.watch<NutritionProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.activeProfile;
    
    final stats = nutrition.totalNutrition;
    final stats65 = nutrition.todayLog.totalNutrition65;
    final calorieGoal = profileProvider.calorieGoal;
    final isOverGoal = stats.calories > calorieGoal && calorieGoal > 0;

    // Detect deficiencies ( personalized logic )
    final List<String> gaps = [];
    if (stats.protein < (profile?.proteinGoal ?? 100) * 0.5) gaps.add('protein');
    if (stats.fiber < (profile?.fiberGoal ?? 25) * 0.5) gaps.add('lif');
    if (stats65 != null) {
      if (stats65.magnesium < (profile?.magnesiumGoal ?? 300) * 0.5) gaps.add('magnezyum');
      if (stats65.iron < (profile?.ironGoal ?? 10) * 0.5) gaps.add('demir');
      if (stats65.calcium < (profile?.calciumGoal ?? 1000) * 0.5) gaps.add('kalsiyum');
      if (stats65.vitC < 50) gaps.add('vitaminC');
      if (stats65.dha < 0.1) gaps.add('omega3');
    }

    // Dynamic Section Titles
    String lunchTitle = 'Hızlı ${currentPeriod.baslik.replaceAll('!', '')}';
    String relaxationTitle = (hour >= 5 && hour < 12) ? 'Sabah Dinçliği' : 'Akşam Dinlenmesi';
    String relaxationSub = (hour >= 5 && hour < 12) ? 'Güne zinde başlamak için öneriler.' : 'Kaliteli bir uyku için hafif seçimler.';

    // Filter recipes based on time and status
    // ─── Sağlık ve Tercih Filtreleme ──────────────────────────────────────────
    final healthConditions = profile?.healthConditions ?? [];
    final dietaryPrefs = profile?.dietaryPreferences ?? [];

    // Filtreleme mantığını yumuşat: Sadece 'Kesinlikle yasak' olanları çıkar (Alerji/Çölyak)
    final safeRecipes = _db.where((r) {
      if (healthConditions.contains('Çölyak') || healthConditions.contains('Gluten İntoleransı')) {
        if (!r.diyetler.contains('glutensiz')) return false;
      }
      if (healthConditions.contains('Yumurta Alerjisi') && r.malzemeler.any((m) => m.toLowerCase().contains('yumurta'))) return false;
      if (healthConditions.contains('Deniz Ürünleri Alerjisi') && r.ad.toLowerCase().contains('somon')) return false;
      if (dietaryPrefs.contains('Karnivor') || dietaryPrefs.contains('Carnivore')) {
        if (!r.diyetler.contains('karnivor')) return false;
      }
      return true;
    }).toList();

    // ─── Bölüm Listeleri ──────────────────────────────────────────────────────
    
    // Metabolism: Always energetic
    final metabolismRecipes = safeRecipes.where((r) => r.etiketler.contains('ENERJİ') || r.etiketler.contains('METABOLİZMA')).take(5).toList();
    if (metabolismRecipes.isEmpty) metabolismRecipes.addAll(safeRecipes.take(5));

    // Main Section: Personalized based on gaps
    final lunchRecipesAll = safeRecipes.where((r) => r.ogunler.contains(currentPeriod.dbKey)).toList();
    if (lunchRecipesAll.isEmpty) lunchRecipesAll.addAll(safeRecipes.take(5));

    if (gaps.isNotEmpty) {
      lunchRecipesAll.sort((a, b) {
        int scoreA = a.zenginOldugu.where((z) => gaps.contains(z)).length;
        int scoreB = b.zenginOldugu.where((z) => gaps.contains(z)).length;
        return scoreB.compareTo(scoreA);
      });
    }
    final lunchRecipes = lunchRecipesAll.take(5).toList();

    final eveningRecipes = safeRecipes.where((r) => r.ogunler.contains(hour < 12 ? 'kahvalti' : 'aksam')).take(5).toList();
    if (eveningRecipes.isEmpty) eveningRecipes.addAll(safeRecipes.reversed.take(5));

    return ListView(
      key: const PageStorageKey<String>('recipes_tab'),
      padding: EdgeInsets.zero,
      children: [
        _buildCoachHeaderCard(context, cs),
        
        if (safeRecipes.length < _db.length)
          _buildInfoBanner('Sağlık profilin için en uygun tarifleri en başa taşıdık.'),
        
        const SizedBox(height: 24),
        
        // Metabolism Boosters Section
        _buildSectionHeader('Metabolizma Hızlandırıcılar', 'Enerjini zirveye taşıyacak seçimler.'),
        const SizedBox(height: 16),
        _HorizontalScrollSection(
          height: 100,
          items: metabolismRecipes.map((r) => _buildWideRecipeCard(context, r, cs, isDark)).toList(),
        ),
        
        const SizedBox(height: 32),
        
        // Main Meal Section (Dynamic Title)
        _buildSectionHeader(lunchTitle, gaps.isNotEmpty ? 'Eksik olduğun besin değerlerine göre özel seçildi.' : (isOverGoal ? 'Kalori hedefini aştığın için hafif seçenekler.' : 'Hızlı ve sağlıklı tarifler.')),
        const SizedBox(height: 16),
        _HorizontalScrollSection(
          height: 240,
          items: lunchRecipes.map((r) => _buildVerticalRecipeCard(context, r, cs, isDark)).toList(),
        ),
        
        const SizedBox(height: 32),
        
        // Evening/Morning Section (Dynamic Title)
        _buildSectionHeader(relaxationTitle, relaxationSub),
        const SizedBox(height: 16),
        _HorizontalScrollSection(
          height: 90,
          items: eveningRecipes.map((r) => _buildListRecipeItem(context, r, cs, isDark)).toList(),
        ),
        
        const SizedBox(height: 120), // Bottom padding for navigation
      ],
    );
  }

  void _showMealSelection(BuildContext context, _Tarif r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öğün Seçin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Bu tarifi hangi öğüne eklemek istersiniz?', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mealButton(context, 'kahvaltı', Icons.wb_sunny_outlined, r),
                _mealButton(context, 'öğle', Icons.light_mode_outlined, r),
                _mealButton(context, 'akşam', Icons.nightlight_outlined, r),
                _mealButton(context, 'ara öğün', Icons.coffee_outlined, r),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _mealButton(BuildContext context, String type, IconData icon, _Tarif r) {
    Color mealColor;
    switch (type) {
      case 'kahvaltı': mealColor = const Color(0xFFFF9500); break;
      case 'öğle': mealColor = const Color(0xFFFFCC00); break;
      case 'akşam': mealColor = const Color(0xFF5856D6); break;
      default: mealColor = const Color(0xFF4CD964);
    }

    return GestureDetector(
      onTap: () {
        final nutrition = context.read<NutritionProvider>();
        nutrition.addFoodEntry(_foodEntryFromTarif(r, type));
        Navigator.pop(context); // Close selection
        Navigator.pop(context); // Close details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${r.ad} tüm besin değerleriyle $type öğününe eklendi!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mealColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: mealColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(icon, color: mealColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  FoodEntry _foodEntryFromTarif(_Tarif r, String mealType) {
    final nutritionData = NutritionData(
      calories: r.kalori.toDouble(),
      protein: r.protein,
      carbohydrates: r.karb,
      fat: r.yag,
      fiber: r.lif,
      iron: r.demir ?? 0,
      magnesium: r.magnezyum ?? 0,
      calcium: r.kalsiyum ?? 0,
      vitaminA: r.vitaminA ?? 0,
      vitaminC: r.vitaminC ?? 0,
      vitaminD: r.vitaminD ?? 0,
      vitaminE: r.vitaminE ?? 0,
      vitaminB12: r.vitaminB12 ?? 0,
      vitaminB6: r.vitaminB6 ?? 0,
      thiamine: r.vitaminB1 ?? 0,
      zinc: r.zinc ?? 0,
      potassium: r.potasyum ?? 0,
      omega3: r.omega3 ?? 0,
    );

    return FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: r.ad,
      portionSize: 100.0,
      portionUnit: 'g (1 porsiyon)',
      nutritionData: nutritionData,
      nutrition65per100g: nutritionData.to65(),
      timestamp: DateTime.now(),
      mealType: mealType,
      imageUrl: r.gorselUrl,
    );
  }

  Widget _buildCoachHeaderCard(BuildContext context, ColorScheme cs) {
    final content = _getDynamicCoachContent(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0969DA), Color(0xFF58A6FF)], // Blue gradient
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0969DA).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Transform.flip(
              flipX: true,
              child: const Icon(Icons.psychology, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'BESLENME KOÇU',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(1, duration: const Duration(milliseconds: 150), curve: Curves.easeOutQuad),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0969DA),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Hemen Gör', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  _CoachContent _getDynamicCoachContent(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final profile = context.watch<ProfileProvider>().activeProfile;
    final stats = nutrition.totalNutrition;
    final calorieGoal = context.read<ProfileProvider>().calorieGoal;
    final steps = nutrition.todayLog.stepsCount ?? 0;
    final hour = DateTime.now().hour;

    // Time-based greetings
    String title = 'Günaydın, canlanma vakti!';
    if (hour >= 12 && hour < 17) title = 'Tünaydın, enerji lazım!';
    if (hour >= 17 && hour < 21) title = 'İyi akşamlar, hafifleyelim!';
    if (hour >= 21 || hour < 6) title = 'İyi geceler, dinlenme vakti!';

    // Logic for description
    String description = 'Senin için en sağlıklı önerileri hazırladım. Bugün hedeflerine ulaşmak için harika bir gün!';

    if (stats.calories > calorieGoal && calorieGoal > 0) {
      description = 'Bugün kalori hedefini biraz aşmışsın. Akşam yemeğinde hafif bir salata veya sebze yemeği tercih ederek dengeleyebiliriz.';
    } else if (steps > 10000) {
      description = 'Harika bir hareketlilik! 10.000 adımı geçtin. Kaslarını desteklemek için protein ağırlıklı bir ara öğün harika olur.';
    } else if (stats.protein < (profile?.proteinGoal ?? 0) * 0.5 && stats.calories > 0) {
      description = 'Bugün protein alımın biraz düşük kalmış. Kas sağlığın için bir sonraki öğününde protein kaynaklarına yer vermeni öneririm.';
    } else if (hour < 10 && stats.calories == 0) {
      description = 'Güne zinde başlamak için besleyici bir kahvaltıya ne dersin? Metabolizmanı ateşleyecek önerilerim aşağıda.';
    } else if (nutrition.todayLog.waterIntakeMl < 1000) {
      description = 'Bugün su içmeyi biraz ihmal etmiş gibisin. Vücudunun nem dengesi için hemen bir bardak su içmeye ne dersin?';
    }

    return _CoachContent(title, description);
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.8),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWideRecipeCard(BuildContext context, _Tarif r, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => _showRecipeDetails(context, r),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: r.renk.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    r.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    r.aciklama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildRecipeImage(r.gorselUrl, 60, r.renk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalRecipeCard(BuildContext context, _Tarif r, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => _showRecipeDetails(context, r),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: _buildRecipeImage(r.gorselUrl, 140, r.renk),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(r.ad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.green, size: 14),
                          Text(' 4.8', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniTag('KARB', Colors.blue),
                      const SizedBox(width: 4),
                      _miniTag('PRO', Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildListRecipeItem(BuildContext context, _Tarif r, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => _showRecipeDetails(context, r),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2128) : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 50, height: 50,
                child: _buildRecipeImage(r.gorselUrl, 50, r.renk),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(r.ad, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(r.aciklama, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeDetails(BuildContext context, _Tarif r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildRecipeImage(r.gorselUrl, 250, r.renk),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        final nutrition = context.watch<NutritionProvider>();
                        final isFav = nutrition.isFavorite(r.ad);
                        return GestureDetector(
                          onTap: () {
                            nutrition.toggleFavoriteMeal(_foodEntryFromTarif(r, 'ara öğün'));
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                            child: Icon(isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isFav ? r.renk : Colors.grey, size: 24),
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.ad, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(r.aciklama, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: r.renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${r.kalori} kcal', style: TextStyle(color: r.renk, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip(Icons.timer_outlined, '${r.dakika} dk'),
                  _infoChip(Icons.local_fire_department_outlined, r.etiketler.first),
                  _infoChip(Icons.eco_outlined, r.diyetler.first),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Besin Değerleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _macroItem('Protein', '${r.protein}g', const Color(0xFF7EE787)),
                        _macroItem('Karb', '${r.karb}g', const Color(0xFF58A6FF)),
                        _macroItem('Yağ', '${r.yag}g', const Color(0xFFFFA726)),
                        _macroItem('Lif', '${r.lif}g', const Color(0xFFBC8CF2)),
                      ],
                    ),
                    if (r.demir != null || r.magnezyum != null || r.kalsiyum != null || r.vitaminA != null || r.vitaminC != null || r.vitaminD != null || r.omega3 != null || r.zinc != null || r.potasyum != null || r.vitaminB12 != null || r.vitaminB6 != null || r.vitaminB1 != null || r.vitaminE != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          bool isExpanded = false;
                          return StatefulBuilder( // use another inner one for local state
                            builder: (context, setState) {
                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isExpanded = !isExpanded;
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Daha fazlası', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
                                        Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                      ],
                                    ),
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        if (r.demir != null) _microItem('Demir', '${r.demir}mg'),
                                        if (r.magnezyum != null) _microItem('Magnezyum', '${r.magnezyum}mg'),
                                        if (r.kalsiyum != null) _microItem('Kalsiyum', '${r.kalsiyum}mg'),
                                        if (r.vitaminA != null) _microItem('Vit A', '${r.vitaminA}µg'),
                                        if (r.vitaminC != null) _microItem('Vit C', '${r.vitaminC}mg'),
                                        if (r.vitaminD != null) _microItem('Vit D', '${r.vitaminD}µg'),
                                        if (r.vitaminB12 != null) _microItem('Vit B12', '${r.vitaminB12}µg'),
                                        if (r.vitaminB1 != null) _microItem('Vit B1', '${r.vitaminB1}mg'),
                                        if (r.zinc != null) _microItem('Çinko', '${r.zinc}mg'),
                                        if (r.potasyum != null) _microItem('Potasyum', '${r.potasyum}mg'),
                                        if (r.omega3 != null) _microItem('Omega-3', '${r.omega3}g'),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            }
                          );
                        }
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Malzemeler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...r.malzemeler.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: r.renk, size: 18),
                    const SizedBox(width: 12),
                    Text(m, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              )),
              const SizedBox(height: 32),
              const Text('Hazırlanışı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...r.adimlar.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: r.renk, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 15, height: 1.5))),
                  ],
                ),
              )),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showMealSelection(context, r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.renk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Tarifi Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _microItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRecipeImage(String url, double height, Color renk) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => Container(
        height: height,
        color: renk.withValues(alpha: 0.2),
        child: Icon(Icons.restaurant, color: renk, size: 24),
      ),
      placeholder: (context, url) => Container(
        height: height,
        color: Colors.grey.withValues(alpha: 0.1),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _CoachContent {
  final String title;
  final String description;
  _CoachContent(this.title, this.description);
}

class _HorizontalScrollSection extends StatefulWidget {
  final List<Widget> items;
  final double height;
  const _HorizontalScrollSection({required this.items, required this.height});

  @override
  State<_HorizontalScrollSection> createState() => _HorizontalScrollSectionState();
}

class _HorizontalScrollSectionState extends State<_HorizontalScrollSection> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final showLeft = _scrollController.offset > 10;
    final showRight = _scrollController.offset < _scrollController.position.maxScrollExtent - 10;
    if (showLeft != _showLeftArrow || showRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = showLeft;
        _showRightArrow = showRight;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          child: ListView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: widget.items,
          ),
        ),
        if (_showLeftArrow)
          Positioned(
            left: 5,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(icon: Icons.chevron_left_rounded, onTap: () => _scroll(-1)),
            ),
          ),
        if (_showRightArrow && widget.items.length > 1)
          Positioned(
            right: 5,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(icon: Icons.chevron_right_rounded, onTap: () => _scroll(1)),
            ),
          ),
      ],
    );
  }

  void _scroll(int direction) {
    _scrollController.animateTo(
      _scrollController.offset + (direction * 200),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 24, color: Colors.black87),
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

