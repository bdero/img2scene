# Reference image prompt template

Use this to turn a text description into an admissible reference for img2scene. The constraints are not stylistic, each one maps to the admission gate or to what primitive assembly can actually reconstruct. Fill in the subject line and send the whole block to an image model.

## Template

> A single [SUBJECT], centered in the frame, filling roughly 40 to 80 percent of the image. Plain flat neutral light gray background. Three-quarter front view, the subject turned slightly so two sides and the top are visible. Even diffuse studio lighting, soft and shadowless. No shadow cast on the background. No props, no other objects, no text, no watermark. Square aspect ratio.

Fill in:

- `[SUBJECT]` = the object to build, described plainly (for example, a red ceramic coffee mug, a wooden crate, a boxy retro robot).

## Why each constraint

- Single isolated subject, no props. The comparator reads one silhouette against a clean background. A second object or a prop splits the silhouette and breaks the shape and scale metrics.
- Centered, filling 40 to 80 percent. The scale gate compares how large the subject is drawn. A subject that is tiny or cropped at the edges fails admission and gives the render nothing stable to match.
- Plain flat neutral light gray background. The silhouette is separated from the background by color difference. A textured, dark, or busy backdrop bleeds into the subject mask.
- Three-quarter front view. Primitive assembly reconstructs a readable shape from a view that shows volume, two sides and the top. A dead-on or pure profile view hides the depth you need to place parts.
- Even diffuse lighting, no cast shadows. Hard shadows on the background read as extra silhouette area, and dramatic lighting distorts the color and edge metrics.
- Square aspect. The comparator normalizes to a square, so a square reference avoids letterboxing the subject.

## Style-coherent sets

To make a set of props look like they belong together, prefix every prompt with the same short style clause and keep it identical across the set. For example, start each with "Low-poly flat-shaded game asset, matte materials, ..." then the template above. A consistent prefix gives style coherence without changing the admission constraints.
