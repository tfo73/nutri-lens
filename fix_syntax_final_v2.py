path = r'c:\\Users\\bora0\\nutri_lens\\lib\\screens\\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()

# Area 1: line 2222 to 2233
# We want to replace these specific lines.

lines[2221] = "                      );" # 2222
lines[2222] = "                    }," # 2223
lines[2223] = "                  )," # 2224
lines[2224] = "                )," # 2225
lines[2225] = "              ]," # 2226
lines[2226] = "            )," # 2227
lines[2227] = "          )," # 2228
lines[2228] = "        )," # 2229
lines[2229] = "      );" # 2230
lines[2230] = "    }," # 2231
lines[2231] = "  );" # 2232
lines[2232] = "}" # 2233

# Let's check Area 2 too just in case.
# My previous script for Area 2 was:
# lines[4190] = "                    );" # 4191
# lines[4191] = "                  }," # 4192
# lines[4192] = "                );" # 4193
# lines[4193] = "              }," # 4194
# lines[4194] = "            )," # 4195
# lines[4195] = "          )," # 4196
# lines[4196] = "        ]," # 4197
# lines[4197] = "      )," # 4198
# lines[4198] = "    )," # 4199
# lines[4199] = "  );" # 4200
# lines[4200] = "}," # 4201
# lines[4201] = ");" # 4202
# lines[4202] = "}" # 4203

# Wait, Area 2 in view_file:
# 4191:                     );
# 4192:                   },
# 4193:                 );
# 4194:               },
# 4195:             ),
# 4196:           ),
# 4197:         ],
# 4198:       ),
# 4199:     ),
# 4200:   );
# 4201: },
# 4202: );
# 4203: }
# This looks correct!

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')

print("Done")
