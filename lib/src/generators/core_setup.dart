import '../config/stack.dart';
import '../core/generation_plan.dart';
import '../core/source_editor.dart';
import '../templates/core_templates.dart';
import '../templates/template_context.dart';

/// Prepares the files generated code depends on: scaffolds the missing ones
/// and adds `// forge:*` anchors to the existing ones.
final class CoreSetup {
  CoreSetup(this.ctx) : _templates = CoreTemplates(ctx);

  final TemplateContext ctx;
  final CoreTemplates _templates;

  /// Core files absent from the project.
  List<String> missing(GenerationPlan plan) =>
      _required.where((path) => !plan.exists(path)).toList();

  List<String> get _required {
    final core = ctx.config.core;
    final stack = ctx.stack;
    return [
      core.failure,
      core.typedefs,
      core.taskRunner,
      if (stack.di != DependencyInjection.riverpod) core.di,
      if (stack.di == DependencyInjection.riverpod && core.dioProvider != null)
        core.dioProvider!,
      core.router,
      if (stack.router == Routing.goRouter && core.routes != null) core.routes!,
    ];
  }

  void apply(GenerationPlan plan, {required bool scaffoldMissing}) {
    final core = ctx.config.core;
    if (scaffoldMissing) {
      for (final path in missing(plan)) {
        plan.create(path, _scaffold(path));
      }
    }
    if (ctx.stack.di == DependencyInjection.getIt) {
      _anchor(
        plan,
        core.di,
        Anchors.di,
        RegExp(r'configureDependencies\s*\([^)]*\)\s*(async\s*)?\{'),
      );
    }
    _anchor(
      plan,
      core.router,
      [Anchors.routes],
      RegExp(r'routes\s*(:|=>)\s*(<\w+>)?\s*\['),
    );
    if (ctx.stack.router == Routing.goRouter && core.routes != null) {
      _anchor(
        plan,
        core.routes!,
        [Anchors.routePaths],
        RegExp(r'class\s+AppRoutes\b[^{]*\{'),
      );
    }
  }

  String _scaffold(String path) {
    final core = ctx.config.core;
    if (path == core.failure) return _templates.failure();
    if (path == core.typedefs) return _templates.typedefs();
    if (path == core.taskRunner) return _templates.taskRunner();
    if (path == core.di) return _templates.di();
    if (path == core.dioProvider) return _templates.dioProvider();
    if (path == core.router) return _templates.router();
    return _templates.routes();
  }

  /// Adds [anchors] before the end of the block opened by [opener].
  void _anchor(
    GenerationPlan plan,
    String path,
    List<String> anchors,
    RegExp opener,
  ) {
    final source = plan.read(path);
    if (source == null) return;
    final missingAnchors =
        anchors.where((a) => !SourceEditor.hasAnchor(source, a)).toList();
    if (missingAnchors.isEmpty) return;
    final match = opener.firstMatch(source);
    final snippet = missingAnchors.map(SourceEditor.anchorComment).join('\n');
    plan.edit(
      path,
      reason: 'add anchors ${missingAnchors.join(', ')}',
      snippet: snippet,
      transform: (s) => match == null
          ? null
          : SourceEditor.insertAnchorsBeforeClose(
              s,
              match.end - 1,
              missingAnchors,
            ),
    );
  }
}
