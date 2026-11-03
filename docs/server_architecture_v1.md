# ORVETHRA authoritative MMORPG server — design v1

Status: **design**, not a deployed server. Target client: Godot 4.3 / Android Compatibility renderer. Existing offline mode is unchanged.

## Trust boundaries
The Android APK is **untrusted**. The client submits intent, not results. Never accept client-supplied damage, XP, HP, inventory balances, item attributes, drop rolls, shop prices, or wallet balances. The server alone owns mutable gameplay state.

```text
Godot Android client (untrusted)
   | TLS + authenticated session, monotonic command seq, request_id
   v
Gateway (auth, payload bounds, per-session limits, routing)
   | trusted internal transport
   +--> Zone simulation (authoritative movement, combat, mob AI, cooldowns)
   |        | durable reward/outbox events
   |        v
   +--> Economy service (items, currency, shops, trading, auctions)
   |        |
   |        v
   +--> PostgreSQL (durable truth, constraints, transactions, audit)
   |
   +--> Redis (ephemeral sessions / presence / rate limits; never sole item ledger)
```

For first playable milestone, run gateway, zone simulation, and economy in **one server process** with clear module boundaries; split services only when load requires it. PostgreSQL remains transactional authority.

## Message protocol v1
- Client sends `hello` / `auth` over TLS, then `move_intent`, `cast_skill`, `pickup`, `equip`, `buy`, `trade_offer`, `trade_confirm`.
- Envelope: `{v:1, type:string, request_id:string, seq:int, payload:object}`. Session identity comes from validated authentication, **not** a client-supplied player_id.
- Server returns `ack`, `reject`, `state_delta`, `inventory_snapshot`, `wallet_snapshot`, `combat_event` and `resync_required`.
- Bound message size, string length, entity IDs and numeric ranges. Reject unknown command types. Use sequence numbers for ordering and a bounded per-session dedupe window.
- `request_id` is an idempotency key for durable economy commands; persist the result with a unique (account_id, request_id) constraint. Replays return the recorded result, not a second grant.
- Use secure authenticated transport (WSS/TLS), token expiration, key rotation, account/session revocation, and per-IP/per-account throttling. Do not hardcode production secrets in APK.

## Authoritative combat
1. Client sends `cast_skill {skill_id, target_entity_id}`; client damage, position and cooldown fields are ignored.
2. Server verifies session, ownership, alive status, zone, target visibility, distance, line of sight where required, skill learned, MP, cooldown, stun/silence and attack rate.
3. Server atomically reserves MP/cooldown in zone state, resolves hit/crit/damage using server RNG and server-owned stats, then emits sequenced combat events.
4. On death, server marks target defeated **once** and emits an idempotent reward event. Rewards are granted in a durable transaction; reconnection must not double-grant.
5. Client interpolates positions and plays animations. Server reconciles movement against collision/nav and speed constraints; reject teleports and impossible action rates.

## Inventory and economy invariants
- Item instance has immutable `instance_id` and server-owned `template_id`, `owner_id`, quantity, binding and version.
- Stack transfers are transactional: verify ownership, quantities, capacity, trade locks and item versions; decrement and increment in **one** database transaction.
- Currency uses integer smallest units (no floating point); balances are constrained nonnegative, with ledger entries and unique idempotency keys.
- Shop purchase: server-side price catalog + balance/capacity check + debit + item grant + ledger + result in one transaction.
- Player trade: lock both offers, revalidate item ownership and funds, commit both sides together or neither. Disconnect cancels uncommitted trade.
- Auctions: reserve items/funds server-side, enforce listing ownership, expiration and bid ordering in transactions. Never trust UI prices.
- Persistent reward inbox/outbox avoids lost/duplicate grants when zone and economy processes retry.
- Backups, restore drills, audit events and admin permissions are required before real-money integration.

## Initial relational schema (conceptual)
```sql
accounts(id PK, auth_subject UNIQUE, status, created_at)
characters(id PK, account_id FK, zone_id, level, xp, stats_json, revision)
wallets(character_id PK FK, balance BIGINT CHECK (balance >= 0), revision)
currency_ledger(id PK, character_id FK, delta BIGINT, reason, request_id, created_at,
                UNIQUE(character_id, request_id))
item_instances(id PK, template_id, owner_character_id FK, quantity CHECK(quantity > 0),
               binding, revision)
transactions(id PK, account_id FK, request_id, result_json, status,
             UNIQUE(account_id, request_id))
reward_events(id PK, source_event_id UNIQUE, character_id FK, status, created_at)
trade_sessions(id PK, state, revision, expires_at)
```
Enforce foreign keys, unique constraints, and row-level locks as appropriate. The ledger alone is not enough: update wallet + ledger atomically, with reconciliations.

## State and recovery
- Zone runs fixed simulation ticks, maintains entity IDs and snapshot sequence, and broadcasts only nearby relevant entities.
- Persist character checkpoints on safe intervals and on zone transitions; persist inventory/currency changes transactionally immediately.
- Zone transition uses an explicit handoff token/lease; a character cannot be active in two zones simultaneously.
- Reconnect resumes a server-owned session or performs authoritative resync; stale commands are rejected.

## Implementation stages
1. Implement **headless Godot server prototype** reusing `scripts/mmorpg` data-only calculations; never import client combat UI.
2. Add command validation, fixed tick, movement/skill checks, combat events, and replay tests.
3. Add PostgreSQL persistence and idempotent item/currency operations with concurrency tests.
4. Add authenticated gateway, TLS termination, limits, reconnect and zone handoff.
5. Add telemetry, abuse alerts, load tests and staged Android integration.

## Acceptance tests (must pass before calling it secure)
- 100 repeated identical purchases => one debit and one grant.
- Concurrent inventory transfers => no negative stacks, no duplicate item instance.
- Replayed kill event => one XP/drop reward.
- Forged damage/XP/balance fields => rejected or ignored.
- Cast from impossible range, zero MP or during cooldown => rejected.
- Client teleport/speed hack => authoritative correction.
- Disconnect during trade => no partial transfer.
- Server crash between reward production and commit => eventual single delivery.
- Reconnect with stale sequence => resync, no state rollback.

## Scope and migration
Existing `scripts/combat.gd` uses `user://orvethra_training.json` and client-side `hp`, `exp_points`, `silver`; this is valid for offline training **only**. Keep it working until a separate online scene/adapter has been tested. No client-side JSON can become the source of truth for online characters.

No Rappelz M proprietary code or undocumented formula is copied. Balance numbers remain tunable and server-owned.
