import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img2scene/img2scene.dart';
import 'package:img2scene_render/emitter.dart';
import 'package:integration_test/integration_test.dart';

// Paths passed by the orchestrator CLI.
const _specPath = String.fromEnvironment('IMG2SCENE_SPEC');
const _outPath = String.fromEnvironment('IMG2SCENE_OUT');
const _size = int.fromEnvironment('IMG2SCENE_SIZE', defaultValue: 512);

final _boundaryKey = GlobalKey();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the spec to a PNG', (tester) async {
    expect(_specPath, isNotEmpty, reason: 'IMG2SCENE_SPEC must be set');
    expect(_outPath, isNotEmpty, reason: 'IMG2SCENE_OUT must be set');

    final spec = SceneSpec.parse(File(_specPath).readAsStringSync());
    final background = spec.background ?? const [0.09, 0.09, 0.10];
    final clear = Color.from(
      alpha: 1,
      red: background[0],
      green: background[1],
      blue: background[2],
    );

    // One ordinary frame before touching flutter_scene, then wait for the
    // static resources the renderer gates on.
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: clear, body: const SizedBox.expand()),
      ),
    );
    await tester.pump();
    await Scene.initializeStaticResources();

    final emitted = buildScene(spec);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: clear,
          body: Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox(
                width: _size.toDouble(),
                height: _size.toDouble(),
                child: SceneView(emitted.scene, camera: emitted.camera),
              ),
            ),
          ),
        ),
      ),
    );

    // Let the scene settle so the capture is not a half-ramped frame.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    final boundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File(_outPath).writeAsBytesSync(png.buffer.asUint8List());
    // ignore: avoid_print
    print('IMG2SCENE wrote ${image.width}x${image.height} to $_outPath');
  });
}
