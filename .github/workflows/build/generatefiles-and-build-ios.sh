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

# Each app has its own main() entry point
declare -A APP_ENTRIES
APP_ENTRIES[apple_music]="lib/apple_music/apple_music_demo.dart"
APP_ENTRIES[apple_podcasts]="lib/apple_podcasts/apple_podcasts_demo.dart"
APP_ENTRIES[apple_messages]="lib/apple_messages/apple_messages_demo.dart"
APP_ENTRIES[apple_news]="lib/apple_news/apple_news_demo.dart"

APPS=(
  apple_music
  apple_podcasts
  apple_messages
  apple_news
)

###############################################################################
# Flutter
###############################################################################

INSTALLED_FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}') || true
echo "Expected Flutter version: $FLUTTER_VERSION"
echo "Installed Flutter version: $INSTALLED_FLUTTER_VERSION"

flutter config \
  --enable-web \
  --enable-linux-desktop \
  --enable-macos-desktop \
  --enable-windows-desktop

###############################################################################
# Platform scaffolding (only if missing)
###############################################################################

if [ -d "$WORKSPACE/example" ] && [ ! -d "$WORKSPACE/example/ios" ]; then
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
# Detect available build targets
###############################################################################

# Map flutter build subcommands to platform target names
# Format: "subcommand:target_name"
ALL_BUILDS=("apk:android" "web:web" "linux:linux" "ios:ios" "macos:macos" "windows:windows")

AVAILABLE_BUILDS=()
AVAILABLE_SUBCMDS=$(flutter build -h 2>/dev/null | sed -n '/^Available subcommands:/,/^$/p' | tail -n +2 | awk '{print $1}')

for BUILD in "${ALL_BUILDS[@]}"; do
  SUBCMD="${BUILD%%:*}"
  while IFS= read -r line; do
    if [ "$line" = "$SUBCMD" ]; then
      AVAILABLE_BUILDS+=("$BUILD")
    fi
  done <<< "$AVAILABLE_SUBCMDS"
done

echo ""
echo "Available builds: ${AVAILABLE_BUILDS[*]:-(none)}"

if [ ${#AVAILABLE_BUILDS[@]} -eq 0 ]; then
  echo "No build targets available on this platform. Skipping builds."
  exit 0
fi

###############################################################################
# Build configuration per target
###############################################################################

target_config() {
  local TARGET="$1"
  case "$TARGET" in
    ios)
      echo "artifacts/ios|build/ios/iphoneos/Runner.app|--release --no-codesign"
      ;;
    android)
      echo "artifacts/android|build/app/outputs/flutter-apk|--release"
      ;;
    web)
      echo "artifacts/web|build/web|--release"
      ;;
    linux)
      echo "artifacts/linux|build/linux/x64/release/bundle|--release"
      ;;
    macos)
      echo "artifacts/macos|build/macos/Build/Products/Release/Runner.app|--release --no-codesign"
      ;;
    windows)
      echo "artifacts/windows|build/windows/x64/runner/Release|--release"
      ;;
  esac
}

copy_artifact() {
  local SRC="$1" DST="$2"
  mkdir -p "$DST"
  if [ -d "$SRC" ]; then
    cp -R "$SRC/." "$DST/"
  elif [ -f "$SRC" ]; then
    cp "$SRC" "$DST/"
  fi
}

###############################################################################
# Build Loop
###############################################################################

for APP in "${APPS[@]}"; do
  ROOT="$WORKSPACE/example"
  ENTRY="${APP_ENTRIES[$APP]}"

  for BUILD in "${AVAILABLE_BUILDS[@]}"; do
    SUBCMD="${BUILD%%:*}"
    TARGET="${BUILD#*:}"
    IFS='|' read -r ARTIFACT_DIR BUILD_OUTPUT BUILD_FLAGS <<< "$(target_config "$TARGET")"

    echo ""
    echo "===================================="
    echo "BUILDING $APP for $TARGET"
    echo "===================================="

    cd "$ROOT"
    flutter clean
    flutter pub get

    # shellcheck disable=SC2086
    if flutter build "$SUBCMD" $BUILD_FLAGS --target="$ENTRY"; then
      echo "Build generated for $APP ($TARGET)"
      copy_artifact "$BUILD_OUTPUT" "$WORKSPACE/$ARTIFACT_DIR/$APP"
    else
      echo "WARNING: Build failed for $APP ($TARGET) — skipping"
    fi
  done
done

###############################################################################
# Final Archives
###############################################################################

cd "$WORKSPACE"

for BUILD in "${AVAILABLE_BUILDS[@]}"; do
  TARGET="${BUILD#*:}"
  IFS='|' read -r ARTIFACT_DIR _ _ <<< "$(target_config "$TARGET")"
  ARCHIVE="${TARGET}-builds.tar.gz"
  tar -czf "$ARCHIVE" "$ARTIFACT_DIR" 2>/dev/null || echo "$TARGET artifacts not available"
done

echo ""
echo "Build complete."
echo ""
echo "Artifacts:"
find artifacts -type f 2>/dev/null || echo "(no artifacts found)"