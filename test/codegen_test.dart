import 'package:img2scene/img2scene.dart';
import 'package:test/test.dart';

void main() {
  // A body cuboid with a sphere head child, a material, and a framing camera.
  final spec = SceneSpec(
    camera: CameraSpec(position: [0, 2, -6], target: [0, 1, 0], fovDegrees: 50),
    parts: [
      PartSpec(
        name: 'body',
        primitive:
            PrimitiveSpec('cuboid', {'sizeX': 1, 'sizeY': 2, 'sizeZ': 1}),
        position: [0, 1, 0],
        rotation: [0, 90, 0],
        material: MaterialSpec(
          baseColor: [0.8, 0.2, 0.2, 1],
          metallic: 0,
          roughness: 0.6,
        ),
        children: [
          PartSpec(
            name: 'head',
            primitive: PrimitiveSpec('sphere', {'radius': 0.5}),
            position: [0, 1.5, 0],
            scale: [1, 1, 1],
          ),
        ],
      ),
    ],
  );

  test('generates a self-contained builder function', () {
    final source = generateDartSource(spec);

    expect(source, isNotEmpty);
    expect(source, contains('BuiltScene buildScene()'));
    expect(source, contains('class BuiltScene {'));
    expect(source, contains('return BuiltScene(root, camera);'));
  });

  test('maps primitives to their geometry constructors', () {
    final source = generateDartSource(spec);

    expect(source, contains('CuboidGeometry(vm.Vector3(1.0, 2.0, 1.0))'));
    expect(source, contains('SphereGeometry(radius: 0.5)'));
  });

  test('emits the material and its present fields', () {
    final source = generateDartSource(spec);

    expect(source, contains('PhysicallyBasedMaterial()'));
    expect(
        source, contains('..baseColorFactor = vm.Vector4(0.8, 0.2, 0.2, 1.0)'));
    expect(source, contains('..metallicFactor = 0.0'));
    expect(source, contains('..roughnessFactor = 0.6'));
  });

  test('emits the camera and the euler rotation in radians', () {
    final source = generateDartSource(spec);

    expect(source, contains('PerspectiveCamera('));
    expect(source, contains('fovRadiansY: 50.0 * pi / 180'));
    // rotation [0, 90, 0] degrees emits euler(yaw, pitch, roll).
    expect(
      source,
      contains('vm.Quaternion.euler(90.0 * pi / 180, 0.0 * pi / 180, '
          '0.0 * pi / 180)'),
    );
  });

  test('wires the child onto its parent node', () {
    final source = generateDartSource(spec);

    expect(source, contains('root.add('));
    expect(source, contains('body0.add(head1)'));
  });

  test('honors a custom function name', () {
    final source = generateDartSource(spec, functionName: 'assemble');

    expect(source, contains('BuiltScene assemble()'));
  });
}
