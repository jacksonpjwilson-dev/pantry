# Device readiness and validation record

Scope: development installation through Xcode, not App Store release. No physical iPhone or Watch is attached to this Linux environment. No Firebase Console credentials, Apple team identity, signing profile or registered iOS Firebase plist is available here. Those are genuine external gates; builds cannot establish runtime functionality on the owner's devices.

Baseline `e5ff442`: [Native iOS run 43457361919, attempt 2](https://github.com/jacksonpjwilson-dev/pantry/actions/runs/43457361919) **passed** 35 Apple core tests (including all 17 Logbook tests), three Apple target builds, the inventory/purchase/use/undo/relaunch/delete simulator test, and simulator launch/capture. Attempt 1 failed before tests due to `Timed out waiting for AX loaded notification`; the unchanged commit passed on retry. The phase-2 CI boots and waits for the simulator before testing, disables parallel simulator clones, and saves failure diagnostics. This mitigates startup races; it does not prove they can never recur.

Phase-2 adds local signing/Firebase configuration validation, configurable consistent identifiers, a Watch run scheme, explicit camera authorization and a scanner-sheet transition fix. New UI scenarios cover metadata edits, linked shopping purchase/persistence, unknown manual barcode handoff, and native Firebase SDK sign-in/stock/account switching against local Auth/Firestore emulators. See **the latest exact-commit workflow and PR #1 validation record** for execution results; a test's presence is not itself a passing result.

| Feature | Automated coverage | Runtime/device work still required |
|---|---|---|
| Inventory CRUD and adjustments | Simulator create, metadata edit, buy/use/delete, relaunch; Decimal clamping tests | Actual iPhone acceptance pass; concurrent native SDK edits |
| History and Undo | Simulator applied undo and retained stock; ledger unit/undo marker fixtures | Cloud undo under deployed rules; interrupted device operations |
| Charts/reporting | Included on exercised detail screen; data comes from actual ledger | Chart visual accuracy, accessibility and large type inspection |
| Shopping | Stable purchase-ID model test; linked completion and persistence UI scenario | List edits/reorder/automation, repeated tap/delivery on device |
| Barcode | UPC/EAN equivalence tests; unknown manual scan opens blank editor | Real camera scan, denial/re-enable, supported hardware |
| Expiration/reminders | Expiry calculation fixtures; reminder implementation inspected | Permission delivery, quiet hours, rescheduling, Focus settings |
| Offline storage/sync | Device-only relaunch; JS concurrent idempotency/ledger retention; persistent outboxes inspected | Native SDK airplane-mode/restart/reconnect and multi-device cases |
| Auth/account separation | Candidate-rules tests; native SDK two-account emulator UI scenario; account-scope collision test | Real email/Google login, keychain restoration and deployed rules |
| Migration/backup | Code review: explicit preview, empty destination, ledger-first resumable migration | Owner backup round trip, interrupted import, conflicting destination |
| Widgets | Extension build; shared configurable App Group and account command guards inspected | Provisioned App Group, timelines, interactive delivery/account switches |
| Watch | Companion build; WatchConnectivity/account boundary inspection | Install/pair, snapshot delivery, offline queues, stale account rejection |
| Siri/App Intents | Compiled phone intents; validation and in-app confirmation inspected | Shortcuts discovery, Siri execution, cancellation, account confirmation |
| Live Activities/Dynamic Island | Phone/widget build; local ActivityKit implementation inspected | Start/update/end on supporting hardware, lock screen, authorization denial |
| Legacy Logbook | All 17 baseline JavaScriptCore adapter tests pass; shared engine byte check | Authorized source/user scenarios with complete server history |
| Future native Logbook | Explicitly disconnected | Authorized owner-aware interface with stable UUID/revision/tombstones; contract in `../docs/LOGBOOK-ADAPTER-CONTRACT.md` |

## What is intentionally unfinished

Production Firebase registration/rules validation, signed device install, physical-device acceptance, shared-account deletion policy, conflict-review UI for ambiguous legacy reappearances, Watch complications, optional product database and optional Head Quarter endpoint are not completed. Telemetry remains disconnected. Reliable closed-app periodic sync and server APNs are not implemented. These are not silently substituted with sample data.

The only baseline Apple build warning found was App Intents metadata extraction skipped for a target with no AppIntents dependency (Watch); it does not block installation. Verify the latest build logs for new warnings. No signing claim is made from `CODE_SIGNING_ALLOWED=NO` simulator builds.

## Local validation commands

```sh
python3 native/scripts/test_configuration.py
swift test --package-path native
node ci/smoke.mjs
node --test ci/store-compat.test.mjs
(cd native/emulator && npm ci && npm test)
```

The normal Xcode Test action runs local UI scenarios; the emulator case skips unless explicitly enabled by the emulator runner. On a Mac, run the CI emulator path with a selected simulator UDID:

```sh
export PANTRY_SIMULATOR=YOUR_SIMULATOR_UDID
xcrun simctl boot "$PANTRY_SIMULATOR"  # Skip if already booted.
xcrun simctl bootstatus "$PANTRY_SIMULATOR" -b
cd native/emulator
npm ci
npx firebase emulators:exec --project demo-pantry-native --only auth,firestore \
  'node seed-ui.mjs && bash ../scripts/run-ui-tests.sh'
```

Remove or choose a fresh `native/TestResults/PantryUITests.xcresult` before repeating: Xcode does not overwrite result bundles. Seed accounts/data are synthetic; the seed and test scripts refuse missing/nonlocal emulator environment variables. Only Debug plus both `--ui-testing` and `--firebase-emulator` enables the hardcoded loopback Swift SDK test backend. Release builds cannot enter that backend. Never run destructive tests against production.

## Physical acceptance record (owner to fill after installation)

Device / iOS / Xcode / signed bundle ID / team: **not tested**.

For each feature above record: test account or device-only scope, synthetic fixture name, expected and observed behavior, pass/fail, and relevant screenshot/error. Use the exact steps in [INSTALL-ON-IPHONE.md](INSTALL-ON-IPHONE.md). Preserve source backups and pending queues while investigating failures.
