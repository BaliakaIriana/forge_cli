import 'dart:io';

import 'package:path/path.dart' as p;

/// File access relative to the project root (POSIX-style relative paths).
///
/// Abstracted so generators can be exercised against an in-memory tree.
abstract interface class FileStore {
  bool exists(String path);
  String? read(String path);
  void write(String path, String content);

  /// Names of the direct sub-directories of [path] (empty if absent).
  List<String> subdirectories(String path);

  /// Every `.dart` file under [path], recursively.
  List<String> dartFiles(String path);
}

final class DiskFileStore implements FileStore {
  DiskFileStore(this.root);

  final String root;

  String _abs(String path) => p.joinAll([root, ...p.posix.split(path)]);

  @override
  bool exists(String path) => File(_abs(path)).existsSync();

  @override
  String? read(String path) {
    final file = File(_abs(path));
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  @override
  void write(String path, String content) {
    final file = File(_abs(path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  @override
  List<String> subdirectories(String path) {
    final dir = Directory(_abs(path));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => !name.startsWith('.'))
        .toList()
      ..sort();
  }

  @override
  List<String> dartFiles(String path) {
    final dir = Directory(_abs(path));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => p.posix.joinAll(p.split(p.relative(f.path, from: root))))
        .toList()
      ..sort();
  }
}

/// In-memory [FileStore], for tests and dry runs.
final class MemoryFileStore implements FileStore {
  MemoryFileStore([Map<String, String>? files]) : files = {...?files};

  final Map<String, String> files;

  @override
  bool exists(String path) => files.containsKey(path);

  @override
  String? read(String path) => files[path];

  @override
  void write(String path, String content) => files[path] = content;

  @override
  List<String> subdirectories(String path) {
    final prefix = '$path/';
    return files.keys
        .where((f) => f.startsWith(prefix))
        .map((f) => f.substring(prefix.length).split('/'))
        .where((parts) => parts.length > 1)
        .map((parts) => parts.first)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  List<String> dartFiles(String path) => files.keys
      .where((f) => f.startsWith('$path/') && f.endsWith('.dart'))
      .toList()
    ..sort();
}
