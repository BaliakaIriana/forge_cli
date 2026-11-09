import 'package:mason_logger/mason_logger.dart';

import '../core/file_store.dart';
import '../core/generation_plan.dart';

/// Writes a [GenerationPlan] to disk (or only reports it on dry runs).
final class PlanExecutor {
  const PlanExecutor(this._store, this._logger);

  final FileStore _store;
  final Logger _logger;

  /// Returns the number of files written (or that would be).
  int apply(GenerationPlan plan, {bool dryRun = false, bool force = false}) {
    var written = 0;
    for (final change in plan.changes) {
      switch (change) {
        case CreateFile(:final path) when _store.exists(path) && !force:
          _logger.info('  ${yellow.wrap('skip')}    $path '
              '${darkGray.wrap('(exists, use --force to overwrite)')}');
        case CreateFile(:final path, :final content):
          final overwrite = _store.exists(path);
          _logger
              .info('  ${green.wrap(overwrite ? 'replace' : 'create')}  $path');
          if (!dryRun) _store.write(path, content);
          written++;
        case UpdateFile(:final path, :final content, :final reason):
          _logger.info('  ${cyan.wrap('update')}  $path '
              '${darkGray.wrap('($reason)')}');
          if (!dryRun) _store.write(path, content);
          written++;
      }
    }
    for (final note in plan.notes) {
      _logger.warn(note);
    }
    if (dryRun) {
      _logger.info(darkGray.wrap('\nDry run: nothing was written.'));
    }
    return written;
  }
}
