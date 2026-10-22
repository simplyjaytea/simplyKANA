#!/bin/bash
# Publishes SimplyKANA.ipa to a rolling prerelease. CI runs it on main with TAG=alpha;
# a dry run uses TAG=alpha-test. Needs gh authenticated (GH_TOKEN in CI).
# usage: tools/publish_alpha.sh IPA TAG SHA
set -euo pipefail
IPA="$1"; TAG="$2"; SHA="$3"
LATEST=$(git ls-remote origin refs/heads/main | cut -f1)
if [ "$LATEST" != "$SHA" ]; then
  echo "main has moved on to $LATEST; not publishing $SHA"; exit 0
fi
SHORT=${SHA::7}
TITLE="Alpha $(date -u +%Y-%m-%d) ($SHORT)"
NOTES="Unsigned alpha build of main at $SHORT. Install with Sideloadly or AltStore: see the README section 'Install the IPA without a Mac'. Expires 7 days after install with a free Apple ID."
# Move the tag to this commit, then replace the file in place: the link never 404s.
git tag -f "$TAG" "$SHA" && git push -f origin "refs/tags/$TAG"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$IPA" --clobber
  gh release edit "$TAG" --title "$TITLE" --notes "$NOTES" --prerelease
  echo "updated release $TAG"
else
  gh release create "$TAG" "$IPA" --prerelease --verify-tag --title "$TITLE" --notes "$NOTES"
  echo "created release $TAG"
fi
