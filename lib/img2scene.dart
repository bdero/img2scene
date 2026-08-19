/// Deterministic image comparator for judging a rendered candidate against a
/// reference. Silhouette IoU, scale delta, perceptual hash, and edge overlap,
/// with hard gates and tagged defects.
library;

export 'src/comparator.dart'
    show ComparatorConfig, ComparisonResult, Defect, compare;
export 'src/edges.dart' show sobelEdges;
export 'src/features.dart' show luminance, silhouette;
export 'src/mask.dart' show BBox, Mask;
export 'src/phash.dart' show hammingDistance, pHash;
