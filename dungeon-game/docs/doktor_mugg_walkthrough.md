# Understanding Doktor Mugg's AI

This guide describes the implemented situation-based refactor. Start with the tree; read projectile internals last.

## 1. The three questions

1. **What is happening?** MuggPerception gathers information, and MuggBehaviorTree chooses the highest-priority relevant situation.
2. **What should I do about it?** MuggTactics makes a weighted choice among eligible responses.
3. **How do I carry it out?** The FSM guards execution; MuggCombat/MuggMovement run the action through EnemyBase's physics loop.

```text
EnemyBase: one physics loop
    |
    +-- DoktorMugg: update cooldowns, perception and navigation
    |
    +-- Active action? -> MuggCombat advances it; FSM records its phase
    |
    +-- Free to decide? -> FSM decision gate -> Behavior Tree
    |                                        |
    |                                        +-> MuggTactics chooses a response
    |
    +-- Movement helper supplies velocity -> EnemyBase moves the body once
```

## 2. Read MuggBehaviorTree.gd first

The tree now asks only about combat situations:

```text
ROOT SELECTOR (first successful branch wins)
|
+-- Immediate danger?
|     +-- Weighted: dodge / cover / running shot / retreat
|
+-- Player hidden or firing line blocked?
|     +-- Weighted: area attack / find firing angle / investigate
|
+-- Visible player too close?
|     +-- Weighted: running shot / dash away / defensive area / retreat / cover
|
+-- Visible player within combat range?
|     +-- Weighted: basic / cluster / homing / running / reposition / wounded cover
|     +-- No response available? Keep kiting between attacks
|
+-- Remember a player position?
|     +-- Weighted: approach / reposition
|
+-- Otherwise: idle
```

`configure()` assembles this tree once. `_when(condition, situation)` creates a sequence: first check the condition, then ask the tactics script to respond. `tick()` checks the FSM gate before evaluating the root. `_respond()` adds combat's ordinary movement fallback.

A **selector** tries children in order until one returns SUCCESS or RUNNING. A **sequence** requires its condition to succeed before trying the action. FAILURE means "this branch cannot help right now," not an error. RUNNING means "a response is in progress." These primitives live in DecisionNode.gd.

The priority order is deliberate. Incoming danger is evaluated before ordinary shooting. Randomness happens among responses inside a situation, not between death and an attack.

## 3. Read MuggTactics.gd second

This is the decision-making file:

- `_choices_for(situation)` lists that situation's responses.
- `_offer(...)` adds a response only if its condition is true and weight is greater than zero.
- `_can_shoot()`, `_can_dodge()`, `_can_cover()` and `_can_area()` perform side-effect-free eligibility checks. They do not roll dice or spend cooldowns.
- `_weighted_index()` chooses an entry in proportion to its weight.
- `choose()` attempts it. If execution fails (for example no safe cover route, or a failed dodge-chance roll), it removes that response and tries another eligible one. It never retries the same response in the same decision.

Example: only Dodge and Cover are eligible, with weights 3 and 1. Dodge is selected about 75% of the time and Cover about 25%. This is an illustration; the actual choices also depend on cooldowns and health. A dodge selected by the lottery must still pass its separate dodge-chance roll and find a collision-safe direction.

The blackboard stores `situation`, `chosen_response` and `choice_weights` to let you inspect this exact process. These fields describe the last decision; they are not extra FSM states.

Health changes weights through `_attack_weight()`, `_defense_weight()` and `_movement_weight()`. Homing's base weight also increases with distance. The actual formulas live in MuggHealth.gd and `homing_selection_weight()`.

## 4. Read MuggStateMachine.gd third

The FSM is a small state holder and transition guard, not a second AI thinker. `can_choose_tactic()` rejects new choices while dead, stunned or executing a committed action. `transition()` changes state, resets its elapsed time and emits a signal. It refuses ordinary transitions out of committed states, and refuses all transitions out of DEAD. Controlled phase changes and explicit interrupts use the `interrupt` argument.

```text
Movement: IDLE / KITE / PRESSURE / REPOSITION
Cover:    TAKE_COVER -> COVER_HOLD -> IDLE
Shots:    WINDUP -> FIRE -> RECOVERY -> IDLE
Dodge:    DODGE -> DODGE_RECOVERY -> IDLE
Area:     AREA_WINDUP -> AREA_RECOVERY -> IDLE
Stun:     STUNNED -> IDLE
Death:    DEAD (terminal)
```

These are all 15 states. Basic, Cluster, Homing and Running Shot share the same three shot phases. `action_state` identifies which kind of action is executing, while the FSM identifies its phase. For example:

```text
action_state = "cluster_shot"
FSM state    = WINDUP
```

The committed states are WINDUP, FIRE, RECOVERY, DODGE, DODGE_RECOVERY, COVER_HOLD, AREA_WINDUP and AREA_RECOVERY. Ordinary movement has shorter commitments; immediate danger can interrupt those. Stun/death are direct lifecycle events and do not wait for a behavior-tree roll.

## 5. Follow one attack in MuggCombat.gd

Suppose the combat lottery chooses Cluster Shot:

1. MuggTactics calls the boss's `ai_basic_shot("cluster_shot")` forwarding method. The legacy method name remains for compatibility; it supports all four projectile types.
2. That forwards to `combat.start_projectile_attack(kind)`.
3. `_shot_profile(kind)` supplies the attack's windup, recovery, speed and display name.
4. The executor locks the initial aim, starts a cancellable EnemyBase action, enters WINDUP and marks one pending release.
5. EnemyBase calls `_update_action(delta)` every physics frame; the boss forwards this to `combat.advance_action(delta)`.
6. At release time, the executor clears the pending flag, enters FIRE and calls `release_projectiles()`.
7. It then enters RECOVERY. Running Shot can move at full speed here and during release; other shots retain their configured movement rules.
8. EnemyBase finishes the timed action. `cleanup_action()` clears pending effects and returns the FSM to IDLE. The next eligible tree tick chooses again.

If stun happens before step 6, cleanup clears the pending shot. No delayed callback fires it afterward. The FSM and action timer therefore protect the decision the tree already made.

Area and dodge use the same structure, but their own action phases. Released homing balls steer in MuggBall.gd. An activated area is updated by MuggAreaAttack.gd; Mugg does not stay in an attack state until every projectile disappears.

## 6. Understand movement without mixing it with attacks

MuggMovement.gd owns:

- `ai_reposition()` and `_choose_position()`: choose a reachable destination, favoring firing angles and shorter trips.
- `ai_take_cover()`: look for a reachable position protected from the remembered player's shots. The tree chooses whether to try cover; this method finds where to go.
- `_try_hold_cover()`: enter the short hold when the route finishes at a protected point.
- `_start_kiting()` and `_kite_velocity()`: retreat, approach or circle to maintain spacing while avoiding walls and predicted projectiles.
- `update_free_movement()`: follow the chosen route or kiting direction on a free physics frame.

ArenaNavigator.gd provides pathfinding and swept body-clearance checks. Green and blue blocks both stop walking, but only projectile blockers (currently blue blocks) are cover. No movement helper calls move_and_slide(); EnemyBase calls it once.

Kiting is also usable during an attack. The FSM can say RECOVERY while the combat executor asks MuggMovement for a kiting velocity. That is why shooting and moving do not require two competing FSM states.

## 7. What Mugg knows

MuggPerception.gd updates the MuggBlackboard: visibility, shot clearance, last-seen position, memory age and distance. It also predicts incoming projectile danger. Hidden movement does not update the remembered target position. Player health is refreshed only while visible. MuggHealth.gd turns health observations into continuous aggression/defense multipliers.

A useful trace for blue cover:

```text
Player disappears behind blue block
 -> perception keeps last-seen position
 -> tree chooses BLOCKED
 -> lottery tries area attack / firing angle / investigation
 -> area, if selected and ready, warns at the remembered location
 -> moving unseen does not move that warning
 -> memory expires: no-target idle unless another observable threat exists
```

## 8. Where to change things

| You want to change... | Start here |
| --- | --- |
| Attack damage, timing, speed or chance | DoktorMugg scene root Inspector; declarations in MuggSettings.gd |
| Relative responses to danger or close range | Inspector's Situation sections |
| Which situation has priority | MuggBehaviorTree.configure() |
| Which responses exist in a situation | MuggTactics._choices_for() |
| When a response is eligible | MuggTactics._can_*() and its execution guard |
| Attack phase behavior | MuggCombat.advance_action() |
| New attack's projectiles | MuggCombat.release_projectiles(), MuggBall.gd |
| Circling, escape routes or cover destinations | MuggMovement.gd |
| Information the boss can observe | MuggPerception.gd |
| Low-health behavior | Health Tactics / Health Weight Multipliers; MuggHealth.gd |
| Interruption rules | MuggStateMachine.gd and EnemyBase action lifecycle |

`actor` inside each helper means the same DoktorMugg instance. For example, `actor.health` reads his health and `actor.navigator` accesses his navigator. The short forwarding methods in DoktorMugg.gd connect the existing public API to these helpers; they do not duplicate the behavior.

MuggSettings inherits EnemyBase, and DoktorMugg inherits MuggSettings. This preserves existing exported property names and scene overrides. The root Inspector is still the balancing interface; you do not need to attach or configure each helper individually.

## 9. See the choices in-game

Open scenes/test/DoktorMuggArena.tscn and press F6. The overlay now shows:

```text
DANGER -> Take cover
State: TAKE_COVER | HP ... | Sight ... | Clear shot ...
```

Try changing only one situation weight at a time. For instance, increase danger_cover_weight and lower danger_dodge_weight, then shoot near him. This changes which eligible response is preferred, while collision and cooldown checks still apply. Restore the values afterward if you were only experimenting.

Do not expect an exact percentage from a short fight: different cooldowns and valid routes change which choices participate. Use the remote debugger's blackboard.choice_weights to see the last eligible weights.
