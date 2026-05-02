extends PanelContainer

@onready var slot_1_icon : TextureRect = %Slot_1_Icon
@onready var slot_1_outline : TextureRect = %Slot_1_Outline
@onready var slot_1_amount : Label = %Slot_1_Amount

@onready var slot_2_icon : TextureRect = %Slot_2_Icon
@onready var slot_2_outline : TextureRect = %Slot_2_Outline
@onready var slot_2_amount : Label = %Slot_2_Amount

@onready var slot_3_icon : TextureRect = %Slot_3_Icon
@onready var slot_3_outline : TextureRect = %Slot_3_Outline
@onready var slot_3_amount : Label = %Slot_3_Amount

@onready var slot_4_icon : TextureRect = %Slot_4_Icon
@onready var slot_4_outline : TextureRect = %Slot_4_Outline
@onready var slot_4_amount : Label = %Slot_4_Amount

@onready var slot_5_icon : TextureRect = %Slot_5_Icon
@onready var slot_5_outline : TextureRect = %Slot_5_Outline
@onready var slot_5_amount : Label = %Slot_5_Amount

@onready var slot_6_icon : TextureRect = %Slot_6_Icon
@onready var slot_6_outline : TextureRect = %Slot_6_Outline
@onready var slot_6_amount : Label = %Slot_6_Amount

@export var color_default : Color = Color.BLACK
@export var color_weapon : Color = Color.DARK_RED
@export var color_weapon_equipped : Color = Color.RED
@export var color_item : Color = Color.DARK_GREEN
@export var color_item_equipped : Color = Color.GREEN

func _process(delta: float) -> void:
	var wHBar : Array[BaseItem] = Global.hotbar_weapons
	var iHBar : Array[BaseItem] = Global.hotbar_items
	
	if wHBar.size() == 3:
		if wHBar[0] and wHBar[0].quantity <= 0: wHBar[0] = null
		if wHBar[1] and wHBar[1].quantity <= 0: wHBar[1] = null
		if wHBar[2] and wHBar[2].quantity <= 0: wHBar[2] = null
		
		if wHBar[0]:
			slot_1_icon.texture = wHBar[0].itemIcon
			slot_1_outline.modulate = color_weapon_equipped if Global.weapon == wHBar[0] else color_weapon
			
			if wHBar[0].stackable:
				slot_1_amount.visible = true
				slot_1_amount.text = str(wHBar[0].quantity)
			else:
				slot_1_amount.visible = false
		else:
			slot_1_icon.texture = null
			slot_1_outline.modulate = color_default
			slot_1_amount.visible = false
		
		if wHBar[1]:
			slot_2_icon.texture = wHBar[1].itemIcon
			slot_2_outline.modulate = color_weapon_equipped if Global.weapon == wHBar[1] else color_weapon
			
			if wHBar[1].stackable:
				slot_2_amount.visible = true
				slot_2_amount.text = str(wHBar[1].quantity)
			else:
				slot_2_amount.visible = false
		else:
			slot_2_icon.texture = null
			slot_2_outline.modulate = color_default
			slot_2_amount.visible = false
		
		if wHBar[2]:
			slot_3_icon.texture = wHBar[2].itemIcon
			slot_3_outline.modulate = color_weapon_equipped if Global.weapon == wHBar[2] else color_weapon
			
			if wHBar[2].stackable:
				slot_3_amount.visible = true
				slot_3_amount.text = str(wHBar[2].quantity)
			else:
				slot_3_amount.visible = false
		else:
			slot_3_icon.texture = null
			slot_3_outline.modulate = color_default
			slot_3_amount.visible = false
	
	if iHBar.size() == 3:
		if iHBar[0] and iHBar[0].quantity <= 0: iHBar[0] = null
		if iHBar[1] and iHBar[1].quantity <= 0: iHBar[1] = null
		if iHBar[2] and iHBar[2].quantity <= 0: iHBar[2] = null
		
		if iHBar[0]:
			slot_4_icon.texture = iHBar[0].itemIcon
			slot_4_outline.modulate = color_item_equipped if Global.weapon == iHBar[0] else color_item
			
			if iHBar[0].stackable:
				slot_4_amount.visible = true
				slot_4_amount.text = str(iHBar[0].quantity)
			else:
				slot_4_amount.visible = false
		else:
			slot_4_icon.texture = null
			slot_4_outline.modulate = color_default
			slot_4_amount.visible = false
		
		if iHBar[1]:
			slot_5_icon.texture = iHBar[1].itemIcon
			slot_5_outline.modulate = color_item_equipped if Global.weapon == iHBar[1] else color_item
			
			if iHBar[1].stackable:
				slot_5_amount.visible = true
				slot_5_amount.text = str(iHBar[1].quantity)
			else:
				slot_5_amount.visible = false
		else:
			slot_5_icon.texture = null
			slot_5_outline.modulate = color_default
			slot_5_amount.visible = false
		
		if iHBar[2]:
			slot_6_icon.texture = iHBar[2].itemIcon
			slot_6_outline.modulate = color_item_equipped if Global.weapon == iHBar[2] else color_item
			
			if iHBar[2].stackable:
				slot_6_amount.visible = true
				slot_6_amount.text = str(iHBar[2].quantity)
			else:
				slot_6_amount.visible = false
		else:
			slot_6_icon.texture = null
			slot_6_outline.modulate = color_default
			slot_6_amount.visible = false
