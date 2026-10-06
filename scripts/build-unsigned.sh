#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 - <<'PY'
import re
import subprocess
version = subprocess.check_output(["xcodebuild", "-version"], text=True)
print(version.strip())
match = re.search(r"Xcode (\d+)", version)
if not match or int(match.group(1)) < 27:
    raise SystemExit("This device validation build requires Xcode 27 or newer.")
PY

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen first: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate --spec project.yml
xcodebuild \
  -project WatchStress.xcodeproj \
  -scheme WatchStressPhone \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  -archivePath build/WatchStress.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

mkdir -p build/Packaging/Payload dist
ditto build/WatchStress.xcarchive/Products/Applications/WatchStressPhone.app \
  build/Packaging/Payload/WatchStressPhone.app

# Keep requested capabilities inside the Mach-O signatures so the sideloader can
# discover them. These local ad-hoc signatures are NOT Apple device signatures
# and are NOT an Apple Developer Program Ad Hoc distribution profile.
python3 scripts/prepare_resigning.py build/Packaging/Payload/WatchStressPhone.app
ditto -c -k --keepParent build/Packaging/Payload dist/WatchStress-resign-required.ipa
python3 scripts/validate_ipa.py dist/WatchStress-resign-required.ipa
echo 'Package created. It still needs Apple device signing, profiles, and installation.'


