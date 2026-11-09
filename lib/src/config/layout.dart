import '../core/name.dart';
import 'stack.dart';

/// A folder the generators write into.
enum Layer {
  entity('entities'),
  repository('repositories'),
  useCase('usecases'),
  model('models'),
  dataSource('data_sources'),
  repositoryImpl('repositories_impl'),
  state('state'),
  screen('screens'),
  widget('widgets'),
  dependencies('dependencies');

  const Layer(this.key);

  /// Key under `layout:` in `forge.yaml`.
  final String key;
}

/// Where each [Layer] lives, as project-relative paths that may contain the
/// `{feature}` placeholder (snake_case feature name).
///
/// Feature-first and layer-first architectures are both expressible:
/// `lib/src/features/{feature}/domain/entities` vs `lib/src/domain/entities`.
final class LayoutConfig {
  const LayoutConfig(this.paths);

  final Map<Layer, String> paths;

  static const featurePlaceholder = '{feature}';

  /// Directory of [layer] for [feature], project-relative, POSIX separators.
  String dir(Layer layer, Name feature) =>
      paths[layer]!.replaceAll(featurePlaceholder, feature.snake);

  /// Directory that holds one sub-folder per feature, when the layout has
  /// one (used to list existing features).
  String? get featuresRoot {
    final screen = paths[Layer.screen]!;
    final index = screen.indexOf(featurePlaceholder);
    if (index <= 0) return null;
    return screen.substring(0, index).replaceAll(RegExp(r'/$'), '');
  }

  LayoutConfig merge(Map<Layer, String> overrides) =>
      LayoutConfig({...paths, ...overrides});
}

/// Architectures observed in existing projects, offered at `forge init`.
enum LayoutPreset implements StackOption {
  featureFirst(
    'feature_first',
    'Feature-first: lib/src/features/<feature>/{domain,data,presentation} '
        '(klekoon_mobile, recommended)',
  ),
  featureFirstFlat(
    'feature_first_flat',
    'Feature-first without features/: lib/src/<feature>/... (kianja)',
  ),
  layerFirst(
    'layer_first',
    'Layer-first: lib/src/{domain,application,presentation}/... (ankle-box)',
  );

  const LayoutPreset(this.id, this.label);
  @override
  final String id;
  @override
  final String label;

  LayoutConfig get layout => switch (this) {
        featureFirst => _featureFirst('lib/src/features/{feature}'),
        featureFirstFlat => _featureFirst(
            'lib/src/{feature}',
            dataSources: 'datasources',
            screens: 'pages',
          ),
        layerFirst => const LayoutConfig({
            Layer.entity: 'lib/src/domain/entities',
            Layer.repository: 'lib/src/domain/repositories',
            Layer.useCase: 'lib/src/domain/use_cases/{feature}',
            Layer.model: 'lib/src/application/models',
            Layer.dataSource: 'lib/src/application/data_sources',
            Layer.repositoryImpl: 'lib/src/application/repositories',
            Layer.state: 'lib/src/presentation/features/{feature}/blocs',
            Layer.screen: 'lib/src/presentation/features/{feature}/pages',
            Layer.widget: 'lib/src/presentation/features/{feature}/widgets',
            Layer.dependencies:
                'lib/src/presentation/features/{feature}/providers',
          }),
      };

  /// Default screen class suffix for the preset.
  String get screenSuffix => this == featureFirst ? 'Screen' : 'Page';

  static LayoutConfig _featureFirst(
    String base, {
    String dataSources = 'data_sources',
    String screens = 'screens',
  }) =>
      LayoutConfig({
        Layer.entity: '$base/domain/entities',
        Layer.repository: '$base/domain/repositories',
        Layer.useCase: '$base/domain/usecases',
        Layer.model: '$base/data/models',
        Layer.dataSource: '$base/data/$dataSources',
        Layer.repositoryImpl: '$base/data/repositories',
        Layer.state: '$base/presentation/providers',
        Layer.screen: '$base/presentation/$screens',
        Layer.widget: '$base/presentation/widgets',
        Layer.dependencies: '$base/presentation/providers',
      });
}
