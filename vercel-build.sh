#!/usr/bin/env bash
set -euo pipefail

FLUTTER_SDK=/tmp/flutter_sdk
rm -rf "$FLUTTER_SDK"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_SDK"
"$FLUTTER_SDK/bin/flutter" config --enable-web
"$FLUTTER_SDK/bin/flutter" pub get
"$FLUTTER_SDK/bin/flutter" build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL:?Set SUPABASE_URL in Vercel}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in Vercel}"
