extends TextureRect

@onready var icon : TextureRect = %InventoryItem
@onready var amountTxt : Label = %Amount
@onready var favIcon : TextureRect = %FavIcon

@export var equippedColor_weapon : Color = Color.RED
@export var equippedColor_armor : Color = Color.BLUE
@export var item : BaseItem = null

var touching : bool = false
var redraw : bool = false
var latch : bool = false

var refreshLatch : bool = false

var favAtlas : AtlasTexture = null
var favIcon_Type : int = 0
var favIcon_Index : int = 0

func is_in_hotbar():
	if not Global.hotbar_weapons.has(item) and \
	not Global.hotbar_items.has(item):
		favIcon.visible = false
		return null
	
	for i in range(Global.hotbar_weapons.size()):
		if Global.hotbar_weapons[i] == item:
			favIcon_Type = 0
			favIcon_Index = i
	
	for i in range(Global.hotbar_items.size()):
		if Global.hotbar_items[i] == item:
			favIcon_Type = 1
			favIcon_Index = i
	
	favIcon.visible = true

func _ready() -> void:
	favAtlas = favIcon.texture.duplicate()
	favIcon.visible = false
	
	if item:
		amountTxt.visible = item.stackable
		
		icon.texture = item.itemIcon
		icon.scale = Vector2.ONE * item.iconScale
		icon.rotation_degrees = item.iconRotOffset
		Mutation.applyTo(icon, item)
	else:
		amountTxt.visible = false

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
		
		is_in_hotbar()
		
		icon.position = (size / 2) - (icon.size / 2)
		icon.pivot_offset = (icon.size / 2)
		_fitIcon()
		
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
		favIcon.visible = false
		amountTxt.visible = false
		if comp and comp.item == item: comp.queue_free()
		if contextMenu and contextMenu.item == item: contextMenu.queue_free()
	
	favIcon_Type = favIcon_Type % 2
	favIcon_Index = favIcon_Index % 3
	
	favAtlas.region = Rect2(favIcon_Index * 32, favIcon_Type * 32, 32, 32)
	favIcon.texture = favAtlas
	
	favIcon.position = (size * scale) - (favIcon.size * favIcon.scale) - Vector2(2, 2)

const ICON_BASE_SCALE : float = 1.0  # _ready sets the icon's scale to iconScale (overrides the scene's 0.5)
const ICON_FIT : float = 0.85        # biggest an icon may be, as a share of the box

# Icons draw at their texture size x iconScale; big images (the potions) overflowed the box.
# Shrink anything that would spill out (rotation included) so it fits; smaller icons stay as tuned.
func _fitIcon() -> void:
	if not icon.texture or size.x <= 0.0: return
	var tex : Vector2 = icon.texture.get_size()
	var s : float = ICON_BASE_SCALE * item.iconScale
	# Bounding box of the rotated icon
	var r : float = deg_to_rad(item.iconRotOffset)
	var bb : Vector2 = Vector2(absf(tex.x * cos(r)) + absf(tex.y * sin(r)), absf(tex.x * sin(r)) + absf(tex.y * cos(r))) * s
	var room : Vector2 = size * ICON_FIT
	var fit : float = minf(1.0, minf(room.x / maxf(bb.x, 0.001), room.y / maxf(bb.y, 0.001)))
	icon.scale = Vector2.ONE * s * fit

func _draw() -> void:
	if item and item.equippable:
		match item.itemType:
			BaseItem.item_type.WEAPON:
				if Global.weapon == item:
					draw_rect(Rect2(0, 0, size.x, size.y), equippedColor_weapon, false, 2)
			BaseItem.item_type.ARMOR:
				if Global.armor == item:
					draw_rect(Rect2(0, 0, size.x, size.y), equippedColor_armor, false, 2)
