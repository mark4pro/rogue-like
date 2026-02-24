extends Resource
class_name BaseItem

enum item_type {
	USABLE,
	WEAPON,
	ARMOR
}

@export_category("Base Item")
@export var id : int = 0
@export var name : String = ""
@export_category("Icon")
@export var itemIcon : Texture2D
@export var iconScale : float = 1.3
@export_range(0, 360, 0.1) var iconRotOffset : float = 0
@export_category("Ground")
@export var groundScale : float = 1
@export_category("Placed")
@export var placedScene : PackedScene = null
@export_category("Base Item Descriptors")
@export var itemType : item_type = item_type.USABLE
@export var equippable : bool = false
@export var stackable : bool = true
@export var throwable : bool = false
@export var placable : bool = false
@export_category("Base Item Data")
@export var weight : float = 1.0
@export var cost : float = 0
@export var costVar : float = 0.2
@export var rolled : bool = false
@export var quantitiy : int = 1

func rollStats() -> void:
	rolled = true

func use() -> void:
	pass

func equip() -> void:
	pass

func unequip() -> void:
	pass

func throw() -> void:
	pass

func drop(amount: int = 1) -> void:
	if not stackable: amount = 1
	amount = clampi(amount, 1, quantitiy)
	unequip()
	var newGroundItem : Node2D = load("res://Assets/prefabs/objects/groundItem.tscn").instantiate()
	newGroundItem.name = name
	newGroundItem.position = Global.player.position
	var newItem : BaseItem = self.duplicate()
	newItem.quantitiy = amount
	newGroundItem.item = newItem
	quantitiy -= amount
	Global.currentScene.add_child(newGroundItem)

func place(pos: Vector2) -> void:
	if placable and equippable:
		var newPlacedScene : Node2D = placedScene.instantiate()
		newPlacedScene.name = name
		newPlacedScene.global_position = pos
		Global.currentScene.add_child(newPlacedScene)
		newPlacedScene.z_index = 3
		quantitiy -= 1
