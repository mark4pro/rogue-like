extends Panel

@export var icon : TextureRect
@export var nameTxt : RichTextLabel
@export var stockTxt : RichTextLabel
@export var costTxt : RichTextLabel
@export var buyBttn : Button

@export var root : CanvasLayer = null
@export var item : BaseItem = null

var touching : bool = false

## Sell tab: panel colour for the weapon / armor you have equipped (same colours as the inventory outline)
@export var equippedColor_weapon : Color = Color(1.0, 0.35, 0.35)
@export var equippedColor_armor : Color = Color(0.4, 0.55, 1.0)

func _equippedColor() -> Color:
	if root.mode != 1 or not item: return Color.WHITE
	if Global.weapon == item: return equippedColor_weapon
	if Global.armor == item: return equippedColor_armor
	return Color.WHITE

var _shownColor : Color = Color.WHITE

func _setPanelColor(c: Color) -> void:
	_shownColor = c
	if c == Color.WHITE:
		remove_theme_stylebox_override("panel")
		return
	var base : StyleBox = get_theme_stylebox("panel")
	var sb : StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.bg_color = Color(c, 0.3)
	sb.border_color = c
	sb.set_border_width_all(3)
	add_theme_stylebox_override("panel", sb)

func _ready() -> void:
	buyBttn.text = "Buy" if root.mode == 0 else "Sell"
	
	if item:
		icon.texture = item.itemIcon
		Mutation.applyTo(icon, item)
		nameTxt.text = Mutation.nameBB(item)
		stockTxt.text = "Stock: " + str(item.quantity)
		if root.mode == 0:
			costTxt.text = "Cost: $" + str(item.cost)
		else:
			costTxt.text = "Cost: $" + str(item.shopPrice)

func _process(_delta: float) -> void:
	if item:
		buyBttn.disabled = item.quantity <= 0
		stockTxt.text = "Stock: " + str(item.quantity)
		# Equipped items stand out in the sell list: coloured panel + border, "Equipped" instead of stock
		var eq : Color = _equippedColor()
		if eq != _shownColor: _setPanelColor(eq)
		if eq != Color.WHITE: stockTxt.text = "[color=%s]Equipped[/color]" % eq.to_html(false)
		if root.mode == 1 and item.quantity <= 0: queue_free()
		
		var mousePos : Vector2 = get_viewport().get_mouse_position()
		
		touching = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
		and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y
		
		var comp : Control = root.get_node_or_null("Compare")
		
		if touching and root.touching:
			if comp and not comp.item == item: comp.queue_free()
			if not comp:
				var newComp : Control = Global.compareUI.instantiate()
				newComp.position = get_viewport().get_mouse_position()
				newComp.item = item
				root.add_child(newComp)
		else:
			if comp and comp.item == item: comp.queue_free()
	else:
		buyBttn.disabled = true

func _on_button_pressed() -> void:
	if root.mode == 0:
			if item.quantity == 1:
				item.buy()
			else:
				root.selected = item
	else:
			if item.quantity == 1:
				item.sell()
			else:
				root.selected = item
