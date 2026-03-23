extends Control

@export var pickupItemUI : PackedScene = null
@export var vBoxContainer : VBoxContainer = null

var loaded : bool = false

func _process(_delta: float) -> void:
	if pickupItemUI and vBoxContainer:
		if not loaded and $"..".visible:
			for i in get_tree().get_nodes_in_group("items"):
				if Global.player.global_position.distance_to(i.global_position) > Global.pickupRange:
					continue
				var newItem : ColorRect = pickupItemUI.instantiate()
				newItem.groundNode = i
				vBoxContainer.add_child(newItem)
			loaded = true
		if loaded and not $"..".visible: loaded = false
