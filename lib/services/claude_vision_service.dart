import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'config_service.dart';

class ClaudeVisionService {
  String get _apiKey => ConfigService.anthropicKey;

  static Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<Map<String, dynamic>> analyzeFoodFromBytes(
    Uint8List bytes, {
    String? hint,
  }) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    return _callApi(base64Encode(bytes), hint: hint);
  }

  Future<Map<String, dynamic>> analyzeFood(
    File imageFile, {
    String? hint,
  }) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    final bytes = await imageFile.readAsBytes();
    return _callApi(base64Encode(bytes), hint: hint);
  }

  /// Kullanıcının metin/sesle tarif ettiği yiyeceği analiz eder.
  Future<Map<String, dynamic>> analyzeFoodFromText(String description) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    final prompt = '''
Sen bir uzman diyetisyen ve besin analisti olarak kullanıcının tarif ettiği yiyeceği analiz et.

Kullanıcı tarifi: "$description"

ADIM 1 — YEMEK TANIMI:
- Tarife göre yemeğin tam adını belirle (Türkçe - yemek_adi, İngilizce - yemek_adi_en)
- Pişirme yöntemini tahmin et (eğer belirtilmemişse en yaygın yöntemi kullan)
- Malzemeleri tespit et

ADIM 2 — PORSIYON HESAPLAMA:
- Kullanıcı gramaj/miktar belirtmişse kullan
- Belirtilmemişse standart bir porsiyon varsay (örn. 1 köfte ≈ 60g, 1 kase pilav ≈ 200g)
- Toplam gram cinsinden porsiyon_gram değerini hesapla

ADIM 3 — MAKRO HESAPLAMA:
- Kalori, protein, karbonhidrat, yağ, lif değerlerini hesapla
- Pişirme yöntemi etkisini uygula

ADIM 4 — MİKRO BESİN TAHMİNİ (DETAYLI):
- Her malzemenin bilinen mikro besin içeriğini kullanarak tahmini değerleri hesapla
- Sıfır vermekten kaçın: eğer malzemede iz miktarda bile varsa gerçekçi bir değer gir
- Birimler: vitaminler μg veya mg (ilgili standartta), mineraller mg, omega'lar g

ADIM 5 — GÜVENİLİRLİK:
- Kullanıcı ne kadar detay verdiyse güven skoru o kadar yüksek
- Belirsiz tarif = düşük güven, detaylı tarif = yüksek güven

SADECE JSON döndür, başka hiçbir şey yazma:
{
  "yemek_adi": "",
  "yemek_adi_en": "",
  "pişirme_yöntemi": "",
  "malzemeler": [],
  "porsiyon_gram": 0,
  "hacim_ml": 0,
  "referans_nesne": "",
  "porsiyon_aciklamasi": "",
  "kalori": 0,
  "protein": 0,
  "karbonhidrat": 0,
  "yag": 0,
  "lif": 0,
  "sodyum": 0,
  "seker": 0,
  "doymus_yag": 0,
  "vitaminA": 0,
  "vitaminC": 0,
  "vitaminD": 0,
  "vitaminE": 0,
  "vitaminK": 0,
  "vitaminB6": 0,
  "vitaminB12": 0,
  "folate": 0,
  "kalsiyum": 0,
  "demir": 0,
  "magnezyum": 0,
  "potasyum": 0,
  "cinko": 0,
  "selenyum": 0,
  "omega3": 0,
  "omega6": 0,
  "guven_skoru": 0,
  "guven_nedeni": "",
  "alternatif_tahmin": {
    "min_kalori": 0,
    "max_kalori": 0
  }
}''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 2000,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['content'][0]['text'] as String;
      final clean = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _callApi(
    String base64Image, {
    String? hint,
  }) async {
    final prompt = '''
Sen bir uzman diyetisyen ve besin analisti olarak bu yemeği analiz et.

${hint != null && hint.isNotEmpty ? 'Kullanıcı notu: "$hint"' : ''}

ADIM 1 — YEMEK TANIMI:
- Yemeğin tam adı (Türkçe - yemek_adi, İngilizce - yemek_adi_en)
- Tahmini pişirme yöntemi (ızgara/haşlama/kızartma/çiğ/fırın)
- Tespit edilen malzemeler (virgülle listele)
- Referans nesne varsa (tabak, çatal, bardak) boyut tahmini için kullan
- Porsiyon tahmini: görsel büyüklük × yoğunluk × standart porsiyon

ADIM 2 — MAKRO HESAPLAMA:
Her malzeme için ayrı ayrı hesapla, sonra topla.
Pişirme yönteminin etkisini uygula:
- Kızartma: yağ +%15-25
- Izgara: nem kaybı -%20-30 (protein konsantrasyonu artar)
- Haşlama: minimal değişim

ADIM 3 — MİKRO BESİN ANALİZİ (DETAYLI):
Her görünen malzemenin bilinen mikro besin içeriğini kullanarak gerçekçi değerler hesapla.
Sıfır vermekten kaçın — iz miktarlar bile dahil gerçekçi değer gir.
Birimler: vitaminler μg veya mg (ilgili standartta), mineraller mg, omega'lar g.

ADIM 4 — GÜVENİLİRLİK SKORU:
- Görüntü kalitesi
- Porsiyon belirsizliği
- Yemek karmaşıklığı
- 0-100 arası skor ve nedeni

SADECE JSON döndür, başka hiçbir şey yazma:
{
  "yemek_adi": "",
  "yemek_adi_en": "",
  "pişirme_yöntemi": "",
  "malzemeler": [],
  "porsiyon_gram": 0,
  "hacim_ml": 0,
  "referans_nesne": "",
  "porsiyon_aciklamasi": "",
  "kalori": 0,
  "protein": 0,
  "karbonhidrat": 0,
  "yag": 0,
  "lif": 0,
  "sodyum": 0,
  "seker": 0,
  "doymus_yag": 0,
  "vitaminA": 0,
  "vitaminC": 0,
  "vitaminD": 0,
  "vitaminE": 0,
  "vitaminK": 0,
  "vitaminB6": 0,
  "vitaminB12": 0,
  "folate": 0,
  "kalsiyum": 0,
  "demir": 0,
  "magnezyum": 0,
  "potasyum": 0,
  "cinko": 0,
  "selenyum": 0,
  "omega3": 0,
  "omega6": 0,
  "guven_skoru": 0,
  "guven_nedeni": "",
  "alternatif_tahmin": {
    "min_kalori": 0,
    "max_kalori": 0
  }
}''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 2000,
        'messages': [
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
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['content'][0]['text'] as String;
      final clean = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }
  }
}
