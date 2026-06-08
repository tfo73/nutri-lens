import os

path = r'c:\\Users\\bora0\\nutri_lens\\lib\\screens\\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# I'll replace the entire functions to be 100% sure.

# 1. Nutrition Score Detail
nutrition_score_detail_start = "void _showNutritionScoreDetail("
# Find where it ends. It currently ends with "class _ScoreSection" after it.
nutrition_score_detail_end_marker = "class _ScoreSection"

# 2. WC History
wc_history_sheet_start = "void _showWcHistorySheet("
# Find where it ends. It currently ends with "void _showMoodPicker" after it.
wc_history_sheet_end_marker = "void _showMoodPicker"

# I'll use a safer approach: regex or finding the specific blocks.

import re

# Replacement for _showNutritionScoreDetail
# I'll take the content from my previous thoughts and ensure it's correct.

new_nutrition_score_detail = """void _showNutritionScoreDetail(
    BuildContext context,
    double score,
    Color scoreColor,
    AppLocalizations l10n,
    NutritionData nutrition,
    NutritionData65? nutrition65,
    ProfileProvider profileProvider,
  ) {
    final pp = profileProvider;
    final profile = pp.activeProfile;
    final n65 = nutrition65;

    double pct(double c, double g) => (c <= 0) ? 0.0 : (g <= 0 ? 1.0 : (c / g).clamp(0.0, 1.0));

    String fmtG(double v, [int d = 1]) => '${v.toStringAsFixed(d)} g';
    String fmtMg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mg';
    String fmtMcg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mcg';

    final items = <Object>[];

    const clrMineral = Color(0xFF26D0CE);
    const clrVitamin = Color(0xFFFF9F0A);
    const clrFat     = Color(0xFF0A84FF);
    const clrAmino   = Color(0xFFBF5AF2);
    const clrMisc    = Color(0xFF8E8E93);

    final showPct = profileProvider.showMicroPercentage;
    String rVal(double v, double g, String u) {
      if (showPct && g > 0) return '%${((v / g) * 100).toStringAsFixed(0)}';
      if (u == 'g') return fmtG(v);
      if (u == 'mg') return fmtMg(v);
      return fmtMcg(v);
    }

    items.add(_ScoreRow('🐓', l10n.isTurkish ? 'Kolesterol' : 'Cholesterol', rVal(n65?.cholesterol ?? 0, 300.0, 'mg'), pct(n65?.cholesterol ?? 0, 300.0), clrMisc));

    items.add(_ScoreSection(l10n.isTurkish ? 'MİNERALLER' : 'MINERALS'));
    final caG = profile?.calciumGoal   ?? 1000.0;
    final feG = profile?.ironGoal      ?? 14.0;
    final mgG = profile?.magnesiumGoal ?? 350.0;
    final znG = profile?.zincGoal      ?? 10.0;
    final kG  = profile?.potassiumGoal ?? 4700.0;
    final naL = profile?.sodiumLimit   ?? 2300.0;
    final seG = profile?.seleniumGoal  ?? 55.0;
    items.add(_ScoreRow('🦴', l10n.isTurkish ? 'Kalsiyum'  : 'Calcium',    rVal(n65?.calcium ?? 0, caG, 'mg'),   pct(n65?.calcium ?? 0, caG),   clrMineral));
    items.add(_ScoreRow('🩸', l10n.isTurkish ? 'Demir'     : 'Iron',       rVal(n65?.iron ?? 0, feG, 'mg'),   pct(n65?.iron ?? 0, feG),   clrMineral));
    items.add(_ScoreRow('⚡', l10n.isTurkish ? 'Magnezyum' : 'Magnesium',  rVal(n65?.magnesium ?? 0, mgG, 'mg'),   pct(n65?.magnesium ?? 0, mgG),   clrMineral));
    items.add(_ScoreRow('🔵', l10n.isTurkish ? 'Fosfor'    : 'Phosphorus', rVal(n65?.phosphorus ?? 0, 700.0, 'mg'), pct(n65?.phosphorus ?? 0, 700.0), clrMineral));
    items.add(_ScoreRow('🫀', l10n.isTurkish ? 'Potasyum'  : 'Potassium',  rVal(n65?.potassium ?? 0, kG, 'mg'),    pct(n65?.potassium ?? 0, kG),    clrMineral));
    items.add(_ScoreRow('🧂', l10n.tr('Sodyum'),                           rVal(n65?.sodium ?? 0, naL, 'mg'),   pct(n65?.sodium ?? 0, naL),   clrMineral));
    items.add(_ScoreRow('🔩', l10n.isTurkish ? 'Çinko'     : 'Zinc',       rVal(n65?.zinc ?? 0, znG, 'mg'),   pct(n65?.zinc ?? 0, znG),   clrMineral));
    items.add(_ScoreRow('🔶', l10n.isTurkish ? 'Bakır'     : 'Copper',     rVal(n65?.copper ?? 0, 0.9, 'mg'),   pct(n65?.copper ?? 0, 0.9),   clrMineral));
    items.add(_ScoreRow('🔘', l10n.isTurkish ? 'Manganez'  : 'Manganese',  rVal(n65?.manganese ?? 0, 2.3, 'mg'),   pct(n65?.manganese ?? 0, 2.3),   clrMineral));
    items.add(_ScoreRow('🌟', l10n.isTurkish ? 'Selenyum'  : 'Selenium',   rVal(n65?.selenium ?? 0, seG, 'mcg'),   pct(n65?.selenium ?? 0, seG),   clrMineral));
    items.add(_ScoreRow('💧', l10n.isTurkish ? 'İyot'    : 'Iodine',     rVal(n65?.iodine ?? 0, 150.0, 'mcg'), pct(n65?.iodine ?? 0, 150.0), clrMineral));
    items.add(_ScoreRow('🔷', l10n.isTurkish ? 'Krom'    : 'Chromium',   rVal(n65?.chromium ?? 0, 35.0, 'mcg'),  pct(n65?.chromium ?? 0, 35.0),  clrMineral));

    items.add(_ScoreSection(l10n.isTurkish ? 'VİTAMİNLER' : 'VITAMINS'));
    final vdG   = profile?.vitaminDGoal  ?? 15.0;
    final vb12G = profile?.vitaminB12Goal ?? 2.4;
    items.add(_ScoreRow('🍊', l10n.isTurkish ? 'C Vitamini'       : 'Vitamin C',    rVal(n65?.vitC ?? 0,       90.0,  'mg'),  pct(n65?.vitC ?? 0,       90.0),  clrVitamin));
    items.add(_ScoreRow('☀️', l10n.isTurkish ? 'D Vitamini'       : 'Vitamin D',    rVal(n65?.vitD_mcg ?? 0,   vdG,   'mcg'), pct(n65?.vitD_mcg ?? 0,   vdG),   clrVitamin));
    items.add(_ScoreRow('🥑', l10n.isTurkish ? 'E Vitamini'       : 'Vitamin E',    rVal(n65?.vitE ?? 0,       15.0,  'mg'),  pct(n65?.vitE ?? 0,       15.0),  clrVitamin));
    items.add(_ScoreRow('🥬', l10n.isTurkish ? 'K Vitamini'       : 'Vitamin K',    rVal(n65?.vitK ?? 0,       120.0, 'mcg'), pct(n65?.vitK ?? 0,       120.0), clrVitamin));
    items.add(_ScoreRow('🥕', l10n.isTurkish ? 'A Vitamini (RAE)' : 'Vitamin A',    rVal(n65?.vitA_RAE ?? 0,   900.0, 'mcg'), pct(n65?.vitA_RAE ?? 0,   900.0), clrVitamin));
    items.add(_ScoreRow('🌾', l10n.isTurkish ? 'B1 (Tiamin)'      : 'B1 (Thiamin)', rVal(n65?.thiamine ?? 0,   1.2,   'mg'),  pct(n65?.thiamine ?? 0,   1.2),   clrVitamin));
    items.add(_ScoreRow('🥛', l10n.isTurkish ? 'B2 (Riboflavin)'  : 'B2',           rVal(n65?.riboflavin ?? 0, 1.3,   'mg'),  pct(n65?.riboflavin ?? 0, 1.3),   clrVitamin));
    items.add(_ScoreRow('🐟', l10n.isTurkish ? 'B3 (Niasin)'      : 'B3 (Niacin)',  rVal(n65?.niacin ?? 0,     16.0,  'mg'),  pct(n65?.niacin ?? 0,     16.0),  clrVitamin));
    items.add(_ScoreRow('🥦', l10n.isTurkish ? 'B5 (Pantotenik)'  : 'B5',           rVal(n65?.pantothenic ?? 0,5.0,   'mg'),  pct(n65?.pantothenic ?? 0,5.0),   clrVitamin));
    items.add(_ScoreRow('🐔', l10n.isTurkish ? 'B6 Vitamini'      : 'Vitamin B6',   rVal(n65?.vitB6 ?? 0,      1.7,   'mg'),  pct(n65?.vitB6 ?? 0,      1.7),   clrVitamin));
    items.add(_ScoreRow('🌿', l10n.isTurkish ? 'Folat'            : 'Folate',       rVal(n65?.folate ?? 0,    400.0, 'mcg'), pct(n65?.folate ?? 0,     400.0), clrVitamin));
    items.add(_ScoreRow('🥩', l10n.isTurkish ? 'B12 Vitamini'     : 'Vitamin B12',  rVal(n65?.vitB12 ?? 0,    vb12G, 'mcg'), pct(n65?.vitB12 ?? 0,     vb12G), clrVitamin));
    items.add(_ScoreRow('🧠', l10n.isTurkish ? 'Kolin'  : 'Choline', rVal(n65?.choline ?? 0, 550.0, 'mg'),   pct(n65?.choline ?? 0, 550.0), clrVitamin));
    items.add(_ScoreRow('💊', 'Biotin',                                rVal(n65?.biotin ?? 0,  30.0, 'mcg'),  pct(n65?.biotin ?? 0,  30.0),  clrVitamin));

    items.add(_ScoreSection(l10n.isTurkish ? 'YAĞ ASİTLERİ' : 'FATTY ACIDS'));
    final o3G = profile?.omega3Goal ?? 1.6;
    final o6G = profile?.omega6Goal ?? 17.0;
    items.add(_ScoreRow('🐟', 'Omega-3',                             rVal(n65?.omega3 ?? 0,  o3G, 'g'),   pct(n65?.omega3 ?? 0,  o3G),  clrFat));
    items.add(_ScoreRow('🌻', 'Omega-6',                             rVal(n65?.omega6 ?? 0,  o6G, 'g'),   pct(n65?.omega6 ?? 0,  o6G),  clrFat));
    items.add(_ScoreRow('🦈', 'EPA',                               rVal(n65?.epa ?? 0,     0.25, 'g'),    pct(n65?.epa ?? 0,     0.25), clrFat));
    items.add(_ScoreRow('🐬', 'DHA',                               rVal(n65?.dha ?? 0,     0.25, 'g'),    pct(n65?.dha ?? 0,     0.25), clrFat));
    items.add(_ScoreRow('🥑', 'ALA',                                 rVal(n65?.ala ?? 0,     1.6, 'g'),     pct(n65?.ala ?? 0,     1.6),  clrFat));
    items.add(_ScoreRow('🍳', l10n.isTurkish ? 'Doymuş Yağ'      : 'Saturated Fat',    rVal(n65?.satFat ?? 0, 20.0, 'g'), pct(n65?.satFat ?? 0, 20.0), clrFat));
    items.add(_ScoreRow('🫒', l10n.isTurkish ? 'Tekli Doymamış'   : 'Monounsaturated',  rVal(n65?.monoFat ?? 0, 25.0, 'g'), pct(n65?.monoFat ?? 0,  25.0),  clrFat));

    items.add(_ScoreSection(l10n.isTurkish ? 'AMİNO ASİTLER' : 'AMINO ACIDS'));
    void aa(String ico, String l, double v, double ref) {
      items.add(_ScoreRow(ico, l, rVal(v, ref, 'g'), pct(v, ref), clrAmino));
    }
    aa('💪', l10n.isTurkish ? 'Lösin'       : 'Leucine',       n65?.leucine ?? 0,       2.7);
    aa('🔗', l10n.isTurkish ? 'Lizin'        : 'Lysine',        n65?.lysine ?? 0,        2.1);
    aa('🏃', l10n.isTurkish ? 'Valin'        : 'Valine',        n65?.valine ?? 0,        1.8);
    aa('⚡', l10n.isTurkish ? 'İzolösin'     : 'Isoleucine',    n65?.isoleucine ?? 0,    1.4);
    aa('🌱', l10n.isTurkish ? 'Treonin'      : 'Threonine',     n65?.threonine ?? 0,     1.0);
    aa('🔸', l10n.isTurkish ? 'Metionin'     : 'Methionine',    n65?.methionine ?? 0,    0.7);
    aa('🔹', l10n.isTurkish ? 'Fenilalanin'  : 'Phenylalanine', n65?.phenylalanine ?? 0, 1.4);
    aa('😴', l10n.isTurkish ? 'Triptofan'    : 'Tryptophan',    n65?.tryptophan ?? 0,    0.28);
    aa('🔬', l10n.isTurkish ? 'Histidin'     : 'Histidine',     n65?.histidine ?? 0,     0.7);
    aa('🧪', l10n.isTurkish ? 'Sistin'       : 'Cystine',       n65?.cystine ?? 0,       0.5);
    aa('🌀', l10n.isTurkish ? 'Tirozin'      : 'Tyrosine',      n65?.tyrosine ?? 0,      1.1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 4,
                              backgroundColor: cs.outlineVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          Text(
                            score.toInt().toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('Beslenme Skoru'),
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${items.whereType<_ScoreRow>().length} ${l10n.isTurkish ? "besin" : "nutrients"}',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item is _ScoreSection) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 6),
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }
                    final r = item as _ScoreRow;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface)),
                              Text(r.value,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: r.pct >= 0.8 ? r.color : cs.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: r.pct,
                              minHeight: 5,
                              color: r.color,
                              backgroundColor: cs.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
"""

new_wc_history_sheet = """  void _showWcHistorySheet(BuildContext context, WellnessProvider wellness) {
    final logs = wellness.today.wcEntries;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bugün hiç girdi yapmadınız')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final hoursWithLogs = <int>{};
        for (final log in logs) {
          hoursWithLogs.add(log.time.hour);
        }
        final sortedHours = hoursWithLogs.toList()..sort((a, b) => b.compareTo(a));

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Giriş Detayları', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: sortedHours.length,
                      itemBuilder: (context, index) {
                        final hour = sortedHours[index];
                        final entries = logs.where((e) => e.time.hour == hour).toList();
                        final isCurrentHour = DateTime.now().hour == hour;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrentHour ? FontWeight.w800 : FontWeight.w600,
                                    color: isCurrentHour ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.2))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: entries.map((log) {
                                  final type = wcStoolTypes.firstWhere((t) => t.value == log.stoolType, 
                                      orElse: () => wcStoolTypes[3]);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: type.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: type.color.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            padding: const EdgeInsets.all(4),
                                            color: type.color.withValues(alpha: 0.1),
                                            child: type.assetPath != null
                                                ? Image.asset(type.assetPath!, fit: BoxFit.contain)
                                                : Center(child: Text(type.emoji, style: const TextStyle(fontSize: 24))),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(type.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                              Text(
                                                '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')} — ${log.stoolType == 0 ? 'Normal' : (log.stoolType < 0 ? 'Kabızlık' : 'İshal')}',
                                                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
"""

# I'll use regex to find the blocks and replace them.

# 1. Nutrition Score Detail
nutrition_pattern = re.compile(r"void _showNutritionScoreDetail\(.*?\}\n(?=class _ScoreSection)", re.DOTALL)
# Wait, my previous view showed line 2233 as } and line 2235 as class _ScoreSection.
# So I'll match everything from "void _showNutritionScoreDetail(" until just before "class _ScoreSection".

# Actually, I'll just use string find and slice.

def replace_function(content, start_marker, end_marker, new_content):
    start_index = content.find(start_marker)
    if start_index == -1:
        return content, False
    end_index = content.find(end_marker, start_index)
    if end_index == -1:
        return content, False
    
    # We want to replace everything from start_index to end_index.
    # Note: end_marker should NOT be included in the replacement.
    
    return content[:start_index] + new_content + "\n" + content[end_index:], True

content, success1 = replace_function(content, "void _showNutritionScoreDetail(", "class _ScoreSection", new_nutrition_score_detail)
content, success2 = replace_function(content, "void _showWcHistorySheet(", "void _showMoodPicker", new_wc_history_sheet)

if success1 and success2:
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print("Done")
else:
    print(f"Failed: success1={success1}, success2={success2}")
