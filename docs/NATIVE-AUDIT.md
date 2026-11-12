# Repository assessment — 2026-11-11

Baseline: `7c120b4`, only remote branch `main`, six commits from initial p1 through p4 and smoke-test CI. No AGENTS.md in checkout. README, all engine/store code, UI flows, styles, manifest, configuration, export and CI reviewed before implementation. Native work lives on `native/ios-pantry`; the production website is not deployed or replaced. The development branch includes one targeted `store.js` metadata-save compatibility fix with a synthetic regression test.

## Existing implementation

Web inventory CRUD, filters, low-stock dashboard, bought adjustments, history/undo, linking/ignore inbox, 12 themes, email/Google/device authentication and skippable setup exist. Firebase web SDK 10.13.2 uses project `logbook-e784a`. No iOS registration, deployed rules, indexes, emulator tests, backend scheduler or native Logbook contract is checked in. Nightly export is a read-only Node script; its actual scheduler and credentials are external and cannot be verified here. CI only checks static files and JavaScript syntax. No shopping, expiry, native widget/watch/scanner implementation exists at baseline.

## Wire contract

`pantry/{uid}/items/{existingID}`: name, qty, unit, category, lowAt, createdAt, updatedAt, updatedBy. Additional native fields are additive. `ledger/{operationID}`: id, itemId, itemName, unit, delta (APPLIED, clamped change), qtyBefore, qtyAfter, reason, source, note, ts (epoch milliseconds), undone. Meta documents state/links/inbox/ignored are maps. Links indexed by food ID: itemId, mode=auto|per, per, food. Source includes key/date/fid/meal/amt/unit/q/food. State includes startDate, lastProcessed, lastCheck, setup. Preserve unknown fields with merge writes.

Logbook is ONLY read at `logbookV2/{same uid}`. Its `r` map contains tombstoned or live `{v,t,d}` records; v can be JSON text. `foods#ID` describes foods; `food@YYYY-MM-DD` contains entries; mealSlots describes meals. No access to users collection is needed. Local browser localStorage is not available to native applications.

## Safety findings

* Cloud UI loads only 500 ledger entries. Deterministic direct transaction checks avoid duplicate writes, but incomplete history misses corrections. Native loads the COMPLETE ledger from server before planning, never treats widget/history caches as authoritative.
* Synthetic keys include amount/meal/quantity and occurrence ordinal, not raw array position. Reordering equal multiset entries is safe; editing creates removal+addition; removal of either identical occurrence is indistinguishable but quantity-equivalent. Remove then re-add leaves original eaten/correction IDs occupied. Native flags this for review instead of inventing a stronger identity or rededucting.
* Web global timestamp cursor can miss older timestamps, metadata-only/link changes and deleted days. Native scans every available day from startDate and includes previously consumed dates as empty when absent. No cursor alone proves an event absent.
* Clamping loses unmet consumption; native ledger adds requestedDelta/unfulfilled while keeping legacy applied delta. Corrections reverse the APPLIED delta for compatibility. This does not retroactively recover lost historic intent.
* Unknown serving/mass-volume conversion in web falls back to per=1. Native requires an explicit verified per link or compatible measured units before automatic processing. It validates the actual recorded entry unit as well as the food definition unit; otherwise the legacy engine can fall back to one serving on a mass/volume mismatch.
* Atomic per-operation inventory/ledger writes exist. Multi-operation sync isn't atomic; deterministic IDs enable retry. Native advances lastCheck only after every operation succeeds. A Logbook source can change during a sync; next foreground full scan reconciles it. Concurrent source generations and remove/re-add ambiguities need a future versioned integration contract.
* Older web clients can overwrite item fields and whole meta maps. This branch changes web metadata saves to merge only the edited fields and omit cached qty for existing items. The regression test simulates a concurrent native deduction and confirms both the quantity and native-only fields survive. Already-open older web clients still need to reload the updated code after deployment. Whole meta-map writes remain a legacy-client concurrency limitation.

Follow-up read-only inspection located Logbook native work in `logbook-v2/native-ios-development`: its current implementation stores local JSON and explicitly has no Firebase/account sync or Pantry interface. It cannot currently feed Pantry v2 synchronization. No assumptions or modifications to that project. See adapter contract and native README for validation and release gates.
