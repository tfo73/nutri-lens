import re

with open('public/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Translations map (English -> Turkish)
# Use exact substrings from the HTML.
translations = [
    # TITLE
    ('<title>LensEat — 65+ Nutrient Intelligence for Longevity</title>', '<title>LensEat — Longevity İçin 65+ Besin Zekası</title>'),
    
    # NAV
    ('<li><a href="#features">Features</a></li>', '<li><a href="#features">Özellikler</a></li>'),
    ('<li><a href="#longevity">Longevity</a></li>', '<li><a href="#longevity">Longevity</a></li>'),
    ('<li><a href="#reviews">Reviews</a></li>', '<li><a href="#reviews">İncelemeler</a></li>'),
    ('Get Started', 'İndir'),
    ('>Download<', '>İndir<'),
    
    # HERO
    ('Eat for a<br>', 'Daha <span class="accent-blue">Uzun</span>,<br>'),
    ('<span class="accent-blue">Longer</span>,<br>', ''),
    ('<span class="accent-mint">Healthier</span> Life', 'Daha <span class="accent-mint">Sağlıklı</span><br>Bir Yaşam'),
    ('The only nutrition app that goes beyond calories. Track 65+ micro and macro nutrients, slow cellular aging, and receive AI-powered longevity strategies personalized to your biology.', 'Sadece kalori saymanın ötesine geçen tek beslenme uygulaması. 65\'ten fazla mikro ve makro besini takip edin, hücresel yaşlanmayı yavaşlatın ve biyolojinize özel yapay zeka destekli longevity stratejileri edinin.'),
    ('Download App', 'Uygulamayı İndir'),
    ('Explore Features', 'Özellikleri Keşfet'),
    
    # STATS
    ('Nutrients tracked', 'Takip edilen besin'),
    ('Accuracy rate', 'Doğruluk oranı'),
    ('Meal logging time', 'Öğün kaydetme süresi'),
    
    # LONGEVITY SECTION
    ('HOW IT WORKS', 'NASIL ÇALIŞIR'),
    ('Reverse your biological age with science-backed nutrition', 'Bilim destekli beslenme ile biyolojik yaşınızı geriye alın'),
    ('Stop guessing. LensEat connects your daily meals to your long-term health outcomes, showing you exactly how what you eat impacts your lifespan.', 'Tahmin etmeyi bırakın. LensEat, günlük öğünlerinizi uzun vadeli sağlık sonuçlarınıza bağlayarak, yediğiniz şeylerin yaşam sürenizi nasıl etkilediğini tam olarak gösterir.'),
    
    ('Diet & Inflammation', 'Diyet ve Enflamasyon'),
    ('Every meal receives an inflammation score based on its omega-6:omega-3 ratio, antioxidant density, and glycemic impact. Chronic inflammation is the root of aging.', 'Her öğün, omega-6:omega-3 oranına, antioksidan yoğunluğuna ve glisemik etkisine göre bir enflamasyon skoru alır. Kronik enflamasyon yaşlanmanın temelidir.'),
    ('Cellular Autophagy', 'Hücresel Otofaji'),
    ('Fasting protocols aren\'t just about weight loss. By tracking your fasts alongside your micronutrient intake, we optimize your cellular cleanup cycles.', 'Oruç protokolleri sadece kilo vermekle ilgili değildir. Oruçlarınızı mikro besin alımınızla birlikte takip ederek hücresel temizlik döngülerinizi optimize ediyoruz.'),
    ('Circadian Nutrition', 'Sirkadiyen Beslenme'),
    ('Late meals disrupt your sleep architecture and metabolic recovery. We analyze your meal timings to align with your natural biological clock.', 'Geç öğünler uyku mimarinizi ve metabolik toparlanmanızı bozar. Öğün zamanlarınızı doğal biyolojik saatinizle uyumlu olacak şekilde analiz ediyoruz.'),
    
    # FEATURES
    ('<h2 class="section-title">A complete operating system for your body</h2>', '<h2 class="section-title">Vücudunuz için eksiksiz bir işletim sistemi</h2>'),
    ('<p class="section-subtitle">Everything you need to optimize your health, performance, and lifespan in one beautifully designed app.</p>', '<p class="section-subtitle">Sağlığınızı, performansınızı ve yaşam sürenizi optimize etmek için ihtiyacınız olan her şey tek bir harika tasarımlı uygulamada.</p>'),
    
    # Bento Cards
    ('Micro & Macro Nutrient Tracking', 'Mikro ve Makro Besin Takibi'),
    ('Track exactly what your body needs. Go beyond standard macros and monitor essential vitamins, minerals, and amino acids for peak performance.', 'Vücudunuzun tam olarak neye ihtiyacı olduğunu takip edin. Standart makroların ötesine geçin ve en üst düzey performans için temel vitaminleri, mineralleri ve amino asitleri izleyin.'),
    
    ('Personalized AI Coach', 'Kişiselleştirilmiş Yapay Zeka Koçu'),
    ('Get highly personalized nutrition advice based on your biology, habits, and deficiencies. Your coach adapts as you progress.', 'Biyolojinize, alışkanlıklarınıza ve eksikliklerinize göre tamamen kişiselleştirilmiş beslenme önerileri alın. Koçunuz siz ilerledikçe uyum sağlar.'),
    
    ('Dynamic Calorie Engine', 'Dinamik Kalori Sistemi'),
    ('Real-time balance of consumed vs. burned calories. Automatically adjusts targets by tracking your steps and activity.', 'Alınan ve yakılan kalorilerin gerçek zamanlı dengesi. Adım ve aktivite takibiyle hedefleri otomatik ayarlar.'),
    
    ('7-Type Stool Scale', '7 Farklı Dışkı Skalası (Bristol)'),
    ('Log your digestion health using the Bristol stool scale. Understand how your diet affects your gut microbiome.', 'Bristol dışkı skalasını kullanarak sindirim sağlığınızı kaydedin. Diyetinizin bağırsak mikrobiyomunuzu nasıl etkilediğini anlayın.'),
    
    ('Sleep Quality Tracking', 'Uyku Kalitesi Takibi'),
    ('Analyze your nightly rest and see how your daily nutrition choices directly impact your deep sleep and recovery.', 'Gecelik dinlenmenizi analiz edin ve günlük beslenme tercihlerinizin derin uyku ve toparlanmanızı nasıl etkilediğini görün.'),
    
    ('Smart Hydration Alerts', 'Akıllı Su Takibi ve Uyarı Sistemi'),
    ('Track your daily water intake with dynamic reminders that adapt to your environment, climate, and activity.', 'Günlük su alımınızı, çevrenize ve aktivitenize uyum sağlayan dinamik uyarılarla takip edin.'),
    
    ('Daily Recipes & Meal Pages', 'Günlük Tarifler ve Öğünler'),
    ('Get daily recipes curated to fill your nutrient gaps, organized neatly into dedicated pages for each meal.', 'Besin eksikliklerinizi gidermek için özenle seçilmiş günlük tarifler, her öğüne özel sayfalarda düzenlenmiştir.'),
    
    ('4 Fasting Protocols', '4 Farklı Aralıklı Oruç'),
    ('Choose from 4 intermittent fasting methods. A real-time timer shows your fasting window and autophagy status.', '4 farklı aralıklı oruç yönteminden birini seçin. Gerçek zamanlı sayaç oruç pencerenizi ve otofaji durumunu gösterir.'),
    
    ('Advanced Health Analytics', 'Gelişmiş Sağlık Analizleri'),
    ('Up to 1-month calorie history and 5 different deep-dive analysis options to understand your long-term trends.', '1 aya kadar geçmiş kalori takibi ve uzun vadeli eğilimlerinizi anlamak için 5 farklı derinlemesine analiz seçeneği.'),
    
    ('Mood Tracking', 'Ruh Hali Takibi'),
    ('Log your emotional state throughout the day. Uncover the hidden nutritional patterns behind your mood swings.', 'Gün boyu duygusal durumunuzu kaydedin. Ruh hali değişimlerinizin ardındaki gizli beslenme kalıplarını keşfedin.'),
    
    ('Doctor Export', 'Doktor ile Paylaşma'),
    ('Export your comprehensive health data with one tap. Easily share your full profile with healthcare professionals.', 'Kapsamlı sağlık verilerinizi tek dokunuşla dışa aktarın. Tam profilinizi sağlık uzmanlarıyla kolayca paylaşın.'),
    
    ('Streak System', 'Seri (Streak) Sistemi'),
    ('Stay motivated by building daily habits. Keep your streak alive and watch your long-term health metrics improve.', 'Günlük alışkanlıklar edinerek motive kalın. Serinizi canlı tutun ve uzun vadeli sağlık metriklerinizin iyileşmesini izleyin.'),
    
    # REVIEWS
    ('Used by people who care about their future', 'Geleceğini önemseyen insanlar tarafından kullanılıyor'),
    ('"I\'ve tried every nutrition app. LensEat is the only one that actually tracks what matters. My micronutrient score went from 62% to 94% in three weeks."', '"Neredeyse tüm beslenme uygulamalarını denedim. LensEat gerçekten önemli olanı takip eden tek uygulama. Mikro besin skorum üç haftada %62\'den %94\'e çıktı."'),
    ('"The longevity scores and circadian analysis make this feel like having a personal doctor in my pocket. The AI coach is genuinely smart."', '"Longevity skorları ve sirkadiyen analiz, cebimde kişisel bir doktor varmış gibi hissettiriyor. Yapay zeka koçu gerçekten çok zeki."'),
    ('"Finally an app that links my sleep and digestion directly to what I ate that day. The insights are incredibly actionable."', '"Sonunda uykumu ve sindirimimi o gün yediğim şeylere doğrudan bağlayan bir uygulama. Buradaki içgörüler inanılmaz derecede uygulanabilir."'),
    
    # CTA
    ('Start Your Longevity Journey', 'Longevity Yolculuğunuza Başlayın'),
    ('Free to download. 65+ nutrients. Zero guesswork.', 'Ücretsiz indirin. 65+ besin takibi. Tahminlere yer yok.'),
    
    # FOOTER
    ('Product', 'Ürün'),
    ('Download', 'İndir'),
    ('Pricing', 'Fiyatlandırma'),
    ('Science', 'Bilim'),
    ('Company', 'Şirket'),
    ('About', 'Hakkımızda'),
    ('Blog', 'Blog'),
    ('Contact', 'İletişim'),
    ('Legal', 'Yasal'),
    ('Privacy', 'Gizlilik'),
    ('Terms', 'Şartlar')
]

html_tr = html
for eng, tur in translations:
    html_tr = html_tr.replace(eng, tur)

with open('public/tr/index.html', 'w', encoding='utf-8') as f:
    f.write(html_tr)

print("Translation applied successfully!")
