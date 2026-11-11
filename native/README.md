# Pantry for iOS

Native SwiftUI iOS 17+ application alongside the unchanged production website. Open `Pantry.xcodeproj`; shared scheme **Pantry** builds the phone app, WidgetKit extension and watchOS 10 companion. Pure Decimal calculations are also a Swift package (`swift test`). Project files are deterministic and can be regenerated with `python3 scripts/generate-project.py` after adding source files.

## Configure on a Mac

1. Select your Apple development team on all three targets. Register the bundle IDs `dev.jacksonwilson.pantry`, `.widgets`, and `.watchkitapp` (or consistently replace them).
2. Enable the shared App Group `group.dev.jacksonwilson.pantry` for phone/widget. Replace the identifier everywhere if your team uses another group.
3. Register an **iOS** app for that phone bundle ID in the existing Firebase project **logbook-e784a**. Download its `GoogleService-Info.plist` into `native/Pantry/`. Do not reuse the web app ID. Regenerate the project to include the local plist; it is gitignored. Never put service-account keys in the app.
4. Add the plist's `REVERSED_CLIENT_ID` as another URL scheme in `Configuration/App-Info.plist` for Google sign-in. Preserve the `pantry` deep-link scheme. Enable the intended Firebase authentication providers in the existing project. A missing plist leaves the app in fully local device mode.
5. Review existing production rules. `emulator/firestore.rules` is an **isolated test candidate**, not a complete replacement for Logbook's deployed rules. Preserve existing authorized Logbook writes in its own app. No rules are deployed by this project.
6. Build for an iPhone simulator: `xcodebuild -project Pantry.xcodeproj -scheme Pantry -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Use a provisioned device for camera, Google sign-in, Watch pairing and Live Activity validation.

Firebase and GoogleSignIn use Swift Package Manager. No paid dependency or CloudKit source of truth is added. Device-only mode does not need Firebase configuration. Simulator camera hardware may be unavailable; manual barcode entry remains available.

## Behavior and compatibility

* Inventory list/search/category/sort, item metadata, add/edit/delete, bought/used/discarded adjustments, low-stock suggestions, applied history/undo and per-item Charts use actual stored data.
* Quantity edits go through ledger operations; metadata editing cannot overwrite concurrent quantity changes. Units are immutable after item creation to protect existing ledger interpretation.
* SwiftData stores account-separated snapshots and durable manual adjustment/item-edit/shopping outboxes. Firestore is authoritative when signed in. Transactions require network; queued changes are replayed with stable IDs and displayed as pending. Device-only changes apply immediately. Deletion/undo require network in cloud mode. Pending cloud changes must resolve before sign-out.
* Native item fields are additive and merge-written. The existing website's item save still replaces a whole document; editing the same enriched item in an older web client may drop native-only fields. Coordinate a separate web merge-write update before production rollout. No such change is silently deployed here.
* Full server history is loaded before Logbook planning. Shared JavaScriptCore engine preserves production synthetic IDs and conversion factors; additional native guards reject ambiguous reappearances, invalid amounts and unverified serving conversion. See the audit and adapter contract in `../docs/`.
* Links/ignore/inbox use existing meta documents. New shopping rows live under individual fields of `meta/nativeShopping`, one JSON string per stable shopping ID. Unrelated shopping rows merge independently; simultaneous edits to the same row are last-writer-wins. Explicit purchase IDs prevent double inventory additions. This is a new additive metadata document, not a migration of existing inventory.
* Device inventory stays separate when signing in. There is no implicit local-to-cloud upload and no access to browser localStorage. Do not erase a device snapshot to resolve a cloud error. A reviewed browser export/import migration remains a release task.
* Foreground/activation and pull-to-refresh synchronize. No claim of reliable periodic iOS background execution. Widgets display cached counts, use an App Group, and deep-link; they do not write Firestore. The Watch queues shopping completion and unit adjustments through WatchConnectivity with an account boundary check. It needs iPhone to apply changes. A shopping-only Live Activity supports finishing the session, a progress display and Dynamic Island. It is user initiated, not passive monitoring.
* Optional notifications use recorded dates and low-stock episode deduplication, with quiet hours. Reminder configuration is local; no server APNs service is installed. Notifications are not proof a food is safe/unsafe.
* Shortcuts open screens or bring a validated mutation to an in-app account-aware confirmation. Head Quarter's HTTPS/Keychain adapter accepts health-only reports; no endpoint is configured and no telemetry is transmitted.

## Tests

`swift test`: Decimal conversions, clamping/applied undo, low stock, expiry, purchase identity, legacy UTF-16 hashing and (on Apple platforms) JavaScriptCore reconciliation fixtures: duplicate replay, correction, deleted days, identical occurrences/reorder, ambiguous reappearance, missing metadata and invalid quantities.

`cd emulator && npm ci && npm test`: isolated `demo-pantry-native` Firestore tests for authentication boundaries, forbidden Logbook/unrelated writes, concurrent idempotent application, historical replay prevention and ledger retention. They test the proposed rules and transaction invariants, not a live Firebase account or the Swift Firebase SDK end to end.

Existing `node ../ci/smoke.mjs` must run from the repository root as `node ci/smoke.mjs`. The website's smoke test is unchanged. CI has separate macOS Swift/Xcode and Linux emulator jobs. All fixtures are synthetic; never point these tests at production.

## Release gates / remaining work

* Confirm Xcode builds and simulator launch on the final branch, then test Firebase native registration, Google redirect, deployed security rules and account restoration with an authorized test user.
* Run native SDK multi-device/offline/concurrent source-edit scenarios against a dedicated emulator configuration. The current emulator suite does not exercise the Swift repository end to end.
* Test Watch pairing/delivery, camera denial, WidgetKit timelines, interactive widgets, Dynamic Island, VoiceOver and large Dynamic Type on devices.
* Add a reviewed explicit browser/device import workflow, account deletion with retained-record policy, and conflict review UI for legacy remove/re-add cases. Current behavior stops safely with an actionable message.
* Home widgets currently emphasize counts rather than complete editable shopping lists. Watch complications, product database lookup, configurable expiry lead days, full theme typography and push-based background health alerts remain follow-up work.
* Authorize/version the future native Logbook interface before connecting it. Supply an authorized Head Quarter endpoint/token if telemetry is desired. Keep both disconnected until then.

This is a development branch, not a claim of completed production validation or all requested release features.
