  Future<Map<String, dynamic>> _analyzeImageFast(
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
              'text': '''
Sen "Nutrition5k" ve "USDA" veri standartlarına hakim uzman bir besin analistisin. Görseldeki tabağı sanal olarak içindeki farklı bileşenlere (segmentlere) ayır.
1. Tabağın veya referans bir nesnenin (çatal/kaşık) boyutunu baz alarak porsiyonu hesapla.
2. Tabağın ana bileşenleri için KESİN bir USDA standart tablosu seç (örn: USDA 170456 Cooked Salmon) ve mikro besin oranlarını sabit tutarak ağırlıkla çarp.
3. Stabilite için segmentasyon oranlarını her zaman en yakın %10'luk dilimlere yuvarla.

--- IN-CONTEXT EĞİTİM VERİLERİ (KALİBRASYON) ---
Kural 1: Etler piştikçe hacim küçülür, 100g başına makro/mikro değerleri artar.
Kural 2: Tahıllar piştikçe su çeker, 100g başına makro/mikro değerleri düşer.
Kural 3: Kızartma işlemi ekstra yağ emilimi yaratır. Değerlere yansıt.
------------------------------------------------
${hint != null ? '\nKullanıcı notu: "$hint"\n' : ''}
Aşağıdaki tüm değerleri 100g başına olacak şekilde hesapla. Porsiyon değerini ise görselin tamamı için gram olarak ver.

SADECE JSON döndür, başka hiçbir şey yazma:
{"yemek_adi":"string","yemek_tipi":"corba|ana_yemek|salata|tatli|icecek|kahvalti|atistirmalik","pisirme":"cig|hashlama|izgara|kizartma|firin|diger","porsiyon_gram":number,"guven_skoru":number,"protein":number,"karbonhidrat":number,"yag":number,"lif":number,"seker":number,"doymus_yag":number,"tekli_doymus_yag":number,"coklu_doymus_yag":number,"trans_yag":number,"kolesterol_mg":number,"su":number,"kalsiyum_mg":number,"demir_mg":number,"magnezyum_mg":number,"fosfor_mg":number,"potasyum_mg":number,"sodyum_mg":number,"cinko_mg":number,"bakir_mg":number,"manganez_mg":number,"selenyum_mcg":number,"iyot_mcg":number,"krom_mcg":number,"molibden_mcg":number,"c_vitamini_mg":number,"d_vitamini_mcg":number,"e_vitamini_mg":number,"k1_vitamini_mcg":number,"a_vitamini_mcg":number,"beta_karoten_mcg":number,"likopen_mcg":number,"lutein_zea_mcg":number,"b1_tiamin_mg":number,"b2_riboflavin_mg":number,"b3_niasin_mg":number,"b5_pantotenik_mg":number,"b6_mg":number,"folat_mcg":number,"b12_mcg":number,"kolin_mg":number,"biotin_mcg":number,"omega3_g":number,"omega6_g":number,"epa_g":number,"dha_g":number,"ala_g":number,"linoleik_g":number,"losin_g":number,"lizin_g":number,"valin_g":number,"izolosin_g":number,"treonin_g":number,"metionin_g":number,"fenilalanin_g":number,"triptofan_g":number,"histidin_g":number,"sistin_g":number,"tirozin_g":number}

Kurallar: Bilmiyorsan 0 yaz. protein+karbonhidrat+yag ≤ 100. Amino asit toplamı ≤ protein.'''
            },
          ],
        },
      ],
      maxTokens: 1000,
      model: 'claude-haiku-4-5-20251001',
    );
    return json;
  }
