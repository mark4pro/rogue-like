extends Control

@onready var useBttn : Button = %useBttn
@onready var dropBttn : Button = %dropBttn
@onready var equipBttn : Button = %equipBttn
@onready var unequipBttn : Button = %unequipBttn
@onready var hotbar1Bttn : Button = %hotbar_1
@onready var hotbar2Bttn : Button = %hotbar_2
@onready var hotbar3Bttn : Button = %hotbar_3

var item : BaseItem

var touching : bool = true

func _ready() -> void:
	if item:
		if item.equippable:
			useBttn.visible = false
			dropBttn.visible = true
			equipBttn.visible = false
			unequipBttn.visible = false
		else:
			useBttn.visible = true
			dropBttn.visible = true
			equipBttn.visible = false
			unequipBttn.visible = false
		if item.hotBarType != BaseItem.hotbar_type.NONE:
			hotbar1Bttn.visible = true
			hotbar2Bttn.visible = true
			hotbar3Bttn.visible = true
		else:
			hotbar1Bttn.visible = false
			hotbar2Bttn.visible = false
			hotbar3Bttn.visible = false

func _process(_delta: float) -> void:
	var mousePos : Vector2 = get_viewport().get_mouse_position()
	
	touching = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
	and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y
	
	if item and item.equippable:
		match item.itemType:
			BaseItem.item_type.WEAPON:
				if Global.weapon == item:
					equipBttn.visible = false
					unequipBttn.visible = true
				else:
					equipBttn.visible = true
					unequipBttn.visible = false
			BaseItem.item_type.ARMOR:
				if Global.armor == item:
					equipBttn.visible = false
					unequipBttn.visible = true
				else:
					equipBttn.visible = true
					unequipBttn.visible = false
	
	#Hot Bar
	if item.hotBarType != BaseItem.hotbar_type.NONE:
		match item.hotBarType:
			BaseItem.hotbar_type.WEAPON:
				if Global.hotbar_weapons[0] == item:
					hotbar1Bttn.text = "Rem slot 1"
				else:
					hotbar1Bttn.text = "Add to slot 1"
				
				if Global.hotbar_weapons[1] == item:
					hotbar2Bttn.text = "Rem slot 2"
				else:
					hotbar2Bttn.text = "Add to slot 2"
				
				if Global.hotbar_weapons[2] == item:
					hotbar3Bttn.text = "Rem slot 3"
				else:
					hotbar3Bttn.text = "Add to slot 3"
			BaseItem.hotbar_type.ITEM:
				if Global.hotbar_items[0] == item:
					hotbar1Bttn.text = "Rem slot 1"
				else:
					hotbar1Bttn.text = "Add to slot 1"
				
				if Global.hotbar_items[1] == item:
					hotbar2Bttn.text = "Rem slot 2"
				else:
					hotbar2Bttn.text = "Add to slot 2"
				
				if Global.hotbar_items[2] == item:
					hotbar3Bttn.text = "Rem slot 3"
				else:
					hotbar3Bttn.text = "Add to slot 3"

func _on_use_bttn_button_down() -> void:
	item.use()

func _on_drop_bttn_button_down() -> void:
	item.drop()
	if item.quantity - 1 <= 0: queue_free()

func _on_unequip_bttn_button_down() -> void:
	item.unequip()

func _on_equip_bttn_button_down() -> void:
	item.equip()

func _on_hotbar_1_button_down() -> void:
	match item.hotBarType:
		BaseItem.hotbar_type.WEAPON:
			if Global.hotbar_weapons[0] == item:
				Global.hotbar_weapons[0] = null
			else:
				Global.hotbar_weapons[0] = item
		BaseItem.hotbar_type.ITEM:
			if Global.hotbar_items[0] == item:
				Global.hotbar_items[0] = null
			else:
				Global.hotbar_items[0] = item

func _on_hotbar_2_button_down() -> void:
	match item.hotBarType:
		BaseItem.hotbar_type.WEAPON:
			if Global.hotbar_weapons[1] == item:
				Global.hotbar_weapons[1] = null
			else:
				Global.hotbar_weapons[1] = item
		BaseItem.hotbar_type.ITEM:
			if Global.hotbar_items[1] == item:
				Global.hotbar_items[1] = null
			else:
				Global.hotbar_items[1] = item

func _on_hotbar_3_button_down() -> void:
	match item.hotBarType:
		BaseItem.hotbar_type.WEAPON:
			if Global.hotbar_weapons[2] == item:
				Global.hotbar_weapons[2] = null
			else:
				Global.hotbar_weapons[2] = item
		BaseItem.hotbar_type.ITEM:
			if Global.hotbar_items[2] == item:
				Global.hotbar_items[2] = null
			else:
				Global.hotbar_items[2] = item
