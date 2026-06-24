import re

def fix_fasting_screen():
    with open('lib/screens/fasting_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Multi-line string error (around line 992)
    # The text was: context.tr('Şu anlık burası boş ama doğru yoldasın,\nbir sonraki orucunda burası dolu olacak.')
    # It probably got split into two lines incorrectly.
    content = re.sub(
        r"context\.tr\('Şu anlık burası boş ama doğru yoldasın,\n\s*bir sonraki orucunda burası dolu olacak\.'\)",
        r"context.tr('Şu anlık burası boş ama doğru yoldasın,\\nbir sonraki orucunda burası dolu olacak.')",
        content,
        flags=re.MULTILINE
    )
    # Also catch if it was broken across lines natively without \n
    content = content.replace("context.tr('Şu anlık burası boş ama doğru yoldasın,\nbir sonraki orucunda burası dolu olacak.')", 
                              "context.tr('Şu anlık burası boş ama doğru yoldasın,\\nbir sonraki orucunda burası dolu olacak.')")
    
    # 2. const Text(context.tr(...))
    content = content.replace("const Text(context.tr('Vazgeç'))", "Text(context.tr('Vazgeç'))")
    content = content.replace("const Text(context.tr('Orucu İptal Et'))", "Text(context.tr('Orucu İptal Et'))")
    content = content.replace("const Text(context.tr('Orucu Bitir'))", "Text(context.tr('Orucu Bitir'))")
    content = content.replace("const Text(context.tr('Süre Seçin')", "Text(context.tr('Süre Seçin')")
    content = content.replace("const Text(context.tr('Henüz geçmiş oruç kaydı bulunmuyor.')", "Text(context.tr('Henüz geçmiş oruç kaydı bulunmuyor.')")

    with open('lib/screens/fasting_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def fix_dashboard_screen():
    try:
        with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # wcStoolTypes usages
        content = content.replace("wcStoolTypes.firstWhere", "wcStoolTypes(context).firstWhere")
        content = content.replace("wcStoolTypes[3]", "wcStoolTypes(context)[3]")

        with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
            f.write(content)
    except FileNotFoundError:
        pass

fix_fasting_screen()
fix_dashboard_screen()
