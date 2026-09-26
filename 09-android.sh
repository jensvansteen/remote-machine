#!/usr/bin/env bash
# Android SDK for headless React Native Android builds.
#
# Installs command-line tools directly from Google. NO Android Studio IDE,
# NO GUI first-run wizard — everything via sdkmanager on the CLI.
# Better for an agent-driven box where opening a GUI app over KVM/VNC is slow.
#
# Want the IDE too? Install separately:
#   brew install --cask android-studio
# Then launch via your hosting provider's KVM/VNC once for the wizard.
set -euo pipefail

echo "==> Android SDK (headless)"

# JDK is required for sdkmanager — comes from mise via 04-mise.sh
if ! command -v java >/dev/null 2>&1; then
  echo "java not found. Run 04-mise.sh first (it installs JDK 17 via mise)."
  exit 1
fi

SDK_DIR="$HOME/Library/Android/sdk"
CMDLINE_DIR="$SDK_DIR/cmdline-tools/latest"

# Latest stable cmdline-tools version (May 2026). Update periodically by checking
# https://developer.android.com/studio#command-line-tools-only
CMDLINE_VERSION="11076708"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_VERSION}_latest.zip"

if [[ ! -x "$CMDLINE_DIR/bin/sdkmanager" ]]; then
  echo "Downloading Android command-line tools (~150 MB)..."
  mkdir -p "$SDK_DIR/cmdline-tools"
  cd /tmp
  curl -fsSL -o cmdline-tools.zip "$CMDLINE_URL"
  unzip -q cmdline-tools.zip
  rm -rf "$CMDLINE_DIR"
  mv cmdline-tools "$CMDLINE_DIR"
  rm -f cmdline-tools.zip
  echo "Installed at $CMDLINE_DIR"
else
  echo "cmdline-tools already present at $CMDLINE_DIR"
fi

# Persist env vars to .zshrc
if ! grep -q "ANDROID_HOME" "$HOME/.zshrc" 2>/dev/null; then
  cat <<'EOF' >> "$HOME/.zshrc"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
  echo "Added ANDROID_HOME + path to ~/.zshrc"
fi

# Apply env to current session
export ANDROID_HOME="$SDK_DIR"
export PATH="$CMDLINE_DIR/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Accept all SDK licenses headlessly (otherwise sdkmanager refuses to install anything)
yes | sdkmanager --licenses >/dev/null 2>&1 || true
echo "SDK licenses accepted"

# Install core packages needed for RN Android builds (~500 MB total).
# API 36 (Android 16) is the current stable. Google Play targeting requirement
# bumps to API 36 in August 2026 — anything new should be built against it.
# Keep this in sync with the latest stable that Expo / React Native support.
echo "Installing core SDK packages..."
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;36.0.0" \
  "emulator"

echo ""
echo "Done."
echo "  ANDROID_HOME=$ANDROID_HOME"
echo "  Verify: adb --version"
echo ""
echo "Optional add-ons:"
echo "  System image for emulator AVD (Apple Silicon arm64):"
echo "    sdkmanager 'system-images;android-36;google_apis;arm64-v8a'"
echo "  Full Android Studio IDE (only needed if you want the GUI):"
echo "    brew install --cask android-studio"
