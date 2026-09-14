## Shared identity fields for anything pickupable: passive Items and ActiveItems
## both extend this, so the HUD/inventory display can treat them uniformly
## (name, description, icon) without caring which subtype it actually is.
class_name ItemBase
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
