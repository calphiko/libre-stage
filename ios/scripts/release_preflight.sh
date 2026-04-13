
#!/usr/bin/env zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR/.."

echo "[1/3] Checking Info.plist for insecure ATS override..."
if /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" ios/LibreStage/Info.plist >/dev/null 2>&1; then
  echo "ERROR: NSAllowsArbitraryLoads is enabled. Remove it before release."
  exit 1
fi

echo "[2/3] Building iOS app (Release, simulator)..."
xcodebuild -project ios/LibreStage.xcodeproj -scheme LibreStage -sdk iphonesimulator -configuration Release build > /tmp/librestage-ios-release-build.log

echo "[3/3] Build OK. Last lines:"
tail -n 15 /tmp/librestage-ios-release-build.log

echo "Preflight passed."

