#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Find Repository Root
###############################################################################

# Try using git first
WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# Fallback: search upward for pubspec.yaml
if [ -z "$WORKSPACE" ] || [ ! -f "$WORKSPACE/pubspec.yaml" ]; then
  WORKSPACE="$(pwd)"
  while [ "$WORKSPACE" != "/" ]; do
    if [ -f "$WORKSPACE/pubspec.yaml" ]; then
      break
    fi
    WORKSPACE="$(dirname "$WORKSPACE")"
  done
fi

# Verify we found the repository root
if [ ! -f "$WORKSPACE/pubspec.yaml" ] && [ ! -d "$WORKSPACE/example" ]; then
  echo "Error: Could not find repository root"
  echo "Last checked: $WORKSPACE"
  exit 1
fi

echo "Repository root: $WORKSPACE"
cd "$WORKSPACE"

FLUTTER_VERSION="3.41.9"

APPS=(
  apple_music
  apple_podcasts
  apple_messages
  apple_news
)

###############################################################################
# Flutter
###############################################################################

flutter --version

flutter config \
  --enable-web \
  --enable-linux-desktop \
  --enable-macos-desktop \
  --enable-windows-desktop

###############################################################################
# Platform scaffolding
###############################################################################

if [ -d "$WORKSPACE/example" ]; then
  cd "$WORKSPACE/example"
  flutter create . \
    --platforms=android,ios,web,linux,macos,windows
  cd "$WORKSPACE"
fi

###############################################################################
# Dependencies
###############################################################################

flutter pub get

if [ -d "$WORKSPACE/example" ]; then
  cd "$WORKSPACE/example"
  flutter pub get
  cd "$WORKSPACE"
fi

###############################################################################
# Artifacts
###############################################################################

mkdir -p artifacts/{android,ios,web,linux,windows,macos}

###############################################################################
# Build Loop
###############################################################################

for APP in "${APPS[@]}"; do

  echo ""
  echo "===================================="
  echo "BUILDING $APP"
  echo "===================================="

  ROOT="$WORKSPACE/example"

  cd "$ROOT"

  flutter clean
  flutter pub get

  ###########################################################################
  # iOS (Local Build)
  ###########################################################################

  flutter build ios \
    --release \
    --no-codesign

  APP_PATH="build/ios/iphoneos/Runner.app"

  if [ -d "$APP_PATH" ]; then
      echo "iOS build generated for $APP"
      echo "Xcode project: $ROOT/ios/Runner.xcworkspace"
      echo "Complete signing and building in Xcode GUI"
  fi

done

###############################################################################
# Final Archives
###############################################################################

cd "$WORKSPACE"

tar -czf ios-builds.tar.gz artifacts/ios 2>/dev/null || echo "iOS artifacts not available"
tar -czf macos-builds.tar.gz artifacts/macos 2>/dev/null || echo "macOS artifacts not available"

echo ""
echo "Build complete."
echo ""
echo "Artifacts:"
find artifacts -type f

echo ""
echo "Next - Continue Development in the GUI of Xcode for building, deployment, and profiling,"
