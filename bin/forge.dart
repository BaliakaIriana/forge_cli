import 'dart:io';

import 'package:forge_cli/forge_cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await ForgeCommandRunner().run(arguments);
  await Future.wait([stdout.close(), stderr.close()]);
  exit(code);
}
