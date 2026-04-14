extends TextureRect

@onready var icon : TextureRect = $InventoryItem
@onready var amountTxt : Label = $Amount

@export var equippedColor_weapon : Color = Color.RED
@export var equippedColor_armor : Color = Color.BLUE
@export var item : BaseItem = null

var touching : bool = false
var redraw : bool = false
var latch : bool = false

var refreshLatch : bool = false

func _ready() -> void:
	if item:
		icon.texture = item.itemIcon
		icon.scale = Vector2.ONE * item.iconScale
		icon.rotation_degrees = item.iconRotOffset
	else: amountTxt.visible = false

func _process(_delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): latch = false
	
	var comp : Control = Global.player.Inventory_UI.get_node_or_null("Compare")
	var contextMenu : Control = Global.player.Inventory_UI.get_node_or_null("ContextMenu")
	
	if item:
		var mousePos : Vector2 = get_viewport().get_mouse_position()
		
		touching = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
		and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y \
		and Global.player.Inventory_Node.visible
		
		amountTxt.text = str(item.quantity)
		if item and item.quantity <= 0 and not refreshLatch:
			icon.texture = null
			item = null
			refreshLatch = true
			print("test"+str(item)+str(refreshLatch))
			get_parent().get_parent().get_parent().loaded = false
		
		icon.position = (size / 2) - (icon.size / 2)
		icon.pivot_offset = (icon.size / 2)
		
		if touching:
			if not contextMenu:
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not latch:
					var newContext : Control = Global.contextMenu.instantiate()
					newContext.position = get_viewport().get_mouse_position() - (newContext.size / 2)
					newContext.item = item
					Global.player.Inventory_UI.add_child(newContext)
					latch = true
				
				if comp and not comp.item == item: comp.queue_free()
				if not comp:
					var newComp : Control = Global.compareUI.instantiate()
					newComp.position = get_viewport().get_mouse_position()
					newComp.item = item
					Global.player.Inventory_UI.add_child(newComp)
			else:
				if comp: comp.queue_free()
				if not contextMenu.touching: contextMenu.queue_free()
		else:
			if comp and comp.item == item: comp.queue_free()
		
		if (Global.weapon == item or Global.armor == item) and not redraw:
			queue_redraw()
			redraw = true
		if not Global.weapon == item and not Global.armor == item and redraw:
			queue_redraw()
			redraw = false
	else:
		amountTxt.visible = false
		if comp and comp.item == item: comp.queue_free()
		if contextMenu and contextMenu.item == item: contextMenu.queue_free()

func _draw() -> void:
	if item and item.equippable:
		match item.itemType:
			BaseItem.item_type.WEAPON:
				if Global.weapon == item:
					draw_rect(Rect2(0, 0, size.x, size.y), equippedColor_weapon, false, 2)
			BaseItem.item_type.ARMOR:
				if Global.armor == item:
					draw_rect(Rect2(0, 0, size.x, size.y), equippedColor_armor, false, 2)
