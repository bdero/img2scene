import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:img2scene/img2scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A built scene plus the camera that frames it, ready for a `SceneView`.
class EmittedScene {
  EmittedScene(this.scene, this.camera);
  final Scene scene;
  final Camera camera;
}

/// Deterministically turns a [SceneSpec] into a flutter_scene node tree. Pure
/// mapping, no model call, so the same spec always renders the same way.
EmittedScene buildScene(SceneSpec spec) {
  final scene = Scene();
  applyLook(scene, spec.look);
  for (final part in spec.parts) {
    scene.add(_buildNode(part));
  }
  final camera = PerspectiveCamera(
    position: _vec3(spec.camera.position),
    target: _vec3(spec.camera.target),
    fovRadiansY: spec.camera.fovDegrees * math.pi / 180,
  );
  return EmittedScene(scene, camera);
}

Node _buildNode(PartSpec part) {
  final node = Node(
    name: part.name,
    mesh: Mesh(_geometry(part.primitive), _material(part.material)),
  );
  if (part.position != null) node.position = _vec3(part.position!);
  if (part.rotation != null) node.rotation = _euler(part.rotation!);
  if (part.scale != null) node.scale = _vec3(part.scale!);
  for (final child in part.children) {
    node.add(_buildNode(child));
  }
  return node;
}

Geometry _geometry(PrimitiveSpec p) {
  double v(String k, double d) => p.param(k, d);
  switch (p.kind) {
    case 'cuboid':
      final s = v('size', 1);
      return CuboidGeometry(
          vm.Vector3(v('sizeX', s), v('sizeY', s), v('sizeZ', s)));
    case 'sphere':
      return SphereGeometry(radius: v('radius', 0.5));
    case 'icosphere':
      return IcosphereGeometry(radius: v('radius', 0.5));
    case 'cylinder':
      return CylinderGeometry(
        bottomRadius: v('bottomRadius', v('radius', 0.5)),
        topRadius: v('topRadius', v('radius', 0.5)),
        height: v('height', 1),
      );
    case 'cone':
      return CylinderGeometry(
        bottomRadius: v('radius', 0.5),
        topRadius: 0,
        height: v('height', 1),
      );
    case 'capsule':
      return CapsuleGeometry(radius: v('radius', 0.5), height: v('height', 1));
    case 'torus':
      return TorusGeometry(
        radius: v('radius', 0.5),
        tubeRadius: v('tubeRadius', 0.2),
      );
    case 'plane':
      return PlaneGeometry(width: v('width', 1), depth: v('depth', 1));
    case 'disc':
      return DiscGeometry(radius: v('radius', 0.5));
    case 'ring':
      return RingGeometry(
        innerRadius: v('innerRadius', 0.25),
        outerRadius: v('outerRadius', 0.5),
      );
    case 'wedge':
      final s = v('size', 1);
      return WedgeGeometry(
          vm.Vector3(v('sizeX', s), v('sizeY', s), v('sizeZ', s)));
    default:
      return CuboidGeometry(vm.Vector3.all(1));
  }
}

Material _material(MaterialSpec? m) {
  final mat = PhysicallyBasedMaterial();
  if (m == null) return mat;
  if (m.baseColor != null) mat.baseColorFactor = _vec4(m.baseColor!);
  if (m.metallic != null) mat.metallicFactor = m.metallic!;
  if (m.roughness != null) mat.roughnessFactor = m.roughness!;
  if (m.emissive != null) {
    final e = m.emissive!;
    mat.emissiveFactor = vm.Vector4(e[0], e[1], e[2], e.length > 3 ? e[3] : 1);
  }
  return mat;
}

/// Applies a named look preset. Mirrors the flutter_scene-looks recipes.
void applyLook(Scene scene, String look) {
  switch (look) {
    case 'stylized':
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        colorGradingEnabled: true,
        saturation: 1.25,
        contrast: 1.1,
        bloomEnabled: true,
        bloomThreshold: 0.9,
        bloomIntensity: 0.28,
      );
    case 'moody':
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        exposure: 0.85,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        vignetteEnabled: true,
        vignetteIntensity: 0.5,
      );
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.4, -1.0, -0.3),
        intensity: 3.5,
        castsShadow: true,
      );
    case 'clean':
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.pbrNeutral,
        ambientOcclusionEnabled: true,
        ambientOcclusionHalfResolution: true,
      );
    case 'showcase':
    default:
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        bloomEnabled: true,
        bloomThreshold: 1.1,
        bloomIntensity: 0.2,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      );
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.3, -1.0, -0.4),
        intensity: 3.0,
        castsShadow: true,
      );
  }
}

vm.Vector3 _vec3(List<double> v) => vm.Vector3(v[0], v[1], v[2]);
vm.Vector4 _vec4(List<double> v) =>
    vm.Vector4(v[0], v[1], v[2], v.length > 3 ? v[3] : 1);
vm.Quaternion _euler(List<double> degrees) => vm.Quaternion.euler(
      degrees[1] * math.pi / 180,
      degrees[0] * math.pi / 180,
      degrees[2] * math.pi / 180,
    );
