import 'dart:convert';

import 'package:forge_cli/src/core/arb_editor.dart';
import 'package:forge_cli/src/core/file_store.dart';
import 'package:forge_cli/src/core/generation_plan.dart';
import 'package:forge_cli/src/generators/l10n_key_builder.dart';
import 'package:test/test.dart';

void main() {
  group('ArbEditor', () {
    test('finds top-level placeholders only', () {
      final found = ArbEditor.placeholders(
        '{name} has {count, plural, =0{no order} other{{count} orders}}',
      );
      expect(found.map((p) => '${p.name}:${p.type}'),
          ['name:String', 'count:num']);
    });

    test('appends the entry and metadata, keeping the file layout', () {
      const source = '{\n    "@@locale": "fr",\n    "a": "A"\n}\n';
      final edited = ArbEditor.addEntry(
        source,
        'hello',
        'Bonjour {name}',
        metadata: {'description': 'Greeting'},
      )!;
      expect(
        edited,
        '{\n    "@@locale": "fr",\n    "a": "A",\n'
        '    "hello": "Bonjour {name}",\n'
        '    "@hello": {\n        "description": "Greeting"\n    }\n}\n',
      );
      expect(jsonDecode(edited), isA<Map<String, dynamic>>());
    });

    test('handles an empty object and rejects invalid JSON', () {
      expect(ArbEditor.addEntry('{}', 'a', 'A'), '{\n  "a": "A"\n}');
      expect(ArbEditor.addEntry('{,', 'a', 'A'), isNull);
    });

    test('reads the locale from @@locale or the file name', () {
      expect(ArbEditor.locale('l/app_xx.arb', '{"@@locale": "fr"}'), 'fr');
      expect(ArbEditor.locale('l/app_pt_BR.arb', '{}'), 'pt_BR');
    });
  });

  group('L10nKeyBuilder', () {
    MemoryFileStore store() => MemoryFileStore({
          'l10n.yaml': 'arb-dir: lib/l10n\ntemplate-arb-file: app_fr.arb\n',
          'lib/l10n/app_fr.arb': '{\n  "@@locale": "fr",\n  "a": "A"\n}\n',
          'lib/l10n/app_en.arb': '{\n  "@@locale": "en",\n  "a": "A"\n}\n',
        });

    test('adds the key to every locale, metadata in the template only', () {
      final files = store();
      final plan = GenerationPlan(files);
      L10nKeyBuilder(files).add(
        plan,
        key: 'greeting',
        messages: {'fr': 'Bonjour {name}', 'en': 'Hello {name}'},
        description: 'Home greeting',
      );
      final fr = jsonDecode(plan.read('lib/l10n/app_fr.arb')!) as Map;
      final en = jsonDecode(plan.read('lib/l10n/app_en.arb')!) as Map;
      expect(fr['greeting'], 'Bonjour {name}');
      expect(fr['@greeting'], {
        'description': 'Home greeting',
        'placeholders': {
          'name': {'type': 'String'},
        },
      });
      expect(en['greeting'], 'Hello {name}');
      expect(en.containsKey('@greeting'), isFalse);
      expect(plan.notes, isEmpty);
    });

    test('copies the template text into untranslated locales, with a note', () {
      final files = store();
      final plan = GenerationPlan(files);
      L10nKeyBuilder(files).add(plan, key: 'b', messages: {'fr': 'B'});
      expect((jsonDecode(plan.read('lib/l10n/app_en.arb')!) as Map)['b'], 'B');
      expect(plan.notes.single, contains('Translate it'));
    });

    test('skips an existing key unless forced', () {
      final files = store();
      final plan = GenerationPlan(files);
      L10nKeyBuilder(files)
          .add(plan, key: 'a', messages: {'fr': 'Z', 'en': 'Z'});
      expect(plan.changes, isEmpty);

      final forced = GenerationPlan(files);
      L10nKeyBuilder(files)
          .add(forced, key: 'a', messages: {'fr': 'Z', 'en': 'Z'}, force: true);
      expect(
          (jsonDecode(forced.read('lib/l10n/app_fr.arb')!) as Map)['a'], 'Z');
    });

    test('warns when a translation drops a placeholder', () {
      final files = store();
      final plan = GenerationPlan(files);
      L10nKeyBuilder(files).add(
        plan,
        key: 'c',
        messages: {'fr': 'Salut {name}', 'en': 'Hi'},
      );
      expect(plan.notes.single, contains('placeholders'));
    });
  });
}
