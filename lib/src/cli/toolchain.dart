import '../core/project.dart';

/// Commands to suggest, prefixed with `fvm` when the project pins its SDK.
final class Toolchain {
  const Toolchain._(this._prefix);

  factory Toolchain.of(Project project) => Toolchain._(
        project.store.exists('.fvmrc') ||
                project.store.exists('.fvm/fvm_config.json')
            ? 'fvm '
            : '',
      );

  final String _prefix;

  String get flutter => '${_prefix}flutter';
  String get dart => '${_prefix}dart';

  String get buildRunner =>
      '$dart run build_runner build --delete-conflicting-outputs';
}
