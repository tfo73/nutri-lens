import 'dart:io';

void main(List<String> args) {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    print('pubspec.yaml not found');
    return;
  }

  final lines = file.readAsLinesSync();
  final versionRegex = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
  
  bool minor = args.contains('--minor');
  
  for (int i = 0; i < lines.length; i++) {
    final match = versionRegex.firstMatch(lines[i]);
    if (match != null) {
      int v1 = int.parse(match.group(1)!);
      int v2 = int.parse(match.group(2)!);
      int v3 = int.parse(match.group(3)!);
      int build = int.parse(match.group(4)!);

      if (minor) {
        v2++;
        v3 = 0;
      } else {
        v3++;
      }
      build++;

      lines[i] = 'version: $v1.$v2.$v3+$build';
      print('Updated version to: $v1.$v2.$v3+$build');
      break;
    }
  }

  file.writeAsStringSync(lines.join('\n') + '\n');
}
