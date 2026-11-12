# Read-only Logbook adapter contract

## Current adapter

`native/PantryCore/LogbookAdapter.swift` reuses the byte-for-byte bundled `engine.js` through Apple's JavaScriptCore. It is actual native execution of shared calculation code, not a web view. The native storage/transactions/UI are Swift. Hashing uses the same UTF-16 FNV/DJB combination and existing `e_`, `c_`, `u_` IDs. Existing ledger document IDs override any inconsistent embedded ID when loaded.

Only a full **server** inventory + ledger + metadata snapshot may be passed to reconciliation. UI caches and widget snapshots are never absence proofs. The adapter scans the complete available source from the user's startDate, includes dates from prior eaten transactions when a whole day disappears, and disregards the web global timestamp checkpoint. A missing whole source document is disconnected, not an instruction to restore every meal. Inbox entries are removed only after adjustment transactions commit. Native does not advance the shared web cursor, so older web clients may continue their own checks.

A per link is explicit user verification of inventory units per logged serving. Legacy auto links require compatible measured units. Missing metadata becomes an inbox item; invalid or unverifiable quantities stop the plan before any adjustments. Native retains requestedDelta and unfulfilled alongside the legacy applied delta. Corrections and undo reverse applied changes, never fictitious negative stock.

## Legacy limitations requiring review

Identical entries are a multiset, keyed by day, fid, meal, amt, unit, q and occurrence number. Reorder is stable for that multiset. An edit is removal plus addition. Equal occurrences cannot be distinguished by real identity. A removed entry that returns after a correction has the same eaten/correction IDs; native blocks and requests review. Native never changes its ID to bypass a production dedup marker. Hash collisions are checked against item/source keys at write time. Old web clients lack these extra checks.

Source reads and multiple destination transactions do not form a distributed transaction. A source edit during synchronization will reconcile on a later full scan; divergent source snapshots across devices may require review. Exactly-once *operation application* is provided by ledger document transactions. Strongly ordered, repeated event lifecycles require an authorized versioned source contract. Do not claim global distributed exactly-once event semantics from legacy arrays.

## Proposed future interface — not connected

Read-only investigation found `jacksonpjwilson-dev/logbook-v2`, branch `native-ios-development`. Its native README, MIGRATION.md, LogbookStore and shared models describe local JSON persistence in an App Group, with no Firebase registration, account sync, or published Pantry interface. Native food logs therefore do not currently reach `logbookV2/{uid}`. The branch was inspected without modification. No access to its SwiftData store is assumed. The owner must authorize a published read interface. Proposed envelope:

```
accountSubject: authenticated owner mapping (never email-based guessing)
sourceNamespace: stable deployment identifier
snapshotRevision: monotonic revision with full-snapshot consistency
isComplete: true | false
entries: [{entryID, revision, occurredAt, foodID, displayName,
           amount: decimal string, unit, verifiedServing?, tombstone}]
```

`entryID` must survive reordering and edits; distinct occurrences have distinct IDs. Retained tombstones/revisions describe removals. A checkpoint is committed only after all operations through the revision are acknowledged. Provide a consistent full baseline and explicit retention/window semantics so absence outside a partial window never means deletion. Units require declared mass/volume/count family and verified item serving conversions; no density guesses.

The destination adapter should store deterministic *revision transitions* (not merely one eaten ID per entry) and transactionally compare a per-source applied revision before changing stock. It must recognize a reviewed alias map from imported legacy source keys to new entryIDs, with old ledger IDs retained. No automatic aliasing based on food name or array position. Include replay, out-of-order, edit/remove/re-add, account switch, and concurrent-device emulator tests before enabling it. Pantry never writes the source under this contract.
