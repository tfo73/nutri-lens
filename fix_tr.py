import re

with open('public/tr/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

translations = [
    ('Nutrition that fights<br>cellular aging', 'Hücresel yaşlanmaya karşı<br>savaşan beslenme'),
    ('Every meal is an opportunity. LensEat maps your intake to the latest longevity research — from telomere health to mitochondrial function.', 'Her öğün bir fırsattır. LensEat, beslenmenizi telomer sağlığından mitokondriyal fonksiyona kadar en son longevity araştırmalarıyla eşleştirir.'),
    ('Circadian Rhythm Optimization', 'Sirkadiyen Ritim Optimizasyonu'),
    ('Time your meals to your biological clock. LensEat syncs your eating window with your sleep-wake cycle to maximize metabolic efficiency.', 'Öğünlerinizi biyolojik saatinize göre zamanlayın. LensEat, metabolik verimliliği en üst düzeye çıkarmak için yeme pencerenizi uyku-uyanıklık döngünüzle senkronize eder.'),
    ('Autophagy & Cellular Renewal', 'Otofaji ve Hücresel Yenilenme'),
    ('Track fasting windows that trigger autophagy — your body\'s natural cellular cleaning process linked to reduced disease risk and extended healthspan.', 'Otofajiyi tetikleyen oruç pencerelerini takip edin — vücudunuzun hastalık riskini azaltan ve sağlıklı yaşam süresini uzatan doğal hücresel temizlik sürecidir.'),
    ('Anti-Inflammatory Scoring', 'Anti-Enflamatuar Skorlama'),
    ('Biological Age vs. Chronological Age', 'Biyolojik Yaş vs. Kronolojik Yaş'),
    ('>Chronological<', '>Kronolojik<'),
    ('Biological (with LensEat)', 'Biyolojik (LensEat ile)'),
    ('>Inflammation<', '>Enflamasyon<'),
    ('>Telomere<', '>Telomer<'),
    ('>Gut Health<', '>Bağırsak Sağlığı<'),
    ('>Mitochondria<', '>Mitokondri<')
]

for eng, tr in translations:
    html = html.replace(eng, tr)

# Fix the missing div
old_divs = """        </div>
      </div>
    </div>
    </div>
  </div>
</section>"""
new_divs = """        </div>
      </div>
    </div>
    </div>
  </div>
  </div>
</section>"""

html = html.replace(old_divs, new_divs)

with open('public/tr/index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Fixed Turkish text and div structure!")
