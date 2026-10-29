#!/bin/zsh
# upload-tester-build.sh — archives a TESTER build and uploads it to App Store Connect (for TestFlight only).
#
# A tester build is a normal Release build (production Firebase, App Attest, real App Store purchases) with the
# TESTFLIGHT_TOOLS flag: Settings shows the Debug section (Reset free words, Unlock every profession, crash test),
# so you and your testers can test everything again and again. NEVER submit a tester build for App Store review —
# the reviewer would see "Unlock every profession". For the review build use Xcode: Product → Archive (no flag).
#
# Usage, from the repository root:
#   scripts/upload-tester-build.sh 3        # 3 = the new build number (must be higher than every uploaded build)
# Then App Store Connect → TestFlight: wait for "Ready to Test", add the build to your tester group.
# Needs: Xcode signed in to the Apple account of team 7XZJ4BCPR6 (Xcode → Settings → Accounts).

set -e
BUILD="$1"
if [[ -z "$BUILD" || ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "Usage: scripts/upload-tester-build.sh <build number>   (higher than the last uploaded build)"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
ARCHIVE="$WORK/LearnScrumble-tester-$BUILD.xcarchive"
trap 'rm -rf "$WORK"' EXIT

# 1. Archive: Release + TESTFLIGHT_TOOLS, with this build number (the project setting is left unchanged).
xcodebuild archive -project "$ROOT/LearnScrumble.xcodeproj" -scheme LearnScrumble -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) TESTFLIGHT_TOOLS' CURRENT_PROJECT_VERSION="$BUILD" -quiet

# 2. Upload to App Store Connect, signed for distribution by Xcode's automatic signing.
cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>7XZJ4BCPR6</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/export" -allowProvisioningUpdates -quiet

echo "Tester build $BUILD uploaded. App Store Connect → TestFlight: add it to your tester group once it's Ready to Test."
