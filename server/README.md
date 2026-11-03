# Training combat server prototype

Run with Godot 4.3: `godot --headless --path . --script res://server/training_server.gd`.
Default: **127.0.0.1:9087**, unencrypted WebSocket; intentionally loopback-only. This is a local prototype and cannot be reached directly from an Android tablet on another machine.

Three server-owned training mobs: `training_0`, `training_1`, `training_2`. Initial hero position: (13,19). Commands: `{"seq":1,"type":"cast_skill","payload":{"skill_id":"basic_attack","target_entity_id":"training_0"}}`. Movement: `{"seq":2,"type":"move_intent","payload":{"x":13.5,"y":19}}`. The server sends a snapshot on connection and a response for each command.

Security scope: server owns damage, HP, XP, silver, loot, cooldowns and movement speed; replays are rejected by per-session sequence. **Not production secure**: no login, TLS, PostgreSQL, durable idempotency, persistence, collision checks or rate limiting yet. A client disconnect currently loses its progress. Do not expose this listener to the internet or accept real-money transactions.

Next: add authenticated WSS gateway and durable transactions, then Android client adapter. Existing offline combat and visual assets are untouched.
