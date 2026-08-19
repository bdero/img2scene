import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';

/// Renders a [SceneSpec] with the headless flutter_scene harness and scores the
/// result against a reference image. The one command a correction loop runs.
///
/// Exit 0 when the render passes the comparator gates, 1 when it fails, 2 on a
/// usage, spec, or render error.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('out', abbr: 'o', help: 'Keep the rendered candidate PNG here.')
    ..addOption('size', help: 'Render size in pixels.', defaultsTo: '512')
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
  if (opts['help'] as bool || opts.rest.length != 2) {
    _usage(parser);
    exit(opts['help'] as bool ? 0 : 2);
  }

  final specPath = File(opts.rest[0]).absolute.path;
  final refPath = File(opts.rest[1]).absolute.path;
  if (!File(specPath).existsSync()) _fail('No such spec: $specPath');
  if (!File(refPath).existsSync()) _fail('No such reference: $refPath');

  final SceneSpec spec;
  try {
    spec = SceneSpec.parse(File(specPath).readAsStringSync());
  } catch (e) {
    _fail('Could not parse the spec: $e');
  }
  final specErrors = spec.validate();
  if (specErrors.isNotEmpty) {
    stderr.writeln('Spec is invalid:');
    for (final e in specErrors) {
      stderr.writeln('  - $e');
    }
    exit(2);
  }

  final keepOut = opts['out'] as String?;
  final outPath = keepOut == null
      ? '${Directory.systemTemp.createTempSync('img2scene').path}/candidate.png'
      : File(keepOut).absolute.path;

  final harness = await _renderHarnessDir();
  if (harness == null || !Directory(harness).existsSync()) {
    _fail('Could not locate the render harness (render_harness/).');
  }

  stderr.writeln('Rendering the spec (flutter_scene, macOS)...');
  final render = await Process.run(
      'flutter',
      [
        'test',
        'integration_test/render_test.dart',
        '-d',
        'macos',
        '--dart-define=IMG2SCENE_SPEC=$specPath',
        '--dart-define=IMG2SCENE_OUT=$outPath',
        '--dart-define=IMG2SCENE_SIZE=${opts['size']}',
      ],
      workingDirectory: harness);

  if (render.exitCode != 0 || !File(outPath).existsSync()) {
    stderr.writeln('Render failed:');
    stderr.writeln(render.stdout);
    stderr.writeln(render.stderr);
    exit(2);
  }

  final candidate = img.decodeImage(File(outPath).readAsBytesSync());
  final reference = img.decodeImage(File(refPath).readAsBytesSync());
  if (candidate == null || reference == null) {
    _fail('Could not decode the rendered candidate or the reference.');
  }

  final result = compare(candidate, reference);
  if (opts['json'] as bool) {
    stdout.writeln(_json(result, outPath));
  } else {
    _printHuman(result, outPath, keepOut != null);
  }
  exit(result.passed ? 0 : 1);
}

Future<String?> _renderHarnessDir() async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:img2scene/img2scene.dart'),
  );
  return lib?.resolve('../render_harness/').toFilePath();
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(2);
}

String _json(ComparisonResult r, String out) {
  final map = r.toJson()..['candidate'] = out;
  return const JsonEncoder.withIndent('  ').convert(map);
}

void _printHuman(ComparisonResult r, String out, bool kept) {
  stdout.writeln(r.passed ? 'PASS' : 'FAIL');
  stdout.writeln(
      '  silhouette IoU : ${(r.silhouetteIou * 100).toStringAsFixed(1)}%');
  stdout.writeln('  scale delta    : ${r.scaleDelta.toStringAsFixed(3)} '
      '(ratio ${r.scaleRatio.toStringAsFixed(2)})');
  stdout.writeln('  phash distance : ${r.phashDistance}/64');
  stdout.writeln(
      '  edge overlap   : ${(r.edgeOverlap * 100).toStringAsFixed(1)}%');
  for (final d in r.defects) {
    stdout.writeln('  [${d.blocking ? 'x' : ' '}] ${d.tag}: ${d.detail}');
  }
  if (kept) stdout.writeln('  candidate: $out');
}

void _usage(ArgParser parser) {
  stderr.writeln('Usage: dart run img2scene <spec.json> <reference.png>');
  stderr.writeln(parser.usage);
}
