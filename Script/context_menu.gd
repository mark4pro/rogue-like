extends Control

var item : BaseItem

var touching : bool = false

func _ready() -> void:
	if item.equippable:
		#$PanelContainer/VBoxContainer/useBttn.visible = true
		$PanelContainer/VBoxContainer/dropBttn.visible = true
		#$PanelContainer/VBoxContainer/equipBttn.visible = false
		#$PanelContainer/VBoxContainer/unequipBttn.visible = false
	else:
		$PanelContainer/VBoxContainer/useBttn.visible = true
		$PanelContainer/VBoxContainer/dropBttn.visible = true
		$PanelContainer/VBoxContainer/equipBttn.visible = false
		$PanelContainer/VBoxContainer/unequipBttn.visible = false

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not touching:
		queue_free()

func _on_use_bttn_button_down() -> void:
	item.use()

func _on_drop_bttn_button_down() -> void:
	item.drop()

func _on_unequip_bttn_button_down() -> void:
	item.unequip()

func _on_equip_bttn_button_down() -> void:
	item.equip()

func _on_panel_container_mouse_entered() -> void:
	touching = true

func _on_panel_container_mouse_exited() -> void:
	touching = false
