# Loop

Sized's window transform animation (`Sized/Core/WindowTransformAnimation.swift`) and preview transition behavior (`Sized/WindowActionIndicators/PreviewWindow/PreviewController.swift`) are adapted from [Loop](https://github.com/mrkai77/Loop), by Kai Azim and contributors.

Source revision: `573ace3071641bbe002527ccfc0811842300ccba`.

The upstream files are `WindowTransformAnimation.swift`, the constraint anchoring helpers in `WindowEngine.swift`, `PreviewController.swift`, `PreviewViewModel.swift`, and `AnimationConfiguration.swift`. The original window animation was created by Kai Azim on 2023-09-02.

Loop is licensed under the GNU General Public License, version 3; the license is reproduced in [LICENSE-Loop](LICENSE-Loop). Sized remains licensed under the GNU Affero General Public License, version 3, in [LICENSE](LICENSE).

The adaptation uses Sized's Accessibility access and settings, synchronous animation cancellation, selected resize anchors, display refresh rates, exact endpoint sizing, and reduced-motion support. It retains Loop's nonblocking NSAnimation driver, ease-out plus cubic interpolation, constraint handling, and default snappy preview curve.
