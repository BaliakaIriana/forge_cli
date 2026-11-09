import 'package:mason_logger/mason_logger.dart';

import '../config/forge_config.dart';
import '../config/layout.dart';
import '../config/project_detector.dart';
import '../config/stack.dart';
import '../core/generation_plan.dart';
import '../core/project.dart';
import '../generators/core_setup.dart';
import '../templates/template_context.dart';
import 'plan_executor.dart';
import 'prompter.dart';
import 'toolchain.dart';

/// `forge init`: detects the stack, asks to confirm each choice, writes
/// `forge.yaml`, scaffolds missing core files and adds anchors.
final class InitFlow {
  const InitFlow(this._logger, this._prompter);

  final Logger _logger;
  final Prompter _prompter;

  ForgeConfig run(
    Project project, {
    bool acceptDefaults = false,
    bool dryRun = false,
  }) {
    final detection = ProjectDetector(project).detect();
    final ask = !acceptDefaults && _prompter.interactive;
    if (ask) {
      _logger.info(
        'Configuring forge for ${styleBold.wrap(project.packageName)} '
        '${darkGray.wrap('(defaults detected from pubspec.yaml and lib/)')}',
      );
    }

    T pick<T extends StackOption>(String message, List<T> values, T detected) =>
        ask
            ? _prompter.choose<T>(
                message,
                values,
                defaultValue: detected,
                display: (v) => v.label,
              )
            : detected;

    final state = pick(
      'State management',
      StateManagement.values,
      detection.stack.state,
    );
    final di = state == StateManagement.riverpod
        ? DependencyInjection.riverpod
        : pick(
            'Dependency injection',
            [DependencyInjection.getIt, DependencyInjection.injectable],
            detection.stack.di == DependencyInjection.riverpod
                ? DependencyInjection.getIt
                : detection.stack.di,
          );
    final stack = StackConfig(
      state: state,
      di: di,
      router: pick('Routing', Routing.values, detection.stack.router),
      network: pick('Networking', Network.values, detection.stack.network),
      dataClass: pick(
        'Entities, models and states',
        DataClass.values,
        detection.stack.dataClass,
      ),
      functional: pick(
        'Either / Failure library',
        FunctionalLib.values,
        detection.stack.functional,
      ),
      jsonFieldCase: pick(
        'JSON key casing of the API',
        JsonFieldCase.values,
        detection.stack.jsonFieldCase,
      ),
    );
    final preset = pick('Architecture', LayoutPreset.values, detection.preset);

    final config = ForgeConfig(
      stack: stack,
      layout: preset == detection.preset ? detection.layout : preset.layout,
      core: detection.core,
      naming: NamingConfig(
        screenSuffix: preset == detection.preset
            ? detection.screenSuffix
            : preset.screenSuffix,
      ),
    );

    final plan = GenerationPlan(project.store)
      ..create(ForgeConfig.fileName, config.toYaml());
    final setup = CoreSetup(TemplateContext(project, config));
    final missing = setup.missing(plan);
    final scaffold = missing.isNotEmpty &&
        (!ask ||
            _prompter.confirm(
              'Create the missing core files?\n'
              '${missing.map((m) => '  - $m').join('\n')}\n',
            ));
    setup.apply(plan, scaffoldMissing: scaffold);

    _logger.info('');
    PlanExecutor(project.store, _logger)
        .apply(plan, dryRun: dryRun, force: true);
    _reportPackages(project, stack);
    return config;
  }

  void _reportPackages(Project project, StackConfig stack) {
    final declared = project.declaredPackages;
    final packages = stack.packages;
    final deps =
        packages.dependencies.where((p) => !declared.contains(p)).toList();
    final dev =
        packages.devDependencies.where((p) => !declared.contains(p)).toList();
    if (deps.isEmpty && dev.isEmpty) return;
    final flutter = Toolchain.of(project).flutter;
    _logger
      ..info('')
      ..warn('Packages used by the generated code are missing:');
    if (deps.isNotEmpty) _logger.info('  $flutter pub add ${deps.join(' ')}');
    if (dev.isNotEmpty) {
      _logger.info('  $flutter pub add --dev ${dev.join(' ')}');
    }
  }
}
