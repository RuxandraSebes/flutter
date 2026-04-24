import 'dart:io';

final ignoreFiles = [
  'firebase_options.dart',
  '.g.dart',
  '.freezed.dart',
];

void main() {
  final dir = Directory('lib');

  print("🔍 UI Text scanner (Text(\"...\") only, ignores _tr)\n");

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !_isIgnoredFile(f.path))
      .toList();

  int found = 0;

  final textRegex = RegExp(
    r'''Text\s*\(\s*(['"])(.*?)\1\s*[,)]''',
    multiLine: true,
    dotAll: true,
  );

  for (final file in files) {
    final lines = file.readAsLinesSync();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 🚨 IMPORTANT: ignoră complet traducerile
      if (line.contains('_tr(')) continue;

      final matches = textRegex.allMatches(line);

      for (final m in matches) {
        final value = m.group(2)?.trim() ?? '';

        if (_isIgnored(value)) continue;

        print("⚠️ ${file.path}:${i + 1}");
        print("   → Text(\"$value\")\n");

        found++;
      }
    }
  }

  print("━━━━━━━━━━━━━━━━━━━━━━");
  print("✔ Scan complet (UI Text only, _tr excluded)");
  print("❗ UI strings găsite: $found");
}

bool _isIgnoredFile(String path) {
  return ignoreFiles.any((f) => path.contains(f));
}

bool _isIgnored(String value) {
  if (value.isEmpty) return true;
  if (value.length < 2) return true;

  // ignoră doar numere / simboluri
  if (RegExp(r'^[0-9\W_]+$').hasMatch(value)) return true;

  // ignora chestii tehnice
  final technical = [
    'http',
    'Bearer',
    'application/json',
    'Authorization',
    'Content-Type',
    'success',
    'message',
    'token',
    'user',
    'patient_id',
  ];

  return technical.any((t) => value.contains(t));
}
