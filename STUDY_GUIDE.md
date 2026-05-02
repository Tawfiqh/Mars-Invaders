# Godot Invaders — Study Guide

## What We're Building
A Space Invaders-inspired game built in Godot 4 where gameplay revolves around a central planet. Instead of the classic flat layout (enemies above, player below), everything orbits a planet at the center of the screen. The player circles the planet and shoots outward; enemies orbit at a larger radius and shoot inward.

## How It Works (High Level)
1. A planet sits at the center of the viewport (128, 135).
2. The player's ship orbits the planet at a close radius (~36px) using a **pivot system** — a parent Node2D rotates, and the ship is offset from center as a child.
3. Enemies orbit the planet at larger radii (60px and 80px) using the same concept — the `EnemyGroup` node sits at the planet center and rotates, carrying all enemies with it.
4. The player shoots rockets **outward** (away from the planet), which travel through the enemy orbit and can destroy them.
5. Enemies shoot bullets **inward toward the planet** (from each enemy toward center), which pass through the player's inner orbit and can damage the ship.
6. As enemies die, the orbit speed increases — making surviving enemies harder to hit.
7. When all enemies are destroyed, the scene reloads with a new random planet and fresh enemies — points and lives carry over.
8. Game ends when the player runs out of lives.

## Key Decisions & Why

### Pivot-based orbit (vs. direct angle manipulation)
- **Chosen:** Parent Node2D rotates; children are offset and orbit as a result of the parent transform.
- **Alternative:** Each enemy tracks its own angle and repositions itself each frame using `cos`/`sin`.
- **Why this choice:** Godot's scene tree handles the math automatically. Rotating one parent moves all children — zero per-enemy orbit math.
- **Tradeoff:** All enemies in a group orbit at the same angular speed (they're rigidly attached). Individual orbit speeds would need the alternative approach.
- **Analogy:** Like gluing toys to a spinning turntable vs. walking each toy in a circle yourself.

### Discrete step movement for the player (vs. smooth rotation)
- **Chosen:** 128 discrete angular positions with a tick timer.
- **Alternative:** Smooth continuous rotation.
- **Why:** Gives a retro, snappy feel that matches the pixel-art aesthetic. Also prevents sub-pixel jitter.
- **Tradeoff:** Movement isn't perfectly smooth — but that's intentional for the arcade feel.

### Enemies use smooth rotation (vs. discrete steps)
- **Chosen:** `rotation += orbit_speed * delta` — smooth continuous orbit.
- **Why:** Enemies should feel like they're "drifting" around the planet. Smooth rotation looks more natural for autonomous enemies and contrasts with the player's snappy movement.

### Enemy center-facing orientation (vs. inherited tumble)
- **Chosen:** Keep orbit motion on the `EnemyGroup`, but run a per-enemy facing pass so each enemy rotates to face the planet center every frame.
- **Alternative:** Let enemies inherit group rotation only (carousel tumble), or move each enemy independently and derive facing from velocity.
- **Why this choice:** We keep simple parent-driven orbit math while fixing readability of enemy intent. Players can instantly read that enemies are "locked onto the planet."
- **Tradeoff:** We add a small per-frame loop over enemies to update facing rotation.
- **Analogy:** Like people standing on a merry-go-round while always turning their head toward the statue in the middle.

### Inward bullet direction (vs. always-down)
- **Chosen:** Enemy bullets fire in the direction from each enemy toward planet center.
- **Alternative:** Always fire `Vector2.DOWN` like classic Space Invaders.
- **Why:** With a circular layout, "down" has no fixed meaning. Inward-to-center keeps enemy attacks focused on the player ring around the planet.

### Event-driven client sync (vs. fixed timer updates)
- **Chosen:** The local player ship emits `player_state_changed` when it rotates to a new step or fires a rocket. `game.gd` listens and sends `send_player_state(...)` only on that signal.
- **Alternative:** Send client state every N milliseconds, even while idle.
- **Why this choice:** It cuts idle network traffic and ties network sends to real gameplay actions.
- **Tradeoff:** If a future gameplay change mutates player state but forgets to emit the signal, remote peers will miss that update.
- **Analogy:** Like sending a text only when plans change, instead of texting every minute saying "still same plan."

### Whole-game snapshot sync (vs. player-only sync)
- **Chosen:** Host `game.gd` now includes `enemy_group`, `planet`, `score`, and `lives` in `get_whole_game_state()`. Client applies all of it in `_update_game_state()`.
- **Alternative:** Sync only players and let each client simulate enemy/planet/state independently.
- **Why this choice:** The host stays source-of-truth. Joiners render exactly what the host sees, including enemy count/layout and HUD values.
- **Tradeoff:** Bigger packets and more frequent world updates can cost bandwidth.
- **Analogy:** Like sending a full whiteboard photo each update, instead of only sending one sticky note change.

### Enemy identity sync by ID (vs. list index sync)
- **Chosen:** Every enemy has `enemy_id`. Snapshots include `enemy_id`, and clients reconcile enemies by ID.
- **Alternative:** Match enemies by array position (`enemies[0]`, `enemies[1]`, ...).
- **Why this choice:** Enemy add/remove order can differ across machines. ID matching keeps each enemy stable and prevents swap/teleport bugs.
- **Tradeoff:** Slightly more sync logic and a few extra bytes per enemy packet.
- **Analogy:** Like tracking people by passport number instead of where they stand in a queue.
- **ID generation rule:** Host assigns an enemy UUID-style string when spawning each enemy (similar to rocket `uuid` generation). Clients only consume these IDs from snapshots.

### Rocket fire cooldown (vs. fire-every-frame spam)
- **Chosen:** Player firing now uses a fixed cooldown gate (`ROCKET_COOLDOWN_SECONDS`) before another rocket can spawn.
- **Alternative:** Spawn a rocket every physics frame while the fire key is held, or drive cooldown from a dedicated `Timer` node.
- **Why this choice:** A local float timer is simple, cheap, and keeps rate-limit logic directly beside input handling.
- **Tradeoff:** Fire cadence is fixed unless code changes the constant. A `Timer` node is more editor-visible but adds extra scene wiring.
- **Analogy:** Like a camera flash that needs a short recharge before the next photo.

### Lifecycle cleanup with `tree_exited` (vs. periodic stale sweeps)
- **Chosen:** Registries now remove nodes as soon as the node leaves the scene tree by listening to `tree_exited` (`rockets`, `current_enemies`, and `_remote_players`).
- **Alternative:** Keep stale-node cleanup inside later loops (for example during serialization) and remove invalid entries there.
- **Why this choice:** Cleanup happens at the exact lifecycle moment, so dictionaries stay accurate between frames and sync code does less defensive work.
- **Tradeoff:** You must remember to connect the signal every time a node is spawned, or cleanup will silently stop for that path.
- **Analogy:** Like immediately crossing a name off a guest list when they leave, instead of waiting until end-of-night cleanup.

## How Each Piece Works

### Pivot (`elements/space_ship/pivot.gd`)
- **What:** Controls the player ship's orbit around the planet.
- **How:** Tracks `angular_velocity` from left/right input. Accumulates a `tick_timer`; when it crosses `TICK_INTERVAL`, advances `current_step` by ±1 and snaps rotation to `step * STEP_ANGLE`. Also handles shooting.
- **Example:** Player presses right → `angular_velocity` increases → after enough accumulated time, `current_step` goes from 0 to 1 → rotation snaps to `TAU/128`.

### EnemyGroup (`elements/enemy_group/enemy_group.gd`)
- **What:** Orbits all enemies around the planet as a single rotating formation, spawning them dynamically based on the player's score.
- **How:** On `_ready()`, calculates enemy count: `BASE (12) + points / 6`, capped at 36. Distributes enemies evenly across concentric rings (6 per ring, starting at radius 60, spaced 20px apart). Alternating rings are staggered by half a step for better coverage. Each frame, `rotation += orbit_speed * delta`, then a helper rotates each enemy to face the group center. The same facing pass runs after initial spawn and after multiplayer snapshot apply, so clients do not show one-frame misalignment. When an enemy dies, `orbit_speed` increases by 0.06 rad/s. A `ShotTimer` fires every 3 seconds, picking a random surviving enemy to shoot. Enemy nodes are removed from `current_enemies` when they emit `tree_exited`, so the map stays in sync with scene lifecycle.
- **Example:** At 0 points → 12 enemies on 2 rings (60px, 80px). At 30 points → 17 enemies on 3 rings (60, 80, 100px). At 144+ points → 36 enemies (max) on 6 rings.

### Enemy (`elements/enemy/enemy.gd`)
- **What:** A single invader in the formation.
- **How:** Passive — it doesn't move itself. Spawned by `EnemyGroup` at a calculated ring position, then carried by the parent group's rotation. A `face_center(center_global)` helper computes the inward vector (`center - enemy_position`) and updates the enemy's rotation with a single sprite-forward offset constant. When `shot()` is called, it calculates the inward direction to the planet center, spawns a bullet slightly toward center, and sets the bullet's direction and rotation.
- **Example:** Enemy at global position (208, 135), planet center at (128, 135) → inward direction is `(-1, 0)` (leftward). Bullet spawns at (198, 135) and flies left toward center.

### Enemy Bullet (`elements/enemy_bullet/enemy_bullet.gd`)
- **What:** A projectile that flies in a set direction and damages the player on contact.
- **How:** Has a `direction` vector (default `Vector2.DOWN`, overridden at spawn). Each physics frame: `move_and_collide(direction * speed * delta)`. On collision, it checks the collider and walks up parent nodes until it finds `take_damage()`, then calls it and self-destructs. This matters because the colliding physics body can be a child node while damage logic lives on the parent gameplay node.
- **Example:** Direction set to `(0.7, -0.7)` → bullet flies up-right at 30 px/s until it exits the screen or hits the player.

### Rocket (`elements/rocket/rocket.gd`)
- **What:** Player projectile fired outward from the ship.
- **How:** Direction is `Vector2.UP.rotated(rotation)` — the rotation is inherited from the pivot, so "up" is "away from planet center". On collision it calls `destroy()` on valid targets and despawns itself. It also listens for screen exit via `VisibleOnScreenNotifier2D` and despawns when it leaves the viewport.
- **Example:** Rocket misses every enemy and travels beyond the top edge of the screen -> `screen_exited` fires -> rocket queues free, so it does not live forever off-screen.

### Player spaceship (`elements/player_space_ship/player_space_ship.gd`)
- **What:** Handles local ship control, firing, and outgoing player projectile state.
- **How:** Reads left/right input for orbit steps, and reads fire input with a cooldown gate so one key hold fires at a controlled cadence. Each spawned rocket is tracked by UUID and removed from the local rocket dictionary when the rocket exits the tree, keeping multiplayer snapshots clean.
- **Example:** Player holds fire for 1 second with cooldown at 0.2s -> about 5 rockets spawn instead of 60+ physics-frame rockets.

### Game (`game/game.gd`)
- **What:** Orchestrates win/loss conditions and level progression.
- **How:** Listens to `lives_changed` and `enemy_died` signals. If lives reach 0, shows game-over screen. If all enemies are destroyed, emits `level_cleared`, waits 1 second, then swaps out just the Planet and EnemyGroup nodes — `queue_free()` the old ones, wait a frame, then `add_child()` fresh instances. The planet script picks a random spritesheet in `_ready()`, so each new instance looks different. The player, HUD, background, and walls stay untouched.
- **Example:** Player kills last enemy → `_check_game_state()` sees ≤1 enemy in group → emits `level_cleared` → waits 1s → `_start_next_level()` frees old planet/enemies, spawns new ones → player keeps position, points, and lives.

### Multiplayer (WebRTC P2P, browser-friendly)
- **What:** Peer-to-peer multiplayer that works from an HTML5 export — any number of browsers can join the same game over LAN (or internet) with no native server. One peer is the *host* (game-state authority); others are *clients*.
- **Why this design:** Browsers can't accept incoming TCP/UDP, so the previous `TCPServer + WebSocketPeer` design only worked from a native build. WebRTC sidesteps that — browsers can both initiate and receive WebRTC data channel connections.
- **Pieces:**
  1. **`signalling/server.js`** — tiny Node.js WebSocket relay (deployed to Railway). Carries only the WebRTC handshake (SDP offers/answers + ICE candidates). Stateless, no game logic. Adapted from Godot's official `webrtc_signaling` demo.
  2. **`addons/webrtc/`** — Godot's `webrtc-native` GDExtension (provides `WebRTCMultiplayerPeer` for native builds; HTML5 export uses the browser's built-in WebRTC).
  3. **`Multiplayer/network.gd`** — autoload (`Network`) that owns the signalling WebSocket + `WebRTCMultiplayerPeer` and exposes a small API: `host_room()`, `join_room(code)`, `send_player_state()`, `send_game_state()`. Hooks `multiplayer.multiplayer_peer = rtc` so Godot's high-level RPC system carries the messages.
  4. **`game/game.gd`** — calls `Network.send_*` and listens for `Network.peer_player_update` / `Network.game_state_update`. Identical packet shape to the old WebSocket flow, so per-feature sync code (rockets, enemies, planet, score) didn't change.
- **Connection flow:**
  1. Host clicks Create Server → `Network.host_room()` opens WS to signalling server, sends `JOIN` with empty room code → server picks a random 16-char room code, returns it → UI displays `Room: <code>`.
  2. Joiner types code, clicks Join Server → `Network.join_room(code)` opens WS, sends `JOIN <code>` → server announces both peers to each other via `PEER_CONNECT`.
  3. The peer with the lower id creates a WebRTC offer → relayed via signalling → other side answers → ICE candidates trickle through signalling → data channel opens.
  4. Once the data channel is up, `multiplayer.multiplayer_peer = rtc` activates RPC. Host's `_receive_game_state` RPC fires on every client; clients' `_receive_player_state` RPCs fire on the host.
- **Topology:** **Star**, not mesh — `WebRTCMultiplayerPeer.create_server()` on host, `create_client(my_id)` on joiners. Clients only have a direct link to host; they don't talk to each other. This matches the existing "host owns world state" design.
- **Why a STUN server (`stun:stun.l.google.com:19302`):** Public STUN helps two peers behind NATs discover each other's reachable addresses. On a single LAN it harmlessly converges to direct host candidates; for non-LAN play it lets most home networks connect without a TURN relay.
- **Sync semantics (unchanged from old design):** Host broadcasts a full snapshot (`{"players": [...], "enemy_group": ..., "planet": ..., "score": ..., "lives": ...}`) at ≤10 Hz. Clients send only their own player state, event-driven on `player_state_changed`. Snapshot reconcile rules for enemies (by `enemy_id`) and rockets (by `uuid`) are unchanged.

### Why a signalling server is unavoidable
- WebRTC peers must exchange SDP descriptions + ICE candidates *before* the P2P link exists. That exchange itself can't ride over WebRTC (chicken-and-egg), and browsers can't listen for raw incoming sockets to act as the rendezvous.
- The only true zero-server alternative is **manual copy-paste signalling** — host generates an offer string, pastes it into Discord, joiner pastes back an answer. Workable for two players, miserable beyond that.
- A Railway-hosted WebSocket relay solves it cleanly: signalling traffic is a few KB per game-start, so the free tier is more than enough, and players never see "signalling server" — they just type a room code.

## Things That Don't Work Well
- **Bullet persistence:** Bullets are children of the enemy that fired them. If that enemy is destroyed while a bullet is in flight, the bullet is also freed. This could cause "disappearing bullet" glitches.
- **Fixed planet center assumption:** The enemy `shot()` function assumes `get_parent().global_position` is the planet center. If the scene hierarchy changes, bullets will fly in wrong directions.
- **Planet layer dependency:** Enemy bullets now collide with the planet, so if planet collision layers are changed later, bullet masks must be kept in sync.
- **Sprite-forward assumption:** Center-facing uses one fixed sprite-forward offset. If enemy art orientation changes later, this constant must be updated or enemies will appear to face the wrong direction.
- **Win check at ≤1 enemy:** The `<= 1` check accounts for the dying enemy still being in the tree when the signal fires (it calls `queue_free()` which defers removal to end-of-frame). So "≤1 in group" effectively means "zero alive."
- **No reconnect controls:** The multiplayer controls hide after host/join starts; there is no in-UI "disconnect/back" button to leave a session and start a new one without reloading.
- **Disconnected peer leaves a stale ship:** When a client disconnects, `Network.peer_disconnected_from_session` fires with a peer id, but `_remote_players` is keyed by player *name*. Without a peer-id↔name map, the disconnected ship lingers until the next level reload. Logged but not cleaned up.
- **No TURN relay configured:** Two players behind symmetric NATs (rare — mostly corporate networks) will fail to connect. STUN-only works for ~95% of home networks; full reliability would need a TURN server (paid or self-hosted).
- **Signalling URL is hardcoded:** `DEFAULT_SIGNALLING_URL` in `network.gd` defaults to `ws://localhost:9080`. Change it to the deployed Railway `wss://...` URL before exporting for end users.
- **Signal coverage risk:** Event-driven sync is leaner, but every state-changing action must emit `player_state_changed`. Missing emit calls cause stale remote state.
- **Off-screen notifier dependency:** Rocket cleanup depends on `VisibleOnScreenNotifier2D` being present and connected in `rocket.tscn`. If someone removes that node or signal connection, rockets can leak off-screen.

## Key Metrics & Results
- **Viewport:** 256×240 pixels (NES-style resolution)
- **Player orbit radius:** ~36px from planet center
- **Enemy orbit radii:** Rings at 60, 80, 100, 120… px (6 enemies per ring, added as count grows)
- **Enemy count scaling:** 12 base + 1 per 6 points, capped at 36
- **Base enemy orbit speed:** 0.4 rad/s (~15.7s per revolution)
- **Orbit speed boost per kill:** +0.06 rad/s
- **Player discrete positions:** 128 around the circle (2.8° per step)
- **Shot interval:** Every 3 seconds, one random enemy fires
- **Player rocket cooldown:** 0.2 seconds between rockets while fire is held
- **Client state send cadence:** Event-driven (on movement step and shoot), not fixed-interval polling
- **Signalling protocol:** JSON over WebSocket; 8 message types (JOIN/ID/PEER_CONNECT/PEER_DISCONNECT/OFFER/ANSWER/CANDIDATE/SEAL). Same wire format as Godot's official `webrtc_signaling` demo.
- **Default signalling port (local):** `9080`
- **Room code length:** 16 alphanumeric characters (server-generated)
