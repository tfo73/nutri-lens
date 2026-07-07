import os
import re

# Paths to Markdown sources
source_files = {
    'privacy_en': 'assets/legal/privacy_policy_en.md',
    'privacy_tr': 'assets/legal/privacy_policy_tr.md',
    'terms_en': 'assets/legal/terms_en.md',
    'terms_tr': 'assets/legal/terms_tr.md',
    'kvkk_en': 'assets/legal/kvkk_consent_en.md',
    'kvkk_tr': 'assets/legal/kvkk_consent_tr.md',
}

# Output directories & routing structure
outputs = {
    'privacy_en': 'public/privacy/index.html',
    'privacy_tr': 'public/privacy/tr/index.html',
    'terms_en': 'public/termandconditions/index.html',
    'terms_tr': 'public/termandconditions/tr/index.html',
    'kvkk_en': 'public/kvkk/index.html',
    'kvkk_tr': 'public/kvkk/tr/index.html',
}

def md_to_html(md_text):
    # Strip carriage returns
    md_text = md_text.replace('\r\n', '\n')
    
    # Pre-process bold links first to prevent conflict
    # e.g., **[link](url)** or [**text**](url)
    md_text = re.sub(r'\[\*\*(.*?)\*\*\]\((.*?)\)', r'<a href="\2"><strong>\1</strong></a>', md_text)
    md_text = re.sub(r'\*\*\[(.*?)\]\((.*?)\)\*\*', r'<strong><a href="\2">\1</a></strong>', md_text)

    # Standard Bold **text**
    md_text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', md_text)
    
    # Inline links [text](url)
    md_text = re.sub(r'\[(.*?)\]\((.*?)\)', r'<a href="\2">\1</a>', md_text)

    lines = md_text.split('\n')
    html_lines = []
    
    in_list = False
    list_type = None # 'ul' or 'ol'
    
    for line in lines:
        stripped = line.strip()
        
        # Headers
        if stripped.startswith('# '):
            if in_list:
                html_lines.append(f'</{list_type}>')
                in_list = False
            html_lines.append(f'<h1>{stripped[2:]}</h1>')
            continue
        elif stripped.startswith('## '):
            if in_list:
                html_lines.append(f'</{list_type}>')
                in_list = False
            html_lines.append(f'<h2>{stripped[3:]}</h2>')
            continue
        elif stripped.startswith('### '):
            if in_list:
                html_lines.append(f'</{list_type}>')
                in_list = False
            html_lines.append(f'<h3>{stripped[4:]}</h3>')
            continue
            
        # Lists (Unordered)
        if stripped.startswith('- ') or stripped.startswith('* '):
            if not in_list or list_type != 'ul':
                if in_list:
                    html_lines.append(f'</{list_type}>')
                html_lines.append('<ul>')
                in_list = True
                list_type = 'ul'
            html_lines.append(f'  <li>{stripped[2:]}</li>')
            continue
            
        # Lists (Ordered)
        match_ol = re.match(r'^(\d+)\.\s+(.*)', stripped)
        if match_ol:
            if not in_list or list_type != 'ol':
                if in_list:
                    html_lines.append(f'</{list_type}>')
                html_lines.append('<ol>')
                in_list = True
                list_type = 'ol'
            html_lines.append(f'  <li>{match_ol.group(2)}</li>')
            continue
            
        # Empty Line
        if not stripped:
            if in_list:
                html_lines.append(f'</{list_type}>')
                in_list = False
            continue
            
        # Paragraphs
        if in_list:
            html_lines.append(f'</{list_type}>')
            in_list = False
        html_lines.append(f'<p>{stripped}</p>')
        
    if in_list:
        html_lines.append(f'</{list_type}>')
        
    return '\n'.join(html_lines)

# Premium HTML wrapper
def get_html_template(title, content, current_lang, switch_lang_url, switch_lang_name, doc_title_nav):
    lang_attr = 'tr' if current_lang == 'tr' else 'en'
    home_name = 'Ana Sayfa' if current_lang == 'tr' else 'Home'
    
    return f"""<!DOCTYPE html>
<html lang="{lang_attr}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} | LensEat</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Outfit:wght@600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {{
            --background: #090b0e;
            --surface: #101419;
            --text-primary: #f3f4f6;
            --text-secondary: #9ca3af;
            --accent: #ff4757;
            --accent-gradient: linear-gradient(135deg, #ff4757, #ff6b81);
            --border: #1e242c;
            --max-width: 800px;
        }}

        * {{
            box-sizing: border-box;
        }}

        body {{
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--background);
            color: var(--text-primary);
            line-height: 1.8;
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }}

        header {{
            border-bottom: 1px solid var(--border);
            background-color: rgba(9, 11, 14, 0.8);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            position: sticky;
            top: 0;
            z-index: 100;
        }}

        .header-container {{
            max-width: var(--max-width);
            margin: 0 auto;
            padding: 20px 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}

        .logo {{
            font-family: 'Outfit', sans-serif;
            font-size: 24px;
            font-weight: 800;
            background: var(--accent-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-decoration: none;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .logo-dot {{
            width: 8px;
            height: 8px;
            background: var(--accent);
            border-radius: 50%;
            display: inline-block;
        }}

        .nav-links {{
            display: flex;
            align-items: center;
            gap: 24px;
        }}

        .nav-links a {{
            color: var(--text-secondary);
            text-decoration: none;
            font-size: 14px;
            font-weight: 500;
            transition: color 0.2s, transform 0.2s;
        }}

        .nav-links a:hover {{
            color: var(--text-primary);
        }}

        .nav-links .active {{
            color: var(--text-primary);
            border-bottom: 2px solid var(--accent);
            padding-bottom: 2px;
        }}

        .lang-switch {{
            border: 1px solid var(--border);
            padding: 6px 12px;
            border-radius: 20px;
            background-color: rgba(255, 255, 255, 0.03);
        }}

        .lang-switch:hover {{
            border-color: var(--accent);
            background-color: rgba(255, 67, 87, 0.05);
        }}

        .container {{
            max-width: var(--max-width);
            margin: 40px auto 80px;
            padding: 0 24px;
        }}

        .doc-card {{
            background-color: var(--surface);
            border: 1px solid var(--border);
            border-radius: 24px;
            padding: 48px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
        }}

        @media (max-width: 640px) {{
            .doc-card {{
                padding: 24px;
                border-radius: 16px;
            }}
            .header-container {{
                padding: 16px;
            }}
            .nav-links {{
                gap: 16px;
            }}
        }}

        h1, h2, h3 {{
            font-family: 'Outfit', sans-serif;
            color: var(--text-primary);
            font-weight: 700;
            line-height: 1.3;
        }}

        h1 {{
            font-size: 34px;
            margin-top: 0;
            margin-bottom: 12px;
            letter-spacing: -0.02em;
        }}

        h2 {{
            font-size: 24px;
            margin-top: 48px;
            margin-bottom: 20px;
            border-bottom: 1px solid var(--border);
            padding-bottom: 8px;
            letter-spacing: -0.01em;
        }}

        h3 {{
            font-size: 19px;
            margin-top: 32px;
            margin-bottom: 16px;
        }}

        p {{
            margin-top: 0;
            margin-bottom: 20px;
            color: #d1d5db;
            font-size: 15px;
        }}

        ul, ol {{
            margin-top: 0;
            margin-bottom: 24px;
            padding-left: 24px;
            color: #d1d5db;
            font-size: 15px;
        }}

        li {{
            margin-bottom: 10px;
        }}

        strong {{
            color: var(--text-primary);
            font-weight: 600;
        }}

        a {{
            color: var(--accent);
            text-decoration: none;
            font-weight: 500;
            transition: color 0.2s;
        }}

        a:hover {{
            color: #ff6b81;
            text-decoration: underline;
        }}

        footer {{
            text-align: center;
            padding: 40px 0;
            color: var(--text-secondary);
            font-size: 13px;
            border-top: 1px solid var(--border);
            margin-top: 80px;
        }}

        /* Scrollbar customization */
        ::-webkit-scrollbar {{
            width: 8px;
        }}
        ::-webkit-scrollbar-track {{
            background: var(--background);
        }}
        ::-webkit-scrollbar-thumb {{
            background: var(--border);
            border-radius: 4px;
        }}
        ::-webkit-scrollbar-thumb:hover {{
            background: var(--text-secondary);
        }}
    </style>
</head>
<body>
    <header>
        <div class="header-container">
            <a href="/" class="logo">LensEat<span class="logo-dot"></span></a>
            <div class="nav-links">
                <a href="/">{home_name}</a>
                <a href="{switch_lang_url}" class="lang-switch">{switch_lang_name}</a>
            </div>
        </div>
    </header>

    <div class="container">
        <div class="doc-card">
            {content}
        </div>
    </div>

    <footer>
        &copy; {import_year()} Longerix Labs. All rights reserved.
    </footer>
</body>
</html>
"""

def import_year():
    import datetime
    return datetime.datetime.now().year

def main():
    print("Generating legal pages for website...")
    
    for key, md_path in source_files.items():
        if not os.path.exists(md_path):
            print(f"Warning: Source file {md_path} not found. Skipping...")
            continue
            
        with open(md_path, 'r', encoding='utf-8') as f:
            md_content = f.read()
            
        # Parse document metadata
        is_tr = key.endswith('_tr')
        doc_type = key.split('_')[0]
        
        # Format links & meta
        if doc_type == 'privacy':
            title = "Gizlilik Politikası" if is_tr else "Privacy Policy"
            switch_lang_url = '/privacy/tr' if not is_tr else '/privacy'
        elif doc_type == 'terms':
            title = "Kullanım Koşulları" if is_tr else "Terms and Conditions"
            switch_lang_url = '/termandconditions/tr' if not is_tr else '/termandconditions'
        else: # kvkk
            title = "KVKK Açık Rıza Metni" if is_tr else "KVKK Consent Text"
            switch_lang_url = '/kvkk/tr' if not is_tr else '/kvkk'
            
        switch_lang_name = "Türkçe" if not is_tr else "English"
        
        # Convert Markdown Content to HTML
        html_content = md_to_html(md_content)
        
        # Generate complete page HTML
        full_html = get_html_template(
            title=title,
            content=html_content,
            current_lang='tr' if is_tr else 'en',
            switch_lang_url=switch_lang_url,
            switch_lang_name=switch_lang_name,
            doc_title_nav=title
        )
        
        # Output setup
        out_path = outputs[key]
        out_dir = os.path.dirname(out_path)
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
            
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(full_html)
            
        print(f"Generated successfully: {out_path}")
        
    print("Done! Legal pages generated.")

if __name__ == '__main__':
    main()
