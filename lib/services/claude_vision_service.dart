import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ClaudeVisionService {
  final String apiKey = const String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');

  Future<Map<String, dynamic>> analyzeFood(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-5',
        'max_tokens': 2048,
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
              {
                'type': 'text',
                'text':
                    'Bu yemek fotoğrafını analiz et. Fotoğraftaki referans nesneleri kullanarak yemeğin hacmini ve gramajını tahmin et. Sadece şu formatta JSON döndür, başka hiçbir şey yazma: {"yemek_adi": "...", "porsiyon_gram": 100, "hacim_ml": 150, "referans_nesne": "standart tabak", "kalori": 200, "protein": 10, "karbonhidrat": 20, "yag": 5, "lif": 2, "seker": 5, "doymus_yag": 1, "selenyum": 5, "magnezyum": 30, "omega3": 0.1, "omega6": 0.5, "demir": 1, "cinko": 0.5, "d_vitamini": 0, "b12": 0.1, "kalsiyum": 50, "potasyum": 200, "sodyum": 150, "volume_aciklamasi": "..."}. Mikro besinleri tahmini olarak ver, bilinmiyorsa 0 yaz.',
              },
            ],
          },
        ],
      }),
    );

    print('API Status: ${response.statusCode}');
    print('API Response: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['content'][0]['text'] as String;
      final cleanText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleanText) as Map<String, dynamic>;
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }
  }
}
