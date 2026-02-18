extends TextureRect

@export var equippedColor : Color = Color.RED
@export var item : BaseItem = null

var touching : bool = false
var redraw : bool = false
var latch : bool = false

func _ready() -> void:
	if item: texture = item.itemIcon
	else: $Amount.visible = false

func _process(_delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): latch = false
	
	$BG.size = size
	
	if item:
		var mousePos : Vector2 = get_viewport().get_mouse_position()
		
		touching = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
		and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y
		
		$Amount.text = str(item.quantitiy)
		if item.quantitiy <= 0:
			item = null
			texture = null
		
		var comp : Control = Global.player.Inventory_UI.get_node_or_null("Compare")
		var contextMenu : Control = Global.player.Inventory_UI.get_node_or_null("ContextMenu")
		
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
		
		if Global.weapon == item and not redraw:
			queue_redraw()
			redraw = true
		if not Global.weapon == item and redraw:
			queue_redraw()
			redraw = false
	else:
		$Amount.visible = false

func _draw() -> void:
	if item and item.equippable:
		if item.itemType == BaseItem.item_type.WEAPON:
			if Global.weapon == item:
				draw_rect(Rect2(0, 0, size.x, size.y), equippedColor, false, 2)
