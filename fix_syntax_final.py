path = r'c:\\Users\\bora0\\nutri_lens\\lib\\screens\\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()

# Area 2: Fix lines 4191 to 4202
# 4191: );
# 4192: );
# 4193: },
# 4194: );
# 4195: },
# 4196: ),
# 4197: ),
# 4198: ),
# 4199: );
# 4200: },
# 4201: );
# 4202: }

# We want:
# 4191: ); (Column)
# 4192: }, (itemBuilder)
# 4193: ); (ListView.builder)
# 4194: }, (builder function)
# 4195: ), (Builder)
# 4196: ), (Expanded)
# 4197: ], (Column children)
# 4198: ), (Column)
# 4199: ), (DraggableScrollableSheet builder)
# 4200: ); (DraggableScrollableSheet return)
# 4201: }, (showModalBottomSheet builder)
# 4202: ); (showModalBottomSheet)
# 4203: } (function end)

lines[4190] = "                    );" # 4191
lines[4191] = "                  }," # 4192
lines[4192] = "                );" # 4193
lines[4193] = "              }," # 4194
lines[4194] = "            )," # 4195
lines[4195] = "          )," # 4196
lines[4196] = "        ]," # 4197
lines[4197] = "      )," # 4198
lines[4198] = "    )," # 4199
lines[4199] = "  );" # 4200
lines[4200] = "}," # 4201
lines[4201] = ");" # 4202
lines[4202] = "}" # 4203

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')

print("Done")
