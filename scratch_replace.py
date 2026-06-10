import sys

def main():
    with open('lib/services/food_analysis_service.dart', 'r') as f:
        content = f.read()
    with open('scratch_new_method.dart', 'r') as f:
        new_method = f.read()
    with open('scratch_new_analyze.dart', 'r') as f:
        new_analyze = f.read()

    # 1. Replace _identifyFood and _analyzeNutrients with new_method
    start_idx = content.find('  Future<_FoodIdentification> _identifyFood')
    end_idx = content.find('  // ── Kullanıcı Geçmişi')
    
    if start_idx == -1 or end_idx == -1:
        print("Could not find start or end index for identifyFood/analyzeNutrients")
        sys.exit(1)
        
    content = content[:start_idx] + new_method + '\n\n' + content[end_idx:]

    # 2. Replace analyze() body
    start_analyze = content.find('  Future<FoodAnalysisResult> analyze({')
    end_analyze = content.find('  // ── Ağırlıklı Kaynak Birleştirme')
    
    if start_analyze == -1 or end_analyze == -1:
        print("Could not find analyze start/end")
        sys.exit(1)
        
    content = content[:start_analyze] + new_analyze + '\n\n' + content[end_analyze:]

    with open('lib/services/food_analysis_service.dart', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    main()
