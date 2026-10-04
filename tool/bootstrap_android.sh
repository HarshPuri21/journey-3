#!/usr/bin/env bash
# Generates the android/ runner on a machine that has Flutter (CI does this
# on every build, so nobody needs Android Studio). Idempotent.
set -euo pipefail

ORG="${JOURNEY_ORG:-com.n5journey}"   # application id = $ORG.n5_kanji_journey
LABEL="${JOURNEY_LABEL:-N5 Kanji Journey}"

if [ ! -d android ]; then
  flutter create --platforms=android --org "$ORG" --project-name n5_kanji_journey --no-pub .
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i "s|android:label=\"[^\"]*\"|android:label=\"$LABEL\"|" "$MANIFEST"
grep -q "android:label=\"$LABEL\"" "$MANIFEST" || { echo "failed to set app label"; exit 1; }
echo "android/ ready (label: $LABEL, org: $ORG)"
