# Install Pantry on your iPhone

Use the existing `native/ios-pantry` branch and draft PR #1. This installs a development build; it does not publish to the App Store or deploy Firebase rules. Keep an existing browser backup before testing migration. Do initial cloud testing with dedicated test accounts, not daily-use inventory.

## 1. Prepare Xcode and your team

On your Mac, install Xcode 16 or newer with iOS 17+ and watchOS 10+ platform support. Open Xcode once to accept its license and install components. In **Xcode → Settings → Accounts**, add your Apple Account. Find your ten-character **Team ID** in your Apple Developer membership details. Certificates and device registration stay in Xcode/your Apple account; do not send signing keys or passwords to this chat.

From your clone:

```sh
git switch native/ios-pantry
git pull --ff-only
python3 native/scripts/configure-ios.py --team YOURTEAMID
open native/Pantry.xcodeproj
```

The exact project in this execution workspace is `/workspace/pantry/native/Pantry.xcodeproj`. On your Mac it is `<your clone>/native/Pantry.xcodeproj`. Open that project, not the Swift package (`Package.swift`). A separate workspace or CocoaPods installation is unnecessary. Allow Swift Package Manager to resolve Firebase 11.x and GoogleSignIn 8.x.

The script creates gitignored `native/Configuration/Local.xcconfig` and regenerates the project. All four targets (including UI tests) use automatic signing and the same team. Do not commit your local config or Firebase plist. If the default identifiers are unavailable to your team, choose your own **before installing or registering Firebase**:

```sh
python3 native/scripts/configure-ios.py --team YOURTEAMID \
  --bundle-id com.yourdomain.pantry --app-group group.com.yourdomain.pantry
```

This updates the phone, widget and Watch identifiers, Watch companion association and both App Group entitlements consistently. Changing the bundle ID later installs a separate app with separate storage. Changing the App Group disconnects old widget snapshots; reinstall widgets after making that change. Do not delete the original app until its data has been backed up.

In the project editor, check **Signing & Capabilities** on Pantry, PantryWidgets and PantryWatch: your team is selected, **Automatically manage signing** is checked, and no provisioning errors remain. The default identifiers are:

| Target | Bundle ID | Capability |
|---|---|---|
| Pantry | `dev.jacksonwilson.pantry` | App Groups: `group.dev.jacksonwilson.pantry` |
| PantryWidgets | `dev.jacksonwilson.pantry.widgets` | Same App Group |
| PantryWatch | `dev.jacksonwilson.pantry.watchkitapp` | Companion iPhone app, WatchConnectivity |

Confirm/register the App Group in Apple Developer **Certificates, Identifiers & Profiles → Identifiers → App Groups**, and enable it for both phone and widget identifiers. Xcode may do this automatically if your role permits it. Otherwise your team administrator must register it and refresh provisioning. The full widget configuration requires a team/profile that supports App Groups; a free Personal Team may not provision this capability. This cannot be resolved by committing a certificate or disabling signing. Notifications are local and Live Activities are local: no APNs key, Push Notifications entitlement, background fetch, Siri entitlement or CloudKit container is required by the current implementation.

## 2. Register the iOS Firebase application

Device-only inventory works before this step. To use existing cloud accounts:

1. Open Firebase Console for the **existing `logbook-e784a` project**. Under Project settings → Your apps, register an **Apple/iOS** app using the exact phone bundle ID above. Do not create a new Firebase project or reuse the web app registration.
2. Under Authentication → Sign-in method, verify Email/Password and Google are enabled. Configure Google's support email if requested. Use existing accounts/providers; do not delete/recreate users, reset UIDs, import users or bulk-reset passwords. This work has not changed production accounts.
3. Download that iOS app's `GoogleService-Info.plist`. If `CLIENT_ID` or `REVERSED_CLIENT_ID` is missing, enable Google and download a fresh plist.
4. Run locally, keeping your chosen identifiers consistent:

```sh
python3 native/scripts/configure-ios.py --team YOURTEAMID \
  --firebase-plist ~/Downloads/GoogleService-Info.plist
```

Include your previous `--bundle-id` and `--app-group` arguments if you customized them. The script checks project and bundle identities, installs the gitignored plist, sets Google's redirect URL scheme, and adds the resource to the project. It does not contact or configure Firebase Console. Never supply a service-account JSON, OAuth client secret or admin credential. If configuration is mismatched, the app stays in device mode and displays a repair message in Settings.

5. Have an authorized project owner review the **existing deployed rules** for owner-only access to `pantry/{uid}/items`, `ledger`, and `meta`, plus owner-only get access to `logbookV2/{uid}`. Pantry must not write Logbook. Native shopping uses additive `meta/nativeShopping`. `native/emulator/firestore.rules` is a test candidate, **not** a replacement for the production rules. If access is denied, record the path/error and request a review; do not broaden rules to all authenticated users or deploy this candidate wholesale.

## 3. Connect and run on iPhone

1. Connect an unlocked iPhone by USB, trust the Mac on the phone, and enable **Settings → Privacy & Security → Developer Mode** if requested. Restart the phone if iOS requires it.
2. Open Xcode **Window → Devices and Simulators**, wait for pairing/preparation, then select the **Pantry** scheme and your physical iPhone as destination. The phone must run iOS 17 or later.
3. Press **⌘R**. Let Xcode register the device and create development profiles if prompted. If your account lacks that permission, a team administrator must register the device and authorize development signing. Follow any trust/developer-app prompt on the phone.
4. The initial screen should open without a Firebase plist. In that case Settings explicitly reports device mode. For cloud mode, verify sign-in is enabled and use a dedicated existing-project test account first.

Do not add `--ui-testing` or `--firebase-emulator` to the normal Run scheme: those arguments are exclusively for synthetic automated tests. The checked-in Run schemes do not contain them.

## 4. Run a device acceptance pass

Record device/iOS version and pass/fail for each row in [DEVICE-READINESS.md](DEVICE-READINESS.md). None of these physical-device checks has been claimed as executed by this cloud task.

* **Inventory:** create a unique test item with unit `count`, threshold 2 and a recorded date. Buy 3, use 1, discard 1. History should show each applied change, quantities should never be negative, and Undo should reverse the selected applied change once. Edit its name/metadata; quantity must stay unchanged. View the chart, relaunch and confirm persistence. Delete only your synthetic item; history remains.
* **Shopping:** add a linked item, edit its list/quantity, complete with inventory addition, confirm one addition and retained shopping history. Reopening the app must not add it again. Test shopping-only completion and reordering separately.
* **Barcode:** tap Inventory → Scan, allow Camera, scan a printed UPC/EAN, and test manual entry. An unknown code opens a blank food editor with the code retained; no product name is guessed. Save and scan again to find that item. Deny Camera in iPhone Settings and confirm manual entry still works. Live scanning requires supported VisionKit hardware (iPhone with A12 Bionic or newer); older supported iOS devices can use manual entry.
* **Notifications:** enable reminders in Pantry Settings, grant notification permission, and set quiet hours and date lead time. Verify pending low-stock/date notifications on the phone. Focus modes, notification settings, denied permission and quiet hours affect delivery. Dates alone do not establish food safety.
* **Cloud:** sign in and verify only that account's inventory appears. Relaunch to check restoration; sign out only after pending queues resolve, test a second account, and return to the first. Device-only inventory must remain separate. With a test account, queue a quantity/edit while offline, relaunch offline, reconnect and Refresh; verify exactly one operation appears in server history and the queue clears. Use two authorized devices for concurrent edits. Do not assume the emulator tests establish behavior under your deployed rules.
* **Migration:** export a complete source backup, keep it unchanged, import only into an empty device pantry and review counts/IDs before confirming. A separate reviewed cloud migration accepts only an empty destination or a matching interrupted migration. Do not test replacement against a populated personal pantry. See the audit for non-restorable nightly summaries.
* **Widgets:** run Pantry once, add Home Screen and Lock Screen widgets, change synthetic stock/shopping and reopen the app. Confirm counts/names and deep links. Interactive shopping actions queue until the iPhone app applies them. Verify switching accounts removes stale account actions. If widgets stay blank, check both signed entitlements and App Group registration.
* **Shortcuts:** open Apple's Shortcuts app and find Pantry actions. Test screen-opening actions and add-stock/shopping actions. Mutations must show the correct account and require in-app confirmation. Cancel once and verify no change.
* **Live Activity:** create shopping rows, start the shopping session while Pantry is foregrounded, lock the phone and check progress. Complete a row and finish the session; the activity should end. Dynamic Island requires a supporting iPhone; the Lock Screen activity is the fallback. Enable Live Activities in iPhone Settings if disabled. No server push activity updates are configured.

Legacy Logbook reconciliation runs when Pantry is active, after account restoration and via manual refresh. Select a consumption start date and review food links with synthetic/authorized source data before enabling it for daily records. All 17 legacy adapter fixtures must continue to pass. **The future native Logbook interface remains disconnected**; its required owner/revision/tombstone contract is in `../docs/LOGBOOK-ADAPTER-CONTRACT.md`. No reliable closed-app periodic deduction is promised.

## 5. Apple Watch installation

Pair a watchOS 10+ Watch with this iPhone, enable Watch Developer Mode if requested, and install the matching watchOS platform in Xcode. The phone scheme embeds PantryWatch; use the iPhone's Watch app → Available Apps → Pantry → Install if automatic installation is off. A shared **PantryWatch** scheme is also provided: select it and your paired Watch in Xcode, then run.

Open Pantry on both devices. Confirm the Watch receives a dated phone snapshot and matching shopping/low-stock rows. Queue a shopping completion and a one-unit adjustment, reopen the phone app, then verify exactly one change in history. Repeat with the Watch disconnected and after a phone account switch; stale account commands must be rejected. Watch actions rely on the iPhone and WatchConnectivity delivery, and are not independent Firebase access. There are no Watch complications yet. Pairing and delivery remain unverified until this device pass is performed.

## Troubleshooting

* **Signing/App Group error:** confirm membership/role, exact registered identifiers, team on every target, and that profiles include the shared group. Use Xcode's signing repair tools; do not commit profiles/private keys.
* **Firebase keychain error in a simulator:** use the normal Xcode Run action or the signed simulator UI-test script. CI uses ad hoc signing plus `Simulator.entitlements`, selected only for `iphonesimulator`; signing-disabled builds are suitable for compilation checks but do not establish working Firebase keychain access. Physical iPhones use your real development profile and the ordinary entitlement file.
* **Google returns to browser or cannot sign in:** re-download the iOS plist after enabling Google, rerun the script, confirm Firebase bundle ID equals the signed phone bundle ID, then rebuild. Google is disabled if registration validation fails.
* **Permission denied / stale cloud status:** check connectivity, current account and authorized deployed rules. Preserve queued operations and backups. Never remove records or change rules just to clear an error.
* **Simulator AX initialization timeout:** this previously occurred before any app test and passed on rerun. CI now boots/waits for the simulator before testing, disables parallel UI clones, and captures simulator logs, screenshot and xcresult summary on failure. A simulator failure is separate from proof of physical-device behavior.
