# ORVETHRA MMORPG Core — foundation

This is an **original data-only gameplay foundation**, not copied proprietary code or verified Rappelz M formulas.

## Modules
- `scripts/mmorpg/core_stats.gd`: six attributes, derived stats, HP/MP, experience and levels.
- `scripts/mmorpg/combat_math.gd`: deterministic seeded hit/crit/defense/damage resolution.
- `scripts/mmorpg/skill_system.gd`: skill gating, MP costs, cooldowns and timed modifiers.
- `scripts/mmorpg/inventory_system.gd`: bounded stack inventory with atomic removal.
- `scripts/mmorpg/loot_system.gd`: data-defined independent drop rolls.

All modules extend `RefCounted`, require no scene or GLB, and are not yet wired into the existing combat UI. Existing gameplay and local saves are untouched.

## Visuals and AI remain independent
Attach later: character and mob models, animation mappings, boss phases, NPC dialog, navigation and AI. The `id` field links data to future asset catalogs; gameplay logic does not assume a particular mesh.

## Balancing and security
Numbers are **starter formulas**, not reverse-engineered Rappelz M values. For online play, the authoritative server must execute damage, XP, loot, item transactions, and cooldown validation. Client-only checks are not anti-cheat.

## Test
Run `godot --headless --path . --script res://tests/mmorpg_core_smoke.gd` after importing project assets. This test covers XP, skill cooldowns, inventory atomicity, and deterministic combat/loot invocation.

## Next integration
Add an adapter to the existing training combat, migrate save schemas with backward compatibility, then build server-authoritative entity state. Do not replace existing scripts until scene-level Android tests pass.
