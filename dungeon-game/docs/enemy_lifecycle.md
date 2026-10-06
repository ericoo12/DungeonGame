# Enemy update and action ownership

EnemyBase owns initialization, the physics update and the single move_and_slide call. ToiletBrush inherits that lifecycle. Do not add an independent physics loop to an enemy FSM/behavior tree or move its body from a state or resource.

## Hooks

- `_setup_animations()`: provide SpriteFrames without copying the base initialization.
- `_update_cooldowns(delta)`: passive timers while alive and past spawn grace. Call super when overriding so resource cooldowns also advance.
- `_update_behavior(delta)`: choose an action or set velocity when free to act. Not called while hurt, performing an action, or receiving knockback.
- `_update_action(delta)`: execute a committed action using `action_elapsed`; may set velocity for a dash/lunge. Base movement still applies knockback priority.
- `_on_action_ended(action, cancelled)`: clear action-specific state on both completion and cancellation. Never emit attack effects here.

## Action lifecycle

Use `begin_action(name, animation, minimum_duration)` and retain the returned handle if external code needs to finish it. The method returns -1 after death/removal. `action_state` is read-only; do not change `_action_state` directly. `finish_action(handle)` ignores stale handles; `cancel_action()` immediately clears pending action effects through the cleanup hook. `action_finished` and `action_cancelled` notify consumers.

Actions advance with physics delta, so tree pause suspends their windup/recovery. Duration is captured from animation frame durations, animation FPS and sprite speed when the action starts; the optional minimum supports an event scheduled later than the animation. Gameplay does not wait for sprite animation_finished. Avoid changing animation speed mid-action unless also designing matching gameplay timing.

Taking damage cancels the current action and begins a new hurt action. Death cancels attacks, prevents new actions, disables contact/body collisions, and finishes its bounded death action once. Removal from the tree also cancels pending effects. A projectile that already launched remains independent; cancellation prevents future launches, not existing bullets.

ToiletBrush keeps a pending spit flag and lunge data rather than suspended timer/signal callbacks. Cancellation resets both. Passive contact damage still ticks through EnemyBase, but does not start a separate cosmetic brush attack that would block its decision hook.

Movement/attack resources are duplicated per enemy. AttackBehavior.update_cooldown runs separately from try_attack so hurt or knockback does not freeze cooldown progress. A failed attack check still allows movement. Static enemy attack/hurt clips are finite.

## Doktor Mugg integration

Keep EnemyBase's lifecycle. Supply animations through the setup hook, run idle tactical decisions through the behavior hook, and execute committed actions through the action hook. Use cancel_action for an allowed tactical interrupt; clear FSM action data in the cleanup hook. Explicitly drive any child AI nodes from these hooks instead of also allowing them to self-process. This is infrastructure for the boss, not an implemented boss FSM or behavior tree.

## Regression checks

After importing the project, run:

```
godot --headless --path . res://tests/EnemyLifecycleTest.tscn
```

The test scene covers knockback priority, movement with unavailable attacks, independent cooldowns, static hurt recovery, interrupted/replaced spits, cancelled lunges, late launch timing, contact grace/repeat damage, stale action handles, terminal death, removal and tree pause.
