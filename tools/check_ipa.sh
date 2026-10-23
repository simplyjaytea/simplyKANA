#!/bin/bash
# Checks an unsigned IPA before anyone gets a link to it (Rachel's gate, alpha item 9).
# usage: tools/check_ipa.sh SimplyKANA.ipa 16.0
set -euo pipefail
IPA="$1"; MIN="$2"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$WORK/Payload/SimplyKANA.app"
EXT="$APP/PlugIns/SimplyKANAWidget.appex"
fail() { echo "IPA CHECK FAILED: $*" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist" 2>/dev/null || true; }

[ -d "$APP" ] || fail "no Payload/SimplyKANA.app"
[ -d "$EXT" ] || fail "widget missing: no PlugIns/SimplyKANAWidget.appex"

for B in "$APP" "$EXT"; do
  name=$(basename "$B")
  # 1. Built for a real phone, not the simulator.
  [ "$(plist "$B" DTPlatformName)" = "iphoneos" ] || fail "$name DTPlatformName is '$(plist "$B" DTPlatformName)', not iphoneos"
  plist "$B" CFBundleSupportedPlatforms | grep -q iPhoneOS || fail "$name not built for iPhoneOS"
  exe="$B/$(plist "$B" CFBundleExecutable)"
  lipo -archs "$exe" | grep -qw arm64 || fail "$name binary is $(lipo -archs "$exe"), not arm64"
  # 3. Minimum iOS and the word bundle.
  [ "$(plist "$B" MinimumOSVersion)" = "$MIN" ] || fail "$name MinimumOSVersion is '$(plist "$B" MinimumOSVersion)', want $MIN"
  # Every pack in the repo must be inside both the app and the widget.
  for P in "$(dirname "$0")"/../kana-core/Sources/KanaCore/Resources/Packs/*.pack.json; do
    P=$(basename "$P"); find "$B" -name "$P" | grep -q . || fail "$name has no $P"
  done
  # Parked packs (status "planned", kept in packs/<lang>/) must not ship.
  for P in "$(dirname "$0")"/../packs/*/*.pack.json; do
    [ -e "$P" ] || continue
    P=$(basename "$P"); ! find "$B" -name "$P" | grep -q . || fail "$name ships parked pack $P"
  done
  echo "ok: $name  iphoneos arm64  iOS $MIN+  language packs present"
done
echo "IPA OK: $(du -h "$IPA" | cut -f1)"
