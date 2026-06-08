import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_analysis_result.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import 'config_service.dart';
import 'edamam_nutrition_service.dart';
import 'open_food_facts_service.dart';
import 'usda_api_service.dart';
import 'usda_cache_service.dart';

// ─── Internal models ───────────────────────────────────────────────────────────

class _FoodIdentification {
  final String foodName;
  final String yemekTipi;
  final int confidenceScore;
  final String cookingMethod;
  final double portionGram;

  const _FoodIdentification({
    required this.foodName,
    required this.yemekTipi,
    required this.confidenceScore,
    required this.cookingMethod,
    required this.portionGram,
  });
}

// ─── Service ───────────────────────────────────────────────────────────────────

class FoodAnalysisService {
  String get _apiKey => ConfigService.anthropicKey;

  // ── Atwater sabitleri ──────────────────────────────────────────────────────

  static const double _proteinKcal = 4.0;
  static const double _carbKcal = 4.0;
  static const double _fatKcal = 9.0;

  /// Uygulamanın tek kalori hesaplama noktası — Atwater, en yakın 5'e yuvarla.
  static double calculateCalories({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    final raw =
        (proteinG * _proteinKcal) + (carbsG * _carbKcal) + (fatG * _fatKcal);
    return (raw / 5).round() * 5.0;
  }

  /// Yemek tipine göre sabit varsayılan porsiyon (gram).
  static double _defaultPortion(String yemekTipi) {
    switch (yemekTipi) {
      case 'corba':
        return 250;
      case 'ana_yemek':
        return 300;
      case 'salata':
        return 150;
      case 'tatli':
        return 100;
      case 'icecek':
        return 200;
      case 'kahvalti':
        return 200;
      case 'atistirmalik':
        return 50;
      default:
        return 200;
    }
  }

  // ── Görüntü Ön İşleme ─────────────────────────────────────────────────────

  /// Görüntüyü API için küçültür ve base64'e çevirir (disk I/O yok).
  Future<String> _preprocessToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return base64Encode(bytes);

    // 768px yeterli — yemek tanıma için 1024 gereksiz
    if (image.width > 768 || image.height > 768) {
      if (image.width >= image.height) {
        image = img.copyResize(image, width: 768);
      } else {
        image = img.copyResize(image, height: 768);
      }
    }
    return base64Encode(img.encodeJpg(image, quality: 75));
  }

  // ── Aşama 1: Hızlı kimlik tespiti (Haiku, küçük yanıt) ──────────────────

  Future<_FoodIdentification> _identifyFood(
      String base64Image, String? hint) async {
    final json = await _callClaude(
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text':
                  'Sen "Nutrition5k" veri seti standartlarında (referans nesne, yoğunluk) uzman bir besin analistisin. Görseldeki tabağı sanal olarak içindeki farklı bileşenlere (segmentlere) ayır. Tabağın veya referans bir nesnenin (çatal/kaşık) boyutunu baz alarak her bileşenin kapladığı hacmi ve gerçek ağırlığını gram cinsinden tahmin et. Ardından tüm bileşenlerin adlarını ve pişirme yöntemlerini birleştirip tek bir ana "yemek_adi" oluştur. Porsiyonu, bu bileşenlerin toplam ağırlığı olarak ver.\n\n'
                  '--- IN-CONTEXT EĞİTİM VERİLERİ (NUTRITION5K KALİBRASYONU) ---\n'
                  'Örnek 1: (Tabakta 1 parça somon, 1 avuç kuşkonmaz) -> Segmentasyon: %60 Somon (150g), %40 Kuşkonmaz (80g) -> porsiyon_gram: 230\n'
                  'Örnek 2: (Orta boy kase mercimek çorbası) -> Segmentasyon: %100 Mercimek Çorbası -> porsiyon_gram: 250\n'
                  'Örnek 3: (Karışık kahvaltı tabağı) -> Segmentasyon: 1 Haşlanmış Yumurta (50g), 2 dilim peynir (60g), 5 zeytin (15g) -> porsiyon_gram: 125\n'
                  '-------------------------------------------------------------\n\n'
                  '${hint != null ? ' Kullanıcı notu: "$hint"' : ''}\n\n'
                  'SADECE JSON döndür:\n{"yemek_adi":"string","yemek_tipi":"corba|ana_yemek|salata|tatli|icecek|kahvalti|atistirmalik","pisirme":"cig|hashlama|izgara|kizartma|firin|diger","porsiyon_gram":number,"guven_skoru":number}\n\nporsiyon_gram: bileşenlerin toplam ağırlığı.',
            },
          ],
        },
      ],
      maxTokens: 160,
      model: 'claude-haiku-4-5-20251001',
    );
    return _FoodIdentification(
      foodName: (json['yemek_adi'] as String?) ?? 'Bilinmeyen',
      yemekTipi: (json['yemek_tipi'] as String?) ?? 'ana_yemek',
      confidenceScore: (json['guven_skoru'] as num?)?.toInt() ?? 70,
      cookingMethod: (json['pisirme'] as String?) ?? 'diger',
      portionGram: (json['porsiyon_gram'] as num?)?.toDouble() ?? 0,
    );
  }

  // ── Aşama 2: Tam besin analizi (sadece USDA/OFF bulunamazsa) ─────────────

  Future<NutritionData65> _analyzeNutrients(
      String base64Image, String foodName, String? hint) async {
    final json = await _callClaude(
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': '''
Sen bir USDA, Open Food Facts ve Nutrition5k uzmanısın. "$foodName" yemeği için 100g başına besin değerlerini verirken yüksek hassasiyetli segmentasyon yöntemini kullan.
Bu yemeği oluşturan tüm alt bileşenleri zihninde parçalarına ayır. Her bir bileşenin USDA'daki makro/mikro besin karşılıklarını bul ve tabağın içindeki kendi oranlarına göre ağırlıklı ortalamayla birleştir.

--- IN-CONTEXT EĞİTİM VERİLERİ (NUTRITION5K HASSASİYET KALİBRASYONU) ---
Kural 1 (Pişirme Kaybı): Et/Tavuk/Balık ürünleri piştiklerinde su kaybeder, protein/yağ oranları (100g için) çiğ haline göre ~%25 artar.
Kural 2 (Su Çekme): Pilav/Makarna haşlandığında su çeker, karbonhidrat oranları (100g için) çiğ haline göre düşer (örn: pişmiş beyaz pirinç ~28g carb).
Kural 3 (Yağ Emilimi): Kızartma işlemi 100g'da ekstra 5-10g yağ emilimi yaratır. Değerlere ekle.
Kural 4 (Soslar): Zeytinyağlı/Soslu sebzelerde lif yüksektir, ancak sos kaynaklı ekstra yağ/kalori vardır.
Kural 5 (Mikro Besin Sabitleme - ÇOK ÖNEMLİ): Mikro besin (vitamin/mineral) değerlerini asla rastgele üretme. Tabağın ana bileşenleri için KESİN bir USDA standart tablosu (örn: USDA 170456 Cooked Salmon) seç ve o tablonun mikro besin oranlarını sabit tutarak ağırlıkla çarp. 
Kural 6 (Oran Yuvarlama): Stabilite için segmentasyon oranlarını her zaman en yakın %10'luk veya %25'lik dilimlere yuvarla (örn: %50 et, %50 pilav). Ufak farklılıklarda mikro değerleri değiştirme. Aynı yemek tipi her zaman aynı sabit mikro değer profiline sahip olmalıdır.
------------------------------------------------------------------------
${hint != null ? '\nKullanıcı notu: "$hint"\n' : ''}
Görseldeki pişirme yöntemini (kızartmanın yağ oranını veya haşlamanın su oranını etkilemesi gibi) mutlaka dikkate al ve değerlere yansıt.

SADECE JSON döndür, başka hiçbir şey yazma:
{"protein":number,"karbonhidrat":number,"yag":number,"lif":number,"seker":number,"doymus_yag":number,"tekli_doymus_yag":number,"coklu_doymus_yag":number,"trans_yag":number,"kolesterol_mg":number,"su":number,"kalsiyum_mg":number,"demir_mg":number,"magnezyum_mg":number,"fosfor_mg":number,"potasyum_mg":number,"sodyum_mg":number,"cinko_mg":number,"bakir_mg":number,"manganez_mg":number,"selenyum_mcg":number,"iyot_mcg":number,"krom_mcg":number,"molibden_mcg":number,"c_vitamini_mg":number,"d_vitamini_mcg":number,"e_vitamini_mg":number,"k1_vitamini_mcg":number,"a_vitamini_mcg":number,"beta_karoten_mcg":number,"likopen_mcg":number,"lutein_zea_mcg":number,"b1_tiamin_mg":number,"b2_riboflavin_mg":number,"b3_niasin_mg":number,"b5_pantotenik_mg":number,"b6_mg":number,"folat_mcg":number,"b12_mcg":number,"kolin_mg":number,"biotin_mcg":number,"omega3_g":number,"omega6_g":number,"epa_g":number,"dha_g":number,"ala_g":number,"linoleik_g":number,"losin_g":number,"lizin_g":number,"valin_g":number,"izolosin_g":number,"treonin_g":number,"metionin_g":number,"fenilalanin_g":number,"triptofan_g":number,"histidin_g":number,"sistin_g":number,"tirozin_g":number}

Kurallar: Bilmiyorsan 0 yaz. protein+karbonhidrat+yag ≤ 100. Amino asit toplamı ≤ protein.''',
            },
          ],
        },
      ],
      maxTokens: 900,
      model: 'claude-haiku-4-5-20251001',
    );

    double g(String k) => (json[k] as num?)?.toDouble() ?? 0.0;

    final protein = g('protein');
    final carb = g('karbonhidrat');
    final fat = g('yag');
    final energy = protein * 4.0 + carb * 4.0 + fat * 9.0 + g('lif') * 2.0;

    return NutritionData65(
      energy: (energy / 5).round() * 5.0,
      protein: protein,
      fat: fat,
      carb: carb,
      fiber: g('lif'),
      sugar: g('seker'),
      satFat: g('doymus_yag'),
      monoFat: g('tekli_doymus_yag'),
      polyFat: g('coklu_doymus_yag'),
      transFat: g('trans_yag'),
      cholesterol: g('kolesterol_mg'),
      water: g('su'),
      calcium: g('kalsiyum_mg'),
      iron: g('demir_mg'),
      magnesium: g('magnezyum_mg'),
      phosphorus: g('fosfor_mg'),
      potassium: g('potasyum_mg'),
      sodium: g('sodyum_mg'),
      zinc: g('cinko_mg'),
      copper: g('bakir_mg'),
      manganese: g('manganez_mg'),
      selenium: g('selenyum_mcg'),
      iodine: g('iyot_mcg'),
      chromium: g('krom_mcg'),
      molybdenum: g('molibden_mcg'),
      vitC: g('c_vitamini_mg'),
      vitD_mcg: g('d_vitamini_mcg'),
      vitE: g('e_vitamini_mg'),
      vitK: g('k1_vitamini_mcg'),
      vitA_RAE: g('a_vitamini_mcg'),
      betaCarot: g('beta_karoten_mcg'),
      lycopene: g('likopen_mcg'),
      luteinZea: g('lutein_zea_mcg'),
      thiamine: g('b1_tiamin_mg'),
      riboflavin: g('b2_riboflavin_mg'),
      niacin: g('b3_niasin_mg'),
      pantothenic: g('b5_pantotenik_mg'),
      vitB6: g('b6_mg'),
      folate: g('folat_mcg'),
      vitB12: g('b12_mcg'),
      choline: g('kolin_mg'),
      biotin: g('biotin_mcg'),
      omega3: g('omega3_g'),
      omega6: g('omega6_g'),
      epa: g('epa_g'),
      dha: g('dha_g'),
      ala: g('ala_g'),
      linoleic: g('linoleik_g'),
      leucine: g('losin_g'),
      lysine: g('lizin_g'),
      valine: g('valin_g'),
      isoleucine: g('izolosin_g'),
      threonine: g('treonin_g'),
      methionine: g('metionin_g'),
      phenylalanine: g('fenilalanin_g'),
      tryptophan: g('triptofan_g'),
      histidine: g('histidin_g'),
      cystine: g('sistin_g'),
      tyrosine: g('tirozin_g'),
      dataSource: 'Claude',
    );
  }

  // ── Kullanıcı Geçmişi ──────────────────────────────────────────────────────

  Future<NutritionData?> _checkUserHistory(String foodName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correction_${foodName.toLowerCase().trim()}';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return NutritionData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Kullanıcı düzeltmesini ağırlıklı ortalama ile kaydet.
  Future<void> saveCorrection(
    String foodName,
    NutritionData correctedNutrition,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correction_${foodName.toLowerCase().trim()}';
    final countKey = '${key}_count';

    final existingRaw = prefs.getString(key);
    final count = prefs.getInt(countKey) ?? 0;

    final NutritionData merged;
    if (existingRaw != null && count > 0) {
      final existing = NutritionData.fromJson(
          jsonDecode(existingRaw) as Map<String, dynamic>);
      double wavg(double a, double b) =>
          _round1((a * count + b) / (count + 1));
      merged = NutritionData(
        calories: wavg(existing.calories, correctedNutrition.calories),
        protein: wavg(existing.protein, correctedNutrition.protein),
        carbohydrates:
            wavg(existing.carbohydrates, correctedNutrition.carbohydrates),
        fat: wavg(existing.fat, correctedNutrition.fat),
        fiber: wavg(existing.fiber, correctedNutrition.fiber),
        sugar: wavg(existing.sugar, correctedNutrition.sugar),
        saturatedFat:
            wavg(existing.saturatedFat, correctedNutrition.saturatedFat),
        sodium: correctedNutrition.sodium,
        vitaminC: correctedNutrition.vitaminC,
        vitaminD: correctedNutrition.vitaminD,
        vitaminB12: correctedNutrition.vitaminB12,
        iron: correctedNutrition.iron,
        calcium: correctedNutrition.calcium,
        magnesium: correctedNutrition.magnesium,
        potassium: correctedNutrition.potassium,
        omega3: correctedNutrition.omega3,
      );
    } else {
      merged = correctedNutrition;
    }

    await prefs.setString(key, jsonEncode(merged.toJson()));
    await prefs.setInt(countKey, count + 1);
  }

  // ── Dış servisler ─────────────────────────────────────────────────────────

  final _usda = UsdaApiService();
  final _cache = UsdaCacheService.instance;
  final _off = OpenFoodFactsService();

  // Türkçe → İngilizce sorgu çevirisi
  static const Map<String, String> _trToEn = {
    'tavuk': 'chicken', 'köfte': 'beef meatball',
    'pilav': 'rice pilaf', 'mercimek': 'lentil',
    'bulgur': 'bulgur wheat', 'nohut': 'chickpea',
    'ızgara': 'grilled', 'haşlama': 'boiled',
    'kızartma': 'fried', 'çorba': 'soup',
    'salata': 'salad', 'börek': 'pastry',
    'yoğurt': 'yogurt', 'peynir': 'cheese',
    'ekmek': 'bread', 'domates': 'tomato',
    'patlıcan': 'eggplant', 'somon': 'salmon',
    'ton balığı': 'tuna', 'karides': 'shrimp',
    'yumurta': 'egg', 'süt': 'milk',
    'kıyma': 'ground beef', 'kuzu': 'lamb',
    'dana': 'beef', 'hindi': 'turkey',
    'balık': 'fish', 'fasulye': 'beans',
    'patates': 'potato', 'pirinç': 'rice',
    'makarna': 'pasta', 'soğan': 'onion',
    'havuç': 'carrot', 'ıspanak': 'spinach',
    'elma': 'apple', 'muz': 'banana',
    'portakal': 'orange', 'badem': 'almond',
    'ceviz': 'walnut', 'zeytinyağı': 'olive oil',
  };

  String _toEnglish(String tr) {
    final lower = tr.toLowerCase();
    for (final entry in _trToEn.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return tr;
  }

  /// Pişirme yöntemini USDA sorgusuna ekler (ızgara tavuk, kızartılmış patates…)
  String _toEnglishWithCooking(String tr, String cooking) {
    final base = _toEnglish(tr);
    final prefix = switch (cooking) {
      'izgara' => 'grilled',
      'kizartma' => 'fried',
      'hashlama' => 'boiled',
      'firin' => 'baked',
      _ => null,
    };
    return prefix != null ? '$prefix $base' : base;
  }

  Future<FoodAnalysisResult> analyzeText(String description) async {
    final json = await _callClaude(
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': '''
Sen "Nutrition5k" ve "USDA" veri standartlarına hakim uzman bir beslenme koçusun. Kullanıcının tarif ettiği yemeği sanal olarak alt bileşenlerine ayırarak yüksek hassasiyetle analiz et: "$description"
Her bir malzemenin ortalama porsiyon ağırlığını hesapla ve bu malzemelerin USDA'daki makro/mikro besin karşılıklarını birleştir.

--- IN-CONTEXT EĞİTİM VERİLERİ (KALİBRASYON) ---
Kural 1: Etler piştikçe hacim küçülür, 100g başına makro değerleri artar.
Kural 2: Tahıllar piştikçe su çeker, 100g başına makro değerleri düşer.
Kural 3: Mikro besinler için rastgele değer üretme. USDA standart profillerini (örn: Cooked Chicken Breast) zihninde referans olarak kilitle ve mikro besin oranlarını sabit tut. Oranları %10'luk dilimlere yuvarla ki stabilite artsın.
------------------------------------------------

SADECE JSON döndür, başka hiçbir şey yazma. Tüm değerler 100g başına olmalı:
{
  "yemek_adi": "string",
  "yemek_tipi": "corba|ana_yemek|salata|tatli|icecek|kahvalti|atistirmalik",
  "porsiyon_gram": number,
  "guven_skoru": number,
  "guven_nedeni": "string",
  "protein": number,
  "karbonhidrat": number,
  "yag": number,
  "lif": number,
  "seker": number,
  "doymus_yag": number,
  "sodyum_mg": number,
  "demir_mg": number,
  "kalsiyum_mg": number,
  "magnezyum_mg": number,
  "potasyum_mg": number,
  "cinko_mg": number,
  "selenyum_mcg": number,
  "vitamin_c_mg": number,
  "vitamin_d_mcg": number,
  "vitamin_b12_mcg": number,
  "vitamin_b6_mg": number,
  "vitamin_a_mcg": number,
  "vitamin_e_mg": number,
  "folik_asit_mcg": number,
  "thiamin_mg": number,
  "omega3_g": number,
  "omega6_g": number
}

Kurallar: 100g başına değerleri ver. protein+karbonhidrat+yag ≤ 100. porsiyon_gram: tarif edilen miktarı grama çevir (örn: 1 kase = 250g). Mikro besin yoksa 0 yaz.
''',
            }
          ],
        }
      ],
      maxTokens: 700,
    );

    double g(String k) => (json[k] as num?)?.toDouble() ?? 0.0;

    final foodName = (json['yemek_adi'] as String?) ?? 'Bilinmeyen';
    final portionGrams = (json['porsiyon_gram'] as num?)?.toDouble() ?? 200.0;

    final nd100 = NutritionData(
      calories: calculateCalories(proteinG: g('protein'), carbsG: g('karbonhidrat'), fatG: g('yag')),
      protein: g('protein'),
      carbohydrates: g('karbonhidrat'),
      fat: g('yag'),
      fiber: g('lif'),
      sugar: g('seker'),
      saturatedFat: g('doymus_yag'),
      sodium: g('sodyum_mg'),
      iron: g('demir_mg') > 0 ? g('demir_mg') : null,
      calcium: g('kalsiyum_mg') > 0 ? g('kalsiyum_mg') : null,
      magnesium: g('magnezyum_mg') > 0 ? g('magnezyum_mg') : null,
      potassium: g('potasyum_mg') > 0 ? g('potasyum_mg') : null,
      zinc: g('cinko_mg') > 0 ? g('cinko_mg') : null,
      vitaminC: g('vitamin_c_mg') > 0 ? g('vitamin_c_mg') : null,
      vitaminD: g('vitamin_d_mcg') > 0 ? g('vitamin_d_mcg') : null,
      vitaminB12: g('vitamin_b12_mcg') > 0 ? g('vitamin_b12_mcg') : null,
      vitaminB6: g('vitamin_b6_mg') > 0 ? g('vitamin_b6_mg') : null,
      vitaminA: g('vitamin_a_mcg') > 0 ? g('vitamin_a_mcg') : null,
      vitaminE: g('vitamin_e_mg') > 0 ? g('vitamin_e_mg') : null,
      omega3: g('omega3_g') > 0 ? g('omega3_g') : null,
      omega6: g('omega6_g') > 0 ? g('omega6_g') : null,
      dataSource: 'Claude (Text)',
    );

    final n65 = NutritionData65(
      energy: nd100.calories,
      protein: nd100.protein,
      fat: nd100.fat,
      carb: nd100.carbohydrates,
      fiber: nd100.fiber,
      sugar: nd100.sugar,
      satFat: nd100.saturatedFat,
      sodium: nd100.sodium ?? 0.0,
      iron: nd100.iron ?? 0.0,
      calcium: nd100.calcium ?? 0.0,
      magnesium: nd100.magnesium ?? 0.0,
      potassium: nd100.potassium ?? 0.0,
      zinc: nd100.zinc ?? 0.0,
      vitC: nd100.vitaminC ?? 0.0,
      vitD_mcg: nd100.vitaminD ?? 0.0,
      vitB12: nd100.vitaminB12 ?? 0.0,
      vitB6: nd100.vitaminB6 ?? 0.0,
      vitA_RAE: nd100.vitaminA ?? 0.0,
      vitE: nd100.vitaminE ?? 0.0,
      omega3: nd100.omega3 ?? 0.0,
      omega6: nd100.omega6 ?? 0.0,
      dataSource: 'Claude (Text)',
    );

    final portionCalories = calculateCalories(
      proteinG: _round1(nd100.protein * portionGrams / 100),
      carbsG: _round1(nd100.carbohydrates * portionGrams / 100),
      fatG: _round1(nd100.fat * portionGrams / 100),
    );

    return FoodAnalysisResult(
      foodName: foodName,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: n65,
      sources: const ['Claude (Text)'],
      confidenceScore: (json['guven_skoru'] as num?)?.toInt() ?? 85,
      confidenceReason: (json['guven_nedeni'] as String?) ?? '',
      alternativeMin: portionCalories * 0.9,
      alternativeMax: portionCalories * 1.1,
    );
  }

  // ── ANA ANALİZ FONKSİYONU ──────────────────────────────────────────────────

  Future<FoodAnalysisResult> analyze({
    required File image,
    String? hint,
    double? gramsHint,
    String? barcode,
  }) async {
    // Aşama 0: Barkod varsa direkt OFF araması
    if (barcode != null) {
      final offProduct = await _off.getByBarcode(barcode);
      if (offProduct != null && offProduct.calories > 0) {
        return _buildFromOff(offProduct, gramsHint ?? 100);
      }
    }

    // Aşama 1: Görüntüyü hazırla + kimlik tespiti (pişirme + porsiyon dahil)
    final base64Image = await _preprocessToBase64(image);
    final id = await _identifyFood(base64Image, hint);
    // Porsiyon: kullanıcı verdiyse üst gelir, yoksa Claude'un görsel tahmini,
    // o da yoksa tipe göre sabit varsayılan
    final portionGrams =
        gramsHint ?? (id.portionGram > 0 ? id.portionGram : _defaultPortion(id.yemekTipi));
    final enQuery = _toEnglishWithCooking(id.foodName, id.cookingMethod);

    // Aşama 2a: USDA önbelleği önce — cache hit'te gereksiz ağ çağrısı yapma
    final usdaFromCache = await _cache.get(id.foodName);
    if (usdaFromCache != null) {
      final stubN65 = NutritionData65(
        energy: 0, protein: 0, fat: 0, carb: 0, dataSource: 'Claude',
      );
      return _mergeResults(
        id: id,
        claudeN65: stubN65,
        usdaDetail: usdaFromCache,
        portionGrams: portionGrams,
        usdaSource: 'USDA_CACHE',
      );
    }

    // Aşama 2b: Cache miss → OFF + USDA API paralel
    final futures = await Future.wait([
      _off.searchByName(id.foodName),
      _usda.lookupFood(enQuery),
    ]);
    final offList = futures[0] as List<OFFProduct>;
    final usdaFromApi = futures[1] as UsdaFoodDetail?;

    if (usdaFromApi != null) {
      unawaited(_cache.save(id.foodName, usdaFromApi));
    }

    final usdaDetail = usdaFromApi;
    final offProduct = offList.isNotEmpty ? offList.first : null;

    // Aşama 3: USDA veya OFF bulundu → pişirme yöntemi ayarlı birleştirme
    if (usdaDetail != null || offProduct != null) {
      final stubN65 = NutritionData65(
        energy: 0, protein: 0, fat: 0, carb: 0, dataSource: 'Claude',
      );
      return _mergeResults(
        id: id,
        claudeN65: stubN65,
        usdaDetail: usdaDetail,
        offProduct: offProduct,
        portionGrams: portionGrams,
        usdaSource: 'USDA_API',
      );
    }

    // Aşama 4: USDA/OFF yok → 3 işlemi paralel çalıştır
    final phase4 = await Future.wait([
      _analyzeNutrients(base64Image, id.foodName, hint),
      EdamamNutritionService.instance.analyze(id.foodName),
      _checkUserHistory(id.foodName),
    ]);
    final n65 = phase4[0] as NutritionData65;
    final edamamN65 = phase4[1] as NutritionData65?;
    final history = phase4[2] as NutritionData?;

    final NutritionData65 baseN65 = edamamN65 != null
        ? EdamamNutritionService.merge(n65, edamamN65)
        : n65;
    final NutritionData65 finalN65;
    final bool fromHistory;
    if (history != null) {
      finalN65 = NutritionData65(
        energy: calculateCalories(
          proteinG: history.protein,
          carbsG: history.carbohydrates,
          fatG: history.fat,
        ),
        protein: history.protein,
        fat: history.fat,
        carb: history.carbohydrates,
        fiber: history.fiber,
        sugar: history.sugar,
        satFat: history.saturatedFat,
        monoFat: baseN65.monoFat,
        polyFat: baseN65.polyFat,
        transFat: baseN65.transFat,
        cholesterol: baseN65.cholesterol,
        water: baseN65.water,
        calcium: history.calcium ?? baseN65.calcium,
        iron: history.iron ?? baseN65.iron,
        magnesium: history.magnesium ?? baseN65.magnesium,
        phosphorus: baseN65.phosphorus,
        potassium: history.potassium ?? baseN65.potassium,
        sodium: history.sodium ?? baseN65.sodium,
        zinc: history.zinc ?? baseN65.zinc,
        copper: baseN65.copper,
        manganese: baseN65.manganese,
        selenium: history.selenium ?? baseN65.selenium,
        iodine: baseN65.iodine,
        chromium: baseN65.chromium,
        vitC: history.vitaminC ?? baseN65.vitC,
        vitD_mcg: history.vitaminD ?? baseN65.vitD_mcg,
        vitE: baseN65.vitE,
        vitK: baseN65.vitK,
        vitA_RAE: baseN65.vitA_RAE,
        thiamine: baseN65.thiamine,
        riboflavin: baseN65.riboflavin,
        niacin: baseN65.niacin,
        pantothenic: baseN65.pantothenic,
        vitB6: baseN65.vitB6,
        folate: baseN65.folate,
        vitB12: history.vitaminB12 ?? baseN65.vitB12,
        choline: baseN65.choline,
        biotin: baseN65.biotin,
        omega3: history.omega3 ?? baseN65.omega3,
        omega6: history.omega6 ?? baseN65.omega6,
        ala: baseN65.ala,
        epa: baseN65.epa,
        dha: baseN65.dha,
        linoleic: baseN65.linoleic,
        leucine: baseN65.leucine,
        lysine: baseN65.lysine,
        valine: baseN65.valine,
        isoleucine: baseN65.isoleucine,
        threonine: baseN65.threonine,
        methionine: baseN65.methionine,
        phenylalanine: baseN65.phenylalanine,
        tryptophan: baseN65.tryptophan,
        histidine: baseN65.histidine,
        cystine: baseN65.cystine,
        tyrosine: baseN65.tyrosine,
        dataSource: edamamN65 != null ? 'Geçmiş+Claude+Edamam' : 'Geçmiş+Claude',
      );
      fromHistory = true;
    } else {
      finalN65 = baseN65;
      fromHistory = false;
    }

    final nd100 = finalN65.toNutritionData();
    final portionCalories = calculateCalories(
      proteinG: _round1(nd100.protein * portionGrams / 100),
      carbsG: _round1(nd100.carbohydrates * portionGrams / 100),
      fatG: _round1(nd100.fat * portionGrams / 100),
    );

    return FoodAnalysisResult(
      foodName: id.foodName,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: finalN65,
      sources: fromHistory ? const ['Geçmiş', 'Claude'] : const ['Claude'],
      confidenceScore: fromHistory ? 92 : id.confidenceScore,
      alternativeMin: portionCalories * 0.9,
      alternativeMax: portionCalories * 1.1,
    );
  }

  // ── Ağırlıklı Kaynak Birleştirme ──────────────────────────────────────────

  FoodAnalysisResult _mergeResults({
    required _FoodIdentification id,
    required NutritionData65 claudeN65,
    UsdaFoodDetail? usdaDetail,
    OFFProduct? offProduct,
    required double portionGrams,
    String usdaSource = 'USDA_API',
  }) {
    final sources = <String>['Claude'];
    NutritionData65? usdaN65;

    if (usdaDetail != null) {
      usdaN65 = NutritionData65.fromUsda(detail: usdaDetail, grams: 100, source: usdaSource);
      // Pişirme yöntemi USDA ham değerini gerçekçi hale getirir
      usdaN65 = _applyCooking(usdaN65, id.cookingMethod);
      sources.add(usdaSource);
    }
    if (offProduct != null) sources.add('OpenFoodFacts');

    // Kaynaklar: USDA=0.90, OFF=0.75, Claude=0.55
    // Sıfır değerleri ortalamaya dahil etme (veri yok anlamına gelir)
    double w(double c, {double? u, double? o}) {
      double sw = 0, sv = 0;
      if (c > 0)                       { sw += 0.55; sv += 0.55 * c; }
      if (u != null && u > 0)          { sw += 0.90; sv += 0.90 * u; }
      if (o != null && o > 0)          { sw += 0.75; sv += 0.75 * o; }
      return sw > 0 ? sv / sw : 0;
    }

    final merged = NutritionData65(
      energy:       w(claudeN65.energy,       u: usdaN65?.energy,       o: offProduct?.calories),
      protein:      w(claudeN65.protein,      u: usdaN65?.protein,      o: offProduct?.protein),
      fat:          w(claudeN65.fat,          u: usdaN65?.fat,          o: offProduct?.fat),
      carb:         w(claudeN65.carb,         u: usdaN65?.carb,         o: offProduct?.carbs),
      fiber:        w(claudeN65.fiber,        u: usdaN65?.fiber,        o: offProduct?.fiber),
      sugar:        w(claudeN65.sugar,        u: usdaN65?.sugar,        o: offProduct?.sugar),
      satFat:       w(claudeN65.satFat,       u: usdaN65?.satFat,       o: offProduct?.saturatedFat),
      monoFat:      w(claudeN65.monoFat,      u: usdaN65?.monoFat),
      polyFat:      w(claudeN65.polyFat,      u: usdaN65?.polyFat),
      transFat:     w(claudeN65.transFat,     u: usdaN65?.transFat),
      cholesterol:  w(claudeN65.cholesterol,  u: usdaN65?.cholesterol),
      water:        w(claudeN65.water,        u: usdaN65?.water),
      calcium:      w(claudeN65.calcium,      u: usdaN65?.calcium),
      iron:         w(claudeN65.iron,         u: usdaN65?.iron),
      magnesium:    w(claudeN65.magnesium,    u: usdaN65?.magnesium),
      phosphorus:   w(claudeN65.phosphorus,   u: usdaN65?.phosphorus),
      potassium:    w(claudeN65.potassium,    u: usdaN65?.potassium),
      sodium:       w(claudeN65.sodium,       u: usdaN65?.sodium,       o: offProduct?.sodium),
      zinc:         w(claudeN65.zinc,         u: usdaN65?.zinc),
      copper:       w(claudeN65.copper,       u: usdaN65?.copper),
      manganese:    w(claudeN65.manganese,    u: usdaN65?.manganese),
      selenium:     w(claudeN65.selenium,     u: usdaN65?.selenium),
      fluoride:     w(claudeN65.fluoride,     u: usdaN65?.fluoride),
      chromium:     w(claudeN65.chromium,     u: usdaN65?.chromium),
      iodine:       w(claudeN65.iodine,       u: usdaN65?.iodine),
      molybdenum:   w(claudeN65.molybdenum,   u: usdaN65?.molybdenum),
      vitA_RAE:     w(claudeN65.vitA_RAE,     u: usdaN65?.vitA_RAE),
      betaCarot:    w(claudeN65.betaCarot,    u: usdaN65?.betaCarot),
      lycopene:     w(claudeN65.lycopene,     u: usdaN65?.lycopene),
      luteinZea:    w(claudeN65.luteinZea,    u: usdaN65?.luteinZea),
      vitE:         w(claudeN65.vitE,         u: usdaN65?.vitE),
      vitD_mcg:     w(claudeN65.vitD_mcg,     u: usdaN65?.vitD_mcg),
      vitK:         w(claudeN65.vitK,         u: usdaN65?.vitK),
      vitC:         w(claudeN65.vitC,         u: usdaN65?.vitC),
      thiamine:     w(claudeN65.thiamine,     u: usdaN65?.thiamine),
      riboflavin:   w(claudeN65.riboflavin,   u: usdaN65?.riboflavin),
      niacin:       w(claudeN65.niacin,       u: usdaN65?.niacin),
      pantothenic:  w(claudeN65.pantothenic,  u: usdaN65?.pantothenic),
      vitB6:        w(claudeN65.vitB6,        u: usdaN65?.vitB6),
      folate:       w(claudeN65.folate,       u: usdaN65?.folate),
      vitB12:       w(claudeN65.vitB12,       u: usdaN65?.vitB12),
      choline:      w(claudeN65.choline,      u: usdaN65?.choline),
      betaine:      w(claudeN65.betaine,      u: usdaN65?.betaine),
      biotin:       w(claudeN65.biotin,       u: usdaN65?.biotin),
      omega3:       w(claudeN65.omega3,       u: usdaN65?.omega3),
      omega6:       w(claudeN65.omega6,       u: usdaN65?.omega6),
      ala:          w(claudeN65.ala,          u: usdaN65?.ala),
      epa:          w(claudeN65.epa,          u: usdaN65?.epa),
      dha:          w(claudeN65.dha,          u: usdaN65?.dha),
      linoleic:     w(claudeN65.linoleic,     u: usdaN65?.linoleic),
      tryptophan:   w(claudeN65.tryptophan,   u: usdaN65?.tryptophan),
      threonine:    w(claudeN65.threonine,    u: usdaN65?.threonine),
      isoleucine:   w(claudeN65.isoleucine,   u: usdaN65?.isoleucine),
      leucine:      w(claudeN65.leucine,      u: usdaN65?.leucine),
      lysine:       w(claudeN65.lysine,       u: usdaN65?.lysine),
      methionine:   w(claudeN65.methionine,   u: usdaN65?.methionine),
      cystine:      w(claudeN65.cystine,      u: usdaN65?.cystine),
      phenylalanine:w(claudeN65.phenylalanine,u: usdaN65?.phenylalanine),
      tyrosine:     w(claudeN65.tyrosine,     u: usdaN65?.tyrosine),
      valine:       w(claudeN65.valine,       u: usdaN65?.valine),
      histidine:    w(claudeN65.histidine,    u: usdaN65?.histidine),
      dataSource: sources.join('+'),
    );

    final nd100 = merged.toNutritionData();
    final kcal = merged.energy * portionGrams / 100;
    final confBoost = (usdaDetail != null ? 15 : 0) + (offProduct != null ? 8 : 0);
    final confidence = (id.confidenceScore + confBoost).clamp(0, 99);

    return FoodAnalysisResult(
      foodName: id.foodName,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: merged,
      offProduct: offProduct,
      sources: sources,
      confidenceScore: confidence,
      alternativeMin: kcal * 0.9,
      alternativeMax: kcal * 1.1,
    );
  }

  FoodAnalysisResult _buildFromOff(OFFProduct product, double portionGrams) {
    final nd = NutritionData(
      calories: product.calories,
      protein: product.protein,
      carbohydrates: product.carbs,
      fat: product.fat,
      fiber: product.fiber,
      sugar: product.sugar,
      saturatedFat: product.saturatedFat,
      sodium: product.sodium,
      dataSource: 'OpenFoodFacts',
      confidenceScore: 88,
    );
    final kcal = product.calories * portionGrams / 100;
    return FoodAnalysisResult(
      foodName: product.name,
      portionGrams: portionGrams,
      nutritionPer100g: nd,
      offProduct: product,
      sources: const ['OpenFoodFacts'],
      confidenceScore: 88,
      alternativeMin: kcal * 0.9,
      alternativeMax: kcal * 1.1,
    );
  }

  // ── Pişirme Yöntemi Düzeltmesi ────────────────────────────────────────────

  /// USDA ham değerlerine pişirme yöntemi etkisini uygular.
  /// Referans: USDA SR28 retention factors + standart mutfak kimyası.
  NutritionData65 _applyCooking(NutritionData65 n, String cooking) {
    if (cooking == 'diger' || cooking == 'cig') return n;

    double fatMult = 1.0;
    double protMult = 1.0;
    double carbMult = 1.0;
    double waterMult = 1.0;

    switch (cooking) {
      case 'kizartma':
        fatMult = 1.20;   // yağ emilimi +%20
        waterMult = 0.85; // nem kaybı
      case 'izgara':
        fatMult = 0.90;   // yağ damlıyor
        protMult = 1.10;  // nem kaybıyla protein konsantrasyonu
        waterMult = 0.80;
      case 'hashlama':
        fatMult = 0.95;
        waterMult = 1.05; // su emilimi
      case 'firin':
        fatMult = 0.95;
        waterMult = 0.88;
    }

    final newFat = n.fat * fatMult;
    final newProt = n.protein * protMult;
    final newCarb = n.carb * carbMult;
    final newEnergy = newProt * 4.0 + newCarb * 4.0 + newFat * 9.0 + n.fiber * 2.0;

    return NutritionData65(
      energy: (newEnergy / 5).round() * 5.0,
      protein: newProt,
      fat: newFat,
      carb: newCarb,
      fiber: n.fiber,
      sugar: n.sugar,
      satFat: n.satFat * fatMult,
      monoFat: n.monoFat * fatMult,
      polyFat: n.polyFat * fatMult,
      transFat: n.transFat,
      cholesterol: n.cholesterol,
      water: n.water * waterMult,
      calcium: n.calcium,
      iron: n.iron,
      magnesium: n.magnesium,
      phosphorus: n.phosphorus,
      potassium: n.potassium,
      sodium: n.sodium,
      zinc: n.zinc,
      copper: n.copper,
      manganese: n.manganese,
      selenium: n.selenium,
      iodine: n.iodine,
      chromium: n.chromium,
      vitC: cooking == 'hashlama' ? n.vitC * 0.70 : n.vitC * 0.85,
      vitD_mcg: n.vitD_mcg,
      vitE: n.vitE * 0.90,
      vitK: n.vitK,
      vitA_RAE: n.vitA_RAE,
      thiamine: cooking == 'hashlama' ? n.thiamine * 0.75 : n.thiamine * 0.85,
      riboflavin: n.riboflavin * 0.90,
      niacin: n.niacin * 0.90,
      pantothenic: n.pantothenic,
      vitB6: n.vitB6 * 0.85,
      folate: cooking == 'hashlama' ? n.folate * 0.65 : n.folate * 0.80,
      vitB12: n.vitB12,
      choline: n.choline,
      biotin: n.biotin,
      omega3: n.omega3 * fatMult,
      omega6: n.omega6 * fatMult,
      ala: n.ala,
      epa: n.epa,
      dha: n.dha,
      linoleic: n.linoleic,
      leucine: n.leucine * protMult,
      lysine: n.lysine * protMult,
      valine: n.valine * protMult,
      isoleucine: n.isoleucine * protMult,
      threonine: n.threonine * protMult,
      methionine: n.methionine * protMult,
      phenylalanine: n.phenylalanine * protMult,
      tryptophan: n.tryptophan * protMult,
      histidine: n.histidine * protMult,
      cystine: n.cystine * protMult,
      tyrosine: n.tyrosine * protMult,
      dataSource: n.dataSource,
    );
  }

  // ── Claude API Yardımcısı ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callClaude({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 1000,
    String model = 'claude-haiku-4-5-20251001',
  }) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'temperature': 0,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }

    final raw = jsonDecode(response.body)['content'][0]['text'] as String;
    return jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
  }

  String _cleanJson(String raw) =>
      raw.replaceAll(RegExp(r'```json|```'), '').trim();

  double _round1(double v) => (v * 10).round() / 10;

  // ── BARKOD ANALİZİ ─────────────────────────────────────────────────────────

  Future<FoodAnalysisResult?> analyzeBarcode(String barcode) async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;
    final n = (data['product']['nutriments'] ?? {}) as Map<String, dynamic>;

    final protein = (n['proteins_100g'] as num?)?.toDouble() ?? 0;
    final carbs = (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0;
    final fat = (n['fat_100g'] as num?)?.toDouble() ?? 0;
    final calories =
        calculateCalories(proteinG: protein, carbsG: carbs, fatG: fat);

    return FoodAnalysisResult(
      foodName: (data['product']['product_name'] as String?) ?? 'Bilinmeyen',
      portionGrams: 100,
      nutritionPer100g: NutritionData(
        calories: calories,
        protein: protein,
        carbohydrates: carbs,
        fat: fat,
        fiber: (n['fiber_100g'] as num?)?.toDouble() ?? 0,
        sodium: (n['sodium_100g'] as num?)?.toDouble(),
      ),
      sources: const ['OpenFoodFacts'],
      confidenceScore: 88,
      alternativeMin: calories * 0.9,
      alternativeMax: calories * 1.1,
    );
  }

  // ── Eski uyumluluk metotları ───────────────────────────────────────────────

  Future<void> saveUserCorrection(
    String foodName,
    NutritionData correctedNutrition,
  ) =>
      saveCorrection(foodName, correctedNutrition);

  Future<NutritionData?> getUserCorrection(String foodName) =>
      _checkUserHistory(foodName);
}
