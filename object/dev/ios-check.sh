#!/bin/sh
# Builds the app and runs the iOS unit tests on an installed iPhone simulator.
#   SAFEORBIT_SIMULATOR_ID  simulator UDID; default: the first available iPhone.
#   SAFEORBIT_ONLY_TESTING  comma-separated tests to run instead of the full suite, e.g.
#     SafeOrbitTests/RiskAlertsTests,SafeOrbitTests/LocationTests/testRiskHomeSnapshots
#     Use test class names, not file names: RecordsTests.swift also holds ElderFrontendTests,
#     ElderLiveNavigationTests and AgentSessionTests. The script fails if any listed test runs
#     nothing, so a typo cannot pass. Subsets are for work in progress; task receipts and
#     acceptance always quote a full-suite run (unset the variable).
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
set -- -project "$repo/object/ios/SafeOrbit.xcodeproj" -scheme SafeOrbit \
  -destination "platform=iOS Simulator,id=$simulator" \
  -derivedDataPath "$repo/object/ios/DerivedData" -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
if [ -z "${SAFEORBIT_ONLY_TESTING:-}" ]; then
  exec xcodebuild "$@" test
fi

tests=
set -f
old_ifs=$IFS
IFS=,
for raw in $SAFEORBIT_ONLY_TESTING; do
  name=$(printf '%s' "$raw" | tr -d '[:space:]')
  [ -n "$name" ] || continue
  tests="$tests$name
"
  set -- "$@" "-only-testing:$name"
done
IFS=$old_ifs
set +f
if [ -z "$tests" ]; then
  echo "SAFEORBIT_ONLY_TESTING lists no tests: '$SAFEORBIT_ONLY_TESTING'" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/safeorbit-ios-check.XXXXXX")
trap 'rm -rf "$work"' EXIT
set +e
xcodebuild "$@" -resultBundlePath "$work/result.xcresult" test
status=$?
set -e

# xcodebuild may run zero tests for an unknown name and still succeed, so every listed
# test must match at least one executed test case in the result bundle.
if [ ! -d "$work/result.xcresult" ]; then
  echo "No test results; check SAFEORBIT_ONLY_TESTING: $SAFEORBIT_ONLY_TESTING" >&2
  [ "$status" -ne 0 ] || status=1
  exit "$status"
fi
xcrun xcresulttool get test-results tests --path "$work/result.xcresult" > "$work/tests.json"
node -e '
const fs=require("node:fs");
const [file, list]=process.argv.slice(1);
const ran=[];
const walk=(node, path)=>{
  const here=["Unit test bundle","UI test bundle","Test Suite","Test Case"].includes(node.nodeType)
    ? [...path, node.name.replace(/\(\)$/, "")] : path;
  if (node.nodeType==="Test Case" && node.result!=="Skipped") ran.push(here);
  (node.children||[]).forEach(child=>walk(child, here));
};
JSON.parse(fs.readFileSync(file, "utf8")).testNodes.forEach(node=>walk(node, []));
const unmatched=list.split("\n").filter(Boolean).filter(test=>{
  const want=test.split("/").map(part=>part.replace(/\(\)$/, ""));
  return !ran.some(path=>want.every((part, i)=>path[i]===part));
});
for (const test of unmatched) console.error(`No test ran for ${test}: check the name (use test class names, not file names).`);
console.log(`Ran ${ran.length} tests for SAFEORBIT_ONLY_TESTING.`);
process.exit(unmatched.length ? 1 : 0);' "$work/tests.json" "$tests" || status=1
exit "$status"
