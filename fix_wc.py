import sys
import os

path = r'c:\Users\bora0\nutri_lens\lib\screens\dashboard_screen.dart'

with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

new_lines = []
skip = 0
for i, line in enumerate(lines):
    if skip > 0:
        skip -= 1
        continue
    
    # Dashboard replacement
    if "wellness.today.wcCount > 0" in line and "tane girdi yaptınız" in line:
        # Wrap Expanded child in GestureDetector
        # We need to find the Expanded line.
        # It's usually 5 lines above or so.
        # But let's just do a string replace on the specific block.
        pass

    new_lines.append(line)

# Since string replacement is tricky with large files and dynamic content,
# I'll use a simpler approach: finding the specific lines by content.

content = "".join(lines)

# 1. Update Dashboard text and tap
old_dashboard = """                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wellness.today.wcCount > 0
                            ? 'Bugün ${wellness.today.wcCount} tane girdi yaptınız'
                            : 'Henüz kayıt yok',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),"""

new_dashboard = """                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showWcHistorySheet(context, wellness),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wellness.today.wcCount > 0
                              ? 'Bugün ${wellness.today.wcCount} tane girdi yaptınız'
                              : 'Bugün hiç girdi yapmadınız',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),"""

# 2. Update History Sheet logic
old_history = """              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: 24, // Show all hours or just entries? "saat başına ayrı bir çizgi olsun" suggests a timeline of hours.
                  itemBuilder: (context, hour) {
                    final entries = logs.where((e) => e.time.hour == hour).toList();"""

new_history = """              Expanded(
                child: Builder(
                  builder: (context) {
                    final hoursWithLogs = <int>{};
                    for (final log in logs) {
                      hoursWithLogs.add(log.time.hour);
                    }
                    final sortedHours = hoursWithLogs.toList()..sort((a, b) => b.compareTo(a));

                    if (sortedHours.isEmpty) {
                      return Center(child: Text('Henüz kayıt yok', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))));
                    }

                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: sortedHours.length,
                      itemBuilder: (context, index) {
                        final hour = sortedHours[index];
                        final entries = logs.where((e) => e.time.hour == hour).toList();"""

# Attempt replacement with different newline styles
if old_dashboard in content:
    content = content.replace(old_dashboard, new_dashboard)
else:
    # Try with CRLF
    old_dashboard_crlf = old_dashboard.replace('\\n', '\\r\\n')
    if old_dashboard_crlf in content:
        content = content.replace(old_dashboard_crlf, new_dashboard.replace('\\n', '\\r\\n'))
    else:
        print("Dashboard block not found")

if old_history in content:
    content = content.replace(old_history, new_history)
else:
    old_history_crlf = old_history.replace('\\n', '\\r\\n')
    if old_history_crlf in content:
        content = content.replace(old_history_crlf, new_history.replace('\\n', '\\r\\n'))
    else:
        print("History block not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
