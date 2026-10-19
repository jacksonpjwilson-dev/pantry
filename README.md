# Pantry

A small pantry app that goes with Logbook v2. Live at https://jacksonpjwilson-dev.github.io/pantry/

- Home widgets (low stock, recently eaten, link inbox, bought, history), a full Items list, item detail with history and undo, add/edit, "Bought" quick add, and Settings with Light/Dark/Auto and 12 colourways.
- Sign in with Google or email (same Firebase project as Logbook v2, logbook-e784a), or continue without an account (this device only).
- Data: `pantry/{uid}` with subcollections `items`, `ledger` and `meta` (docs `state`, `links`, `inbox`, `ignored`).
- Auto-decrement: reads Logbook v2 food logs (`logbookV2/{uid}`, read only) newer than `meta/state.lastProcessed`. Linked foods come off stock with unit conversion (count, g/kg/oz/lb, ml/L/fl oz/cup/tbsp/tsp). Unlinked foods wait in the "Link to pantry?" inbox and links are remembered. Every eaten entry has a stable source key and its ledger id is derived from it, so nothing is counted twice. If an entry is edited or removed in Logbook, the stock is put back once.
- Never writes to `logbookV2/{uid}` or `users/{uid}`.
- `tools/export-pantry.mjs`: read-only nightly export to `/home/box/shared/crew/pantry.json` (path B). Needs a service-account key from `PANTRY_SA_KEY_FILE`; never commit keys.
