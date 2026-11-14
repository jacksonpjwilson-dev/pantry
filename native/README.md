# Pantry for iOS

Native SwiftUI iOS 17+ application alongside the existing production website (no deployment performed). Open `Pantry.xcodeproj`; shared scheme **Pantry** builds the phone app, WidgetKit extension and watchOS 10 companion. Pure Decimal calculations are also a Swift package (`swift test`). Project files are deterministic and can be regenerated with `python3 scripts/generate-project.py` after adding source files.

See [Install on iPhone](INSTALL-ON-IPHONE.md) for the complete signing/Firebase/device workflow and [Device readiness](DEVICE-READINESS.md) for coverage versus unverified runtime behavior. Personal settings live in gitignored `Configuration/Local.xcconfig`; `scripts/configure-ios.py` validates and prepares all targets together.

## Configure on a Mac

1. Run `python3 native/scripts/configure-ios.py --team YOURTEAMID` from the repository root. Add `--firebase-plist /path/to/GoogleService-Info.plist` for the registered iOS client in existing project `logbook-e784a`. Optional `--bundle-id` and `--app-group` customize all related identifiers together. The script sets the Google URL scheme and regenerates the project; no manual source edits are required.
2. Open `native/Pantry.xcodeproj`, choose **Pantry**, select your iPhone and verify automatic signing/team and App Group provisioning for phone/widget. Choose **PantryWatch** for a paired Watch. See the installation guide for Apple/Firebase Console steps and capability restrictions.
3. Simulator build: `xcodebuild -project native/Pantry.xcodeproj -scheme Pantry -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Device signing and runtime checks require the owner's Mac/accounts/devices.
4. Production rules and data are unchanged. `emulator/firestore.rules` remains an isolated test candidate, not a replacement for Logbook's deployed rules.

Firebase and GoogleSignIn use Swift Package Manager. No paid dependency or CloudKit source of truth is added. Device-only mode does not need Firebase configuration. Simulator camera hardware may be unavailable; manual barcode entry remains available.

## Behavior and compatibility

* Inventory list/search/category/sort, item metadata, add/edit/delete, bought/used/discarded adjustments, low-stock suggestions, applied history/undo and per-item Charts use actual stored data.
* Quantity edits go through ledger operations; metadata editing cannot overwrite concurrent quantity changes. Units are immutable after item creation to protect existing ledger interpretation.
* SwiftData stores account-separated snapshots and durable manual adjustment/item-edit/shopping outboxes. Firestore is authoritative when signed in. Transactions require network; queued changes are replayed with stable IDs and displayed as pending. Device-only changes apply immediately. Deletion/undo require network in cloud mode. Pending cloud changes must resolve before sign-out.
* Native item fields are additive and merge-written. This branch also fixes web metadata saves to merge edited fields and exclude cached quantity for existing items. A synthetic test verifies a concurrent native deduction and native-only fields survive. Already-open older web clients need to reload the updated code after deployment. No production website deployment is performed here.
* Full server history is loaded before Logbook planning. Signed-in cold starts check Logbook after account restoration; in-flight sync results are discarded if account scope changes. Malformed or unsupported source snapshots stop safely instead of restoring stock based on unreadable data. Shared JavaScriptCore engine preserves production synthetic IDs and conversion factors; additional native guards reject ambiguous reappearances, invalid amounts and unverified serving conversion. See the audit and adapter contract in `../docs/`.
* Links/ignore/inbox use existing meta documents. New shopping rows live under individual fields of `meta/nativeShopping`, one JSON string per stable shopping ID. Unrelated shopping rows merge independently; simultaneous edits to the same row are last-writer-wins. Explicit purchase IDs prevent double inventory additions. This is a new additive metadata document, not a migration of existing inventory.
* Device inventory stays separate when signing in. Settings can preview a complete browser/native JSON backup and import it only into an empty device-only pantry. A separate confirmed device-to-cloud migration requires an empty cloud pantry or a matching interrupted migration, imports ledger history first, preserves identifiers, rejects conflicting records and keeps the local source. It does not directly access browser localStorage. Export the complete `pantry:local` JSON object from the browser; the nightly export summary lacks restorable IDs/history. Do not erase a source snapshot to resolve a cloud error.
* Foreground/activation and pull-to-refresh synchronize. The existing `meta/state.setup.linkV2` off preference is honored by both the native sync controller and reconciliation adapter; Settings edits that same flag. No claim of reliable periodic iOS background execution. Widgets display cached counts and food/shopping rows through an App Group, and deep-link. Interactive shopping actions write account-scoped durable commands for the iPhone; widgets never write Firestore directly. Accessory families show counts/status rather than food names. The Watch queues shopping completion and unit adjustments through WatchConnectivity with an account boundary check. It needs iPhone to apply changes. A shopping-only Live Activity supports finishing the session, a progress display and Dynamic Island. It is user initiated, not passive monitoring.
* Optional notifications use recorded dates and low-stock episode deduplication, with quiet hours. Reminder configuration is local; no server APNs service is installed. Notifications are not proof a food is safe/unsafe.
* Shortcuts open screens or bring a validated mutation to an in-app account-aware confirmation. Head Quarter's HTTPS/Keychain adapter accepts health-only reports; no endpoint is configured and no telemetry is transmitted.

## Tests

`swift test`: Decimal conversions, clamping/applied undo, low stock, expiry, purchase identity, legacy UTF-16 hashing and (on Apple platforms) JavaScriptCore reconciliation fixtures: duplicate replay, correction, deleted days, identical occurrences/reorder, ambiguous reappearance, missing metadata and invalid quantities.

`cd emulator && npm ci && npm test`: isolated `demo-pantry-native` Firestore tests for authentication boundaries, forbidden Logbook/unrelated writes, concurrent idempotent application, historical replay prevention and ledger retention. They test the proposed rules and transaction invariants, not a live Firebase account. The macOS UI job separately runs the Swift Firebase SDK against isolated Auth/Firestore emulators; see the readiness record.

Run `node ci/smoke.mjs` and `node --test ci/store-compat.test.mjs` from the repository root. The original smoke test is unchanged; the new regression test covers the web/native metadata boundary. CI has separate macOS Swift/Xcode and Linux emulator jobs. Native UI tests create synthetic local stock, purchase/consume/undo it and verify persistence after relaunch; `--ui-testing` disables Firebase regardless of any bundled configuration. All fixtures are synthetic; never point these tests at production.

## Release gates / remaining work

* Confirm Xcode builds and simulator launch on the final branch, then test Firebase native registration, Google redirect, deployed security rules and account restoration with an authorized test user.
* Run native SDK multi-device/offline/concurrent source-edit scenarios against a dedicated emulator configuration. The added native emulator UI scenario covers sign-in, stock and account switching; airplane-mode/restart/reconnect and multi-device conflict scenarios still require runtime testing.
* Test Watch pairing/delivery, camera denial, WidgetKit timelines, interactive widgets, Dynamic Island, VoiceOver and large Dynamic Type on devices.
* Validate the reviewed browser/device import workflow with owner-provided backups; add account deletion with a retained-record policy and conflict review UI for legacy remove/re-add cases. Current behavior stops safely with an actionable message.
* Watch complications, optional product database lookup, full theme typography and push-based background health alerts remain follow-up work. Expiry reminders offer three/seven day lead times; local reminders refresh after inventory changes when enabled.
* Authorize/version the future native Logbook interface before connecting it. Supply an authorized Head Quarter endpoint/token if telemetry is desired. Keep both disconnected until then.

This is a development branch, not a claim of completed production validation or all requested release features.
