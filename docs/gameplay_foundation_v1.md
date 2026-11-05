# ORVETHRA — complete gameplay foundation v1 (experimental)

This branch, `feature/orvethra-gameplay-foundation-v1`, is based on `feature/android-training-client-v1`. **It does not change `main`, OE Engine, existing city construction data, or saved player files.** Data-level systems are wired together through `gameplay_state.gd` and exercised by headless integration tests. They are NOT yet wired into the 3D city's HUD or persistently hosted on an MMO server.

## Implemented foundations (actual code)

| Domain | Where | Tested behavior |
| --- | --- | --- |
| RPG stats, seven primary stats including LUK | `scripts/mmorpg/core_stats.gd` | Derived stats, leveling, equipment modifiers; game-authored balance |
| Hit/crit/defense, MP, cooldowns | `combat_math.gd`, `skill_system.gd` | Configurable original combat formula, deterministic seeded RNG |
| Professions and job points | `class_rules.gd` | Starting class, job XP/JP, specialization after job level 20, once-only skill learning |
| Equipment and inventory | `inventory_system.gd`, `equipment_rules.gd` | Slots, single-item equip with rollback on failure, stats recalculation |
| Regular-monster rewards and drops | `reward_rules.gd`, `loot_system.gd` | Independent XP and loot penalties, bounded item-stack commit, exactly-once encounter ID |
| **Training targets** | `server/training_zone.gd`, `scripts/combat.gd`, `reward_rules.gd` | **Never XP, silver, cards, or drops**; tutorial kill count for practice quests may still change |
| Pet cards / taming | `pet_system.gd`, `gameplay_state.gd` | Ownership, unique card IDs, mark target with compatible blank card, defeat target, consume blank on success/failure |
| Summoned pet combat + XP | `pet_combat_rules.gd`, `gameplay_state.gd` | Companion stats and test attack; active pet gets 50% of regular-monster XP; zero from tutorial targets |
| Pet evolution / overbreeding | `pet_system.gd` | Evo I–III; threshold levels 50/100; OB ranges 51–60 and 101–115 grant 2 JP/level |
| Pet staging Epic 7-inspired | `pet_system.gd` | Two tamed cards of same species/stage + catalyst, S0–S5, main card protected on failure, 8 stage JP each, visual tier at S3 |
| Simple quests | `quest_rules.gd` | Kill progress only for regular targets, one-time claim with capacity check |
| Buying/selling | `economy_rules.gd` | Atomic bag/wallet update using **server catalog price**; no player-driven prices |
| Android gliding rule set | `flight_rules.gd` | Takeoff conditions, energy, sink speed, landing; existing `city_preview.gd` remains unchanged |
| Shared gameplay state and offline JSON schema | `gameplay_state.gd` | Composition of actor, pet stable, job, quests, inventory, equipment, flight, defeat-id ledger; owner and version verification |

## Design source and deliberate choices

Our reference is the ORVETHRA research report dated **2026-11-04**: gameplay feeling from Rappelz 2008–2009 (Epic 5–6), pets with Epic 7 S0–S5, and wings inspired by Aion. No proprietary code was copied. Official, emulator, community, and **ORVETHRA-authored** balance are different. In particular:

- `balance_catalog.gd` contains **demo/proposed rates**, not verified historical Rappelz rates. S1–S5: 85%, 65%, 45%, 30%, 18%; taming rarity defaults: 80%, 25%, 7%, 2%. These are adjustable in a trusted server build.
- `PetSystem.combine`: failed attempt consumes material card and catalyst, but not main; successful attempt resets to Lv.1/Evo I, resets skills and assigns cumulative `8 * stage` JP. Resetting Evo to I is an explicit ORVETHRA technical rule to keep progression coherent; review this rule before production.
- `taming` requires defeating the **marked regular creature**. Training slime cannot be marked via `GameplayState.start_tame`.
- The original `scripts/city_training.gd` training slimes never granted XP/currency; their beginner tutorial/quest **counter** may still advance. The formerly rewarding separate `scripts/combat.gd` tutorial and `server/training_zone.gd` have now been made zero-reward too.
- Camera gliding code from the Android prototype is kept unchanged. This module models rules; game-level movement synchronization and complete free flight are future work.

## Boundary: foundation is not a finished MMORPG

Not implemented or not integrated: live inventory/pet screens, real pet models, companion follow AI, cooldown validation and abilities, class UI/quests, complete server persistence, authentication/TLS/WSS, authoritative networking for all operations, anti-cheat, transactions in a real database, player trading/auction, LOD/streaming for the entire game, end-to-end tablet performance and soak tests. The server prototype still only has a small training zone. Neither a passing smoke test nor Android build verifies the game on the tablet.

## Testing

```bash
godot --headless --path . --script res://tests/mmorpg_core_smoke.gd
godot --headless --path . --script res://tests/mmorpg_foundation_smoke.gd
godot --headless --path . --script res://tests/server_training_smoke.gd
godot --headless --path . --script res://tests/gliding_smoke.gd
```

`MMORPG_FOUNDATION_OK` covers regular vs training rewards, exactly-once kill IDs, quests, blank cards, capture, OB, Evo, success/failure S0–S5, class JP, equipment, economy, flight and schema serialization. Existing city/launcher tests must remain green before any branch integration.

**Recommended next step:** a separate gameplay adapter + minimal pet/inventory HUD that reuses `GameplayState`, beginning with a *regular forest wolf* **outside** the beginner training enclosure. A regular forest wolf may give XP and blank pet cards; the nine tutorial slimes never will.
