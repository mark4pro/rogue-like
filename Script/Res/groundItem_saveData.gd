extends Resource
class_name GroundItem

@export var item : BaseItem = null
@export var pos : Vector2 = Vector2.ZERO
@export var rot : float = 0
@export var placed : bool = false # true = respawn as the item's placedScene (e.g. a lit torch), false = groundItem pickup
