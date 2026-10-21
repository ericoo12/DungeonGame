extends FinalBossBase
class_name MuggSettings

## BALANCING ONLY. Inherited exports still appear on the DoktorMugg scene root.
## Scene/instance overrides keep their existing names and values.
## Change the Inspector to tune one boss; change these defaults for new instances.

@export_category("Tactics")
@export_range(0.05, 1.0) var decision_interval: float = 0.2
@export var preferred_distance: float = 155.0
@export var close_distance: float = 85.0
@export var attack_range: float = 280.0
@export var memory_duration: float = 3.0
@export var movement_commitment: float = 0.65
@export var movement_timeout: float = 1.6
@export var reposition_cooldown: float = 0.8
@export var navigation_radius: float = 20.0
## 0 changes the random sequence each run; a fixed number reproduces choices.
@export var random_seed: int = 0
@export var debug_ai: bool = false

@export_category("Health Tactics")
@export var health_tactics_enabled: bool = true
@export_range(0.1, 1.0, 0.05) var player_low_health_threshold: float = 0.5
@export_range(0.1, 1.0, 0.05) var boss_low_health_threshold: float = 0.45
@export_range(1.0, 5.0, 0.1) var low_player_attack_weight_boost: float = 3.0
@export_range(0.3, 1.0, 0.05) var low_player_cooldown_scale: float = 0.5
@export var low_player_close_in_distance: float = 45.0
@export var low_boss_extra_distance: float = 75.0
@export_range(0.0, 0.5, 0.05) var low_boss_dodge_bonus: float = 0.2
@export_range(0.3, 1.0, 0.05) var low_boss_defense_cooldown_scale: float = 0.55
@export_range(1.0, 5.0, 0.1) var low_boss_movement_weight_boost: float = 3.0
@export_range(1.0, 3.0, 0.1) var low_boss_cover_hold_boost: float = 1.5

@export_category("Kiting")
@export var kiting_enabled: bool = true
## Disable ordinary hit stagger for sustained kiting; explicit stun still interrupts.
@export var kite_hit_stagger: bool = false
## Movement during windup; the final plant window and release remain stationary.
@export_range(0.0, 1.0, 0.05) var kite_windup_speed: float = 0.4
@export_range(0.0, 1.5, 0.05) var kite_recovery_speed: float = 1.0
@export_range(0.0, 0.3, 0.01) var kite_plant_window: float = 0.1
@export var kite_spacing_tolerance: float = 30.0
@export var kite_probe_distance: float = 45.0
@export var kite_direction_interval: float = 1.7
@export_range(0.0, 1.0, 0.05) var kite_reverse_chance: float = 0.4
@export var kite_strafe_weight: float = 1.4
@export var kite_spacing_weight: float = 3.0
## Predict only from consecutive visible observations, never hidden movement.
@export_range(0.0, 1.0, 0.05) var aim_lead_strength: float = 0.0
@export var aim_lead_max_distance: float = 55.0

@export_category("Basic Shot")
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 0.5
@export var projectile_speed: float = 160.0
@export_range(0.1, 3.0) var windup_duration: float = 0.55
@export_range(0.01, 1.0) var fire_duration: float = 0.08
@export_range(0.1, 3.0) var recovery_duration: float = 0.65
@export var attack_cooldown: float = 1.8

@export_category("Running Shot")
## Almost-empty paper roll fired while kiting at full speed, including release.
@export_range(0.0, 10.0, 0.1) var running_shot_weight: float = 3.0
@export_range(0.05, 0.5, 0.01) var running_shot_windup: float = 0.12
@export_range(0.05, 0.5, 0.01) var running_shot_recovery: float = 0.16
@export var running_shot_damage: float = 0.5
@export var running_shot_speed: float = 205.0
@export var running_shot_cooldown: float = 0.65

@export_category("Cluster Shot")
@export_range(0.0, 10.0, 0.1) var cluster_weight: float = 2.0
@export_range(3, 9, 1) var cluster_count: int = 5
@export_range(10.0, 90.0, 1.0) var cluster_cone_degrees: float = 38.0
## Jitter within each cone sector; keeps the spread irregular without clumping.
@export_range(0.0, 1.0, 0.05) var cluster_scatter: float = 0.8
@export var cluster_speed: float = 145.0
@export_range(0.0, 0.4, 0.01) var cluster_speed_variation: float = 0.12
@export var cluster_damage: float = 0.5
@export var cluster_lifetime: float = 2.2
@export var cluster_windup: float = 0.7

@export_category("Homing Shot")
@export_range(0.0, 10.0, 0.1) var homing_near_weight: float = 0.25
@export_range(0.0, 10.0, 0.1) var homing_far_weight: float = 3.0
@export var homing_near_distance: float = 80.0
@export var homing_far_distance: float = 280.0
@export var homing_speed: float = 145.0
@export_range(10.0, 180.0, 5.0) var homing_turn_rate: float = 85.0
@export var homing_tracking_duration: float = 1.6
@export var homing_tracking_delay: float = 0.2
@export var homing_lifetime: float = 3.2
@export var homing_damage: float = 0.5
@export var homing_windup: float = 0.85
@export var homing_cooldown: float = 6.0
@export var paper_trail_damage: float = 0.5
@export var paper_trail_lifetime: float = 1.0
@export var paper_trail_width: float = 8.0
@export var homing_color := Color(0.75, 0.25, 1.0)

@export_category("Dodge — Reaction")
## Roll once per incoming projectile, when not committed and cooldown is ready.
@export var dodge_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var dodge_chance: float = 0.65
@export_range(0.1, 2.0, 0.05) var dodge_lookahead: float = 0.65
@export_range(20.0, 500.0, 5.0) var dodge_detection_range: float = 180.0
## Predicted collision corridor, including the boss and projectile footprint.
@export_range(10.0, 80.0, 1.0) var dodge_threat_radius: float = 30.0
@export_range(0.0, 10.0, 0.1) var dodge_cooldown: float = 2.5

@export_category("Dodge — Movement")
@export_range(50.0, 600.0, 10.0) var dodge_speed: float = 320.0
@export_range(0.05, 0.8, 0.01) var dodge_duration: float = 0.22
@export_range(0.05, 1.0, 0.01) var dodge_recovery: float = 0.25
## Relative weights; zero disables a direction. Blocked routes are excluded.
@export_range(0.0, 10.0, 0.1) var dodge_left_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var dodge_right_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var dodge_away_weight: float = 0.5
@export_range(0.0, 10.0, 0.1) var dodge_diagonal_weight: float = 0.75

@export_category("Position Preferences")
@export_range(0.0, 20.0, 0.1) var clear_position_weight: float = 5.0
@export_range(0.0, 20.0, 0.1) var blocked_position_weight: float = 0.5
## Larger values reduce the preference for nearby destinations.
@export_range(10.0, 600.0, 10.0) var position_distance_scale: float = 150.0

@export_category("Tactic Probabilities")
## Combat weights combine with Cluster, Homing and Running Shot weights.
@export_range(0.0, 10.0, 0.1) var basic_shot_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var tactical_move_weight: float = 1.0
## Avoid rolling the same tactical choice every decision tick.
@export_range(0.1, 3.0, 0.1) var tactic_choice_interval: float = 0.8
## Random +/- fraction of shot/dodge cooldown; 0 gives fixed timings.
@export_range(0.0, 0.75, 0.05) var cooldown_variation: float = 0.2

@export_category("Take Cover")
@export var cover_enabled: bool = true
@export_range(40.0, 350.0, 10.0) var cover_search_distance: float = 180.0
@export_range(0.1, 2.0, 0.1) var cover_hold_duration: float = 0.6
@export_range(0.5, 10.0, 0.1) var cover_cooldown: float = 3.5

@export_category("Area Attack")
@export var area_enabled: bool = true
@export_range(20.0, 120.0, 5.0) var area_radius: float = 60.0
@export_range(0.4, 2.5, 0.05) var area_warning: float = 0.9
@export_range(0.2, 4.0, 0.1) var area_lifetime: float = 1.4
@export var area_damage: float = 0.5
@export_range(0.1, 2.0, 0.05) var area_recovery: float = 0.5
@export_range(1.0, 15.0, 0.1) var area_cooldown: float = 5.0
@export var area_range: float = 300.0
@export var area_defensive_distance: float = 95.0
@export var area_cover_delay: float = 0.6
@export_range(0.0, 1.0, 0.05) var area_anti_cover_chance: float = 0.8
@export_range(0.0, 1.0, 0.05) var area_defensive_chance: float = 0.5
## A failed area roll cannot repeat until this many seconds have passed.
@export_range(0.2, 3.0, 0.1) var area_choice_interval: float = 1.2


@export_category("Situation — Danger")
@export_range(0, 10, 0.1) var danger_dodge_weight: float = 3.0
@export_range(0, 10, 0.1) var danger_cover_weight: float = 2.0
@export_range(0, 10, 0.1) var danger_running_shot_weight: float = 1.0
@export_range(0, 10, 0.1) var danger_retreat_weight: float = 1.0

@export_category("Situation — Blocked Player")
@export_range(0, 10, 0.1) var blocked_area_weight: float = 3.0
@export_range(0, 10, 0.1) var blocked_flank_weight: float = 2.0
@export_range(0, 10, 0.1) var blocked_investigate_weight: float = 1.0

@export_category("Situation — Too Close")
@export_range(0, 10, 0.1) var close_running_shot_weight: float = 3.0
@export_range(0, 10, 0.1) var close_dodge_weight: float = 1.0
@export_range(0, 10, 0.1) var close_area_weight: float = 2.0
@export_range(0, 10, 0.1) var close_retreat_weight: float = 2.0
@export_range(0, 10, 0.1) var close_cover_weight: float = 1.0

@export_category("Situation — Combat and Search")
## Extra combat cover preference, multiplied by how wounded Mugg is.
@export_range(0, 10, 0.1) var combat_cover_weight: float = 2.0
@export_range(0, 10, 0.1) var search_approach_weight: float = 2.0
@export_range(0, 10, 0.1) var search_reposition_weight: float = 1.0

@export_category("Health Weight Multipliers")
@export_range(0, 1, 0.05) var wounded_stationary_attack_scale: float = 0.6
@export_range(1, 4, 0.1) var wounded_running_attack_scale: float = 2.0
@export_range(0, 1, 0.05) var aggressive_movement_scale: float = 0.5
@export_range(0, 1, 0.05) var proactive_cover_defense_threshold: float = 0.25
