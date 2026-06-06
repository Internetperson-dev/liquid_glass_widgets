#!/usr/bin/env bash
set -euo pipefail

# Use current directory as workspace
WORKSPACE="$(pwd)"

FLUTTER_VERSION="3.41.9"

APPS=(
  apple_music
  apple_podcasts
  apple_messages
  apple_news
  showcase
)

###############################################################################
# Verify we're in the right directory
###############################################################################

if [ ! -f "pubspec.yaml" ] && [ ! -d "example" ]; then
  echo "Error: This script must be run from the repository root"
  echo "Current directory: $WORKSPACE"
  exit 1
fi

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

cd example

flutter create . \
  --platforms=android,ios,web,linux,macos,windows

cd showcase

flutter create . \
  --platforms=android,ios,web,linux,macos,windows

cd ..

###############################################################################
# Dependencies
###############################################################################

flutter pub get

cd example
flutter pub get

cd showcase
flutter pub get

cd "$WORKSPACE"

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

  if [ "$APP" = "showcase" ]; then
    ROOT="example/showcase"
    ENTRY="lib/main.dart"
  else
    ROOT="example"
    ENTRY="lib/${APP}/${APP}_demo.dart"
  fi

  cd "$WORKSPACE/$ROOT"

  flutter clean
  flutter pub get

  ###########################################################################
  # iOS (Local Build)
  ###########################################################################

  flutter build ios \
    --release \
    --no-codesign \
    -t "$ENTRY"

  APP_PATH="build/ios/iphoneos/Runner.app"

  if [ -d "$APP_PATH" ]; then
      echo "iOS build generated for $APP"
      echo "Xcode project: $WORKSPACE/$ROOT/ios/Runner.xcworkspace"
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
find artifacts

echo ""
echo "Next - Continue Development in the GUI of Xcode for building, deployment, and profiling,"
