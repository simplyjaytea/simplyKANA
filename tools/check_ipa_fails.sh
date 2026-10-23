#!/bin/bash
# Proves tools/check_ipa.sh rejects bad archives, so a pass means something.
# usage: tools/check_ipa_fails.sh GOOD.ipa MIN
set -euo pipefail
GOOD=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); MIN="$2"
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

expect_fail() {  # name, ipa, min
  if "$HERE/check_ipa.sh" "$2" "$3" >/dev/null 2>&1; then
    echo "CHECK DID NOT FAIL: $1" >&2; exit 1
  fi
  echo "ok: rejects $1"
}
mutate() {  # name, command run inside the unzipped copy
  rm -rf "$T/x" && mkdir "$T/x" && (cd "$T/x" && unzip -q "$GOOD" && eval "$2" && zip -qry "$T/$1.ipa" Payload)
}

mutate no-widget 'rm -rf Payload/SimplyKANA.app/PlugIns/SimplyKANAWidget.appex'
expect_fail "an IPA without the widget" "$T/no-widget.ipa" "$MIN"

mutate simulator '/usr/libexec/PlistBuddy -c "Set :DTPlatformName iphonesimulator" Payload/SimplyKANA.app/Info.plist'
expect_fail "a simulator build" "$T/simulator.ipa" "$MIN"

mutate no-words "find Payload -name 'zh-Hans.pack.json' -delete"
expect_fail "an IPA without the language packs" "$T/no-words.ipa" "$MIN"

expect_fail "the wrong minimum iOS" "$GOOD" "99.0"
echo "check_ipa.sh fails on every bad archive"
