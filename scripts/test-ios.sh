#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
    echo "iOS tests require macOS, Xcode 15 or later, and an installed iOS 17+ Simulator runtime." >&2
    exit 1
fi

# Override SIMULATOR_ID to select a particular installed device.
if [[ -z "${SIMULATOR_ID:-}" ]]; then
    SIMULATOR_ID=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime, entries in sorted(devices.items(), reverse=True):
    if "iOS-" not in runtime:
        continue
    version = runtime.rsplit("iOS-", 1)[1].split("-")[0]
    if not version.isdigit() or int(version) < 17:
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("Install an iOS 17+ Simulator runtime and iPhone device in Xcode Settings > Platforms.")
')
fi

xcodebuild test \
    -project Planto.xcodeproj \
    -scheme Planto \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath DerivedData \
    CODE_SIGNING_ALLOWED=NO
