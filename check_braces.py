path = r'c:\\Users\\bora0\\nutri_lens\\lib\\screens\\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

def check(opening, closing):
    stack = []
    for i, char in enumerate(content):
        if char == opening:
            stack.append((opening, i))
        elif char == closing:
            if not stack:
                line = content.count('\n', 0, i) + 1
                print(f"Extra closing '{closing}' at line {line}")
            else:
                stack.pop()
    for char, i in stack:
        line = content.count('\n', 0, i) + 1
        print(f"Unclosed '{opening}' at line {line}")

print("Checking {}")
check('{', '}')
print("Checking ()")
check('(', ')')
print("Checking []")
check('[', ']')
print("Done")
