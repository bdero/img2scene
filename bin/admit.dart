import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';

/// Gates whether an image is usable as a reference and prints the verdict. Exit
/// code 0 when admitted, 1 when rejected, 2 on a usage or decode error.
void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json', help: 'Emit the verdict as JSON.', negatable: false)
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

  final image = _decode(opts.rest[0]);
  final result = admitReference(image);

  if (opts['json'] as bool) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  } else {
    _printHuman(result);
  }
  exit(result.admitted ? 0 : 1);
}

img.Image _decode(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exit(2);
  }
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode image: $path');
    exit(2);
  }
  return decoded;
}

void _printHuman(AdmissionResult r) {
  stdout.writeln(r.admitted ? 'ADMIT' : 'REJECT');
  stdout.writeln('  short side          : ${r.metrics['shortSide']}');
  stdout.writeln('  coverage            : ${r.metrics['coverage']}');
  stdout.writeln('  largest blob        : ${r.metrics['largestBlobFraction']}');
  if (r.reasons.isEmpty) return;
  stdout.writeln('  reasons:');
  for (final reason in r.reasons) {
    stdout.writeln('    - $reason');
  }
}

void _usage(ArgParser parser) {
  stderr.writeln('Usage: dart run img2scene:admit <image.png> [--json]');
  stderr.writeln(parser.usage);
}
