import 'dart:io';

import 'package:args/args.dart';
import 'package:img2scene/img2scene.dart';

/// Reads a scene spec JSON file and emits copy-paste flutter_scene Dart source
/// that rebuilds the same node tree. Writes to the `-o` path or stdout. Exit
/// code 0 on success, 2 on a usage or parse error.
void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o', help: 'Write to this file instead of stdout.')
    ..addOption(
      'function',
      abbr: 'f',
      help: 'Name of the generated function (default buildScene).',
    )
    ..addFlag('help', abbr: 'h', help: 'Show usage.', negatable: false);

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    _usage(parser);
    exit(2);
  }

  if (opts['help'] as bool || opts.rest.length != 1) {
    _usage(parser);
    exit(opts['help'] as bool ? 0 : 2);
  }

  final path = opts.rest[0];
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exit(2);
  }

  final SceneSpec spec;
  try {
    spec = SceneSpec.parse(file.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('Could not parse spec: ${e.message}');
    exit(2);
  } catch (e) {
    stderr.writeln('Invalid spec: $e');
    exit(2);
  }

  final source = generateDartSource(
    spec,
    functionName: (opts['function'] as String?) ?? 'buildScene',
  );

  final outPath = opts['output'] as String?;
  if (outPath == null) {
    stdout.write(source);
  } else {
    File(outPath).writeAsStringSync(source);
    stderr.writeln('Wrote $outPath');
  }
  exit(0);
}

void _usage(ArgParser parser) {
  stderr.writeln('Usage: dart run img2scene:emit <spec.json> [-o out.dart]');
  stderr.writeln(parser.usage);
}
