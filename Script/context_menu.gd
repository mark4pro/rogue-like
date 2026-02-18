extends Control

var item : BaseItem

var touching : bool = true

func _ready() -> void:
	if item.equippable:
		#$PanelContainer/VBoxContainer/useBttn.visible = true
		$PanelContainer/VBoxContainer/dropBttn.visible = true
		$PanelContainer/VBoxContainer/equipBttn.visible = false
		$PanelContainer/VBoxContainer/unequipBttn.visible = false
	else:
		$PanelContainer/VBoxContainer/useBttn.visible = true
		$PanelContainer/VBoxContainer/dropBttn.visible = true
		$PanelContainer/VBoxContainer/equipBttn.visible = false
		$PanelContainer/VBoxContainer/unequipBttn.visible = false

func _process(_delta: float) -> void:
	var mousePos : Vector2 = get_viewport().get_mouse_position()
	
	touching = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
	and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y
	
	if item.equippable:
		if item.itemType == BaseItem.item_type.WEAPON:
			if Global.weapon == item:
				$PanelContainer/VBoxContainer/equipBttn.visible = false
				$PanelContainer/VBoxContainer/unequipBttn.visible = true
			else:
				$PanelContainer/VBoxContainer/equipBttn.visible = true
				$PanelContainer/VBoxContainer/unequipBttn.visible = false

func _on_use_bttn_button_down() -> void:
	item.use()

func _on_drop_bttn_button_down() -> void:
	item.drop()

func _on_unequip_bttn_button_down() -> void:
	item.unequip()

func _on_equip_bttn_button_down() -> void:
	item.equip()
