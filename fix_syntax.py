path = r'c:\\Users\\bora0\\nutri_lens\\lib\\screens\\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()

# Area 1: Nutrition Score Detail
lines[2222] = "                      );" # return Column(...);
lines[2223] = "                    }," # itemBuilder
lines[2224] = "                  );" # return ListView.builder
lines[2225] = "                )," # Expanded
lines[2226] = "              ]," # Column children
lines[2227] = "            )," # Column
lines[2228] = "          )," # DraggableScrollableSheet builder
lines[2229] = "        );" # DraggableScrollableSheet return
lines[2230] = "      }," # showModalBottomSheet builder
lines[2231] = "    );" # showModalBottomSheet
lines[2232] = "  }" # function end

# Area 2: WC History
lines[4191] = "                        );" # return Column
lines[4192] = "                      }," # itemBuilder
lines[4193] = "                    );" # return ListView.builder
lines[4194] = "                  }," # builder function
lines[4195] = "                )," # Builder
lines[4196] = "              )," # Expanded

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')

print("Done")
