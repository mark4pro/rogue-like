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

var quantitiy : int = 1

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
	var newGroundItem : Node2D = Global.groundItem.instantiate()
	newGroundItem.name = name
	newGroundItem.position = Global.player.position
	var newItem : BaseItem = self.duplicate()
	newItem.quantitiy = amount
	newGroundItem.item = newItem
	quantitiy -= amount
	Global.currentScene.add_child(newGroundItem)
