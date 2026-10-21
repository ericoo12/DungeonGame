## Shared identity fields for anything pickupable: passive Items and ActiveItems
## both extend this, so the HUD/inventory display can treat them uniformly
## (name, description, icon) without caring which subtype it actually is.
class_name ItemBase
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
## Shop price in ducks. 0 = the default for its rarity (Dungeon shop prices).
@export var shop_price: int = 0
## How often it shows up in item rooms and shops (Dungeon.rarity weights; luck makes
## Uncommon and Rare items more likely). Rare = run-defining items.
enum Rarity { COMMON, UNCOMMON, RARE }
@export var rarity: Rarity = Rarity.COMMON
