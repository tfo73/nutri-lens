import os

path = r'c:\Users\bora0\nutri_lens\lib\screens\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Current messy state from my previous script
messy_end = """                    );
                  },
                ),
              };
            ),
          ),"""

# Correct state
clean_end = """                    );
                  },
                ),
              };
            },
          ),
        ),"""

# Wait, let's re-verify the braces.
# itemCount is at 4112.
# itemBuilder starts at 4113.
# Column starts at 4118.
# Column ends at 4191.
# itemBuilder ends at 4192.
# ListView.builder ends at 4193.
# builder: (context) { ... } ends at 4194.
# Builder( ... ) ends at 4195.
# Expanded( ... ) ends at 4196.

# Actually, the Builder was:
# Expanded(
#   child: Builder(
#     builder: (context) {
#       ...
#       return ListView.builder(
#         ...
#         itemBuilder: (context, index) {
#            ...
#            return Column(...);
#         },
#       );
#     },
#   ),
# ),

# So:
# 4191: ); (Column)
# 4192: }, (itemBuilder)
# 4193: ), (ListView.builder)
# 4194: }; (should be })
# 4195: ), (Builder)
# 4196: ), (Expanded)

# Let's fix it.
content = content.replace(messy_end, """                    );
                  },
                ),
              };
            },
          ),
        ),""")

# Wait, I see line 4194 is }; and 4195 is ),.
# If I use Builder(builder: (context) { ... }), it's:
# Builder(
#   builder: (context) {
#     return ...;
#   },
# )

# So line 4194 should be } and 4195 should be ).
# But there's also the closing for Expanded.

# Let's just do a direct line replacement for those lines.
lines = content.splitlines()
# I'll search for the lines by index if I can, but let's just use string replace.

final_end = """                    );
                  },
                ),
              },
            ),
          ),"""

content = content.replace(messy_end, final_end)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
