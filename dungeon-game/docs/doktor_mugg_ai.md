# Doktor Mugg: first playable AI

Open `scenes/test/DoktorMuggArena.tscn` and press F6. WASD moves, arrow keys shoot, R restarts. The test room is twice the width and height of a normal room. The arena now contains ten green/blue blocks and reuses the existing quarter-room artwork at its original pixel scale. The normal dungeon boss-room resource also uses this larger layout. Its overlay shows the active state, decision, health, sight and firing clearance. Yellow lines show the route. Orange shows attack windup/aim; blue marks recovery.

The test player deals 3.5 damage. The existing dungeon currently overrides player damage to 50, which makes the 100 HP boss fight very short; that existing setting has not been changed. The normal boss pool now uses this AI whenever it selects Doktor Mugg.

## Ownership

- EnemyBase retains the only physics loop, movement call, health, contact damage and cancellable action lifecycle.
- DoktorMugg.gd connects perception, decisions and execution through the inherited hooks.
- MuggBlackboard stores visible observations, last seen position, memory age and debug counters. Hidden player movement does not update the remembered position; memory expires after 3 seconds.
- MuggBehaviorTree chooses tactics using reusable selector/sequence/condition/action nodes from DecisionNode.gd. Failed movement choices fall through rather than trapping the selector.
- MuggStateMachine names the current execution state and blocks ordinary transitions during windup/fire/recovery. It has no independent update loop.
- ArenaNavigator samples movement collisions into an AStarGrid2D, includes body clearance, checks swept paths, and rebuilds once per second for obstacle changes. It uses room-provided world bounds. Designed for axis-aligned rectangular rooms and the current obstacle sizes; narrow routes smaller than the grid/body clearance may be treated as unavailable.
- RoomBase passes itself to the boss after spawning it. Room geometry and obstacles remain the source of bounds and blocking rules.

## Current decision order

Death, stun, finish committed action, react to an incoming projectile with Dodge, wait if no remembered target, finish short movement commitment, find firing angle when hidden/blocked, create distance when close, weighted Basic Shot / tactical reposition when ready, reposition if poorly placed, pressure/investigate remembered position, idle fallback.

Reposition samples reachable positions around the remembered target and makes a weighted random choice favoring clear firing angles and shorter travel. Short movement commitments and retry/cooldown timers prevent constant rerolling. Sight checks use sight blockers; shots sweep the projectile footprint against world/projectile blockers; navigation uses movement blockers.

Basic Shot locks aim at attack start, telegraphs for 0.55 seconds, fires once, then recovers for 0.65 seconds. It rechecks the original firing corridor before spawning a projectile. Ordinary damage still reduces health and flashes the sprite, but does not cancel windup or recovery. Explicit `stun(duration)` and death cancel pending shots. The scene enables knockback immunity so ordinary knockback cannot slide the boss through committed attacks. Pause freezes the entire action.

## Tuning and later extension

Select the DoktorMugg scene root to tune distance, decision timing, movement commitment, memory, navigation radius and Basic Shot timing/damage/speed. A nonzero random_seed makes tactical sampling repeatable. Match navigation_radius to the body footprint when changing scale. debug_ai enables routes and the boss label.

This iteration implements Dodge, Basic Shot, Reposition and Pressure, with retreat/anti-cover handled by repositioning. Predictive/spread attacks and offensive Dash remain future tactics. Take Cover and area denial are implemented below. Add conditions/leaves to MuggBehaviorTree and cancellable execution through DoktorMugg's inherited action hooks; do not add a second physics or movement loop. Dead and Stunned are real lifecycle states, not placeholder branches.

## Validation

Run normal test scenes headlessly after editor import:

- `godot --headless --path . res://tests/MuggAITest.tscn`: 28 checks for collision/perception, memory, path clearance, real-frame movement, commitments, firing, damage, stun, pause and death.
- `godot --headless --path . res://tests/EnemyLifecycleTest.tscn`: 42 existing regression checks.

These checks establish behavior and lifecycle correctness; fight pacing and visual readability still need human playtesting.

ArenaPlayTest.tscn adds 12 checks with the actual player and camera: spawn visibility, all four movement inputs, crossing the interior, and outer-wall collision.

## Dodge and probability tuning

Select the root of `scenes/enemies/bosses/DoktorMugg.tscn`. All balancing properties are exported in the Inspector; no code edits are needed. Save the scene to apply them to both the test arena and dungeon bosses. Existing scene-instance overrides take precedence.

| Inspector section / property | Default | Meaning |
| --- | --- | --- |
| Dodge Reaction / Chance | 0.65 | 65% chance per eligible incoming projectile, once per projectile |
| Lookahead | 0.65 s | Predicted closest approach must be within this time and projectile lifetime |
| Detection Range | 180 | Maximum distance to notice a projectile |
| Threat Radius | 30 | Predicted collision corridor, combined boss/projectile size |
| Cooldown | 2.5 s | Time between dodges, measured from dodge start |
| Dodge Movement / Speed | 320 | Units per second |
| Duration | 0.22 s | About 70 units of travel |
| Recovery | 0.25 s | Stationary opening after the dash |
| Left / Right weights | 1 / 1 | Sideways relative to incoming projectile travel |
| Away weight | 0.5 | Directly away from projectile position |
| Diagonal weight | 0.75 | Applies separately to each of the two away/sideways diagonals |
| Tactic Probabilities / Basic Shot / Tactical Move | 3 / 1 | 75% shot versus 25% reposition when both are available |
| Tactic Choice Interval | 0.8 s | Minimum delay between offensive-choice rolls |
| Cooldown Variation | 0.2 | Random +/-20% on shot and dodge cooldowns; never shorter than the action |
| Position Preferences / Clear / Blocked | 5 / 0.5 | Relative preference for firing angles when choosing reachable destinations |
| Position Distance Scale | 150 | Larger values make distant choices more competitive |

Weights are relative, not percentages: 2:1 means roughly 67%:33%. Zero disables a direction/choice; all-zero weights safely fall through. Blocked dash routes are removed before rolling, so remaining weights are renormalized. If a randomly chosen tactical move cannot run, an enabled Basic Shot is the fallback. Hard-priority retreat/anti-cover behavior still takes precedence over offensive randomness.

Dodge predicts incoming standard player Projectile trajectories. It ignores receding, passing, expired, sight-hidden and wall-blocked shots, and does not read player input. Lasers and other damage types are not currently dodge triggers. It rolls once per detected eligible projectile, only when cooldown/action commitment permits; it does not repeatedly roll against the same shot until it succeeds.

The tree may interrupt walking with a dodge, but not attack windup/fire/recovery. Dodge itself is committed and has **no invulnerability**: hits still deal damage. Explicit stun and death cancel it. Full-body swept checks reject blocked/out-of-bounds directions and stop movement if a blocker appears during the dash. Movement still runs only through EnemyBase's physics loop. For now it uses the run animation and a cyan motion streak; roll/somersault animation can be added later without changing decisions.

Set `random_seed` to a fixed nonzero value for repeatable tactical sampling, or keep 0 for a different sequence each run. The outcome also depends on the same world/input timing.

`MuggDodgeTest.tscn` covers probability endpoints, no rerolling, trajectory filtering, direction weights, wall rejection, attack commitment, real-frame movement, recovery, damage, stun, pause, death and offensive weighting.

## Cover and area denial

The boss arena has five green and five blue 44-unit blocks. Green blocks stop movement only: both player and boss shots pass over them. Blue blocks stop movement, shots and sight. The block-free foundation remains LargeBossRoom.tscn; BoosRoom.tscn adds the combat layout. Normal zoom is unchanged.

After a recent hit (two-second reaction window), or when an incoming projectile threatens him and he does not dodge, Doktor Mugg searches nearby obstacles for a reachable position that actually blocks the line of fire from the remembered player position. He chooses the shortest valid route, commits to reaching it, holds briefly, and then re-engages. If a visible player flanks him during the hold, he abandons it. Cover cannot interrupt committed attacks. Unreachable cover falls through to other tactics.

Inspector **Take Cover** controls enablement, search distance (180), hold duration (0.6 s) and cooldown (3.5 s). Only projectile-blocking obstacles (currently blue blocks) provide cover. Green blocks are excluded from cover candidates and do not trigger anti-cover area attacks merely by standing between the actors.

Inspector **Area Attack** controls radius (60), warning (0.9 s), damage (1), active lifetime (1.4 s), caster recovery (0.5 s), cooldown (5 s), range (300), defensive distance (95), cover delay (0.6 s), anti-cover chance (80%), defensive chance (50%), and failed-choice retry interval (1.2 s).

The area attack is a simple overhead attack: a yellow outlined countdown marks a fixed target, then turns into an orange/red damaging area. It bypasses projectile-blocking cover. It is selected after sustained blocked sight/shots or when a visible player is too close. Hidden targets use only last-seen memory, never their live position; moving after the warning is safe if outside the final circle. The area stays briefly to discourage immediately returning to the same spot. Player invulnerability still governs repeat damage. There is no boss self-damage.

Stun cancels a pending warning; a released area persists through normal action changes and stun. Boss death or removal clears its child hazards. Tree pause freezes warning, active area and recovery. It does not launch area attacks without target memory or outside range. Cooldowns and probability retry intervals prevent constant bombardment.

MuggCoverTest.tscn covers layout connectivity, safe spawns, cover selection/arrival, finite cover holds, defensive and remembered anti-cover targeting, warning safety, fixed aim, cancellation, damage radius, expiry and cooldown. ArenaPlayTest removes the combat obstacles to continue testing the room foundation independently.

## Cluster and homing shots

The offensive selector now weights Basic Shot, Cluster Shot, Homing Shot and tactical movement. All still require a visible target and a clear initial shot. Movement, cover and area-denial priorities remain in the tree. All three projectile attacks lock their initial aim at windup start, use committed recovery, and cancel pending fire on stun/death.

Select the DoktorMugg scene root in the Inspector:

- **Cluster Shot:** weight 2, five smaller orange balls, a 38-degree cone, scatter 0.8, speed 145 with +/-12% variation, damage 1, lifetime 2.2 s, windup 0.7 s. Each pellet gets its own sector and jitter so the cone is irregular but not entirely clumped. Blocked muzzle paths are skipped.
- **Homing Shot:** purple; near weight 0.25 at 80 units, rising linearly to weight 3 at 280 units. It clamps outside those distances. These are relative selection weights, not direct percentages. With other default weights and both attacks eligible, its share rises from about 4% to 33%. A separate six-second cooldown prevents repeated homing shots.
- Homing defaults: speed 145, turn rate 85 degrees/second, tracking delay 0.2 s, tracking duration 1.6 s, total lifetime 3.2 s, damage 1 and windup 0.85 s. Its warning uses the projectile's configurable purple color.

The homing ball starts along the committed firing direction, then steers gradually. After tracking expires it continues straight. If the target ends up more than 100 degrees off its heading (a successful close sidestep/overshoot), it permanently loses tracking. Blue sight blockers also break tracking. Green blocks allow both shot types through; blue blocks destroy them. Neither shot type tracks player inputs or predicts dodges. Lost/dead targets stop tracking safely. Projectiles remain in the room after being fired, like existing Basic Shots; stun cancels only shots not yet released.

Increase homing turn rate/tracking duration for a harder missile; lower them for a wider dodge window. Increase far weight to make it more common at distance. Set cluster_weight and both homing weights to zero to disable these choices. Balancing difficulty still requires playtesting.

Implementation: `DoktorMugg.gd` owns selection and attack timing; `scripts/ai/mugg/MuggBall.gd` handles small-ball visuals, homing and collision. MuggVolleyTest.tscn checks the cone/count, timing, cancellation, distance weighting, turn limit, overshoot, blue-cover tracking loss, real projectile/block collisions, pause and expiry.

## Aggressive kiting preset

The DoktorMugg scene now overrides the earlier starting values: move speed 120, preferred range 195, close range 135, decision interval 0.1 s, short movement commitment 0.3 s, Basic/Cluster/Homing windups 0.4/0.55/0.7 s, shot recovery 0.4 s, shared shot cooldown 1.25 s, tactical choice interval 0.45 s, dodge chance 85%, dodge cooldown 1.65 s, cover hold 0.25 s and area cooldown 3.8 s. Health remains 100 and damage values are unchanged. Inspector values on the scene are authoritative over the earlier defaults documented above.

Kiting maintains spacing with retreat/approach and lateral circling. It periodically rolls whether to reverse orbit direction, scores collision-safe headings for distance, firing angle, escape space and incoming projectile danger, and falls back to pathfinding when local steering has no clear direction. Hidden-player pursuit uses existing last-seen memory. It does not read player input.

During projectile windup it moves at 40% speed, plants for the last 0.1 seconds and release, then moves at full speed during recovery. This preserves attack timing and the single EnemyBase physics loop. Recovery still prevents a new attack/dodge; it no longer means the boss stands still. Dodge recovery, area casting/recovery, explicit stun and brief cover holds retain their own movement rules.

The **Kiting** Inspector section exposes enablement, windup/recovery speed factors, plant window, spacing tolerance, lookahead distance, orbit-change timing/chance, strafe/spacing weights and aim leading. Ordinary hits still reduce health but do not stagger him with kite_hit_stagger=false; explicit stun still works. Set kite_hit_stagger=true to restore ordinary hurt pauses while moving.

Basic and cluster shots lead the player's observed velocity at 65% of estimated projectile travel time, capped at 55 units. Only consecutive visible observations contribute. Homing retains its committed initial direction and separate limited steering.

MuggKitingTest verifies retreat, circling, attack movement/release, exact firing, actual damage, explicit stun, corner escape, no-memory behavior, sustained movement/attack pressure, arena clearance and unchanged health. This is an aggressive starting preset, not proof that upgrades are required: difficulty must be tested against player builds. The normal Dungeon.tscn still contains its pre-existing player base_damage=50 override, whereas DoktorMuggArena uses 3.5 damage. No player stats were changed for this preset.

## Faster attacks and Running Shot

Current scene timing: Basic windup 0.22 s, Cluster 0.32 s, Homing 0.45 s, projectile recovery 0.3 s, shared cooldown 0.95 s, and tactical choice interval 0.3 s. These supersede the earlier preset timings; other existing Inspector choices were preserved.

The new **Running Shot** fires a small cyan ball while maintaining full kiting speed throughout windup, release and recovery. It has selection weight 3, windup 0.12 s, recovery 0.16 s, projectile speed 205 and cooldown 0.65 s. It uses normal projectile damage, committed initial aim/observed lead, and the existing green/blue collision rules. Selection is disabled when kiting is disabled. Change its settings under Running Shot on the DoktorMugg scene root.

Cooldown is measured from attack start and remains bounded by total action duration. Running Shot has no stationary plant, but cannot overlap other actions, bypass stun/death cancellation, or fire during recovery. Placeholder animation length no longer extends configured projectile attack timing. MuggRunningShotTest checks full-speed movement in each attack phase, exact timing, single firing, cancellation and scene timing values.

## Health-dependent tactics

The **Health Tactics** Inspector section controls all thresholds and response strengths. Below 50% observed player health, Mugg gradually becomes more aggressive: stronger attack-selection weights, shorter attack cooldowns, closer preferred spacing and a higher anti-cover area chance. Below 45% of his own health he gradually becomes defensive: more spacing, more dodge chance, shorter dodge/cover cooldowns, proactive cover seeking (once defense strength reaches 25%), longer finite cover holds, more tactical movement/Running Shots and higher defensive area chance.

Both responses are continuous ramps, strongest near zero health. Thresholds mark the beginning of the ramp, not an instant full-strength switch. When both actors are wounded, defensive strength proportionally reduces aggression, so self-preservation wins near death. Attack cooldowns still cannot become shorter than the committed action. Health and damage stats are not increased.

Player health is observed only while the player is visible and cached while hidden; disappearing does not reveal hidden healing/damage. Healing visible actors restores normal behavior automatically. Exported baseline settings are never mutated by these modifiers, so repeated updates cannot compound buffs. Disable health_tactics_enabled for neutral behavior. Tests in MuggHealthTest cover thresholds, both-low priority, actual cooldown use, healing, hidden information and unchanged stats.
