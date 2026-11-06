#!/bin/zsh
set -euo pipefail
sized_root="$(cd "$(dirname "$0")/.." && pwd)"
sized_test_dir="$(mktemp -d /tmp/sized-animation-checks.XXXXXX)"
trap 'rm -rf "$sized_test_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
    -enable-upcoming-feature MemberImportVisibility \
    "$sized_root/Sized/Core/WindowTransformAnimation.swift" \
    "$sized_root/Sized/Core/WindowResizeResult.swift" \
    "$sized_root/Sized/Core/WindowEngine.swift" \
    "$sized_root/Sized/WindowActionIndicators/PreviewWindow/PreviewController.swift" \
    "$sized_root/Sized/WindowActionIndicators/PreviewWindow/PreviewView.swift" \
    "$sized_root/Sized/WindowActionIndicators/ActivePanel.swift" \
    "$sized_root/Sized/Extensions/Color+Hex.swift" \
    "$sized_root/Tests/WindowAnimationChecks.swift" \
    -o "$sized_test_dir/checks"
"$sized_test_dir/checks"
