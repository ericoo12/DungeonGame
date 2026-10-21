## Base class for what an ActiveItem actually DOES when triggered.
## Subclass this and override activate() — see RadialBurstEffect / TickBeamEffect
## for examples. Kept separate from ActiveItem itself so the same effect could,
## in principle, be reused by a differently-named/iconed item later.
class_name ActiveItemEffect
extends Resource

func activate(player: Player) -> void:
	push_warning("ActiveItemEffect.activate() not implemented for this effect")
