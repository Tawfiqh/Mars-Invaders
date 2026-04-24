# Godot Invaders — Study Guide

## What We're Building
A Space Invaders-inspired game built in Godot 4 where gameplay revolves around a central planet. Instead of the classic flat layout (enemies above, player below), everything orbits a planet at the center of the screen. The player circles the planet and shoots outward; enemies orbit at a larger radius and shoot inward.

## How It Works (High Level)
1. A planet sits at the center of the viewport (128, 135).
2. The player's ship orbits the planet at a close radius (~36px) using a **pivot system** — a parent Node2D rotates, and the ship is offset from center as a child.
3. Enemies orbit the planet at larger radii (60px and 80px) using the same concept — the `EnemyGroup` node sits at the planet center and rotates, carrying all enemies with it.
4. The player shoots rockets **outward** (away from the planet), which travel through the enemy orbit and can destroy them.
5. Enemies shoot bullets **outward from the planet** (in the direction from planet center through the enemy), which travel through the player's orbit and can damage the ship.
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

### Outward bullet direction (vs. always-down)
- **Chosen:** Enemy bullets fire in the direction from planet center through the enemy's position.
- **Alternative:** Always fire `Vector2.DOWN` like classic Space Invaders.
- **Why:** With a circular layout, "down" has no fixed meaning. Outward-from-center makes bullets travel through the player's orbit regardless of where the enemy is on the circle.

## How Each Piece Works

### Pivot (`elements/space_ship/pivot.gd`)
- **What:** Controls the player ship's orbit around the planet.
- **How:** Tracks `angular_velocity` from left/right input. Accumulates a `tick_timer`; when it crosses `TICK_INTERVAL`, advances `current_step` by ±1 and snaps rotation to `step * STEP_ANGLE`. Also handles shooting.
- **Example:** Player presses right → `angular_velocity` increases → after enough accumulated time, `current_step` goes from 0 to 1 → rotation snaps to `TAU/128`.

### EnemyGroup (`elements/enemy_group/enemy_group.gd`)
- **What:** Orbits all enemies around the planet as a single rotating formation, spawning them dynamically based on the player's score.
- **How:** On `_ready()`, calculates enemy count: `BASE (12) + points / 6`, capped at 36. Distributes enemies evenly across concentric rings (6 per ring, starting at radius 60, spaced 20px apart). Alternating rings are staggered by half a step for better coverage. Each frame, `rotation += orbit_speed * delta`. When an enemy dies, `orbit_speed` increases by 0.06 rad/s. A `ShotTimer` fires every 3 seconds, picking a random surviving enemy to shoot.
- **Example:** At 0 points → 12 enemies on 2 rings (60px, 80px). At 30 points → 17 enemies on 3 rings (60, 80, 100px). At 144+ points → 36 enemies (max) on 6 rings.

### Enemy (`elements/enemy/enemy.gd`)
- **What:** A single invader in the formation.
- **How:** Passive — it doesn't move itself. Spawned by `EnemyGroup` at a calculated ring position, then carried by the parent group's rotation. When `shot()` is called, it calculates the outward direction from the planet center, spawns a bullet there, and sets the bullet's direction and rotation.
- **Example:** Enemy at global position (208, 135), planet center at (128, 135) → outward direction is `(1, 0)` (rightward). Bullet spawns at (218, 135) and flies right.

### Enemy Bullet (`elements/enemy_bullet/enemy_bullet.gd`)
- **What:** A projectile that flies in a set direction and damages the player on contact.
- **How:** Has a `direction` vector (default `Vector2.DOWN`, overridden at spawn). Each physics frame: `move_and_collide(direction * speed * delta)`. If it hits something with `take_damage()`, calls it and self-destructs.
- **Example:** Direction set to `(0.7, -0.7)` → bullet flies up-right at 30 px/s until it exits the screen or hits the player.

### Rocket (`elements/rocket/rocket.gd`)
- **What:** Player projectile fired outward from the ship.
- **How:** Direction is `Vector2.UP.rotated(rotation)` — the rotation is inherited from the pivot, so "up" is "away from planet center". Calls `destroy()` on anything it hits.

### Game (`game/game.gd`)
- **What:** Orchestrates win/loss conditions and level progression.
- **How:** Listens to `lives_changed` and `enemy_died` signals. If lives reach 0, shows game-over screen. If all enemies are destroyed, emits `level_cleared`, waits 1 second, then swaps out just the Planet and EnemyGroup nodes — `queue_free()` the old ones, wait a frame, then `add_child()` fresh instances. The planet script picks a random spritesheet in `_ready()`, so each new instance looks different. The player, HUD, background, and walls stay untouched.
- **Example:** Player kills last enemy → `_check_game_state()` sees ≤1 enemy in group → emits `level_cleared` → waits 1s → `_start_next_level()` frees old planet/enemies, spawns new ones → player keeps position, points, and lives.

## Things That Don't Work Well
- **Bullet persistence:** Bullets are children of the enemy that fired them. If that enemy is destroyed while a bullet is in flight, the bullet is also freed. This could cause "disappearing bullet" glitches.
- **Fixed planet center assumption:** The enemy `shot()` function assumes `get_parent().global_position` is the planet center. If the scene hierarchy changes, bullets will fly in wrong directions.
- **No collision with planet:** Enemy bullets pass through the planet (collision mask doesn't include environment layer). This is intentional but could look odd visually.
- **Enemy sprites rotate with the group:** Enemies don't counter-rotate to always face outward. They tumble as they orbit — charming but not precisely "facing the player."
- **Win check at ≤1 enemy:** The `<= 1` check accounts for the dying enemy still being in the tree when the signal fires (it calls `queue_free()` which defers removal to end-of-frame). So "≤1 in group" effectively means "zero alive."

## Key Metrics & Results
- **Viewport:** 256×240 pixels (NES-style resolution)
- **Player orbit radius:** ~36px from planet center
- **Enemy orbit radii:** Rings at 60, 80, 100, 120… px (6 enemies per ring, added as count grows)
- **Enemy count scaling:** 12 base + 1 per 6 points, capped at 36
- **Base enemy orbit speed:** 0.4 rad/s (~15.7s per revolution)
- **Orbit speed boost per kill:** +0.06 rad/s
- **Player discrete positions:** 128 around the circle (2.8° per step)
- **Shot interval:** Every 3 seconds, one random enemy fires
