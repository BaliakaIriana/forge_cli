import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../config/forge_config.dart';
import '../../core/generation_plan.dart';
import '../../core/name.dart';
import '../../core/project.dart';
import '../../generators/artifact_builder.dart';
import '../../templates/template_context.dart';
import '../init_flow.dart';
import '../plan_executor.dart';
import '../prompter.dart';
import '../toolchain.dart';

/// Everything a generator needs once arguments are resolved.
final class GeneratorInput {
  const GeneratorInput({
    required this.name,
    required this.feature,
    required this.builder,
    required this.plan,
    required this.prompter,
  });

  final String name;
  final Name feature;
  final ArtifactBuilder builder;
  final GenerationPlan plan;
  final Prompter prompter;
}

/// Base of every `forge generate <x>` command (Template Method): resolves
/// the project, config, name and feature, lets the subclass fill the plan,
/// then writes it.
abstract class GeneratorCommand extends Command<int> {
  GeneratorCommand(this.logger, this.prompter) {
    if (!nameIsFeature) {
      argParser.addOption(
        'feature',
        abbr: 'f',
        help: 'Feature the artifact belongs to (snake_case).',
      );
    }
    argParser
      ..addFlag(
        'dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Show the files that would be created/updated, write nothing.',
      )
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite files that already exist.',
      );
  }

  final Logger logger;
  final Prompter prompter;

  /// `forge g feature orders`: the name *is* the feature.
  bool get nameIsFeature => false;

  /// Shown when the name is prompted.
  String get namePrompt;

  @override
  String get invocation =>
      'forge generate $name <name>${nameIsFeature ? '' : ' --feature <feature>'}';

  void generate(GeneratorInput input);

  @override
  Future<int> run() async {
    final located = Project.locate(Directory.current);
    if (located == null) {
      logger.err('No pubspec.yaml found in this directory or its parents.');
      return ExitCode.usage.code;
    }
    final project = _ensureConfig(located);
    if (project == null) return ExitCode.config.code;
    final config = project.config!;
    final problems = config.stack.validate();
    if (problems.isNotEmpty) {
      logger.err('Invalid ${ForgeConfig.fileName}: ${problems.join('; ')}');
      return ExitCode.config.code;
    }

    final args = argResults!;
    final rawName = args.rest.firstOrNull ?? _promptRequired(namePrompt);
    final feature = nameIsFeature
        ? Name(rawName)
        : _resolveFeature(config, project, args.option('feature'));

    final plan = GenerationPlan(project.store);
    generate(
      GeneratorInput(
        name: rawName,
        feature: feature,
        builder: ArtifactBuilder(TemplateContext(project, config)),
        plan: plan,
        prompter: prompter,
      ),
    );

    final dryRun = args.flag('dry-run');
    final written = PlanExecutor(project.store, logger)
        .apply(plan, dryRun: dryRun, force: args.flag('force'));
    if (written > 0 && plan.usesCodegen && !dryRun) {
      logger.info('\nGenerated code uses build_runner. Run:\n'
          '  ${Toolchain.of(project).buildRunner}');
    }
    return ExitCode.success.code;
  }

  /// Runs `forge init` first on a never-configured project.
  Project? _ensureConfig(Project project) {
    if (project.config != null) return project;
    if (!prompter.interactive) {
      logger.err('No ${ForgeConfig.fileName}: run `forge init` first.');
      return null;
    }
    logger.info('No ${ForgeConfig.fileName} yet: let\'s configure forge.\n');
    final config = InitFlow(logger, prompter).run(project);
    logger.info('');
    return project.withConfig(config);
  }

  Name _resolveFeature(ForgeConfig config, Project project, String? option) {
    if (option != null) return Name(option);
    if (!prompter.interactive) {
      throw UsageException('Missing --feature.', usage);
    }
    final root = config.layout.featuresRoot;
    final existing =
        root == null ? <String>[] : project.store.subdirectories(root);
    const other = '+ new feature';
    if (existing.isEmpty) return Name(_promptRequired('Feature name'));
    final choice = prompter.choose<String>('Feature', [...existing, other]);
    return Name(choice == other ? _promptRequired('Feature name') : choice);
  }

  String _promptRequired(String message) {
    if (!prompter.interactive) {
      throw UsageException('Missing <name>.', usage);
    }
    final value = prompter.ask(message);
    if (value.isEmpty) throw UsageException('A name is required.', usage);
    return value;
  }
}
