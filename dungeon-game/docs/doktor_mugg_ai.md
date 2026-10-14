# Doktor Mugg: current AI reference

For a guided explanation and diagrams, read [doktor_mugg_walkthrough.md](doktor_mugg_walkthrough.md).

## Architecture

EnemyBase owns the sole physics loop, health/contact handling, and cancellable action timer. DoktorMugg is the coordinator. It inherits the exported settings from MuggSettings, so existing Inspector overrides remain on the boss scene root. Helpers share the same boss instance and never start independent processing loops.

- MuggPerception updates sight, remembered position/health and projectile threat predictions.
- MuggBehaviorTree prioritizes situations: danger, blocked player, too close, combat, search, idle.
- MuggTactics builds weighted eligible responses for that situation and tries the selected response. Failed responses are removed before retrying other valid choices.
- MuggStateMachine stores the 15 execution states, protects committed actions, and decides whether the tree may select a new tactic.
- MuggCombat executes projectile attacks, dodge, area attacks and cancellation. Four projectile types share windup/fire/recovery.
- MuggMovement selects routes, finds shot-blocking cover and provides kiting velocity. ArenaNavigator checks bounds and body clearance.
- MuggHealth derives aggression/defense multipliers without mutating settings.
- MuggBall and MuggAreaAttack execute already-released projectile/hazard behavior.

## Balancing

Select the root of scenes/enemies/bosses/DoktorMugg.tscn. Existing scene values override script defaults. All existing exported names were preserved; the refactor does not rewrite scene overrides.

New Situation sections expose separate weights for danger, blocked-player, close-range, combat-cover and search responses. Existing Basic/Cluster/Homing/Running weights apply in combat. Close-range Running Shot uses its own close_running_shot_weight; zeroing one context's weight does not disable that response in every other context. To disable an ability globally, use its enable setting when available, or zero its weights in each context.

Weights determine relative preference, not guaranteed success. Eligibility removes cooldown-blocked, out-of-range or otherwise invalid actions before rolling. Execution still validates paths and action commitments. Dodge and Area Attack retain their own chance settings as an additional gate. A failed selected response is not retried in the same decision. Zero weights never enter the lottery. Combat keeps moving when no attack is ready; it does not need to label that movement as a search.

Health Tactics scale response weights and timing. Low observed player health favors attacks and closer spacing. Low boss health favors cover, dodge, movement and running shots. Health Weight Multipliers exposes the previously fixed combat-health weight factors. When both are low, self-preservation progressively reduces aggression. Player health is only refreshed while visible.

The situation priority order, state names and collision rules are structural logic, not probability values. Collision geometry and visibility cannot be bypassed by a lucky roll.

## Behavior details

- Green blocks stop movement only. Blue blocks stop movement, shots and sight. Only projectile blockers provide cover.
- Cover is now a weighted response. Its destination is the shortest valid route to a nearby position that blocks the remembered line of fire. Holds are bounded and can end when visibly flanked.
- Close range can select a deliberate dash away even without an incoming projectile; it shares the dodge chance, safe direction weights and cooldown.
- Projectile attacks commit their initial aim. Basic, Cluster and Homing move during most windup/recovery but briefly plant to fire. Running Shot moves at full kiting speed throughout.
- Cluster pellets vary angle/speed. Homing has distance-scaled selection weight, limited turn rate/time, an independent cooldown, and loses tracking on overshoot or blue-cover occlusion.
- Area attacks warn at a fixed known location before damage. They can bypass projectile cover, but do not track hidden live positions.
- Explicit stun and death cancel pending shots/warnings/dodges. Fired balls and active areas follow their existing lifetimes; boss removal/death removes its area children.
- The tree does not tick new decisions during committed execution. Movement commitments can be interrupted by immediate danger. A pause freezes action progress.

## Playtesting

Run scenes/test/DoktorMuggArena.tscn with F6. WASD moves, arrows shoot, R restarts. The four-room-sized arena keeps normal camera zoom. Its overlay shows the current situation, chosen response and FSM state. Inspect blackboard.choice_weights in the remote debugger for the eligible weights from the last lottery.

The arena uses player base damage 3.5. The normal Dungeon.tscn has an existing base_damage=50 override; this refactor does not change it. Judge difficulty with the intended player stats.

## Verification

Run normal test scenes headlessly after importing the project. MuggSituationTest covers situation priority, weighted selection, zero/invalid options, failed-choice fallback, deliberate retreat dodge, FSM commitment, inherited settings and health weighting. Existing AI, projectile, dodge, cover/area, kiting, health, running-shot, enemy-lifecycle and arena tests remain applicable. Automated checks do not replace fight-balance playtesting.
