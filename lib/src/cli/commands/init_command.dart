import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../config/forge_config.dart';
import '../../core/project.dart';
import '../init_flow.dart';
import '../prompter.dart';

final class InitCommand extends Command<int> {
  InitCommand(this._logger, this._prompter) {
    argParser
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Accept the detected defaults without asking.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing ${ForgeConfig.fileName}.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show what would be written, write nothing.',
      );
  }

  final Logger _logger;
  final Prompter _prompter;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Configure forge for this project: choose packages and architecture, '
      'write ${ForgeConfig.fileName}, scaffold core files and anchors.';

  @override
  Future<int> run() async {
    final project = Project.locate(Directory.current);
    if (project == null) {
      _logger.err('No pubspec.yaml found in this directory or its parents.');
      return ExitCode.usage.code;
    }
    final args = argResults!;
    if (project.config != null && !args.flag('force')) {
      final overwrite = _prompter.interactive &&
          _prompter.confirm(
            '${ForgeConfig.fileName} already exists. Reconfigure?',
            defaultValue: false,
          );
      if (!overwrite) {
        _logger.info('Kept the existing ${ForgeConfig.fileName} '
            '(use --force to overwrite).');
        return ExitCode.success.code;
      }
    }
    InitFlow(_logger, _prompter).run(
      project,
      acceptDefaults: args.flag('yes'),
      dryRun: args.flag('dry-run'),
    );
    _logger.success('\nReady. Try: forge g feature <name>');
    return ExitCode.success.code;
  }
}
