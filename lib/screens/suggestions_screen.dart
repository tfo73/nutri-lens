import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/exercise_entry.dart';
import '../providers/language_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';

// ─── Öneri Modeli ─────────────────────────────────────────────────────────────

class SuggestionItem {
  final String titleTr;
  final String titleEn;
  final String descriptionTr;
  final String descriptionEn;
  final String category;
  final IconData icon;
  final Color color;

  const SuggestionItem({
    required this.titleTr,
    required this.titleEn,
    required this.descriptionTr,
    required this.descriptionEn,
    required this.category,
    required this.icon,
    required this.color,
  });

  String title(bool isTurkish) => isTurkish ? titleTr : titleEn;
  String description(bool isTurkish) => isTurkish ? descriptionTr : descriptionEn;
}

// ─── Antrenman Modeli ──────────────────────────────────────────────────────────

enum WorkoutDifficulty { easy, medium, hard }
enum WorkoutCategory { cardio, strength, flexibility }

class WorkoutItem {
  final String nameTr;
  final String nameEn;
  final IconData icon;
  final String durationTr;
  final String durationEn;
  final int calories;
  final WorkoutDifficulty difficulty;
  final WorkoutCategory category;
  final int durationSeconds;

  const WorkoutItem({
    required this.nameTr,
    required this.nameEn,
    required this.icon,
    required this.durationTr,
    required this.durationEn,
    required this.calories,
    required this.difficulty,
    required this.category,
    required this.durationSeconds,
  });

  String name(bool isTurkish) => isTurkish ? nameTr : nameEn;
  String duration(bool isTurkish) => isTurkish ? durationTr : durationEn;
}

// ─── Öneri Havuzu (40+) ───────────────────────────────────────────────────────

const List<SuggestionItem> _pool = [
  // Sabah rutini
  SuggestionItem(
    titleTr: 'Kahvaltıyı atlama',
    titleEn: 'Don\'t skip breakfast',
    descriptionTr: 'Güne yulaf, yumurta ya da tam tahıllı ekmekle başla. Kahvaltı gün boyu odaklanmayı artırır.',
    descriptionEn: 'Start the day with oats, eggs or whole-grain bread. Breakfast improves focus throughout the day.',
    category: 'morning', icon: Icons.breakfast_dining, color: Colors.orange,
  ),
  SuggestionItem(
    titleTr: 'Güne su ile başla',
    titleEn: 'Start the day with water',
    descriptionTr: 'Sabah kalktığında aç karnına 1-2 bardak su için. Metabolizmayı hızlandırır.',
    descriptionEn: 'Drink 1-2 glasses of water on an empty stomach in the morning. It speeds up metabolism.',
    category: 'morning', icon: Icons.water_drop, color: Colors.cyan,
  ),
  SuggestionItem(
    titleTr: 'Sabah proteini önemli',
    titleEn: 'Morning protein matters',
    descriptionTr: 'Sabah öğününde en az 20g protein alın. Kas koruması ve tokluk hissi için kritik.',
    descriptionEn: 'Consume at least 20g of protein at breakfast. Critical for muscle retention and satiety.',
    category: 'morning', icon: Icons.egg_alt, color: Colors.amber,
  ),
  SuggestionItem(
    titleTr: 'Aralıklı oruç dene',
    titleEn: 'Try intermittent fasting',
    descriptionTr: '16:8 yöntemi: 16 saat açlık, 8 saat yeme penceresi. Birçok kişiye yarar sağlar.',
    descriptionEn: '16:8 method: 16 hours fasting, 8-hour eating window. Benefits many people.',
    category: 'morning', icon: Icons.schedule, color: Colors.deepPurple,
  ),
  // Protein
  SuggestionItem(
    titleTr: 'Protein alımını artır',
    titleEn: 'Increase protein intake',
    descriptionTr: 'Akşam yemeğine tavuk, yumurta veya baklagil ekleyerek günlük protein ihtiyacını karşıla.',
    descriptionEn: 'Add chicken, eggs or legumes to dinner to meet daily protein needs.',
    category: 'protein', icon: Icons.fitness_center, color: Colors.blue,
  ),
  SuggestionItem(
    titleTr: 'Bitkisel protein tüket',
    titleEn: 'Consume plant protein',
    descriptionTr: 'Mercimek, nohut, edamame güçlü bitkisel protein kaynaklarıdır. Hem lif hem protein içerir.',
    descriptionEn: 'Lentils, chickpeas, and edamame are strong plant protein sources with fiber too.',
    category: 'protein', icon: Icons.spa, color: Colors.green,
  ),
  SuggestionItem(
    titleTr: 'Antrenman sonrası protein',
    titleEn: 'Protein after workout',
    descriptionTr: 'Egzersizden sonra 30 dakika içinde protein tüket. Kas onarımı için en kritik pencere.',
    descriptionEn: 'Consume protein within 30 minutes after exercise. The most critical window for muscle repair.',
    category: 'protein', icon: Icons.sports_gymnastics, color: Colors.indigo,
  ),
  // Hidrasyon
  SuggestionItem(
    titleTr: 'Günde 2 litre su iç',
    titleEn: 'Drink 2 liters of water daily',
    descriptionTr: 'Her saat başı 1 bardak su içmeyi alışkanlık haline getir. Yanında her zaman su şişesi taşı.',
    descriptionEn: 'Make it a habit to drink 1 glass of water every hour. Always carry a water bottle.',
    category: 'hydration', icon: Icons.water_drop, color: Colors.cyan,
  ),
  SuggestionItem(
    titleTr: 'Yemekten önce su iç',
    titleEn: 'Drink water before meals',
    descriptionTr: 'Her öğünden 30 dakika önce 1 bardak su iç. Porsiyon kontrolüne yardımcı olur.',
    descriptionEn: 'Drink 1 glass of water 30 minutes before each meal. Helps with portion control.',
    category: 'hydration', icon: Icons.local_drink, color: Colors.lightBlue,
  ),
  SuggestionItem(
    titleTr: 'Elektrolit dengesi',
    titleEn: 'Electrolyte balance',
    descriptionTr: 'Çok terlendiysen sadece su değil, biraz tuzlu veya elektrolititli içecek de al.',
    descriptionEn: 'If you sweat a lot, also drink something slightly salty or electrolyte-rich.',
    category: 'hydration', icon: Icons.bolt, color: Colors.teal,
  ),
  SuggestionItem(
    titleTr: 'Kafein su değildir',
    titleEn: 'Caffeine is not water',
    descriptionTr: 'Çay ve kahve idrar söktürücüdür. Günlük 2-3 fincan sınırını aşmamaya çalış.',
    descriptionEn: 'Tea and coffee are diuretics. Try not to exceed 2-3 cups per day.',
    category: 'hydration', icon: Icons.coffee, color: Colors.brown,
  ),
  // Öğün zamanlaması
  SuggestionItem(
    titleTr: 'Düzenli yemek zamanlaması',
    titleEn: 'Regular meal timing',
    descriptionTr: 'Her 3-4 saatte bir beslenmeye çalış. Uzun açlık metabolizmayı yavaşlatır.',
    descriptionEn: 'Try to eat every 3-4 hours. Extended fasting slows metabolism.',
    category: 'timing', icon: Icons.schedule, color: Colors.purple,
  ),
  SuggestionItem(
    titleTr: 'Ara öğün ekle',
    titleEn: 'Add a snack',
    descriptionTr: 'Öğünler arası bir avuç fındık veya bir porsiyon yoğurt kan şekerini dengeler.',
    descriptionEn: 'A handful of hazelnuts or a portion of yogurt between meals balances blood sugar.',
    category: 'timing', icon: Icons.restaurant, color: Colors.green,
  ),
  SuggestionItem(
    titleTr: 'Geç saatte yemekten kaçın',
    titleEn: 'Avoid late-night eating',
    descriptionTr: 'Yatmadan en az 2-3 saat önce son öğününü tamamla. Gece geç yemek sindirimi zorlaştırır.',
    descriptionEn: 'Finish your last meal at least 2-3 hours before bed. Late-night eating impairs digestion.',
    category: 'timing', icon: Icons.nights_stay, color: Colors.blueAccent,
  ),
  SuggestionItem(
    titleTr: 'Yavaş ye',
    titleEn: 'Eat slowly',
    descriptionTr: 'Her öğünü en az 20 dakikada tüket. Yavaş yemek tokluk sinyallerinin beyne ulaşmasını sağlar.',
    descriptionEn: 'Take at least 20 minutes per meal. Slow eating allows satiety signals to reach the brain.',
    category: 'timing', icon: Icons.timer_outlined, color: Colors.deepPurple,
  ),
  // Karbonhidrat
  SuggestionItem(
    titleTr: 'Lif tüketimini artır',
    titleEn: 'Increase fiber intake',
    descriptionTr: 'Sebze ve tam tahıl tüketimini artır. Günde en az 25g lif almaya çalış.',
    descriptionEn: 'Increase vegetable and whole grain consumption. Aim for at least 25g of fiber per day.',
    category: 'carbs', icon: Icons.grass, color: Colors.lightGreen,
  ),
  SuggestionItem(
    titleTr: 'Glisemik indeksi düşür',
    titleEn: 'Lower glycemic index',
    descriptionTr: 'Beyaz pirinç ve ekmek yerine esmer pirinç ve tam tahıllı ekmek tercih et.',
    descriptionEn: 'Choose brown rice and whole grain bread instead of white rice and bread.',
    category: 'carbs', icon: Icons.trending_down, color: Colors.greenAccent,
  ),
  SuggestionItem(
    titleTr: 'İşlenmiş şekeri azalt',
    titleEn: 'Reduce processed sugar',
    descriptionTr: 'Hazır meyve suyu ve şekerleme yerine taze meyve tercih et. Etiketteki gizli şekere dikkat.',
    descriptionEn: 'Choose fresh fruit instead of packaged juice and candy. Watch for hidden sugar in labels.',
    category: 'carbs', icon: Icons.no_food, color: Colors.red,
  ),
  // Yağ
  SuggestionItem(
    titleTr: 'Omega-3 kaynakları tüket',
    titleEn: 'Consume Omega-3 sources',
    descriptionTr: 'Haftada 2 kez somon veya uskumru ye. Ceviz ve keten tohumu da iyi kaynaklardır.',
    descriptionEn: 'Eat salmon or mackerel twice a week. Walnuts and flaxseed are also good sources.',
    category: 'fat', icon: Icons.set_meal, color: Colors.teal,
  ),
  SuggestionItem(
    titleTr: 'Zeytinyağı kullan',
    titleEn: 'Use olive oil',
    descriptionTr: 'Pişirmede tereyağı yerine zeytinyağı tercih et. Soğuk baskı zeytinyağı en faydalısıdır.',
    descriptionEn: 'Use olive oil instead of butter for cooking. Cold-pressed olive oil is most beneficial.',
    category: 'fat', icon: Icons.opacity, color: Colors.lime,
  ),
  SuggestionItem(
    titleTr: 'Avokado tüket',
    titleEn: 'Eat avocado',
    descriptionTr: 'Haftada birkaç kez avokado ye. Tekli doymamış yağ asitleri kalp sağlığını korur.',
    descriptionEn: 'Eat avocado a few times a week. Monounsaturated fatty acids protect heart health.',
    category: 'fat', icon: Icons.eco, color: Colors.green,
  ),
  // Vitamin & Mineral
  SuggestionItem(
    titleTr: 'D vitamini takviyesi al',
    titleEn: 'Take vitamin D',
    descriptionTr: 'Yağlı balık, yumurta sarısı tüket ya da güneşten yararlan. Eksiklik yorgunluğa yol açar.',
    descriptionEn: 'Eat fatty fish, egg yolks or get sunlight. Deficiency leads to fatigue.',
    category: 'vitamin', icon: Icons.wb_sunny, color: Colors.amber,
  ),
  SuggestionItem(
    titleTr: 'Kalsiyum alımına dikkat et',
    titleEn: 'Pay attention to calcium intake',
    descriptionTr: 'Günde 1-2 porsiyon süt, yoğurt veya peynir tüket. Kemik sağlığı için kritik öneme sahiptir.',
    descriptionEn: 'Consume 1-2 portions of milk, yogurt or cheese per day. Critical for bone health.',
    category: 'vitamin', icon: Icons.egg_alt, color: Colors.blueGrey,
  ),
  SuggestionItem(
    titleTr: 'Demir deposunu doldur',
    titleEn: 'Fill your iron stores',
    descriptionTr: 'Ispanak, kırmızı et veya mercimek tüket. C vitaminiyle birlikte alınca emilimi artar.',
    descriptionEn: 'Eat spinach, red meat or lentils. Absorption increases when taken with vitamin C.',
    category: 'vitamin', icon: Icons.bloodtype, color: Colors.red,
  ),
  SuggestionItem(
    titleTr: 'Magnezyum alımını artır',
    titleEn: 'Increase magnesium intake',
    descriptionTr: 'Kabak çekirdeği, badem ve koyu yapraklı sebzeler bol magnezyum içerir. Uyku kalitesini artırır.',
    descriptionEn: 'Pumpkin seeds, almonds and dark leafy vegetables are rich in magnesium. Improves sleep quality.',
    category: 'vitamin', icon: Icons.bolt, color: Colors.lime,
  ),
  SuggestionItem(
    titleTr: 'B12 vitaminine dikkat et',
    titleEn: 'Pay attention to vitamin B12',
    descriptionTr: 'Kırmızı et, balık ve süt ürünleri tüket. Sinir sistemi ve enerji için hayati öneme sahiptir.',
    descriptionEn: 'Consume red meat, fish and dairy. Vital for nervous system and energy.',
    category: 'vitamin', icon: Icons.electric_bolt, color: Colors.yellow,
  ),
  SuggestionItem(
    titleTr: 'C vitamini tüket',
    titleEn: 'Consume vitamin C',
    descriptionTr: 'Her gün bir portakal, kivi veya kırmızı biber ye. Bağışıklık sistemini ve demir emilimini destekler.',
    descriptionEn: 'Eat an orange, kiwi or red pepper every day. Supports immune system and iron absorption.',
    category: 'vitamin', icon: Icons.circle, color: Colors.deepOrangeAccent,
  ),
  SuggestionItem(
    titleTr: 'Antioksidan tüket',
    titleEn: 'Consume antioxidants',
    descriptionTr: 'Yaban mersini, nar veya yeşil çay tüket. Hücre hasarına karşı koruma sağlar.',
    descriptionEn: 'Consume blueberries, pomegranate or green tea. Protects against cellular damage.',
    category: 'vitamin', icon: Icons.local_florist, color: Colors.pink,
  ),
  SuggestionItem(
    titleTr: 'Çinko eksikliğini gider',
    titleEn: 'Address zinc deficiency',
    descriptionTr: 'Kabak çekirdeği, kırmızı et ve kurubaklagil iyi çinko kaynaklarıdır. Bağışıklığı güçlendirir.',
    descriptionEn: 'Pumpkin seeds, red meat and legumes are good zinc sources. Strengthens immunity.',
    category: 'vitamin', icon: Icons.shield, color: Colors.tealAccent,
  ),
  SuggestionItem(
    titleTr: 'Folat tüketimini artır',
    titleEn: 'Increase folate consumption',
    descriptionTr: 'Brokoli, ıspanak ve mercimek bol folat içerir. Hücre yenilenmesi için gereklidir.',
    descriptionEn: 'Broccoli, spinach and lentils are rich in folate. Required for cell renewal.',
    category: 'vitamin', icon: Icons.eco, color: Colors.lightGreen,
  ),
  SuggestionItem(
    titleTr: 'Potasyum alımını artır',
    titleEn: 'Increase potassium intake',
    descriptionTr: 'Muz, patates ve fasulye potasyum açısından zengindir. Kan basıncını dengelemeye yardımcı olur.',
    descriptionEn: 'Bananas, potatoes and beans are rich in potassium. Helps balance blood pressure.',
    category: 'vitamin', icon: Icons.favorite, color: Colors.redAccent,
  ),
  // Genel beslenme
  SuggestionItem(
    titleTr: 'Renkli tabak oluştur',
    titleEn: 'Create a colorful plate',
    descriptionTr: 'Her öğüne en az 3 farklı renkte sebze ekle. Renk çeşitliliği antioksidan zenginliğini gösterir.',
    descriptionEn: 'Add at least 3 different colored vegetables to each meal. Color variety indicates antioxidant richness.',
    category: 'general', icon: Icons.palette, color: Colors.deepOrange,
  ),
  SuggestionItem(
    titleTr: 'Probiyotik tüket',
    titleEn: 'Consume probiotics',
    descriptionTr: 'Her gün bir kase kefir veya ev yapımı yoğurt ye. Bağırsak florasını destekler.',
    descriptionEn: 'Eat a bowl of kefir or homemade yogurt daily. Supports gut flora.',
    category: 'general', icon: Icons.science, color: Colors.indigo,
  ),
  SuggestionItem(
    titleTr: 'Tuzu azalt',
    titleEn: 'Reduce salt',
    descriptionTr: 'Yemekler pişerken az tuz kullan, sofraya tuzluk koyma. Baharatlarla lezzet kat.',
    descriptionEn: 'Use less salt when cooking, don\'t put a salt shaker on the table. Add flavor with spices.',
    category: 'general', icon: Icons.soup_kitchen, color: Colors.brown,
  ),
  SuggestionItem(
    titleTr: 'E vitamini al',
    titleEn: 'Get vitamin E',
    descriptionTr: 'Badem, avokado ve zeytinyağı iyi E vitamini kaynaklarıdır. Cildi ve bağışıklığı korur.',
    descriptionEn: 'Almonds, avocado and olive oil are good vitamin E sources. Protects skin and immunity.',
    category: 'vitamin', icon: Icons.spa, color: Colors.orangeAccent,
  ),
  // Davranış ve alışkanlık
  SuggestionItem(
    titleTr: 'Yemek günlüğü tut',
    titleEn: 'Keep a food diary',
    descriptionTr: 'Her gün ne yediğini kaydetmek bilinç düzeyini artırır. Araştırmalar kilo kaybını %50 hızlandırdığını gösterir.',
    descriptionEn: 'Recording what you eat daily increases awareness. Research shows it speeds up weight loss by 50%.',
    category: 'habit', icon: Icons.book_outlined, color: Colors.purple,
  ),
  SuggestionItem(
    titleTr: 'Uyku ve beslenme bağlantısı',
    titleEn: 'Sleep and nutrition connection',
    descriptionTr: 'Günde 7-8 saat uyumak ghrelin/leptin dengesini korur. Az uyku aşırı yemeye yol açar.',
    descriptionEn: '7-8 hours of sleep maintains ghrelin/leptin balance. Too little sleep leads to overeating.',
    category: 'habit', icon: Icons.bedtime, color: Colors.deepPurple,
  ),
  SuggestionItem(
    titleTr: 'Stres yönetimi',
    titleEn: 'Stress management',
    descriptionTr: 'Stres kortizol artırır ve yağ depolamayı tetikler. Nefes egzersizleri veya meditasyon dene.',
    descriptionEn: 'Stress increases cortisol and triggers fat storage. Try breathing exercises or meditation.',
    category: 'habit', icon: Icons.self_improvement, color: Colors.teal,
  ),
  SuggestionItem(
    titleTr: 'Tabak boyutunu küçült',
    titleEn: 'Reduce plate size',
    descriptionTr: 'Küçük tabak kullanmak psikolojik olarak daha dolu hissettirir. Porsiyon kontrolünde etkili.',
    descriptionEn: 'Using a smaller plate makes you feel psychologically fuller. Effective for portion control.',
    category: 'habit', icon: Icons.crop_din, color: Colors.grey,
  ),
  SuggestionItem(
    titleTr: 'Alışveriş listesi yap',
    titleEn: 'Make a shopping list',
    descriptionTr: 'Planlı alışveriş işlenmiş gıda satın alma riskini azaltır. Sağlıklı seçim için aç karnına gitme.',
    descriptionEn: 'Planned shopping reduces the risk of buying processed food. Don\'t go hungry for healthy choices.',
    category: 'habit', icon: Icons.shopping_cart, color: Colors.green,
  ),
  SuggestionItem(
    titleTr: 'Türk mutfağından sağlıklı seçimler',
    titleEn: 'Healthy choices from Turkish cuisine',
    descriptionTr: 'Zeytinyağlılar, çorbalar ve taze salata Türk mutfağının en sağlıklı seçenekleridir. Kızartmalı seçenekleri azalt.',
    descriptionEn: 'Olive oil dishes, soups and fresh salads are the healthiest options in Turkish cuisine. Reduce fried options.',
    category: 'general', icon: Icons.restaurant_menu, color: Colors.redAccent,
  ),
  SuggestionItem(
    titleTr: 'Mevsimsel sebze tüket',
    titleEn: 'Consume seasonal vegetables',
    descriptionTr: 'Mevsimsel sebzeler daha taze ve besleyicidir. Kış için lahana, yaz için domates vazgeçilmezdir.',
    descriptionEn: 'Seasonal vegetables are fresher and more nutritious. Cabbage for winter, tomatoes for summer are essential.',
    category: 'general', icon: Icons.eco, color: Colors.lightGreen,
  ),
];

// ─── Antrenman Havuzu ─────────────────────────────────────────────────────────

const List<WorkoutItem> _workouts = [
  // Kardiyovasküler
  WorkoutItem(
    nameTr: 'Tempolu Yürüyüş',
    nameEn: 'Brisk Walking',
    icon: Icons.directions_walk,
    durationTr: '30 dakika',
    durationEn: '30 minutes',
    calories: 150,
    difficulty: WorkoutDifficulty.easy,
    category: WorkoutCategory.cardio,
    durationSeconds: 1800,
  ),
  WorkoutItem(
    nameTr: 'Koşu',
    nameEn: 'Running',
    icon: Icons.directions_run,
    durationTr: '20 dakika',
    durationEn: '20 minutes',
    calories: 220,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.cardio,
    durationSeconds: 1200,
  ),
  WorkoutItem(
    nameTr: 'Bisiklet',
    nameEn: 'Cycling',
    icon: Icons.directions_bike,
    durationTr: '30 dakika',
    durationEn: '30 minutes',
    calories: 200,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.cardio,
    durationSeconds: 1800,
  ),
  WorkoutItem(
    nameTr: 'Yüzme',
    nameEn: 'Swimming',
    icon: Icons.pool,
    durationTr: '30 dakika',
    durationEn: '30 minutes',
    calories: 260,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.cardio,
    durationSeconds: 1800,
  ),
  WorkoutItem(
    nameTr: 'Atlama İpi',
    nameEn: 'Jump Rope',
    icon: Icons.sports_gymnastics,
    durationTr: '15 dakika',
    durationEn: '15 minutes',
    calories: 180,
    difficulty: WorkoutDifficulty.hard,
    category: WorkoutCategory.cardio,
    durationSeconds: 900,
  ),
  // Güç
  WorkoutItem(
    nameTr: 'Şınav',
    nameEn: 'Push-ups',
    icon: Icons.fitness_center,
    durationTr: '3×15 tekrar',
    durationEn: '3×15 reps',
    calories: 60,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.strength,
    durationSeconds: 300,
  ),
  WorkoutItem(
    nameTr: 'Mekik',
    nameEn: 'Sit-ups',
    icon: Icons.accessibility_new,
    durationTr: '3×20 tekrar',
    durationEn: '3×20 reps',
    calories: 50,
    difficulty: WorkoutDifficulty.easy,
    category: WorkoutCategory.strength,
    durationSeconds: 300,
  ),
  WorkoutItem(
    nameTr: 'Squat',
    nameEn: 'Squats',
    icon: Icons.sports_martial_arts,
    durationTr: '3×15 tekrar',
    durationEn: '3×15 reps',
    calories: 70,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.strength,
    durationSeconds: 360,
  ),
  WorkoutItem(
    nameTr: 'Plank',
    nameEn: 'Plank',
    icon: Icons.square,
    durationTr: '3×45 saniye',
    durationEn: '3×45 seconds',
    calories: 30,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.strength,
    durationSeconds: 135,
  ),
  WorkoutItem(
    nameTr: 'Dumbbell Kıvırma',
    nameEn: 'Dumbbell Curl',
    icon: Icons.sports,
    durationTr: '3×12 tekrar',
    durationEn: '3×12 reps',
    calories: 45,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.strength,
    durationSeconds: 300,
  ),
  WorkoutItem(
    nameTr: 'Burpee',
    nameEn: 'Burpees',
    icon: Icons.height,
    durationTr: '3×10 tekrar',
    durationEn: '3×10 reps',
    calories: 100,
    difficulty: WorkoutDifficulty.hard,
    category: WorkoutCategory.strength,
    durationSeconds: 300,
  ),
  // Esneklik
  WorkoutItem(
    nameTr: 'Sabah Yogası',
    nameEn: 'Morning Yoga',
    icon: Icons.self_improvement,
    durationTr: '20 dakika',
    durationEn: '20 minutes',
    calories: 80,
    difficulty: WorkoutDifficulty.easy,
    category: WorkoutCategory.flexibility,
    durationSeconds: 1200,
  ),
  WorkoutItem(
    nameTr: 'Esneme Hareketleri',
    nameEn: 'Stretching',
    icon: Icons.accessibility,
    durationTr: '15 dakika',
    durationEn: '15 minutes',
    calories: 40,
    difficulty: WorkoutDifficulty.easy,
    category: WorkoutCategory.flexibility,
    durationSeconds: 900,
  ),
  WorkoutItem(
    nameTr: 'Pilates',
    nameEn: 'Pilates',
    icon: Icons.airline_seat_legroom_extra,
    durationTr: '30 dakika',
    durationEn: '30 minutes',
    calories: 120,
    difficulty: WorkoutDifficulty.medium,
    category: WorkoutCategory.flexibility,
    durationSeconds: 1800,
  ),
  WorkoutItem(
    nameTr: 'Akşam Esneme',
    nameEn: 'Evening Stretching',
    icon: Icons.nightlight,
    durationTr: '10 dakika',
    durationEn: '10 minutes',
    calories: 25,
    difficulty: WorkoutDifficulty.easy,
    category: WorkoutCategory.flexibility,
    durationSeconds: 600,
  ),
];

// ─── Ana Ekran ─────────────────────────────────────────────────────────────────

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen>
    with SingleTickerProviderStateMixin {
  static const int _displayCount = 6;

  late final TabController _tabController;
  List<SuggestionItem> _active = [];
  final Set<int> _usedIndices = {};
  int _completedToday = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();
    final count = prefs.getInt('completed_count_$todayKey') ?? 0;

    final random = Random();
    final indices = <int>{};
    while (indices.length < _displayCount.clamp(0, _pool.length)) {
      indices.add(random.nextInt(_pool.length));
    }
    _usedIndices.addAll(indices);

    setState(() {
      _completedToday = count;
      _active = indices.map((i) => _pool[i]).toList();
      _loaded = true;
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  SuggestionItem? _getNextSuggestion() {
    for (int i = 0; i < _pool.length; i++) {
      if (!_usedIndices.contains(i)) {
        _usedIndices.add(i);
        return _pool[i];
      }
    }
    return null;
  }

  Future<void> _completeSuggestion(int index, SuggestionItem item) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();
    final newCount = _completedToday + 1;
    await prefs.setInt('completed_count_$todayKey', newCount);

    final titles = prefs.getStringList('completed_titles_$todayKey') ?? [];
    titles.add(item.titleTr);
    await prefs.setStringList('completed_titles_$todayKey', titles);

    final next = _getNextSuggestion();
    if (mounted) {
      setState(() {
        _completedToday = newCount;
        if (next != null) {
          _active[index] = next;
        } else {
          _active.removeAt(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);

    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('Öneriler')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.isTurkish ? 'Öneriler' : 'Tips'),
            Tab(text: l10n.isTurkish ? 'Eksikler' : 'Deficits'),
            Tab(text: l10n.tr('Antrenman')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuggestionsTab(l10n),
          _ExiklerTab(isTurkish: l10n.isTurkish),
          _WorkoutTab(isTurkish: l10n.isTurkish),
        ],
      ),
    );
  }

  Widget _buildSuggestionsTab(AppLocalizations l10n) {
    final isTurkish = l10n.isTurkish;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCompletionBanner(context, isTurkish),
        const SizedBox(height: 8),
        _buildInfoBanner(context, isTurkish),
        const SizedBox(height: 16),
        ..._active.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(1.0, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _buildSuggestionCard(
              context,
              item,
              index,
              isTurkish: isTurkish,
              key: ValueKey('${item.titleTr}_$index'),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompletionBanner(BuildContext context, bool isTurkish) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Text(
              isTurkish
                  ? 'Bugün $_completedToday öneri tamamlandı'
                  : '$_completedToday tips completed today',
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, bool isTurkish) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isTurkish
                    ? 'Bu öneriler günlük beslenme verileriniz analiz edilerek oluşturulmuştur.'
                    : 'These tips are generated by analyzing your daily nutrition data.',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
    BuildContext context,
    SuggestionItem item,
    int index, {
    Key? key,
    required bool isTurkish,
  }) {
    return _DismissibleSuggestionCard(
      key: key,
      item: item,
      isTurkish: isTurkish,
      onComplete: () => _completeSuggestion(index, item),
    );
  }
}

// ─── Dismissible Suggestion Card ─────────────────────────────────────────────

class _DismissibleSuggestionCard extends StatefulWidget {
  final SuggestionItem item;
  final bool isTurkish;
  final VoidCallback onComplete;

  const _DismissibleSuggestionCard({
    super.key,
    required this.item,
    required this.isTurkish,
    required this.onComplete,
  });

  @override
  State<_DismissibleSuggestionCard> createState() =>
      _DismissibleSuggestionCardState();
}

class _DismissibleSuggestionCardState
    extends State<_DismissibleSuggestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.3, 0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_dismissed) return;
    _dismissed = true;
    if (!MediaQuery.of(context).disableAnimations) {
      await _ctrl.forward();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isTurkish = widget.isTurkish;
    final colorScheme = Theme.of(context).colorScheme;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 2,
          shadowColor: item.color.withOpacity(0.15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title(isTurkish),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description(isTurkish),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CheckButton(onPressed: _handleComplete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CheckButton({required this.onPressed});

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handle,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF4CAF50),
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ─── Eksikler Sekmesi ─────────────────────────────────────────────────────────

class _SupplementItem {
  final String name;
  final IconData icon;
  final String reason;
  final String dose;

  const _SupplementItem({
    required this.name,
    required this.icon,
    required this.reason,
    required this.dose,
  });
}

class _ExiklerTab extends StatelessWidget {
  final bool isTurkish;
  const _ExiklerTab({required this.isTurkish});

  static const _proteinFoods = [
    ['Tavuk göğsü', 0.31],
    ['Ton balığı (konserve)', 0.25],
    ['Yumurta', 0.13],
    ['Süzme yoğurt', 0.10],
    ['Mercimek (pişmiş)', 0.09],
  ];

  static const _carbFoods = [
    ['Yulaf ezmesi', 0.60],
    ['Tam tahıllı ekmek', 0.40],
    ['Pirinç (pişmiş)', 0.28],
    ['Muz', 0.23],
    ['Tatlı patates', 0.20],
  ];

  static const _fatFoods = [
    ['Ceviz', 0.65],
    ['Badem', 0.50],
    ['Avokado', 0.15],
    ['Somon', 0.13],
    ['Zeytinyağı', 1.00],
  ];

  static const _calorieFoods = [
    ['Karışık kuruyemiş', 6.00],
    ['Avokado', 1.60],
    ['Peynir (kaşar)', 3.50],
    ['Muz', 0.89],
    ['Tam yağlı yoğurt', 0.97],
  ];

  String _foodLine(String name, double deficit, double macroPerGram,
      String unit, double maxGrams) {
    final neededGrams = deficit / macroPerGram;
    if (neededGrams > maxGrams) {
      final actualMacro = maxGrams * macroPerGram;
      return '${maxGrams.toStringAsFixed(0)}g $name → +${actualMacro.toStringAsFixed(0)}$unit';
    }
    return '${neededGrams.toStringAsFixed(0)}g $name → +${deficit.toStringAsFixed(0)}$unit';
  }

  Widget _buildDeficitCard(
    BuildContext context, {
    required String title,
    required double deficit,
    required String unit,
    required Color color,
    required List<dynamic> foods,
    required double maxGrams,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.trending_up, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTurkish ? '$title Eksikliği' : '$title Deficit',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isTurkish
                            ? '${deficit.toStringAsFixed(0)}$unit eksik'
                            : '${deficit.toStringAsFixed(0)}$unit missing',
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isTurkish ? 'Tamamlamak için:' : 'To complete:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              foods.length > 3 ? 3 : foods.length,
              (i) {
                final food = foods[i];
                final line = _foodLine(
                  food[0] as String,
                  deficit,
                  food[1] as double,
                  unit,
                  maxGrams,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, color: color, size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(line,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _proteinSupplements = [
    _SupplementItem(
      name: 'Whey Protein',
      icon: Icons.fitness_center,
      reason: 'Günlük protein açığınızı hızlı kapatmak için',
      dose: '1 porsiyon (25-30g) antrenman sonrası',
    ),
    _SupplementItem(
      name: 'Kazein Protein',
      icon: Icons.nightlight_round,
      reason: 'Gece yavaş salınımlı protein desteği',
      dose: '1 porsiyon (25-30g) uyumadan önce',
    ),
    _SupplementItem(
      name: 'Bitkisel Protein',
      icon: Icons.eco,
      reason: 'Bitkisel kaynaklı protein takviyesi',
      dose: '1 porsiyon (25-30g) öğün aralarında',
    ),
  ];

  static const _generalSupplements = [
    _SupplementItem(
      name: 'D3 Vitamini',
      icon: Icons.wb_sunny,
      reason: 'D vitamini eksikliği yorgunluk ve bağışıklık zayıflamasına yol açar',
      dose: 'Günde 1000-2000 IU (doktor önerisine göre)',
    ),
    _SupplementItem(
      name: 'Balık Yağı (Omega-3)',
      icon: Icons.set_meal,
      reason: 'Omega-3 kalp, beyin ve eklem sağlığını destekler',
      dose: 'Günde 1-2g EPA+DHA içeren kapsül',
    ),
    _SupplementItem(
      name: 'Magnezyum Glisinat',
      icon: Icons.bolt,
      reason: 'Magnezyum kas fonksiyonu ve uyku kalitesini artırır',
      dose: 'Günde 200-400mg yatmadan önce',
    ),
    _SupplementItem(
      name: 'B12 Vitamini',
      icon: Icons.electric_bolt,
      reason: 'B12 sinir sistemi ve enerji metabolizması için kritik',
      dose: 'Günde 500-1000mcg (özellikle vejetaryenler)',
    ),
    _SupplementItem(
      name: 'Demir Takviyesi',
      icon: Icons.bloodtype,
      reason: 'Demir eksikliği yorgunluk ve anemi riskini artırır',
      dose: 'Günde 18mg (doktor kontrolünde)',
    ),
    _SupplementItem(
      name: 'Multivitamin',
      icon: Icons.medication,
      reason: 'Genel besin eksikliklerini kapatmak için',
      dose: 'Günde 1 tablet sabah yemeğiyle',
    ),
  ];

  Widget _buildSupplementCard(BuildContext context, _SupplementItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.amber.shade100,
              child:
                  Icon(item.icon, color: Colors.amber.shade800, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(item.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 13, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(item.dose,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.w500,
                                    )),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<NutritionProvider, ProfileProvider>(
      builder: (context, nutritionProvider, profileProvider, _) {
        if (!profileProvider.isProfileComplete) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline,
                      size: 72,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    isTurkish
                        ? 'Eksikleri görmek için\nProfilinizi doldurun.'
                        : 'Fill your profile\nto see deficits.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final nutrition = nutritionProvider.totalNutrition;
        final proteinDeficit =
            (profileProvider.proteinGoal - nutrition.protein)
                .clamp(0.0, double.infinity);
        final carbDeficit =
            (profileProvider.carbGoal - nutrition.carbohydrates)
                .clamp(0.0, double.infinity);
        final fatDeficit =
            (profileProvider.fatGoal - nutrition.fat)
                .clamp(0.0, double.infinity);
        final calorieDeficit =
            (profileProvider.calorieGoal - nutrition.calories)
                .clamp(0.0, double.infinity);

        const proteinThreshold = 5.0;
        const carbThreshold = 10.0;
        const fatThreshold = 3.0;
        const calorieThreshold = 50.0;

        final hasProtein = proteinDeficit > proteinThreshold;
        final hasCarb = carbDeficit > carbThreshold;
        final hasFat = fatDeficit > fatThreshold;
        final hasCalorie = calorieDeficit > calorieThreshold;
        final hasAnyDeficit = hasProtein || hasCarb || hasFat || hasCalorie;

        final supplements = [
          if (hasProtein) ..._proteinSupplements,
          ..._generalSupplements,
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!hasAnyDeficit) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        isTurkish
                            ? 'Bugün tüm hedeflerinize ulaştınız!'
                            : 'You reached all your goals today!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isTurkish
                            ? 'Harika iş çıkardınız, böyle devam edin.'
                            : 'Great job, keep it up!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Text('🥗', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    isTurkish ? 'Gıda Önerileri' : 'Food Suggestions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasProtein)
                _buildDeficitCard(context,
                    title: isTurkish ? 'Protein' : 'Protein',
                    deficit: proteinDeficit,
                    unit: 'g protein',
                    color: Colors.blue,
                    foods: _proteinFoods,
                    maxGrams: 500),
              if (hasCarb)
                _buildDeficitCard(context,
                    title: isTurkish ? 'Karbonhidrat' : 'Carbohydrate',
                    deficit: carbDeficit,
                    unit: isTurkish ? 'g karb.' : 'g carbs',
                    color: Colors.orange,
                    foods: _carbFoods,
                    maxGrams: 500),
              if (hasFat)
                _buildDeficitCard(context,
                    title: isTurkish ? 'Yağ' : 'Fat',
                    deficit: fatDeficit,
                    unit: isTurkish ? 'g yağ' : 'g fat',
                    color: Colors.green,
                    foods: _fatFoods,
                    maxGrams: 200),
              if (hasCalorie)
                _buildDeficitCard(context,
                    title: isTurkish ? 'Kalori' : 'Calorie',
                    deficit: calorieDeficit,
                    unit: 'kcal',
                    color: Colors.red,
                    foods: _calorieFoods,
                    maxGrams: 300),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('💊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  isTurkish ? 'Supplement Önerileri' : 'Supplement Tips',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTurkish
                          ? 'Supplement kullanmadan önce doktorunuza danışın.'
                          : 'Consult your doctor before using supplements.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...supplements.map((s) => _buildSupplementCard(context, s)),
          ],
        );
      },
    );
  }
}

// ─── Antrenman Sekmesi ────────────────────────────────────────────────────────

class _WorkoutTab extends StatefulWidget {
  final bool isTurkish;
  const _WorkoutTab({required this.isTurkish});

  @override
  State<_WorkoutTab> createState() => _WorkoutTabState();
}


class _WorkoutTabState extends State<_WorkoutTab> {
  WorkoutCategory? _selectedCategory;
  WorkoutItem? _activeWorkout;
  int _secondsRemaining = 0;
  bool _isFinished = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startWorkout(WorkoutItem workout) {
    _timer?.cancel();
    setState(() {
      _activeWorkout = workout;
      _secondsRemaining = workout.durationSeconds;
      _isFinished = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _isFinished = true;
          t.cancel();
        }
      });
    });
  }

  void _stopWorkout() {
    _timer?.cancel();
    setState(() {
      _activeWorkout = null;
      _isFinished = false;
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _difficultyColor(WorkoutDifficulty d) {
    switch (d) {
      case WorkoutDifficulty.easy:
        return Colors.green;
      case WorkoutDifficulty.medium:
        return Colors.orange;
      case WorkoutDifficulty.hard:
        return Colors.red;
    }
  }

  Color _categoryColor(WorkoutCategory c) {
    switch (c) {
      case WorkoutCategory.cardio:
        return const Color(0xFFE53935);
      case WorkoutCategory.strength:
        return const Color(0xFF1565C0);
      case WorkoutCategory.flexibility:
        return const Color(0xFF00897B);
    }
  }

  IconData _categoryIcon(WorkoutCategory c) {
    switch (c) {
      case WorkoutCategory.cardio:
        return Icons.directions_run;
      case WorkoutCategory.strength:
        return Icons.fitness_center;
      case WorkoutCategory.flexibility:
        return Icons.self_improvement;
    }
  }

  String _difficultyLabel(WorkoutDifficulty d, bool isTurkish) {
    switch (d) {
      case WorkoutDifficulty.easy:
        return isTurkish ? 'Kolay' : 'Easy';
      case WorkoutDifficulty.medium:
        return isTurkish ? 'Orta' : 'Medium';
      case WorkoutDifficulty.hard:
        return isTurkish ? 'Zor' : 'Hard';
    }
  }

  String _categoryLabel(WorkoutCategory c, bool isTurkish) {
    switch (c) {
      case WorkoutCategory.cardio:
        return isTurkish ? 'Kardiyovasküler' : 'Cardio';
      case WorkoutCategory.strength:
        return isTurkish ? 'Güç' : 'Strength';
      case WorkoutCategory.flexibility:
        return isTurkish ? 'Esneklik' : 'Flexibility';
    }
  }

  void _showAddExerciseDialog(BuildContext context, WorkoutItem workout) {
    final durationCtrl = TextEditingController(
      text: (workout.durationSeconds ~/ 60).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu antrenmanı bugüne ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(workout.name(widget.isTurkish)),
            const SizedBox(height: 16),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Süre (dakika)',
                border: OutlineInputBorder(),
                suffixText: 'dk',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(durationCtrl.text) ??
                  (workout.durationSeconds ~/ 60);
              final burnedCalories = workout.calories *
                  minutes /
                  (workout.durationSeconds ~/ 60);
              final entry = ExerciseEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: workout.name(widget.isTurkish),
                durationMinutes: minutes,
                burnedCalories: burnedCalories,
                timestamp: DateTime.now(),
              );
              context.read<NutritionProvider>().addExercise(entry);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${entry.name} eklendi (${burnedCalories.toStringAsFixed(0)} kcal)'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTurkish = widget.isTurkish;
    final colorScheme = Theme.of(context).colorScheme;

    final filtered = _selectedCategory == null
        ? _workouts
        : _workouts.where((w) => w.category == _selectedCategory).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active workout timer
        if (_activeWorkout != null) ...[
          Card(
            color: _isFinished
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _activeWorkout!.name(isTurkish),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_isFinished) ...[
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      isTurkish
                          ? 'Tebrikler! ~${_activeWorkout!.calories} kalori yaktın! 🔥'
                          : 'Congrats! ~${_activeWorkout!.calories} calories burned! 🔥',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _stopWorkout,
                      icon: const Icon(Icons.check),
                      label: Text(isTurkish ? 'Tamam' : 'Done'),
                    ),
                  ] else ...[
                    Text(
                      _formatTime(_secondsRemaining),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 1 -
                          (_secondsRemaining / _activeWorkout!.durationSeconds),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _stopWorkout,
                      icon: const Icon(Icons.stop),
                      label: Text(isTurkish ? 'Durdur' : 'Stop'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(isTurkish ? 'Tümü' : 'All'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 8),
              ...WorkoutCategory.values.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_categoryLabel(c, isTurkish)),
                      selected: _selectedCategory == c,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = c),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Workout cards with colored header bands
        ...filtered.map((workout) {
          final catColor = _categoryColor(workout.category);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 2,
            shadowColor: catColor.withOpacity(0.15),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // Colored category header band
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  color: catColor,
                  child: Row(
                    children: [
                      Icon(_categoryIcon(workout.category),
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _categoryLabel(workout.category, isTurkish)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _difficultyLabel(workout.difficulty, isTurkish),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card body
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(workout.icon, color: catColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.name(isTurkish),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 13,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  workout.duration(isTurkish),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 10),
                                const Text('🔥',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 3),
                                Text(
                                  '~${workout.calories} kcal',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          FilledButton.tonal(
                            onPressed: _activeWorkout == null
                                ? () => _startWorkout(workout)
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(isTurkish ? 'Başla' : 'Start',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () =>
                                _showAddExerciseDialog(context, workout),
                            child: Icon(Icons.add_circle_outline,
                                color: colorScheme.primary, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
