import os

path = r'c:\Users\bora0\nutri_lens\lib\screens\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'itemCount: sortedHours.length,' in line:
        # Correcting the itemBuilder structure if needed, but the main issue is the end of ListView.builder
        pass
    
    # We need to find the specific sequence at the end of the history sheet
    new_lines.append(line)

content = "".join(lines)

# Target the end of ListView.builder and Expanded
old_end = """                    );
                  },
                ),
              ),"""

# Add the missing braces for the Builder
new_end = """                    );
                  },
                ),
              };
            ),
          ),"""

if old_end in content:
    content = content.replace(old_end, new_end)
else:
    # Try CRLF
    old_end_crlf = old_end.replace('\\n', '\\r\\n')
    if old_end_crlf in content:
        content = content.replace(old_end_crlf, new_end.replace('\\n', '\\r\\n'))
    else:
        print("End block not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
