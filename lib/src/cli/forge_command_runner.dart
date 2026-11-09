import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../version.dart';
import 'commands/generator_command.dart';
import 'commands/generators.dart';
import 'commands/init_command.dart';
import 'prompter.dart';

final class GenerateCommand extends Command<int> {
  GenerateCommand(List<GeneratorCommand> generators) {
    generators.forEach(addSubcommand);
  }

  @override
  String get name => 'generate';
  @override
  List<String> get aliases => const ['g'];
  @override
  String get description => 'Generate an artifact (like `ng generate`).';
}

final class ForgeCommandRunner extends CommandRunner<int> {
  ForgeCommandRunner({Logger? logger, Prompter? prompter})
      : _logger = logger ?? Logger(),
        super(
          'forge',
          'Clean Architecture code generator for Flutter projects.',
        ) {
    final ask = prompter ?? TerminalPrompter(_logger);
    _generators = generatorCommands(_logger, ask);
    _prompter = ask;
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the forge version.',
    );
    addCommand(InitCommand(_logger, ask));
    addCommand(GenerateCommand(_generators));
  }

  final Logger _logger;
  late final Prompter _prompter;
  late final List<GeneratorCommand> _generators;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final list = args.toList();
      if (list.isEmpty && _prompter.interactive) return await _interactive();
      if (list.length == 1 &&
          (list.first == 'g' || list.first == 'generate') &&
          _prompter.interactive) {
        return await _interactiveGenerate();
      }
      final results = parse(list);
      if (results.flag('version')) {
        _logger.info('forge $packageVersion');
        return ExitCode.success.code;
      }
      return await runCommand(results) ?? ExitCode.success.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } on FormatException catch (e) {
      _logger.err(e.toString());
      return ExitCode.data.code;
    }
  }

  Future<int> _interactive() async {
    const init = 'init';
    const generate = 'generate';
    final action = _prompter.choose<String>(
      'What do you want to do?',
      [generate, init],
      display: (a) => a == init
          ? 'init      configure forge for this project'
          : 'generate  create a feature, use case, screen…',
    );
    return action == init ? run(const ['init']) : _interactiveGenerate();
  }

  Future<int> _interactiveGenerate() async {
    final width =
        _generators.map((g) => g.name.length).reduce((a, b) => a > b ? a : b);
    final generator = _prompter.choose<GeneratorCommand>(
      'Generate',
      _generators,
      display: (g) =>
          '${g.name.padRight(width)}  ${darkGray.wrap(g.description)}',
    );
    return run(['generate', generator.name]);
  }
}
