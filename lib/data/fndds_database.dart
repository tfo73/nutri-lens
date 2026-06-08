// USDA FNDDS 2019-2020 tabanlı yerel besin veritabanı
// Her kayıt 100g için besin değerleri içerir.

// ── Besin ID sabitleri (USDA FDC) ───────────────────────────────────────────

// MAKROLAR
const nEnergy      = '1008';
const nProtein     = '1003';
const nFat         = '1004';
const nCarb        = '1005';
const nFiber       = '1079';
const nSugar       = '2000';
const nSatFat      = '1258';
const nMonoFat     = '1292';
const nPolyFat     = '1293';
const nTransFat    = '1257';
const nCholesterol = '1253';
const nWater       = '1051';
const nAsh         = '1007';

// MİNERALLER
const nCalcium     = '1087';
const nIron        = '1089';
const nMagnesium   = '1090';
const nPhosphorus  = '1091';
const nPotassium   = '1092';
const nSodium      = '1093';
const nZinc        = '1095';
const nCopper      = '1098';
const nManganese   = '1101';
const nSelenium    = '1103';
const nFluoride    = '1099';
const nChromium    = '1096';
const nIodine      = '1100';
const nMolybdenum  = '1102';

// VİTAMİNLER
const nVitA_RAE    = '1106';
const nVitA_IU     = '1104';
const nRetinol     = '1105';
const nAlphaCarot  = '1108';
const nBetaCarot   = '1107';
const nBetaCrypt   = '1109';
const nLycopene    = '1122';
const nLuteinZea   = '1123';
const nVitE        = '1158'; // alpha-tocopherol (mg)
const nVitD_mcg    = '1114';
const nVitD_IU     = '1110';
const nVitK        = '1185';
const nVitK_Mena   = '1183';
const nVitC        = '1162';
const nThiamine    = '1165';
const nRiboflavin  = '1166';
const nNiacin      = '1167';
const nPantothenic = '1170';
const nVitB6       = '1175';
const nFolate      = '1177';
const nFolicAcid   = '1186';
const nFolate_DFE  = '1190';
const nVitB12      = '1178';
const nVitB12_add  = '1246';
const nCholine     = '1180';
const nBetaine     = '1198';
const nBiotin      = '1176';

// YAĞ ASİTLERİ
const nOmega3      = '1404';
const nOmega6      = '1405';
const nALA         = '1404'; // ALA = temel omega-3 (aynı ID)
const nEPA         = '1278';
const nDHA         = '1272';
const nLinoleic    = '1269';

// AMİNO ASİTLER
const nTryptophan      = '1210';
const nThreonine       = '1211';
const nIsoleucine      = '1212';
const nLeucine         = '1213';
const nLysine          = '1214';
const nMethionine      = '1215';
const nCystine         = '1216';
const nPhenylalanine   = '1217';
const nTyrosine        = '1218';
const nValine          = '1219';
const nHistidine       = '1221';

// ── Veri Sınıfları ───────────────────────────────────────────────────────────

class FnddsNutrient {
  final String id;
  final String name;
  final String unit;
  final double value;
  const FnddsNutrient(this.id, this.name, this.unit, this.value);
}

class FnddsFood {
  final int fdcId;
  final String name;
  final List<String> aliases;
  final String category;
  final List<FnddsNutrient> nutrients;

  const FnddsFood({
    required this.fdcId,
    required this.name,
    required this.aliases,
    required this.category,
    required this.nutrients,
  });

  double nutrient(String id) =>
      nutrients
          .firstWhere((n) => n.id == id,
              orElse: () => FnddsNutrient(id, '', '', 0))
          .value;
}

// ── Veritabanı ───────────────────────────────────────────────────────────────

const List<FnddsFood> fnddsDatabase = [

  // ── TAVUK ──────────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 171477,
    name: 'Tavuk Göğsü (Izgara)',
    aliases: ['tavuk göğsü', 'chicken breast', 'ızgara tavuk', 'tavuk şiş', 'izgara tavuk'],
    category: 'Tavuk',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 165),
      FnddsNutrient(nProtein,    'Protein',   'g',     31.0),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.6),
      FnddsNutrient(nCarb,       'Karb',      'g',      0.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      0.0),
      FnddsNutrient(nSugar,      'Şeker',     'g',      0.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      1.0),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    85.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    74.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   256.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    15.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    29.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   220.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   27.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.9),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.3),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',    13.7),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    0.1),
      FnddsNutrient(nCholine,    'Kolin',     'mg',    85.0),
      FnddsNutrient(nEPA,        'EPA',       'g',      0.01),
      FnddsNutrient(nDHA,        'DHA',       'g',      0.04),
      FnddsNutrient(nTryptophan, 'Trp',       'g',      0.37),
      FnddsNutrient(nLeucine,    'Leu',       'g',      2.44),
      FnddsNutrient(nLysine,     'Lys',       'g',      2.84),
    ],
  ),

  FnddsFood(
    fdcId: 171482,
    name: 'Hindi Göğsü (Izgara)',
    aliases: ['hindi', 'turkey breast', 'hindi göğsü', 'hindi eti'],
    category: 'Tavuk',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 135),
      FnddsNutrient(nProtein,    'Protein',   'g',     30.1),
      FnddsNutrient(nFat,        'Yağ',       'g',      1.0),
      FnddsNutrient(nCarb,       'Karb',      'g',      0.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    70.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   298.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   32.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.5),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',    11.8),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     2.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.4),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   210.0),
    ],
  ),

  FnddsFood(
    fdcId: 171461,
    name: 'Tavuk Uyluk (Izgara)',
    aliases: ['tavuk but', 'tavuk uyluk', 'chicken thigh', 'but tavuk'],
    category: 'Tavuk',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 209),
      FnddsNutrient(nProtein,    'Protein',   'g',     25.9),
      FnddsNutrient(nFat,        'Yağ',       'g',     10.9),
      FnddsNutrient(nCarb,       'Karb',      'g',      0.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      2.9),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',   105.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    95.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   225.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.3),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     2.4),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   22.0),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     6.2),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.5),
    ],
  ),

  // ── ET ────────────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 174032,
    name: 'Dana Kıyma (%15 yağ, pişmiş)',
    aliases: ['kıyma', 'dana kıyma', 'köfte', 'hamburger', 'meat', 'beef mince'],
    category: 'Et',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 215),
      FnddsNutrient(nProtein,    'Protein',   'g',     26.1),
      FnddsNutrient(nFat,        'Yağ',       'g',     11.8),
      FnddsNutrient(nCarb,       'Karb',      'g',      0.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      4.6),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    88.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    88.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   318.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.8),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     6.2),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   19.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    2.4),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     6.2),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.4),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   207.0),
      FnddsNutrient(nCholine,    'Kolin',     'mg',    82.0),
    ],
  ),

  FnddsFood(
    fdcId: 174036,
    name: 'Dana Biftek (Izgara)',
    aliases: ['biftek', 'dana biftek', 'steak', 'antrikot', 'bonfile'],
    category: 'Et',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 217),
      FnddsNutrient(nProtein,    'Protein',   'g',     26.4),
      FnddsNutrient(nFat,        'Yağ',       'g',     12.0),
      FnddsNutrient(nCarb,       'Karb',      'g',      0.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      4.5),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    82.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    65.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   330.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.5),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     5.3),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   22.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    2.2),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     7.5),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.5),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   215.0),
    ],
  ),

  FnddsFood(
    fdcId: 174003,
    name: 'Kuzu Pirzola (Izgara)',
    aliases: ['kuzu', 'kuzu pirzola', 'lamb chop', 'kuzu tandır', 'kuzu eti'],
    category: 'Et',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 294),
      FnddsNutrient(nProtein,    'Protein',   'g',     24.5),
      FnddsNutrient(nFat,        'Yağ',       'g',     20.9),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      8.8),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.9),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     4.5),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    2.7),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   22.0),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     6.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   196.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   280.0),
    ],
  ),

  // ── BALIK ─────────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 175168,
    name: 'Somon (Izgara)',
    aliases: ['somon', 'salmon', 'somon balığı', 'atlantik somonu'],
    category: 'Balık',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 208),
      FnddsNutrient(nProtein,    'Protein',   'g',     20.4),
      FnddsNutrient(nFat,        'Yağ',       'g',     13.4),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      3.1),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    63.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    59.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   363.0),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',      2.26),
      FnddsNutrient(nEPA,        'EPA',       'g',      0.69),
      FnddsNutrient(nDHA,        'DHA',       'g',      1.24),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',   11.1),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    3.2),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   40.0),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     8.6),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.8),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   252.0),
    ],
  ),

  FnddsFood(
    fdcId: 171986,
    name: 'Ton Balığı (Konserve, Suda)',
    aliases: ['ton balığı', 'tuna', 'konserve ton', 'ton'],
    category: 'Balık',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 116),
      FnddsNutrient(nProtein,    'Protein',   'g',     25.5),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.8),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   396.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   90.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    2.5),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',    13.3),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    1.7),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',      0.18),
      FnddsNutrient(nDHA,        'DHA',       'g',      0.11),
      FnddsNutrient(nEPA,        'EPA',       'g',      0.04),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   190.0),
    ],
  ),

  FnddsFood(
    fdcId: 175180,
    name: 'Karides (Haşlama)',
    aliases: ['karides', 'shrimp', 'karides haşlama', 'deniz ürünü'],
    category: 'Balık',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  99),
      FnddsNutrient(nProtein,    'Protein',   'g',     23.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.3),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',   189.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   224.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   54.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    1.9),
      FnddsNutrient(nIodine,     'İyot',      'mcg',   35.0),
    ],
  ),

  FnddsFood(
    fdcId: 175112,
    name: 'Hamsi (Taze)',
    aliases: ['hamsi', 'anchovy', 'hamsi balığı', 'taze hamsi'],
    category: 'Balık',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 131),
      FnddsNutrient(nProtein,    'Protein',   'g',     20.4),
      FnddsNutrient(nFat,        'Yağ',       'g',      4.8),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      1.3),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    60.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   104.0),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',      2.1),
      FnddsNutrient(nEPA,        'EPA',       'g',      0.73),
      FnddsNutrient(nDHA,        'DHA',       'g',      0.91),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   232.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   36.5),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    4.8),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.6),
    ],
  ),

  FnddsFood(
    fdcId: 175157,
    name: 'Çipura (Izgara)',
    aliases: ['çipura', 'levrek', 'sea bass', 'çipura balık', 'levrek balığı'],
    category: 'Balık',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 128),
      FnddsNutrient(nProtein,    'Protein',   'g',     23.6),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.6),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      0.8),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',    82.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   46.8),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    1.1),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',      0.65),
      FnddsNutrient(nDHA,        'DHA',       'g',      0.42),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   220.0),
    ],
  ),

  // ── YUMURTA ───────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 173424,
    name: 'Yumurta (Haşlama, Tüm)',
    aliases: ['yumurta', 'egg', 'haşlanmış yumurta', 'rafadan', 'katı yumurta', 'scrambled egg'],
    category: 'Yumurta',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 155),
      FnddsNutrient(nProtein,    'Protein',   'g',     12.6),
      FnddsNutrient(nFat,        'Yağ',       'g',     10.6),
      FnddsNutrient(nCarb,       'Karb',      'g',      1.1),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',      3.3),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',   373.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   124.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   126.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    50.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.2),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    12.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   172.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.1),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   20.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  149.0),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    2.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    1.1),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   44.0),
      FnddsNutrient(nCholine,    'Kolin',     'mg',   294.0),
      FnddsNutrient(nLuteinZea,  'Lutein+Zea','mcg',  353.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.1),
    ],
  ),

  // ── SÜT ÜRÜNLERİ ─────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 171265,
    name: 'Süt (Tam Yağlı)',
    aliases: ['süt', 'whole milk', 'tam yağlı süt', 'inek sütü'],
    category: 'Süt Ürünleri',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  61),
      FnddsNutrient(nProtein,    'Protein',   'g',      3.2),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.3),
      FnddsNutrient(nCarb,       'Karb',      'g',      4.8),
      FnddsNutrient(nSugar,      'Şeker',     'g',      5.1),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   113.0),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    1.3),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.4),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   150.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',    91.0),
      FnddsNutrient(nIodine,     'İyot',      'mcg',   22.0),
      FnddsNutrient(nCholine,    'Kolin',     'mg',    14.0),
    ],
  ),

  FnddsFood(
    fdcId: 171304,
    name: 'Yoğurt (Tam Yağlı)',
    aliases: ['yoğurt', 'yogurt', 'süzme yoğurt', 'greek yogurt', 'probiyotik yoğurt'],
    category: 'Süt Ürünleri',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  61),
      FnddsNutrient(nProtein,    'Protein',   'g',      3.5),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.3),
      FnddsNutrient(nCarb,       'Karb',      'g',      4.7),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   121.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',    95.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   155.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.5),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     0.6),
      FnddsNutrient(nIodine,     'İyot',      'mcg',   20.0),
    ],
  ),

  FnddsFood(
    fdcId: 173420,
    name: 'Beyaz Peynir (Feta Tipi)',
    aliases: ['beyaz peynir', 'peynir', 'feta', 'lor peyniri', 'çökelek'],
    category: 'Süt Ürünleri',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 264),
      FnddsNutrient(nProtein,    'Protein',   'g',     14.2),
      FnddsNutrient(nFat,        'Yağ',       'g',     21.3),
      FnddsNutrient(nCarb,       'Karb',      'g',      4.1),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',     14.9),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    89.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',  1116.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   493.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   337.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    1.7),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  125.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     2.9),
    ],
  ),

  FnddsFood(
    fdcId: 173418,
    name: 'Kaşar Peyniri',
    aliases: ['kaşar', 'kaşar peyniri', 'sarı peynir', 'tost peyniri'],
    category: 'Süt Ürünleri',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 402),
      FnddsNutrient(nProtein,    'Protein',   'g',     25.0),
      FnddsNutrient(nFat,        'Yağ',       'g',     33.1),
      FnddsNutrient(nCarb,       'Karb',      'g',      1.3),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',     21.1),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',    99.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   621.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   721.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   512.0),
      FnddsNutrient(nVitB12,     'B12',       'mcg',    0.8),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  271.0),
    ],
  ),

  FnddsFood(
    fdcId: 171259,
    name: 'Tereyağı',
    aliases: ['tereyağı', 'butter', 'tereyag'],
    category: 'Süt Ürünleri',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 717),
      FnddsNutrient(nFat,        'Yağ',       'g',     81.1),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',     51.4),
      FnddsNutrient(nCholesterol,'Kolest.',   'mg',   215.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   714.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  684.0),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    1.5),
      FnddsNutrient(nVitE,       'VitE',      'mg',     2.3),
      FnddsNutrient(nVitK,       'VitK',      'mcg',    7.0),
    ],
  ),

  // ── BAKLAGİLLER ──────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 172421,
    name: 'Kırmızı Mercimek (Pişmiş)',
    aliases: ['mercimek', 'red lentil', 'kırmızı mercimek', 'mercimek çorbası', 'mercimek yemeği'],
    category: 'Baklagil',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 116),
      FnddsNutrient(nProtein,    'Protein',   'g',      9.0),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.4),
      FnddsNutrient(nCarb,       'Karb',      'g',     20.1),
      FnddsNutrient(nFiber,      'Lif',       'g',      7.9),
      FnddsNutrient(nSugar,      'Şeker',     'g',      1.8),
      FnddsNutrient(nIron,       'Demir',     'mg',     3.3),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  181.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    36.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   369.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   180.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.3),
      FnddsNutrient(nThiamine,   'B1',        'mg',     0.2),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.2),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.5),
    ],
  ),

  FnddsFood(
    fdcId: 172426,
    name: 'Yeşil Mercimek (Pişmiş)',
    aliases: ['yeşil mercimek', 'green lentil', 'mercimek'],
    category: 'Baklagil',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 116),
      FnddsNutrient(nProtein,    'Protein',   'g',      9.0),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.4),
      FnddsNutrient(nCarb,       'Karb',      'g',     20.1),
      FnddsNutrient(nFiber,      'Lif',       'g',      7.9),
      FnddsNutrient(nIron,       'Demir',     'mg',     3.3),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  181.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    36.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.3),
    ],
  ),

  FnddsFood(
    fdcId: 173756,
    name: 'Nohut (Pişmiş)',
    aliases: ['nohut', 'chickpea', 'nohutlu', 'humus', 'nohut yemeği'],
    category: 'Baklagil',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 164),
      FnddsNutrient(nProtein,    'Protein',   'g',      8.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      2.6),
      FnddsNutrient(nCarb,       'Karb',      'g',     27.4),
      FnddsNutrient(nFiber,      'Lif',       'g',      7.6),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.9),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  172.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    48.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   291.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.5),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   168.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     1.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.1),
    ],
  ),

  FnddsFood(
    fdcId: 175237,
    name: 'Kuru Fasulye (Pişmiş)',
    aliases: ['fasulye', 'kuru fasulye', 'white bean', 'barbunya', 'fasulyeli'],
    category: 'Baklagil',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 127),
      FnddsNutrient(nProtein,    'Protein',   'g',      8.7),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.5),
      FnddsNutrient(nCarb,       'Karb',      'g',     22.8),
      FnddsNutrient(nFiber,      'Lif',       'g',      6.3),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.5),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  130.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    44.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   403.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   138.0),
    ],
  ),

  // ── TAHILLAR ─────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 169760,
    name: 'Beyaz Pirinç (Pişmiş)',
    aliases: ['pirinç', 'pilav', 'pirinç pilavı', 'beyaz pilav', 'rice'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 130),
      FnddsNutrient(nProtein,    'Protein',   'g',      2.7),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.3),
      FnddsNutrient(nCarb,       'Karb',      'g',     28.6),
      FnddsNutrient(nFiber,      'Lif',       'g',      0.4),
      FnddsNutrient(nThiamine,   'B1',        'mg',     0.2),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     1.6),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   98.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.2),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    12.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.5),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',    7.5),
    ],
  ),

  FnddsFood(
    fdcId: 170285,
    name: 'Bulgur (Pişmiş)',
    aliases: ['bulgur', 'bulgur pilavı', 'kisir', 'kısır', 'bulgur salatası'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  83),
      FnddsNutrient(nProtein,    'Protein',   'g',      3.1),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     18.6),
      FnddsNutrient(nFiber,      'Lif',       'g',      4.5),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    32.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.9),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   18.0),
    ],
  ),

  FnddsFood(
    fdcId: 173904,
    name: 'Yulaf Ezmesi (Pişmiş)',
    aliases: ['yulaf', 'oatmeal', 'yulaf ezmesi', 'porridge', 'oat'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  71),
      FnddsNutrient(nProtein,    'Protein',   'g',      2.5),
      FnddsNutrient(nFat,        'Yağ',       'g',      1.5),
      FnddsNutrient(nCarb,       'Karb',      'g',     12.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.7),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    26.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',    90.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.7),
      FnddsNutrient(nThiamine,   'B1',        'mg',     0.1),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',    8.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     0.9),
    ],
  ),

  FnddsFood(
    fdcId: 172687,
    name: 'Ekmek (Beyaz, Buğday)',
    aliases: ['ekmek', 'bread', 'beyaz ekmek', 'buğday ekmeği', 'sandviç ekmeği'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 265),
      FnddsNutrient(nProtein,    'Protein',   'g',      9.0),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     49.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.7),
      FnddsNutrient(nSugar,      'Şeker',     'g',      5.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   491.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     3.6),
      FnddsNutrient(nThiamine,   'B1',        'mg',     0.5),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     4.8),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  100.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   28.7),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    151.0),
    ],
  ),

  FnddsFood(
    fdcId: 172687,
    name: 'Tam Buğday Ekmeği',
    aliases: ['tam buğday ekmeği', 'whole wheat bread', 'çavdar ekmeği', 'kepekli ekmek'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 247),
      FnddsNutrient(nProtein,    'Protein',   'g',     13.0),
      FnddsNutrient(nFat,        'Yağ',       'g',      3.4),
      FnddsNutrient(nCarb,       'Karb',      'g',     41.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      7.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   400.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.5),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    76.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     1.8),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     2.2),
    ],
  ),

  FnddsFood(
    fdcId: 169732,
    name: 'Makarna (Pişmiş)',
    aliases: ['makarna', 'pasta', 'spagetti', 'spaghetti', 'erişte', 'linguine', 'penne'],
    category: 'Tahıl',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 157),
      FnddsNutrient(nProtein,    'Protein',   'g',      5.8),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.9),
      FnddsNutrient(nCarb,       'Karb',      'g',     30.9),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.8),
      FnddsNutrient(nIron,       'Demir',     'mg',     1.3),
      FnddsNutrient(nThiamine,   'B1',        'mg',     0.2),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     2.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   83.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',   26.4),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',     1.0),
    ],
  ),

  // ── SEBZELER ─────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 170379,
    name: 'Brokoli (Çiğ)',
    aliases: ['brokoli', 'broccoli'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  34),
      FnddsNutrient(nProtein,    'Protein',   'g',      2.8),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.4),
      FnddsNutrient(nCarb,       'Karb',      'g',      6.6),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.6),
      FnddsNutrient(nVitC,       'VitC',      'mg',    89.0),
      FnddsNutrient(nVitK,       'VitK',      'mcg',  102.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   63.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',   31.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    47.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   316.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.2),
      FnddsNutrient(nLuteinZea,  'Lutein+Zea','mcg', 1403.0),
    ],
  ),

  FnddsFood(
    fdcId: 168462,
    name: 'Ispanak (Çiğ)',
    aliases: ['ıspanak', 'spinach', 'ıspanak salatası', 'ıspanak yemeği'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  23),
      FnddsNutrient(nProtein,    'Protein',   'g',      2.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.4),
      FnddsNutrient(nCarb,       'Karb',      'g',      3.6),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.2),
      FnddsNutrient(nVitK,       'VitK',      'mcg',  483.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  469.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  194.0),
      FnddsNutrient(nIron,       'Demir',     'mg',     2.7),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    79.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    99.0),
      FnddsNutrient(nVitC,       'VitC',      'mg',    28.0),
      FnddsNutrient(nLuteinZea,  'Lutein+Zea','mcg',12198.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   558.0),
    ],
  ),

  FnddsFood(
    fdcId: 170457,
    name: 'Domates (Çiğ)',
    aliases: ['domates', 'tomato', 'çeri domates', 'domates salatası'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  18),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',      3.9),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.2),
      FnddsNutrient(nVitC,       'VitC',      'mg',    14.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',   42.0),
      FnddsNutrient(nLycopene,   'Likopen',   'mcg', 2573.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   237.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   15.0),
      FnddsNutrient(nVitK,       'VitK',      'mcg',    7.9),
    ],
  ),

  FnddsFood(
    fdcId: 170393,
    name: 'Havuç (Çiğ)',
    aliases: ['havuç', 'carrot'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  41),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',      9.6),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.8),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  835.0),
      FnddsNutrient(nBetaCarot,  'BetaKar',   'mcg', 8285.0),
      FnddsNutrient(nVitK,       'VitK',      'mcg',   13.2),
      FnddsNutrient(nVitC,       'VitC',      'mg',     5.9),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   320.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   19.0),
    ],
  ),

  FnddsFood(
    fdcId: 170108,
    name: 'Kırmızı Biber (Çiğ)',
    aliases: ['kırmızı biber', 'red pepper', 'dolmalık biber', 'biber'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  31),
      FnddsNutrient(nProtein,    'Protein',   'g',      1.0),
      FnddsNutrient(nCarb,       'Karb',      'g',      6.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.1),
      FnddsNutrient(nVitC,       'VitC',      'mg',   128.0),
      FnddsNutrient(nVitA_RAE,   'VitA',      'mcg',  157.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.3),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   46.0),
      FnddsNutrient(nBetaCarot,  'BetaKar',   'mcg', 1624.0),
    ],
  ),

  FnddsFood(
    fdcId: 170427,
    name: 'Patates (Haşlama)',
    aliases: ['patates', 'potato', 'haşlanmış patates', 'fırın patates'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  87),
      FnddsNutrient(nProtein,    'Protein',   'g',      1.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.1),
      FnddsNutrient(nCarb,       'Karb',      'g',     20.1),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.8),
      FnddsNutrient(nVitC,       'VitC',      'mg',    13.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.3),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   379.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   18.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    20.0),
    ],
  ),

  FnddsFood(
    fdcId: 168409,
    name: 'Patlıcan (Haşlama)',
    aliases: ['patlıcan', 'eggplant', 'patlıcan kebabı', 'imam bayıldı', 'şakşuka'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  25),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.8),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',      5.9),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.5),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   123.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   14.0),
      FnddsNutrient(nVitC,       'VitC',      'mg',     1.3),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.2),
    ],
  ),

  FnddsFood(
    fdcId: 169987,
    name: 'Mantar (Çiğ)',
    aliases: ['mantar', 'mushroom', 'şampinyon', 'champignon'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  22),
      FnddsNutrient(nProtein,    'Protein',   'g',      3.1),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.3),
      FnddsNutrient(nCarb,       'Karb',      'g',      3.3),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.0),
      FnddsNutrient(nSelenium,   'Selenyum',  'mcg',    9.3),
      FnddsNutrient(nVitD_mcg,   'VitD',      'mcg',    0.2),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',     3.6),
      FnddsNutrient(nRiboflavin, 'B2',        'mg',     0.4),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.1),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   318.0),
      FnddsNutrient(nCopper,     'Bakır',     'mg',     0.5),
    ],
  ),

  FnddsFood(
    fdcId: 170388,
    name: 'Soğan (Çiğ)',
    aliases: ['soğan', 'onion', 'kuru soğan'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  40),
      FnddsNutrient(nProtein,    'Protein',   'g',      1.1),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.1),
      FnddsNutrient(nCarb,       'Karb',      'g',      9.3),
      FnddsNutrient(nFiber,      'Lif',       'g',      1.7),
      FnddsNutrient(nSugar,      'Şeker',     'g',      4.2),
      FnddsNutrient(nVitC,       'VitC',      'mg',     7.4),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   19.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.1),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   146.0),
    ],
  ),

  FnddsFood(
    fdcId: 170383,
    name: 'Lahana (Çiğ)',
    aliases: ['lahana', 'cabbage', 'beyaz lahana', 'kırmızı lahana'],
    category: 'Sebze',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  25),
      FnddsNutrient(nProtein,    'Protein',   'g',      1.3),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.1),
      FnddsNutrient(nCarb,       'Karb',      'g',      5.8),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.5),
      FnddsNutrient(nVitC,       'VitC',      'mg',    36.6),
      FnddsNutrient(nVitK,       'VitK',      'mcg',   76.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   53.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    40.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   170.0),
    ],
  ),

  // ── MEYVELER ─────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 171688,
    name: 'Elma',
    aliases: ['elma', 'apple', 'kırmızı elma', 'yeşil elma', 'golden elma'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  52),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.3),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     13.8),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.4),
      FnddsNutrient(nSugar,      'Şeker',     'g',     10.4),
      FnddsNutrient(nVitC,       'VitC',      'mg',     4.6),
      FnddsNutrient(nVitK,       'VitK',      'mcg',    2.2),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   107.0),
    ],
  ),

  FnddsFood(
    fdcId: 173944,
    name: 'Muz',
    aliases: ['muz', 'banana'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  89),
      FnddsNutrient(nProtein,    'Protein',   'g',      1.1),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.3),
      FnddsNutrient(nCarb,       'Karb',      'g',     22.8),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.6),
      FnddsNutrient(nSugar,      'Şeker',     'g',     12.2),
      FnddsNutrient(nVitC,       'VitC',      'mg',     8.7),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.4),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   358.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    27.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   20.0),
    ],
  ),

  FnddsFood(
    fdcId: 171705,
    name: 'Avokado',
    aliases: ['avokado', 'avocado'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 160),
      FnddsNutrient(nProtein,    'Protein',   'g',      2.0),
      FnddsNutrient(nFat,        'Yağ',       'g',     14.7),
      FnddsNutrient(nCarb,       'Karb',      'g',      8.5),
      FnddsNutrient(nFiber,      'Lif',       'g',      6.7),
      FnddsNutrient(nMonoFat,    'TekDoyYağ', 'g',      9.8),
      FnddsNutrient(nVitK,       'VitK',      'mcg',   21.0),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   81.0),
      FnddsNutrient(nVitB6,      'B6',        'mg',     0.3),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   485.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',    29.0),
      FnddsNutrient(nVitC,       'VitC',      'mg',    10.0),
      FnddsNutrient(nVitE,       'VitE',      'mg',     2.1),
    ],
  ),

  FnddsFood(
    fdcId: 171710,
    name: 'Portakal',
    aliases: ['portakal', 'orange', 'portakal suyu', 'mandalina'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  47),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.9),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.1),
      FnddsNutrient(nCarb,       'Karb',      'g',     11.8),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.4),
      FnddsNutrient(nSugar,      'Şeker',     'g',      9.4),
      FnddsNutrient(nVitC,       'VitC',      'mg',    53.2),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   30.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   181.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',    40.0),
    ],
  ),

  FnddsFood(
    fdcId: 167762,
    name: 'Çilek',
    aliases: ['çilek', 'strawberry', 'çilek smoothie'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  32),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.7),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.3),
      FnddsNutrient(nCarb,       'Karb',      'g',      7.7),
      FnddsNutrient(nFiber,      'Lif',       'g',      2.0),
      FnddsNutrient(nSugar,      'Şeker',     'g',      4.9),
      FnddsNutrient(nVitC,       'VitC',      'mg',    58.8),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',   24.0),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   153.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     0.4),
    ],
  ),

  FnddsFood(
    fdcId: 171726,
    name: 'Üzüm',
    aliases: ['üzüm', 'grape', 'kırmızı üzüm', 'yeşil üzüm'],
    category: 'Meyve',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal',  69),
      FnddsNutrient(nProtein,    'Protein',   'g',      0.7),
      FnddsNutrient(nFat,        'Yağ',       'g',      0.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     18.1),
      FnddsNutrient(nFiber,      'Lif',       'g',      0.9),
      FnddsNutrient(nSugar,      'Şeker',     'g',     15.5),
      FnddsNutrient(nVitC,       'VitC',      'mg',     3.2),
      FnddsNutrient(nVitK,       'VitK',      'mcg',   14.6),
      FnddsNutrient(nPotassium,  'Potasyum',  'mg',   191.0),
    ],
  ),

  // ── FISTIK VE TOHUMLAR ────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 170567,
    name: 'Badem',
    aliases: ['badem', 'almond', 'badem içi', 'çiğ badem'],
    category: 'Kuruyemiş',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 579),
      FnddsNutrient(nProtein,    'Protein',   'g',     21.2),
      FnddsNutrient(nFat,        'Yağ',       'g',     49.9),
      FnddsNutrient(nCarb,       'Karb',      'g',     21.6),
      FnddsNutrient(nFiber,      'Lif',       'g',     12.5),
      FnddsNutrient(nVitE,       'VitE',      'mg',    25.6),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   270.0),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   264.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   481.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     3.1),
      FnddsNutrient(nRiboflavin, 'B2',        'mg',     1.1),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     2.2),
      FnddsNutrient(nCopper,     'Bakır',     'mg',     1.0),
    ],
  ),

  FnddsFood(
    fdcId: 170187,
    name: 'Ceviz',
    aliases: ['ceviz', 'walnut', 'ceviz içi'],
    category: 'Kuruyemiş',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 654),
      FnddsNutrient(nProtein,    'Protein',   'g',     15.2),
      FnddsNutrient(nFat,        'Yağ',       'g',     65.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     13.7),
      FnddsNutrient(nFiber,      'Lif',       'g',      6.7),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',      9.08),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   158.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   346.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     3.4),
      FnddsNutrient(nCopper,     'Bakır',     'mg',     1.6),
      FnddsNutrient(nVitE,       'VitE',      'mg',     0.7),
    ],
  ),

  FnddsFood(
    fdcId: 174260,
    name: 'Yer Fıstığı',
    aliases: ['yer fıstığı', 'peanut', 'fıstık', 'çiğ fıstık'],
    category: 'Kuruyemiş',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 567),
      FnddsNutrient(nProtein,    'Protein',   'g',     25.8),
      FnddsNutrient(nFat,        'Yağ',       'g',     49.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     16.1),
      FnddsNutrient(nFiber,      'Lif',       'g',      8.5),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   168.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   376.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     3.3),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',    12.1),
      FnddsNutrient(nVitE,       'VitE',      'mg',     8.3),
      FnddsNutrient(nFolate_DFE, 'Folat',     'mcg',  240.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     1.9),
    ],
  ),

  FnddsFood(
    fdcId: 174270,
    name: 'Fıstık Ezmesi',
    aliases: ['fıstık ezmesi', 'peanut butter', 'yer fıstığı ezmesi'],
    category: 'Kuruyemiş',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 588),
      FnddsNutrient(nProtein,    'Protein',   'g',     25.0),
      FnddsNutrient(nFat,        'Yağ',       'g',     50.0),
      FnddsNutrient(nCarb,       'Karb',      'g',     20.0),
      FnddsNutrient(nFiber,      'Lif',       'g',      6.0),
      FnddsNutrient(nSodium,     'Sodyum',    'mg',   429.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   154.0),
      FnddsNutrient(nNiacin,     'Niasin',    'mg',    13.1),
      FnddsNutrient(nVitE,       'VitE',      'mg',     6.3),
    ],
  ),

  FnddsFood(
    fdcId: 170554,
    name: 'Chia Tohumu',
    aliases: ['chia', 'chia seed', 'chia tohumu'],
    category: 'Tohum',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 486),
      FnddsNutrient(nProtein,    'Protein',   'g',     16.5),
      FnddsNutrient(nFat,        'Yağ',       'g',     30.7),
      FnddsNutrient(nCarb,       'Karb',      'g',     42.1),
      FnddsNutrient(nFiber,      'Lif',       'g',     34.4),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',     17.8),
      FnddsNutrient(nCalcium,    'Kalsiyum',  'mg',   631.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   860.0),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   335.0),
      FnddsNutrient(nZinc,       'Çinko',     'mg',     4.6),
      FnddsNutrient(nIron,       'Demir',     'mg',     7.7),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     2.7),
    ],
  ),

  FnddsFood(
    fdcId: 170150,
    name: 'Keten Tohumu',
    aliases: ['keten tohumu', 'flaxseed', 'flax'],
    category: 'Tohum',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 534),
      FnddsNutrient(nProtein,    'Protein',   'g',     18.3),
      FnddsNutrient(nFat,        'Yağ',       'g',     42.2),
      FnddsNutrient(nCarb,       'Karb',      'g',     28.9),
      FnddsNutrient(nFiber,      'Lif',       'g',     27.3),
      FnddsNutrient(nOmega3,     'Omega-3',   'g',     22.8),
      FnddsNutrient(nMagnesium,  'Magnezyum', 'mg',   392.0),
      FnddsNutrient(nPhosphorus, 'Fosfor',    'mg',   642.0),
      FnddsNutrient(nManganese,  'Mangan',    'mg',     2.5),
    ],
  ),

  // ── YAĞLAR ───────────────────────────────────────────────────────────────

  FnddsFood(
    fdcId: 171413,
    name: 'Zeytinyağı',
    aliases: ['zeytinyağı', 'olive oil', 'sızma zeytinyağı', 'naturel zeytinyağı'],
    category: 'Yağ',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 884),
      FnddsNutrient(nFat,        'Yağ',       'g',    100.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',     13.8),
      FnddsNutrient(nMonoFat,    'TekDoyYağ', 'g',     73.0),
      FnddsNutrient(nPolyFat,    'ÇokDoyYağ', 'g',     10.5),
      FnddsNutrient(nVitE,       'VitE',      'mg',    14.4),
      FnddsNutrient(nVitK,       'VitK',      'mcg',   60.2),
    ],
  ),

  FnddsFood(
    fdcId: 172337,
    name: 'Ayçiçek Yağı',
    aliases: ['ayçiçek yağı', 'sunflower oil', 'sıvı yağ', 'bitkisel yağ'],
    category: 'Yağ',
    nutrients: [
      FnddsNutrient(nEnergy,     'Enerji',    'kcal', 884),
      FnddsNutrient(nFat,        'Yağ',       'g',    100.0),
      FnddsNutrient(nSatFat,     'Doy.Yağ',   'g',     10.3),
      FnddsNutrient(nMonoFat,    'TekDoyYağ', 'g',     19.5),
      FnddsNutrient(nPolyFat,    'ÇokDoyYağ', 'g',     65.7),
      FnddsNutrient(nVitE,       'VitE',      'mg',    41.1),
      FnddsNutrient(nVitK,       'VitK',      'mcg',    5.4),
    ],
  ),

];
