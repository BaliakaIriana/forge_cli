import 'package:forge_cli/src/core/source_editor.dart';
import 'package:test/test.dart';

void main() {
  group('addImport', () {
    test('inserts after the last import and is idempotent', () {
      const source = "import 'a.dart';\nimport 'b.dart';\n\nvoid main() {}\n";
      final once = SourceEditor.addImport(source, 'c.dart');
      expect(once,
          "import 'a.dart';\nimport 'b.dart';\nimport 'c.dart';\n\nvoid main() {}\n");
      expect(SourceEditor.addImport(once, 'c.dart'), once);
    });

    test('inserts before code when there is no import', () {
      expect(
        SourceEditor.addImport('// header\nvoid main() {}\n', 'a.dart'),
        "// header\nimport 'a.dart';\n\nvoid main() {}\n",
      );
    });
  });

  group('insertAtAnchor', () {
    const source = 'void f() {\n  a();\n  // forge:x\n}\n';

    test('inserts above the anchor with its indentation', () {
      expect(
        SourceEditor.insertAtAnchor(source, 'x', 'b(\n  1,\n);'),
        'void f() {\n  a();\n  b(\n    1,\n  );\n  // forge:x\n}\n',
      );
    });

    test('is idempotent and null without anchor', () {
      final once = SourceEditor.insertAtAnchor(source, 'x', 'b();')!;
      expect(SourceEditor.insertAtAnchor(once, 'x', 'b();'), once);
      expect(SourceEditor.insertAtAnchor(source, 'y', 'b();'), isNull);
    });
  });

  test('findClosing skips strings and comments', () {
    const source = "f() { var s = '}'; // }\n /* } */ return; }";
    expect(SourceEditor.findClosing(source, 4), source.length - 1);
  });

  test('insertAnchorsBeforeClose indents one level deeper', () {
    const source = 'final r = R(\n  routes: [\n    A(),\n  ],\n);\n';
    final open = source.indexOf('[');
    expect(
      SourceEditor.insertAnchorsBeforeClose(source, open, ['routes']),
      'final r = R(\n  routes: [\n    A(),\n    // forge:routes\n  ],\n);\n',
    );
  });

  test('insertInClass appends before the class end', () {
    const source = 'abstract interface class R {\n  void a();\n}\n';
    expect(
      SourceEditor.insertInClass(source, 'R', 'void b();'),
      'abstract interface class R {\n  void a();\n\n  void b();\n}\n',
    );
  });
}
