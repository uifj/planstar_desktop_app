import 'dart:convert';
import 'dart:io';

final RegExp _placeholderPattern = RegExp(r'\{(\w+)(?=[,}])');
final RegExp _hanPattern = RegExp(r'[\u3400-\u9fff]');
final RegExp _sourceKeyPattern = RegExp(
  r'(?:_l10n|\b_localizations\b|\bl10n|\bstrings|\blocalizations)\s*\.\s*([a-z]\w*)',
);

Set<String> placeholders(String value) => <String>{
  for (final RegExpMatch match in _placeholderPattern.allMatches(value))
    match.group(1)!,
};

Never fail(List<String> errors) {
  for (final String error in errors) {
    stderr.writeln(error);
  }
  exit(1);
}

void main() {
  final errors = <String>[];
  final catalogs = <String, Map<String, Object?>>{};
  for (final String locale in <String>['zh', 'en']) {
    final file = File('lib/l10n/arb/app_$locale.arb');
    final Map<String, Object?> decoded =
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    if (decoded['@@locale'] != locale) {
      errors.add('$file: @@locale must be $locale');
    }
    catalogs[locale] = decoded;
  }

  Map<String, Object?> messages(Map<String, Object?> catalog) =>
      <String, Object?>{
        for (final MapEntry<String, Object?> entry in catalog.entries)
          if (!entry.key.startsWith('@')) entry.key: entry.value,
      };

  final zh = messages(catalogs['zh']!);
  final en = messages(catalogs['en']!);
  final zhKeys = zh.keys.toSet();
  final enKeys = en.keys.toSet();
  if (zhKeys.difference(enKeys).isNotEmpty) {
    errors.add(
      'Missing English keys: ${zhKeys.difference(enKeys).toList()..sort()}',
    );
  }
  if (enKeys.difference(zhKeys).isNotEmpty) {
    errors.add(
      'Missing Chinese keys: ${enKeys.difference(zhKeys).toList()..sort()}',
    );
  }

  for (final String key in zhKeys.intersection(enKeys)) {
    final values = <String, String>{
      'zh': zh[key]! as String,
      'en': en[key]! as String,
    };
    Set<String>? expectedPlaceholders;
    for (final MapEntry<String, String> value in values.entries) {
      final locale = value.key;
      final text = value.value;
      if (text.trim().isEmpty) errors.add('$locale/$key is empty');
      if (locale == 'en' && _hanPattern.hasMatch(text)) {
        errors.add('en/$key contains untranslated Chinese');
      }
      final metadata = catalogs[locale]!['@$key'];
      if (metadata is! Map || metadata['description'] is! String) {
        errors.add('$locale/$key needs @key metadata with a description');
        continue;
      }
      final declared = metadata['placeholders'];
      final actual = placeholders(text);
      if (declared == null && actual.isNotEmpty) {
        errors.add('$locale/$key has placeholders without metadata: $actual');
      }
      if (declared is Map) {
        final declaredNames = declared.keys.toSet();
        if (declaredNames.difference(actual).isNotEmpty ||
            actual.difference(declaredNames).isNotEmpty) {
          errors.add(
            '$locale/$key placeholder mismatch: declared=$declaredNames actual=$actual',
          );
        }
        for (final String name in actual) {
          final definition = declared[name];
          if (definition is! Map || definition['type'] is! String) {
            errors.add('$locale/$key placeholder $name needs a type');
          }
        }
      }
      expectedPlaceholders ??= actual;
      if (actual.difference(expectedPlaceholders).isNotEmpty ||
          expectedPlaceholders.difference(actual).isNotEmpty) {
        errors.add('$key placeholder sets differ between zh and en');
      }
    }
  }

  final generated = File(
    'lib/l10n/generated/app_localizations.dart',
  ).readAsStringSync();
  final generatedKeys = <String>{
    for (final RegExpMatch match in RegExp(
      r'String get (\w+)',
    ).allMatches(generated))
      match.group(1)!,
    for (final RegExpMatch match in RegExp(
      r'String (\w+)\(',
    ).allMatches(generated))
      match.group(1)!,
  }..remove('localeName');
  if (generatedKeys.difference(zhKeys).isNotEmpty) {
    errors.add(
      'Generated API missing ARB entries: ${generatedKeys.difference(zhKeys).toList()..sort()}',
    );
  }
  if (zhKeys.difference(generatedKeys).isNotEmpty) {
    errors.add(
      'ARB entries missing from generated API: ${zhKeys.difference(generatedKeys).toList()..sort()}',
    );
  }

  final referencedKeys = <String>{};
  for (final FileSystemEntity entity in Directory(
    'lib',
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('/l10n/generated/')) continue;
    final source = entity
        .readAsStringSync()
        .replaceAll(RegExp(r'^\s*(?:import|export).*$', multiLine: true), '')
        .replaceAll(RegExp(r'//.*$', multiLine: true), '');
    for (final RegExpMatch match in _sourceKeyPattern.allMatches(source)) {
      final key = match.group(1)!;
      if (key != 'localeName') referencedKeys.add(key);
    }
  }
  final missingReferences = referencedKeys.difference(zhKeys);
  if (missingReferences.isNotEmpty) {
    errors.add(
      'Source references missing ARB keys: ${missingReferences.toList()..sort()}',
    );
  }
  final unusedKeys = zhKeys.difference(referencedKeys);
  if (unusedKeys.isNotEmpty) {
    errors.add('Unused ARB keys: ${unusedKeys.toList()..sort()}');
  }

  if (errors.isNotEmpty) fail(errors);
  stdout.writeln(
    'Localization catalogs valid: ${zhKeys.length} keys in zh and en.',
  );
}
