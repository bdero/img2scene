import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';

/// Compares a candidate render against a reference image and prints the
/// verdict. Exit code 0 when it passes, 1 when a blocking defect fires, 2 on a
/// usage or decode error.
void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json', help: 'Emit the verdict as JSON.', negatable: false)
    ..addOption(
      'silhouette-gate',
      help: 'Silhouette IoU below this rejects (default 0.85).',
    )
    ..addOption(
      'scale-gate',
      help: 'Linear-size-fraction delta above this rejects (default 0.15).',
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

  if (opts['help'] as bool || opts.rest.length != 2) {
    _usage(parser);
    exit(opts['help'] as bool ? 0 : 2);
  }

  final candidate = _decode(opts.rest[0]);
  final reference = _decode(opts.rest[1]);

  final base = const ComparatorConfig();
  final config = ComparatorConfig(
    silhouetteIouGate:
        _asDouble(opts['silhouette-gate']) ?? base.silhouetteIouGate,
    scaleDeltaGate: _asDouble(opts['scale-gate']) ?? base.scaleDeltaGate,
  );

  final result = compare(candidate, reference, config: config);

  if (opts['json'] as bool) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  } else {
    _printHuman(result);
  }
  exit(result.passed ? 0 : 1);
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

double? _asDouble(Object? v) => v == null ? null : double.tryParse(v as String);

void _printHuman(ComparisonResult r) {
  stdout.writeln(r.passed ? 'PASS' : 'FAIL');
  stdout.writeln('  silhouette IoU : ${_pct(r.silhouetteIou)}');
  stdout.writeln('  scale delta    : ${r.scaleDelta.toStringAsFixed(3)} '
      '(ratio ${r.scaleRatio.toStringAsFixed(2)})');
  stdout.writeln('  phash distance : ${r.phashDistance}/64');
  stdout.writeln('  edge overlap   : ${_pct(r.edgeOverlap)}');
  if (r.defects.isEmpty) return;
  stdout.writeln('  defects:');
  for (final d in r.defects) {
    stdout.writeln('    [${d.blocking ? 'x' : ' '}] ${d.tag}: ${d.detail}');
  }
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

void _usage(ArgParser parser) {
  stderr.writeln('Usage: dart run img2scene:compare <candidate> <reference>');
  stderr.writeln(parser.usage);
}
