#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# This mode is never permitted to target Firebase production.
test "${FIRESTORE_EMULATOR_HOST:-}" = '127.0.0.1:8080'
test "${FIREBASE_AUTH_EMULATOR_HOST:-}" = '127.0.0.1:9099'
mkdir -p native/TestResults
TEST_RUNNER_PANTRY_EMULATOR_UI=1 xcodebuild -project native/Pantry.xcodeproj -scheme Pantry -configuration Debug -derivedDataPath native/DerivedData -destination "id=$PANTRY_SIMULATOR" CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -resultBundlePath native/TestResults/PantryUITests.xcresult test 2>&1 | tee native-uitests.log
