import 'file_store.dart';

/// A file the plan creates or rewrites.
sealed class FileChange {
  const FileChange(this.path, this.content);
  final String path;
  final String content;
}

final class CreateFile extends FileChange {
  const CreateFile(super.path, super.content);
}

final class UpdateFile extends FileChange {
  const UpdateFile(super.path, super.content, this.reason);
  final String reason;
}

/// Everything a generator wants to write, collected before touching disk so
/// `--dry-run` can show it and composite generators can build on earlier
/// steps (a planned file reads as existing).
final class GenerationPlan {
  GenerationPlan(this._store);

  final FileStore _store;
  final Map<String, FileChange> _changes = {};
  final List<String> _notes = [];
  bool _usesCodegen = false;

  Iterable<FileChange> get changes => _changes.values;
  List<String> get notes => List.unmodifiable(_notes);

  /// Whether a generated file needs `build_runner` (part directives).
  bool get usesCodegen => _usesCodegen;

  bool exists(String path) => _changes.containsKey(path) || _store.exists(path);

  /// Current content: planned if any, otherwise on disk.
  String? read(String path) => _changes[path]?.content ?? _store.read(path);

  void create(String path, String content) {
    if (content.contains("part '")) _usesCodegen = true;
    _changes[path] = CreateFile(path, content);
  }

  /// Rewrites [path] with [transform]. When the file is missing or
  /// [transform] returns `null` (anchor not found), the [snippet] is reported
  /// as a manual step instead. An unchanged result means "already wired".
  void edit(
    String path, {
    required String? Function(String source) transform,
    required String reason,
    required String snippet,
  }) {
    final source = read(path);
    final updated = source == null ? null : transform(source);
    if (updated == null) {
      note('Add to $path ($reason):\n$snippet');
      return;
    }
    if (updated == source) return;
    final previous = _changes[path];
    _changes[path] = previous is CreateFile
        ? CreateFile(path, updated)
        : UpdateFile(
            path,
            updated,
            previous is UpdateFile ? '${previous.reason}, $reason' : reason,
          );
  }

  void note(String message) => _notes.add(message);
  void markCodegen() => _usesCodegen = true;
}
