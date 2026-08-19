import 'package:flutter/material.dart';

/// The render harness has no interactive UI. Its real entry point is the
/// integration test at integration_test/render_test.dart, which the img2scene
/// orchestrator drives to emit a SceneSpec and capture a candidate PNG. This
/// main exists only so the platform app builds.
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('img2scene render harness')),
        ),
      );
}
