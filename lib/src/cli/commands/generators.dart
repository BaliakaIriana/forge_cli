import 'package:mason_logger/mason_logger.dart';

import 'package:args/command_runner.dart';

import '../../core/artifacts.dart';
import '../../core/name.dart';
import '../../generators/l10n_key_builder.dart';
import '../prompter.dart';
import '../toolchain.dart';
import 'generator_command.dart';

const _fieldsHelp = 'Fields as name:Type pairs, comma separated '
    '(e.g. "id:String,total:double,note:String?"). Default: id:String.';

List<Field>? _fields(String? raw) {
  final fields = Field.parseAll(raw);
  return fields.isEmpty ? null : fields;
}

/// Every generator, in the order shown by `forge g --help`.
List<GeneratorCommand> generatorCommands(Logger logger, Prompter prompter) => [
      FeatureGenerator(logger, prompter),
      EntityGenerator(logger, prompter),
      ModelGenerator(logger, prompter),
      DataSourceGenerator(logger, prompter),
      RepositoryGenerator(logger, prompter),
      UseCaseGenerator(logger, prompter),
      StateGenerator(logger, prompter),
      ScreenGenerator(logger, prompter),
      WidgetGenerator(logger, prompter),
      L10nKeyGenerator(logger, prompter),
    ];

final class FeatureGenerator extends GeneratorCommand {
  FeatureGenerator(super.logger, super.prompter) {
    argParser
      ..addOption('entity',
          abbr: 'e', help: 'Entity name. Default: singular of the feature.')
      ..addOption('fields', help: _fieldsHelp)
      ..addFlag('screen',
          defaultsTo: true, help: 'Generate the screen and its route.');
  }

  @override
  String get name => 'feature';
  @override
  List<String> get aliases => const ['resource', 'f'];
  @override
  String get description =>
      'Full vertical slice: entity, model, data source, repository, use case, '
      'state holder, screen, wired into DI and routing.';
  @override
  bool get nameIsFeature => true;
  @override
  String get namePrompt => 'Feature name (e.g. orders)';

  @override
  void generate(GeneratorInput input) {
    final args = argResults!;
    var entity = args.option('entity');
    var fields = args.option('fields');
    if (input.prompter.interactive && args.rest.isEmpty) {
      entity ??= input.prompter
          .ask('Entity name', defaultValue: input.feature.singular.pascal);
      fields ??= input.prompter
          .ask('Entity fields (name:Type, ...)', defaultValue: 'id:String');
    }
    input.builder.feature(
      input.plan,
      input.feature,
      entityName: entity == null ? null : Name(entity),
      fields: _fields(fields),
      withScreen: args.flag('screen'),
    );
  }
}

final class EntityGenerator extends GeneratorCommand {
  EntityGenerator(super.logger, super.prompter) {
    argParser.addOption('fields', help: _fieldsHelp);
  }

  @override
  String get name => 'entity';
  @override
  List<String> get aliases => const ['e'];
  @override
  String get description => 'Domain entity (immutable, value equality).';
  @override
  String get namePrompt => 'Entity name (e.g. Order)';

  @override
  void generate(GeneratorInput input) => input.builder.entity(
        input.plan,
        input.feature,
        Name(input.name),
        fields: _fields(argResults!.option('fields')),
      );
}

final class ModelGenerator extends GeneratorCommand {
  ModelGenerator(super.logger, super.prompter) {
    argParser.addOption('fields', help: _fieldsHelp);
  }

  @override
  String get name => 'model';
  @override
  List<String> get aliases => const ['dto'];
  @override
  String get description =>
      'JSON model (DTO) with toEntity() when the entity exists.';
  @override
  String get namePrompt => 'Entity name the model maps (e.g. Order)';

  @override
  void generate(GeneratorInput input) => input.builder.model(
        input.plan,
        input.feature,
        Name(input.name).withoutSuffix('Model'),
        fields: _fields(argResults!.option('fields')),
      );
}

final class DataSourceGenerator extends GeneratorCommand {
  DataSourceGenerator(super.logger, super.prompter);

  @override
  String get name => 'data-source';
  @override
  List<String> get aliases => const ['datasource', 'ds'];
  @override
  String get description =>
      'Remote data source (Retrofit, Dio, or client-free with network: none), '
      'registered in DI.';
  @override
  String get namePrompt => 'Data source name (e.g. orders)';

  @override
  void generate(GeneratorInput input) => input.builder.dataSource(
        input.plan,
        input.feature,
        input.builder.artifacts.dataSourceName(input.name),
      );
}

final class RepositoryGenerator extends GeneratorCommand {
  RepositoryGenerator(super.logger, super.prompter);

  @override
  String get name => 'repository';
  @override
  List<String> get aliases => const ['repo', 'r'];
  @override
  String get description =>
      'Repository contract (domain) + implementation (data), registered in DI. '
      'Named after the feature.';
  @override
  bool get nameIsFeature => true;
  @override
  String get namePrompt => 'Feature name (e.g. orders)';

  @override
  void generate(GeneratorInput input) =>
      input.builder.repository(input.plan, input.feature);
}

final class UseCaseGenerator extends GeneratorCommand {
  UseCaseGenerator(super.logger, super.prompter) {
    argParser.addOption(
      'returns',
      help: 'T in FutureEither<T> (e.g. "List<Order>"). Default: void.',
    );
  }

  @override
  String get name => 'usecase';
  @override
  List<String> get aliases => const ['use-case', 'uc'];
  @override
  String get description =>
      'Use case calling the feature repository; adds the repository method '
      'when missing. Registered in DI.';
  @override
  String get namePrompt => 'Use case name (e.g. get_order)';

  @override
  void generate(GeneratorInput input) {
    var returns = argResults!.option('returns');
    if (returns == null &&
        input.prompter.interactive &&
        argResults!.rest.isEmpty) {
      returns = input.prompter
          .ask('Return type (T of FutureEither<T>)', defaultValue: 'void');
    }
    input.builder.useCase(
      input.plan,
      input.feature,
      input.builder.artifacts.useCaseName(input.name),
      returnType: returns ?? 'void',
    );
  }
}

final class StateGenerator extends GeneratorCommand {
  StateGenerator(super.logger, super.prompter) {
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help:
          'Use cases of the feature to inject (e.g. get_orders,delete_order). '
          'The first one without parameter loads the state.',
    );
  }

  @override
  String get name => 'state';
  @override
  List<String> get aliases =>
      const ['bloc', 'provider', 'notifier', 'controller', 's'];
  @override
  String get description =>
      'State holder of the configured stack: Bloc (bloc/event/state files, '
      'DI factory) or Riverpod notifier.';
  @override
  String get namePrompt => 'State name (e.g. orders)';

  @override
  void generate(GeneratorInput input) {
    final artifacts = input.builder.artifacts;
    input.builder.state(
      input.plan,
      input.feature,
      artifacts.stateName(input.name),
      useCases: argResults!
          .multiOption('usecases')
          .map(artifacts.useCaseName)
          .toList(),
    );
  }
}

final class ScreenGenerator extends GeneratorCommand {
  ScreenGenerator(super.logger, super.prompter) {
    argParser
      ..addOption('state',
          help:
              'State holder to provide/watch. Default: the one with the same name, if any.')
      ..addOption('route', help: 'Route path. Default: /<name-in-kebab-case>.')
      ..addFlag('no-route', negatable: false, help: 'Do not register a route.');
  }

  @override
  String get name => 'screen';
  @override
  List<String> get aliases => const ['page', 'sc'];
  @override
  String get description =>
      'Screen, provided with its state holder and registered as a route.';
  @override
  String get namePrompt => 'Screen name (e.g. order_detail)';

  @override
  void generate(GeneratorInput input) {
    final args = argResults!;
    final artifacts = input.builder.artifacts;
    final name = artifacts.screenName(input.name);
    final state = args.option('state');
    input.builder.screen(
      input.plan,
      input.feature,
      name,
      stateName: state == null ? null : artifacts.stateName(state),
      routePath: args.flag('no-route')
          ? null
          : args.option('route') ?? '/${name.kebab}',
    );
  }
}

final class WidgetGenerator extends GeneratorCommand {
  WidgetGenerator(super.logger, super.prompter) {
    argParser.addFlag('stateful',
        negatable: false, help: 'Generate a StatefulWidget.');
  }

  @override
  String get name => 'widget';
  @override
  List<String> get aliases => const ['w'];
  @override
  String get description => 'Widget in the feature presentation layer.';
  @override
  String get namePrompt => 'Widget name (e.g. order_card)';

  @override
  void generate(GeneratorInput input) => input.builder.widget(
        input.plan,
        input.feature,
        Name(input.name),
        stateful: argResults!.flag('stateful'),
      );
}

final class L10nKeyGenerator extends GeneratorCommand {
  L10nKeyGenerator(super.logger, super.prompter) {
    argParser
      ..addMultiOption(
        'text',
        abbr: 't',
        splitCommas: false,
        help: 'Message per locale, as locale=text (repeatable): '
            '-t fr="Bonjour {name}" -t en="Hello {name}". A second positional '
            'argument is the template-locale text.',
      )
      ..addOption('description',
          help: 'Description stored in @key (template).');
  }

  @override
  String get name => 'l10n-key';
  @override
  List<String> get aliases => const ['l10n', 'i18n', 'tr'];
  @override
  String get description =>
      'Translation key added to every ARB file (gen-l10n), with placeholders '
      'metadata deduced from {name} / {count, plural, ...}.';
  @override
  bool get usesFeature => false;
  @override
  bool get requiresConfig => false;
  @override
  String get namePrompt => 'Key (e.g. orders_empty_title)';
  @override
  String get invocation =>
      'forge generate l10n-key <key> [template text] [-t <locale>=<text> ...]';

  @override
  void generate(GeneratorInput input) {
    final args = argResults!;
    final key = Name(input.name).camel;
    final builder = L10nKeyBuilder(input.project.store);
    final files = builder.arbFiles();
    final template = files.where((f) => f.isTemplate).firstOrNull;

    final messages = <String, String>{};
    for (final entry in args.multiOption('text')) {
      final separator = entry.indexOf('=');
      if (separator <= 0) {
        throw UsageException(
            '--text expects locale=text, got "$entry".', usage);
      }
      messages[entry.substring(0, separator).trim()] =
          entry.substring(separator + 1);
    }
    if (template != null && args.rest.length > 1) {
      messages.putIfAbsent(template.locale, () => args.rest[1]);
    }

    var description = args.option('description');
    if (input.prompter.interactive && template != null) {
      for (final file in files) {
        if (messages.containsKey(file.locale)) continue;
        final text = input.prompter.ask(
          '${file.locale} text${file.isTemplate ? ' (template)' : ''}',
          defaultValue: file.isTemplate ? null : messages[template.locale],
        );
        if (text.isNotEmpty) messages[file.locale] = text;
      }
      description ??= input.prompter.ask('Description (optional)');
    }
    if (template != null && !messages.containsKey(template.locale)) {
      throw UsageException(
        'Missing the ${template.locale} (template) text: '
        '-t ${template.locale}="...".',
        usage,
      );
    }

    builder.add(
      input.plan,
      key: key,
      messages: messages,
      description: description,
      force: args.flag('force'),
    );
    final flutter = Toolchain.of(input.project).flutter;
    input.plan.hint('Regenerate localizations: $flutter gen-l10n\n'
        'Use it: ${builder.settings.outputClass}.of(context)!.$key');
  }
}
