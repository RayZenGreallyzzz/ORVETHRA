# Online training client (experimental)

Standalone scene: `res://scenes/training_online_test.tscn`. Existing main menu, offline training zone, models and scripts remain unchanged.

The scene shows connection status, the three server-owned training targets, server HP snapshots and attack responses. It sends **intent only**; no client-provided damage, loot or XP.

By default it connects to `ws://127.0.0.1:9087`, which works only when client and server share the same host. On Android, the server must be reachable via a secure WSS endpoint; do **not** expose the unauthenticated prototype directly.

Not yet implemented: production auth, TLS gateway, persistent player data, position syncing with the existing town scene, reconnection/resync, Android end-to-end APK testing. This is a separate test UI, not a production multiplayer client.
