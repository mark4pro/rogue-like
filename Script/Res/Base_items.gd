extends Resource
class_name BaseItem

enum item_type {
	USABLE,
	WEAPON,
	ARMOR
}

@export var id : int = 0
@export var name : String = ""
@export var itemType : item_type = item_type.USABLE
@export var itemIcon : Texture2D
@export var equippable : bool = false
@export var stackable : bool = true
@export var weight : float = 1.0
@export var cost : int = 0
@export var costVar : float = 0.2

var rolled : bool = false
var quantitiy : int = 1

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
	var newGroundItem : Node2D = preload("res://Assets/prefabs/groundItem.tscn").instantiate()
	newGroundItem.name = name
	newGroundItem.position = Global.player.position
	var newItem : BaseItem = self.duplicate()
	newItem.quantitiy = amount
	newGroundItem.item = newItem
	quantitiy -= amount
	Global.currentScene.add_child(newGroundItem)
