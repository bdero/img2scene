import 'dart:convert';

/// A scene the model authors to match a reference image: a small tree of
/// primitive parts with transforms and materials, a camera, and a named look.
///
/// This is the intermediate representation. A deterministic emitter turns it
/// into a flutter_scene node tree (to render and to codegen), and the
/// comparator scores the render against the reference. The model spends tokens
/// here, on visual judgment, never on the mechanical build.
class SceneSpec {
  SceneSpec({
    required this.camera,
    required this.parts,
    this.look = 'showcase',
    this.background,
  });

  final CameraSpec camera;
  final List<PartSpec> parts;

  /// A named look preset (showcase, stylized, moody, clean).
  final String look;

  /// Clear color RGB in `[0, 1]`, or null for the look's default.
  final List<double>? background;

  factory SceneSpec.fromJson(Map<String, Object?> json) => SceneSpec(
        camera: CameraSpec.fromJson(json['camera'] as Map<String, Object?>),
        parts: [
          for (final p in (json['parts'] as List? ?? const []))
            PartSpec.fromJson(p as Map<String, Object?>),
        ],
        look: json['look'] as String? ?? 'showcase',
        background: _numList(json['background']),
      );

  static SceneSpec parse(String jsonText) =>
      SceneSpec.fromJson(jsonDecode(jsonText) as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'camera': camera.toJson(),
        'look': look,
        if (background != null) 'background': background,
        'parts': [for (final p in parts) p.toJson()],
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// A count of every part in the tree, the coarse "is this spec shallow"
  /// signal the admission side pairs with the reference detail.
  int get partCount {
    var n = 0;
    void walk(List<PartSpec> ps) {
      for (final p in ps) {
        n++;
        walk(p.children);
      }
    }

    walk(parts);
    return n;
  }

  /// Validation errors, empty when the spec is well formed. A shallow or
  /// malformed spec is rejected before it wastes a render.
  List<String> validate() {
    final errors = <String>[];
    if (parts.isEmpty) errors.add('spec has no parts');
    void walk(List<PartSpec> ps, String path) {
      for (final p in ps) {
        errors.addAll(p.primitive.validate('$path/${p.name}'));
        walk(p.children, '$path/${p.name}');
      }
    }

    walk(parts, '');
    return errors;
  }
}

class CameraSpec {
  CameraSpec({
    required this.position,
    this.target = const [0, 0, 0],
    this.fovDegrees = 45,
  });

  final List<double> position;
  final List<double> target;
  final double fovDegrees;

  factory CameraSpec.fromJson(Map<String, Object?> json) => CameraSpec(
        position: _numList(json['position']) ?? const [0, 1, -5],
        target: _numList(json['target']) ?? const [0, 0, 0],
        fovDegrees: _num(json['fovDegrees']) ?? 45,
      );

  Map<String, Object?> toJson() => {
        'position': position,
        'target': target,
        'fovDegrees': fovDegrees,
      };
}

class PartSpec {
  PartSpec({
    required this.name,
    required this.primitive,
    this.position,
    this.rotation,
    this.scale,
    this.material,
    this.children = const [],
  });

  final String name;
  final PrimitiveSpec primitive;

  /// Local translation `[x, y, z]`, default origin.
  final List<double>? position;

  /// Local rotation as Euler degrees `[x, y, z]`, default none.
  final List<double>? rotation;

  /// Local scale `[x, y, z]`, default one.
  final List<double>? scale;

  final MaterialSpec? material;
  final List<PartSpec> children;

  factory PartSpec.fromJson(Map<String, Object?> json) => PartSpec(
        name: json['name'] as String? ?? 'part',
        primitive: PrimitiveSpec.fromJson(
          json['primitive'] as Map<String, Object?>,
        ),
        position: _numList(json['position']),
        rotation: _numList(json['rotation']),
        scale: _numList(json['scale']),
        material: json['material'] == null
            ? null
            : MaterialSpec.fromJson(json['material'] as Map<String, Object?>),
        children: [
          for (final c in (json['children'] as List? ?? const []))
            PartSpec.fromJson(c as Map<String, Object?>),
        ],
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'primitive': primitive.toJson(),
        if (position != null) 'position': position,
        if (rotation != null) 'rotation': rotation,
        if (scale != null) 'scale': scale,
        if (material != null) 'material': material!.toJson(),
        if (children.isNotEmpty)
          'children': [for (final c in children) c.toJson()],
      };
}

/// A built-in primitive and its parameters. The kinds map one to one onto the
/// engine's primitive geometry vocabulary.
class PrimitiveSpec {
  PrimitiveSpec(this.kind, [this.params = const {}]);

  final String kind;
  final Map<String, double> params;

  /// The recognized kinds. Extend the emitter in lockstep when adding one.
  static const Set<String> kinds = {
    'cuboid',
    'sphere',
    'icosphere',
    'cylinder',
    'cone',
    'capsule',
    'torus',
    'plane',
    'disc',
    'ring',
    'wedge',
  };

  factory PrimitiveSpec.fromJson(Map<String, Object?> json) => PrimitiveSpec(
        json['kind'] as String? ?? '',
        {
          for (final e in (json['params'] as Map? ?? const {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
      );

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (params.isNotEmpty) 'params': params,
      };

  double param(String key, double fallback) => params[key] ?? fallback;

  List<String> validate(String path) {
    if (!kinds.contains(kind)) {
      return ['$path: unknown primitive kind "$kind"'];
    }
    return const [];
  }
}

class MaterialSpec {
  MaterialSpec({this.baseColor, this.metallic, this.roughness, this.emissive});

  /// Base color RGBA in `[0, 1]`.
  final List<double>? baseColor;
  final double? metallic;
  final double? roughness;

  /// Emissive RGB in `[0, 1]`.
  final List<double>? emissive;

  factory MaterialSpec.fromJson(Map<String, Object?> json) => MaterialSpec(
        baseColor: _numList(json['baseColor']),
        metallic: _num(json['metallic']),
        roughness: _num(json['roughness']),
        emissive: _numList(json['emissive']),
      );

  Map<String, Object?> toJson() => {
        if (baseColor != null) 'baseColor': baseColor,
        if (metallic != null) 'metallic': metallic,
        if (roughness != null) 'roughness': roughness,
        if (emissive != null) 'emissive': emissive,
      };
}

double? _num(Object? v) => v == null ? null : (v as num).toDouble();
List<double>? _numList(Object? v) =>
    v == null ? null : [for (final e in v as List) (e as num).toDouble()];
