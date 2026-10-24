#!/usr/bin/env bash
# Xcode 26 ships the Metal compiler as a separately downloaded component, and the app has .metal shaders
# (ios/Timbre/Design/Shaders.metal). Install it only when it's missing.
set -euo pipefail
if xcrun -sdk iphoneos metal -v >/dev/null 2>&1; then
  echo "Metal toolchain present"
  exit 0
fi
echo "Downloading the Metal toolchain"
xcodebuild -downloadComponent MetalToolchain
xcrun -sdk iphoneos metal -v
