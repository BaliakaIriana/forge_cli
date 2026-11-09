import '../config/stack.dart';
import '../core/artifacts.dart';
import '../core/generation_plan.dart';
import '../core/name.dart';
import '../core/source_editor.dart';
import '../templates/core_templates.dart';
import '../templates/template_context.dart';

/// A screen to expose as a route.
final class RouteSpec {
  const RouteSpec(
      {required this.name, required this.screen, required this.path});

  final Name name;
  final Artifact screen;

  /// URL path, e.g. `/orders` or `/orders/:id`.
  final String path;
}

/// Adds a route to the project's router (Strategy per [Routing]).
abstract interface class RouteWiring {
  void addRoute(GenerationPlan plan, RouteSpec route);

  factory RouteWiring(TemplateContext ctx) => switch (ctx.stack.router) {
        Routing.goRouter => GoRouterWiring(ctx),
        Routing.autoRoute => AutoRouteWiring(ctx),
      };
}

final class GoRouterWiring implements RouteWiring {
  const GoRouterWiring(this.ctx);

  final TemplateContext ctx;

  @override
  void addRoute(GenerationPlan plan, RouteSpec route) {
    final routesFile = ctx.config.core.routes;
    final constant = route.name.camel;
    var pathExpression = "'${route.path}'";

    if (routesFile != null) {
      final snippet = "static const String $constant = '${route.path}';";
      plan.edit(
        routesFile,
        reason: 'route path $constant',
        snippet: snippet,
        transform: (source) =>
            SourceEditor.insertAtAnchor(source, Anchors.routePaths, snippet),
      );
      if (plan.read(routesFile)?.contains(snippet) ?? false) {
        final cls = RegExp(r'class\s+(\w+)')
                .firstMatch(plan.read(routesFile)!)
                ?.group(1) ??
            'AppRoutes';
        pathExpression = '$cls.$constant';
      }
    }

    final snippet = 'GoRoute(\n'
        '  path: $pathExpression,\n'
        "  name: '$constant',\n"
        '  builder: (context, state) => const ${route.screen.className}(),\n'
        '),';
    plan.edit(
      ctx.config.core.router,
      reason: 'route ${route.path}',
      snippet: snippet,
      transform: (source) {
        final inserted =
            SourceEditor.insertAtAnchor(source, Anchors.routes, snippet);
        if (inserted == null) return null;
        return SourceEditor.addImports(inserted, [
          ctx.uri(route.screen.path),
          if (routesFile != null && pathExpression != "'${route.path}'")
            ctx.uri(routesFile),
        ]);
      },
    );
  }
}

final class AutoRouteWiring implements RouteWiring {
  const AutoRouteWiring(this.ctx);

  final TemplateContext ctx;

  @override
  void addRoute(GenerationPlan plan, RouteSpec route) {
    final router = plan.read(ctx.config.core.router) ?? '';
    // auto_route names the route after the page class; with
    // `replaceInRouteName` the screen suffix becomes `Route`.
    final routeClass = router.contains('replaceInRouteName')
        ? '${route.name.pascal}Route'
        : '${route.screen.className}Route';
    final snippet = "AutoRoute(page: $routeClass.page, path: '${route.path}'),";
    plan
      ..markCodegen()
      ..edit(
        ctx.config.core.router,
        reason: 'route ${route.path}',
        snippet: snippet,
        transform: (source) =>
            SourceEditor.insertAtAnchor(source, Anchors.routes, snippet),
      );
  }
}
