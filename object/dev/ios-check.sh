#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
if [ -n "${SAFEORBIT_SIMULATOR_ID:-}" ]; then
  simulator=$SAFEORBIT_SIMULATOR_ID
else
  simulator=$(node -e '
const {execFileSync}=require("node:child_process");
const inventory=JSON.parse(execFileSync("xcrun",["simctl","list","devices","available","-j"]));
const device=Object.values(inventory.devices).flat().find(d=>d.isAvailable&&d.name.startsWith("iPhone"));
if(!device) { console.error("An installed iPhone simulator is required"); process.exit(1); }
console.log(device.udid);')
fi
# Ad-hoc "Sign to Run Locally" needs no account or certificate; without it the Keychain tests fail.
# In an iCloud-synced folder iCloud tags existing app bundles with Finder info and codesign refuses
# them, so the previous bundle is removed and rebuilt (compiled code stays cached).
rm -rf "$repo/object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app"
exec xcodebuild -project "$repo/object/ios/SafeOrbit.xcodeproj" -scheme SafeOrbit \
  -destination "platform=iOS Simulator,id=$simulator" \
  -derivedDataPath "$repo/object/ios/DerivedData" -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
