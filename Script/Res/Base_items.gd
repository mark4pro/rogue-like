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

var quantitiy : int = 1

func use() -> void:
	pass

func equip() -> void:
	pass

func unequip() -> void:
	pass

func drop() -> void:
	var newGroundItem : Node2D = Global.groundItem.instantiate()
	newGroundItem.name = name
	newGroundItem.position = Global.player.position
	var newItem : BaseItem = self.duplicate()
	newItem.quantitiy = 1
	newGroundItem.item = newItem
	quantitiy -= 1
	Global.player.get_node("..").add_child(newGroundItem)
