path = r'c:\Users\bora0\nutri_lens\lib\screens\dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Line numbers in view_file are 1-based.
# 4192:                     );
# 4193:                   },
# 4194:                 ),
# 4195:               };
# 4196:             },
# 4197:           ),
# 4198:         ),

# We want:
# 4192:                     );
# 4193:                   },
# 4194:                 ),
# 4195:               },
# 4196:             ),
# 4197:           ),

# Let's just rebuild the whole block from 4190 to 4200.
# No, let's just find the sequence.

content = "".join(lines)
old = """                    );
                  },
                ),
              };
            },
          ),
        ),"""

new = """                    );
                  },
                ),
              },
            ),
          ),"""

if old in content:
    content = content.replace(old, new)
else:
    print("Not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
