class EnRecipe {
  final String ad;
  final String aciklama;
  final List<String> etiketler;
  final List<String> diyetler;
  final List<String> malzemeler;
  final List<String> adimlar;

  const EnRecipe({
    required this.ad,
    required this.aciklama,
    required this.etiketler,
    required this.diyetler,
    required this.malzemeler,
    required this.adimlar,
  });
}

const enRecipes = <String, EnRecipe>{
  'Gecelik Yulaf': EnRecipe(
    ad: 'Overnight Oats',
    aciklama: 'Creamy oats with fruit and chia seeds',
    etiketler: ['HIGH FIBER', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['½ cup oats', '1 cup almond milk', '1 tbsp chia seeds', 'Fresh fruits', '1 tsp honey'],
    adimlar: [
      'Mix oats, milk and chia in a jar.',
      'Close the lid and keep in the fridge overnight.',
      'Serve in the morning topped with fruits and honey.'
    ],
  ),
  'Ispanaklı Omlet': EnRecipe(
    ad: 'Spinach Omelet',
    aciklama: 'Omelet with fresh spinach and feta cheese',
    etiketler: ['HIGH PROTEIN', 'LOW CARB'],
    diyetler: ['vegetarian', 'keto', 'gluten-free'],
    malzemeler: ['2 eggs', '1 handful of spinach', '30g feta cheese', '1 tsp olive oil'],
    adimlar: [
      'Sauté spinach lightly in olive oil.',
      'Whisk eggs and pour over the spinach.',
      'Add cheese and cook on low heat.'
    ],
  ),
  'Yunan Yoğurdu Parfesi': EnRecipe(
    ad: 'Greek Yogurt Parfait',
    aciklama: 'Parfait layered with granola and honey',
    etiketler: ['HIGH PROTEIN'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['1 bowl strained yogurt', '3 tbsp granola', 'Blueberries', '1 tsp honey'],
    adimlar: [
      'Place yogurt in a bowl.',
      'Top with granola and berries.',
      'Drizzle honey and serve.'
    ],
  ),
  'Avokadolu Tost': EnRecipe(
    ad: 'Avocado Toast',
    aciklama: 'Avocado on sourdough bread',
    etiketler: ['HEALTHY FAT', 'HIGH PROTEIN'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['1 slice sourdough bread', 'Half avocado', '1 boiled egg', 'Black cumin seeds'],
    adimlar: [
      'Toast the bread.',
      'Mash avocado on top and squeeze lemon juice.',
      'Slice egg and place on top.'
    ],
  ),
  'Muzlu Smoothie Bowl': EnRecipe(
    ad: 'Banana Smoothie Bowl',
    aciklama: 'Energy filled breakfast bowl',
    etiketler: ['ENERGY', 'POTASSIUM'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Banana', 'Blueberries', 'Coconut milk'],
    adimlar: [
      'Blend banana and milk.',
      'Decorate with fruits.'
    ],
  ),
  'Chia Puding': EnRecipe(
    ad: 'Chia Pudding',
    aciklama: 'With fruit and coconut',
    etiketler: ['LIGHT', 'FIBER'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['3 tbsp chia seeds', '1 cup coconut milk', 'Fruit'],
    adimlar: [
      'Mix chia and milk, keep in fridge.',
      'Once thickened, decorate with fruits.'
    ],
  ),
  'Tam Buğdaylı Pankek': EnRecipe(
    ad: 'Whole Wheat Pancake',
    aciklama: 'Fiber rich and filling pancake',
    etiketler: ['FIBER', 'ENERGY'],
    diyetler: ['vegetarian'],
    malzemeler: ['1 cup whole wheat flour', '1 egg', '1 cup milk', '1 tsp baking powder', 'Strawberries or banana'],
    adimlar: [
      'Mix flour, egg and milk.',
      'Cook both sides on low heat.',
      'Serve with fruits.'
    ],
  ),
  'Fıstık Ezmeli Muz Tost': EnRecipe(
    ad: 'Peanut Butter Banana Toast',
    aciklama: 'Protein and potassium filled breakfast',
    etiketler: ['ENERGY', 'PROTEIN'],
    diyetler: ['vegan', 'vegetarian'],
    malzemeler: ['2 slices bread', '2 tbsp peanut butter', '1 banana', 'Honey'],
    adimlar: [
      'Toast the bread.',
      'Spread peanut butter.',
      'Place sliced banana on top, drizzle honey.'
    ],
  ),
  'Sebzeli Yumurta Haşlama': EnRecipe(
    ad: 'Boiled Egg with Vegetables',
    aciklama: 'Low calorie filling breakfast',
    etiketler: ['LOW CALORIE', 'PROTEIN'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['2 eggs', '1 tomato', '½ pepper', 'Parsley', 'Olive oil'],
    adimlar: [
      'Chop vegetables finely.',
      'Sauté vegetables in olive oil.',
      'Crack eggs on top and cook.'
    ],
  ),
  'Yeşil Smoothie': EnRecipe(
    ad: 'Green Smoothie',
    aciklama: 'Detox and energy boosting drink',
    etiketler: ['DETOX', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 handful spinach', '1 banana', '½ apple', '1 cup water', '1 tsp ginger'],
    adimlar: [
      'Put all ingredients in blender.',
      'Blend until smooth.',
      'Consume immediately.'
    ],
  ),
  'Izgara Tavuklu Kinoa': EnRecipe(
    ad: 'Grilled Chicken Quinoa',
    aciklama: 'Protein rich post workout plate',
    etiketler: ['HIGH PROTEIN', 'RECOVERY'],
    diyetler: ['gluten-free'],
    malzemeler: ['150g chicken breast', '½ cup quinoa', 'Broccoli', 'Olive oil'],
    adimlar: [
      'Boil the quinoa.',
      'Grill the chicken.',
      'Serve with steamed broccoli.'
    ],
  ),
  'Mercimek Çorbası': EnRecipe(
    ad: 'Lentil Soup',
    aciklama: 'Warm soup rich in iron',
    etiketler: ['HIGH IRON', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 cup red lentils', '1 onion', '1 carrot', 'Turmeric'],
    adimlar: [
      'Sauté vegetables.',
      'Add lentils and water.',
      'Blend when cooked.'
    ],
  ),
  'Ton Balıklı Salata': EnRecipe(
    ad: 'Tuna Salad',
    aciklama: 'Quick and protein rich lunch',
    etiketler: ['HIGH PROTEIN', 'OMEGA-3'],
    diyetler: ['keto', 'gluten-free'],
    malzemeler: ['Tuna', 'Seasonal greens', 'Corn', 'Lemon'],
    adimlar: [
      'Chop greens, add tuna.'
    ],
  ),
  'Kinoalı Akdeniz Salatası': EnRecipe(
    ad: 'Mediterranean Quinoa Salad',
    aciklama: 'Refreshing and filling',
    etiketler: ['VEGAN', 'LIGHT'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Quinoa', 'Tomato', 'Cucumber', 'Olive oil'],
    adimlar: [
      'Mix boiled quinoa with chopped vegetables.'
    ],
  ),
  'Fırın Falafel': EnRecipe(
    ad: 'Baked Falafel',
    aciklama: 'Baked oil free crispy falafel balls',
    etiketler: ['VEGAN', 'HIGH FIBER'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Chickpeas', 'Parsley', 'Garlic', 'Spices'],
    adimlar: [
      'Process ingredients in food processor.',
      'Shape into balls and bake at 200°C for 25 minutes.'
    ],
  ),
  'Tofu Sote': EnRecipe(
    ad: 'Tofu Stir-Fry',
    aciklama: 'Crispy tofu with vegetables',
    etiketler: ['VEGAN', 'PROTEIN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['200g firm tofu', 'Pepper', 'Zucchini', 'Soy sauce'],
    adimlar: [
      'Dice and fry tofu.',
      'Add vegetables and sauté.',
      'Season with soy sauce.'
    ],
  ),
  'Karabuğday Pilavı': EnRecipe(
    ad: 'Buckwheat Pilaf',
    aciklama: 'Gluten free healthy carb',
    etiketler: ['HIGH FIBER', 'GLUTEN FREE'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Buckwheat', 'Onion', 'Mushroom', 'Olive oil'],
    adimlar: [
      'Boil buckwheat.',
      'Sauté onion and mushroom in olive oil.',
      'Mix and serve.'
    ],
  ),
  'Tavuklu Wrap': EnRecipe(
    ad: 'Chicken Wrap',
    aciklama: 'Protein wrapped in fiber tortilla',
    etiketler: ['HIGH PROTEIN', 'PRACTICAL'],
    diyetler: ['gluten-free'],
    malzemeler: ['1 whole wheat tortilla', '120g chicken breast', 'Lettuce', 'Tomato', 'Yogurt sauce'],
    adimlar: [
      'Grill chicken with spices.',
      'Place all ingredients on tortilla.',
      'Wrap tightly and serve.'
    ],
  ),
  'Nohutlu Ispanaklı Yemek': EnRecipe(
    ad: 'Chickpea Spinach Stew',
    aciklama: 'Hot stew filled with iron and protein',
    etiketler: ['HIGH IRON', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 can chickpeas', '2 handfuls spinach', '1 onion', 'Garlic', 'Turmeric', 'Tomato'],
    adimlar: [
      'Sauté onion, add garlic.',
      'Add tomatoes and spices and cook.',
      'Add chickpeas and spinach, cook for 10 more minutes.'
    ],
  ),
  'Tam Buğday Makarna': EnRecipe(
    ad: 'Whole Wheat Pasta',
    aciklama: 'Healthy pasta with tomato sauce',
    etiketler: ['HIGH FIBER', 'ENERGY'],
    diyetler: ['vegan', 'vegetarian'],
    malzemeler: ['Whole wheat pasta', 'Tomato sauce', 'Garlic', 'Basil', 'Olive oil'],
    adimlar: [
      'Cook pasta al dente.',
      'Sauté garlic in olive oil, add tomato sauce.',
      'Mix with pasta and serve.'
    ],
  ),
  'Sebzeli Kuskus': EnRecipe(
    ad: 'Vegetable Couscous',
    aciklama: 'Mediterranean style light couscous plate',
    etiketler: ['VEGAN', 'LIGHT'],
    diyetler: ['vegan', 'vegetarian'],
    malzemeler: ['1 cup couscous', 'Zucchini', 'Pepper', 'Tomato', 'Olive oil', 'Mint'],
    adimlar: [
      'Soak couscous in hot water.',
      'Sauté vegetables in olive oil.',
      'Mix couscous with vegetables, add mint.'
    ],
  ),
  'Somon Izgara': EnRecipe(
    ad: 'Grilled Salmon',
    aciklama: 'Omega-3 bomb dinner',
    etiketler: ['OMEGA-3', 'HIGH PROTEIN'],
    diyetler: ['gluten-free', 'carnivore'],
    malzemeler: ['1 slice salmon', 'Asparagus', 'Lemon', 'Rosemary'],
    adimlar: [
      'Season salmon.',
      'Place salmon and asparagus on baking sheet.',
      'Bake at 200°C for 20 minutes.'
    ],
  ),
  'Biftek ve Kuşkonmaz': EnRecipe(
    ad: 'Steak and Asparagus',
    aciklama: 'Perfectly cooked steak',
    etiketler: ['HIGH PROTEIN', 'LOW CARB'],
    diyetler: ['keto', 'gluten-free', 'carnivore'],
    malzemeler: ['200g steak', 'Asparagus', 'Butter', 'Garlic'],
    adimlar: [
      'Heat pan well.',
      'Cook steak 4-5 minutes on both sides.',
      'Add butter and garlic in final minute to baste.'
    ],
  ),
  'Fırın Sebze Dizmesi': EnRecipe(
    ad: 'Baked Vegetable Medley',
    aciklama: 'Light and healthy vegetable plate',
    etiketler: ['LOW CALORIE', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Eggplant', 'Zucchini', 'Tomato', 'Olive oil'],
    adimlar: [
      'Slice and bake vegetables.'
    ],
  ),
  'Sebzeli Tavuk Sote': EnRecipe(
    ad: 'Chicken Vegetable Stir-Fry',
    aciklama: 'Chicken breast with colorful peppers',
    etiketler: ['LOW CALORIE', 'HIGH PROTEIN'],
    diyetler: ['keto', 'gluten-free'],
    malzemeler: ['Chicken', 'Pepper', 'Onion', 'Spices'],
    adimlar: [
      'Sauté chicken.',
      'Add vegetables and cook.'
    ],
  ),
  'Hindi Köfte': EnRecipe(
    ad: 'Turkey Meatballs',
    aciklama: 'Light and high protein meatballs',
    etiketler: ['HIGH PROTEIN', 'LOW FAT'],
    diyetler: ['gluten-free'],
    malzemeler: ['300g ground turkey', 'Onion', 'Parsley', 'Egg', 'Spices'],
    adimlar: [
      'Knead all ingredients.',
      'Shape into meatballs.',
      'Grill or bake.'
    ],
  ),
  'Balık Tava': EnRecipe(
    ad: 'Pan-Seared Fish',
    aciklama: 'Crispy fish with olive oil',
    etiketler: ['OMEGA-3', 'PROTEIN'],
    diyetler: ['gluten-free', 'carnivore'],
    malzemeler: ['Seabass or sea bream', 'Lemon', 'Olive oil', 'Fresh herbs'],
    adimlar: [
      'Wash and dry fish.',
      'Marinate with olive oil and lemon.',
      'Cook in pan or bake.'
    ],
  ),
  'Sebzeli Güveç': EnRecipe(
    ad: 'Vegetable Stew',
    aciklama: 'Low calorie nutritious claypot stew',
    etiketler: ['LOW CALORIE', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Eggplant', 'Potato', 'Pepper', 'Tomato', 'Onion', 'Olive oil'],
    adimlar: [
      'Chop vegetables.',
      'Place in claypot or baking dish.',
      'Bake at 180°C for 40 minutes.'
    ],
  ),
  'Fırın Tavuk Baget': EnRecipe(
    ad: 'Baked Chicken Drumsticks',
    aciklama: 'Spicy crispy chicken drumsticks',
    etiketler: ['HIGH PROTEIN', 'LOW CARB'],
    diyetler: ['gluten-free', 'keto', 'carnivore'],
    malzemeler: ['Chicken drumsticks', 'Garlic powder', 'Chili flakes', 'Olive oil', 'Lemon'],
    adimlar: [
      'Rub chicken with spices.',
      'Drizzle olive oil and squeeze lemon.',
      'Bake at 200°C for 35 minutes.'
    ],
  ),
  'Humus Tabağı': EnRecipe(
    ad: 'Hummus Platter',
    aciklama: 'Chickpea hummus with crispy vegetables',
    etiketler: ['VEGAN', 'HIGH FIBER'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 bowl hummus', 'Carrot sticks', 'Cucumber', 'Whole wheat lavash'],
    adimlar: [
      'Slice vegetables.',
      'Place hummus in the center of plate.',
      'Serve with olive oil and chili flakes.'
    ],
  ),
  'Lor Peynirli Salata': EnRecipe(
    ad: 'Cottage Cheese Salad',
    aciklama: 'Muscle friendly light meal',
    etiketler: ['HIGH PROTEIN', 'LOW FAT'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['Cottage cheese', 'Arugula', 'Walnut', 'Pomegranate molasses'],
    adimlar: [
      'Add cottage cheese and walnuts over arugula, drizzle sauce.'
    ],
  ),
  'Fıstık Ezmeli Elma': EnRecipe(
    ad: 'Apple with Peanut Butter',
    aciklama: 'Fiber and healthy fat combined',
    etiketler: ['LIGHT', 'HEALTHY FAT'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 apple', '2 tbsp peanut butter', 'Cinnamon'],
    adimlar: [
      'Slice apple.',
      'Serve with peanut butter for dipping.'
    ],
  ),
  'Karışık Kuruyemiş': EnRecipe(
    ad: 'Mixed Nuts',
    aciklama: 'Healthy fat and mineral source',
    etiketler: ['HEALTHY FAT', 'MINERAL'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Walnuts', 'Almonds', 'Hazelnuts', 'Pumpkin seeds'],
    adimlar: [
      'Mix nuts and serve. 30g serving is recommended.'
    ],
  ),
  'Protein Topu': EnRecipe(
    ad: 'Protein Balls',
    aciklama: 'Chocolate energy ball for post workout',
    etiketler: ['PROTEIN', 'SPORTS'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Oats', 'Peanut butter', 'Cocoa powder', 'Honey', 'Protein powder (optional)'],
    adimlar: [
      'Mix all ingredients.',
      'Shape into balls.',
      'Cool in fridge for 30 minutes.'
    ],
  ),
  'Meyve ve Yoğurt': EnRecipe(
    ad: 'Fruit and Yogurt',
    aciklama: 'Probiotic snack with fresh fruit',
    etiketler: ['PROBIOTIC', 'LOW CALORIE'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['1 bowl Greek yogurt', 'Strawberry', 'Blueberries', 'Banana'],
    adimlar: [
      'Place yogurt in a bowl.',
      'Add fresh fruits on top.',
      'Serve immediately.'
    ],
  ),
  'Peynirli Gözleme': EnRecipe(
    ad: 'Cheese Gözleme',
    aciklama: 'Traditional flatbread with white cheese',
    etiketler: ['TRADITIONAL', 'PROTEIN'],
    diyetler: ['vegetarian'],
    malzemeler: ['2 phyllo sheets', '100g white cheese', 'Parsley', 'Olive oil'],
    adimlar: [
      'Oil phyllo lightly.',
      'Add cheese and parsley, fold.',
      'Cook on non-stick pan until golden brown on both sides.'
    ],
  ),
  'Tarhana Çorbası': EnRecipe(
    ad: 'Tarhana Soup',
    aciklama: 'Traditional breakfast soup with fermented grains',
    etiketler: ['PROBIOTIC', 'TRADITIONAL'],
    diyetler: ['vegetarian'],
    malzemeler: ['4 tbsp tarhana', '3 cups water', 'Butter', 'Chili flakes', 'Mint'],
    adimlar: [
      'Dissolve tarhana in cold water.',
      'Cook on low heat, stirring continuously.',
      'Sauté mint and chili flakes in butter, pour on top.'
    ],
  ),
  'Tahin Pekmez': EnRecipe(
    ad: 'Tahini & Molasses',
    aciklama: 'Traditional and nutritious breakfast duo',
    etiketler: ['ENERGY', 'MINERAL'],
    diyetler: ['vegan', 'vegetarian'],
    malzemeler: ['2 tbsp tahini', '2 tbsp grape molasses', 'Whole wheat bread'],
    adimlar: [
      'Place tahini on plate.',
      'Drizzle molasses on top.',
      'Serve with toast or bread.'
    ],
  ),
  'Bulgur Pilavı': EnRecipe(
    ad: 'Bulgur Pilaf',
    aciklama: 'Bulgur wheat pilaf with vermicelli',
    etiketler: ['HIGH FIBER', 'ENERGY'],
    diyetler: ['vegan', 'vegetarian'],
    malzemeler: ['1 cup bulgur', '1 onion', 'Vermicelli', 'Tomato paste', 'Olive oil'],
    adimlar: [
      'Sauté onion in olive oil.',
      'Add tomato paste and bulgur, sauté.',
      'Add hot water and simmer on low heat.'
    ],
  ),
  'Zeytinyağlı Taze Fasulye': EnRecipe(
    ad: 'Green Beans in Olive Oil',
    aciklama: 'Traditional Turkish green beans stew',
    etiketler: ['VEGAN', 'LOW CALORIE'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['500g green beans', '2 tomatoes', '1 onion', 'Olive oil', 'Sugar'],
    adimlar: [
      'Sauté onion in olive oil.',
      'Add tomatoes and green beans.',
      'Simmer on low heat for 30 minutes, serve cold.'
    ],
  ),
  'Patlıcan Musakka': EnRecipe(
    ad: 'Eggplant Moussaka',
    aciklama: 'Baked eggplant with minced meat',
    etiketler: ['TRADITIONAL', 'HIGH PROTEIN'],
    diyetler: ['gluten-free'],
    malzemeler: ['2 eggplants', '300g minced meat', '1 onion', 'Tomato sauce', 'Olive oil'],
    adimlar: [
      'Slice and salt eggplants, fry lightly.',
      'Sauté meat with onion, add tomato sauce.',
      'Layer eggplants and meat, bake for 35 minutes.'
    ],
  ),
  'Sarımsaklı Karides': EnRecipe(
    ad: 'Garlic Shrimp',
    aciklama: 'Buttery sautéed garlic shrimp',
    etiketler: ['HIGH PROTEIN', 'OMEGA-3'],
    diyetler: ['gluten-free', 'keto', 'carnivore'],
    malzemeler: ['300g shrimp', '3 cloves garlic', 'Butter', 'Lemon', 'Parsley'],
    adimlar: [
      'Sauté garlic in butter.',
      'Add shrimp, once pink squeeze lemon.',
      'Add parsley and serve.'
    ],
  ),
  'Nohut Çorbası': EnRecipe(
    ad: 'Chickpea Soup',
    aciklama: 'Hearty and protein rich hot soup',
    etiketler: ['HIGH FIBER', 'VEGAN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['2 cups boiled chickpeas', '1 onion', 'Turmeric', 'Cumin', 'Olive oil'],
    adimlar: [
      'Sauté onion in olive oil.',
      'Add chickpeas, spices and water.',
      'Simmer until thickened, serve.'
    ],
  ),
  'Levrek Buğulama': EnRecipe(
    ad: 'Steamed Seabass',
    aciklama: 'Steamed seabass with vegetables',
    etiketler: ['OMEGA-3', 'LOW CALORIE'],
    diyetler: ['gluten-free', 'carnivore'],
    malzemeler: ['1 seabass (400g)', 'Olive oil', 'Lemon', 'Carrot', 'Celery', 'Bay leaf'],
    adimlar: [
      'Place seabass and vegetables in pot.',
      'Add lemon juice and olive oil.',
      'Steam for 20 minutes under closed lid.'
    ],
  ),
  'Dana Güveci': EnRecipe(
    ad: 'Beef Stew',
    aciklama: 'Slow cooked beef with vegetables',
    etiketler: ['HIGH PROTEIN', 'TRADITIONAL'],
    diyetler: ['gluten-free', 'carnivore'],
    malzemeler: ['400g beef cubes', 'Potato', 'Carrot', 'Pepper', 'Tomato', 'Onion', 'Olive oil'],
    adimlar: [
      'Sauté beef in olive oil.',
      'Add vegetables and sauté.',
      'Add hot water and cook on low heat for 75 minutes.'
    ],
  ),
  'Zeytinyağlı Enginar': EnRecipe(
    ad: 'Artichokes in Olive Oil',
    aciklama: 'Cold appetizer with olive oil',
    etiketler: ['VEGAN', 'LOW CALORIE'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['4 artichoke hearts', 'Olive oil', 'Lemon', 'Onion', 'Peas', 'Sugar'],
    adimlar: [
      'Keep artichokes in lemon water.',
      'Place onion and peas in pot.',
      'Add olive oil and lemon, cook for 30 minutes, let cool.'
    ],
  ),
  'Taze Meyve Salatası': EnRecipe(
    ad: 'Fresh Fruit Salad',
    aciklama: 'Vitamin bomb colorful fruit salad',
    etiketler: ['LOW CALORIE', 'VITAMIN'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['Strawberry', 'Melon', 'Watermelon', 'Grape', 'Mint', 'Lemon juice'],
    adimlar: [
      'Dice all fruits.',
      'Add lemon juice and mint.',
      'Serve cold.'
    ],
  ),
  'Lor Peyniri ve Domates': EnRecipe(
    ad: 'Cottage Cheese and Tomatoes',
    aciklama: 'Light and protein filled healthy snack',
    etiketler: ['HIGH PROTEIN', 'LOW CALORIE'],
    diyetler: ['vegetarian', 'gluten-free'],
    malzemeler: ['150g cottage cheese', '2 tomatoes', 'Olive oil', 'Thyme', 'Salt'],
    adimlar: [
      'Slice tomatoes.',
      'Arrange with cottage cheese on plate.',
      'Serve with olive oil and thyme.'
    ],
  ),
  'Mercimekli Köfte': EnRecipe(
    ad: 'Lentil Meatballs',
    aciklama: 'Traditional cold lentil meatballs',
    etiketler: ['VEGAN', 'HIGH IRON'],
    diyetler: ['vegan', 'vegetarian', 'gluten-free'],
    malzemeler: ['1 cup red lentils', '½ cup fine bulgur', '1 onion', 'Tomato paste', 'Olive oil', 'Parsley', 'Lemon'],
    adimlar: [
      'Boil lentils, drain water.',
      'Add bulgur, paste and oil, knead.',
      'Shape into balls, serve with parsley and lemon.'
    ],
  ),
};
