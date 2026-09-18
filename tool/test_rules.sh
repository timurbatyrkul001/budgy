#!/usr/bin/env bash
# firestore.rules testlerini Firestore emülatöründe çalıştırır.
#
# Kuralları her değiştirdiğinde çalıştır: bir koleksiyonu kural dosyasında
# unutmak, o özelliği canlıda sessizce tamamen kırar.
set -euo pipefail
cd "$(dirname "$0")/.."

# Emülatör Java ister; sistemde ayrı JDK yoksa Android Studio'nunkini kullan.
if ! java -version >/dev/null 2>&1; then
  ANDROID_STUDIO_JDK="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [ -d "$ANDROID_STUDIO_JDK" ]; then
    export JAVA_HOME="$ANDROID_STUDIO_JDK"
    export PATH="$JAVA_HOME/bin:$PATH"
  else
    echo "Java bulunamadı. JDK kur ya da JAVA_HOME ayarla." >&2
    exit 1
  fi
fi

[ -d test_rules/node_modules ] || (cd test_rules && npm install)

firebase emulators:exec --only firestore --project budgy-rules-test \
  "cd test_rules && node rules.test.mjs"
