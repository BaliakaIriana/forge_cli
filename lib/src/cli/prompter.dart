import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Asks the user for missing input. Non-interactive sessions (CI, pipes)
/// must get everything from arguments.
abstract interface class Prompter {
  bool get interactive;

  String ask(String message, {String? defaultValue});

  bool confirm(String message, {bool defaultValue = true});

  T choose<T extends Object>(
    String message,
    List<T> choices, {
    T? defaultValue,
    String Function(T choice)? display,
  });
}

final class TerminalPrompter implements Prompter {
  TerminalPrompter(this._logger);

  final Logger _logger;

  @override
  bool get interactive => stdin.hasTerminal && stdout.hasTerminal;

  @override
  String ask(String message, {String? defaultValue}) =>
      _logger.prompt(message, defaultValue: defaultValue).trim();

  @override
  bool confirm(String message, {bool defaultValue = true}) =>
      _logger.confirm(message, defaultValue: defaultValue);

  @override
  T choose<T extends Object>(
    String message,
    List<T> choices, {
    T? defaultValue,
    String Function(T choice)? display,
  }) =>
      _logger.chooseOne<T>(
        message,
        choices: choices,
        defaultValue: defaultValue,
        display: display,
      );
}
