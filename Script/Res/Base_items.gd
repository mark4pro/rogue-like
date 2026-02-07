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

var quantitiy : int = 1

func use() -> void:
	pass

func equip() -> void:
	pass

func unequip() -> void:
	pass
