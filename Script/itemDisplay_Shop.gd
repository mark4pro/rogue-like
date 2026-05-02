extends Panel

@export var icon : TextureRect
@export var nameTxt : RichTextLabel
@export var stockTxt : RichTextLabel
@export var costTxt : RichTextLabel
@export var buyBttn : Button

@export var root : CanvasLayer = null
@export var item : BaseItem = null

var touching : bool = false

func _ready() -> void:
	buyBttn.text = "Buy" if root.mode == 0 else "Sell"
	
	if item:
		icon.texture = item.itemIcon
		nameTxt.text = "[color=%s]%s[/color]" % [
			item.getRarity().color.to_html(),
			item.name,
		]
		stockTxt.text = "Stock: " + str(item.quantity)
		if root.mode == 0:
			costTxt.text = "Cost: $" + str(item.cost)
		else:
			costTxt.text = "Cost: $" + str(item.shopPrice)

func _process(delta: float) -> void:
	
	if item:
		buyBttn.disabled = item.quantity <= 0
		stockTxt.text = "Stock: " + str(item.quantity)
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
