import 'package:forge_cli/forge_cli.dart';
import 'package:test/test.dart';

void main() {
  test('forge.yaml round-trips', () {
    final config = ForgeConfig(
      stack: const StackConfig(
        state: StateManagement.riverpod,
        di: DependencyInjection.riverpod,
        router: Routing.autoRoute,
        network: Network.dio,
        dataClass: DataClass.freezed,
        functional: FunctionalLib.dartz,
        jsonFieldCase: JsonFieldCase.snake,
      ),
      layout: LayoutPreset.featureFirstFlat.layout,
      core: CorePaths.defaults.copyWith(routes: 'lib/routes.dart'),
      naming: const NamingConfig(screenSuffix: 'Page'),
    );
    final parsed = ForgeConfig.parse(config.toYaml());

    expect(parsed.stack.state, StateManagement.riverpod);
    expect(parsed.stack.router, Routing.autoRoute);
    expect(parsed.stack.functional, FunctionalLib.dartz);
    expect(parsed.stack.jsonFieldCase, JsonFieldCase.snake);
    expect(parsed.layout.paths, config.layout.paths);
    expect(parsed.core.routes, 'lib/routes.dart');
    expect(parsed.naming.screenSuffix, 'Page');
  });

  test('unknown option values are rejected', () {
    expect(
      () => ForgeConfig.parse('stack:\n  state: mobx\n'),
      throwsFormatException,
    );
  });

  test('riverpod state requires riverpod DI', () {
    const stack = StackConfig(state: StateManagement.riverpod);
    expect(stack.validate(), isNotEmpty);
  });

  test('layout resolves {feature} and the features root', () {
    final layout = LayoutPreset.featureFirst.layout;
    expect(
      layout.dir(Layer.useCase, Name('orders')),
      'lib/src/features/orders/domain/usecases',
    );
    expect(layout.featuresRoot, 'lib/src/features');
    expect(LayoutPreset.layerFirst.layout.featuresRoot,
        'lib/src/presentation/features');
  });
}
