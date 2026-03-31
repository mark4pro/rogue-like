extends ColorRect

@export var compareUI : PackedScene = null
var groundNode : Node2D = null
var thisComp : Control = null
var thisItem : BaseItem = null

func _ready() -> void:
	if "item" in groundNode:
		thisItem = groundNode.item
	if "weapSys" in groundNode:
		thisItem = groundNode.weapSys.weapon
	if not thisItem:
		print("Can't find item on ground node: ", groundNode.name)
		queue_free()
	
	$Name.text = "\t[color=%s]%s[/color] x%s" % [
		thisItem.getRarity().color.to_html(),
		str(thisItem.name),
		str(thisItem.quantity)
	]

func _process(_delta: float) -> void:
	if not Global.inventory.hasSpace(thisItem):
		$Button.disabled = true
	else:
		$Button.disabled = false
	
	if compareUI:
		thisComp = Global.player.Inventory_UI.get_node_or_null("Compare")
		
		var mousePos : Vector2 = get_viewport().get_mouse_position()
			
		var touching : bool = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
		and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y \
		and Global.player.Pickup_Node.visible
		
		if touching:
			if not thisComp:
				var newComp : Control = compareUI.instantiate()
				newComp.item = thisItem
				Global.player.Inventory_UI.add_child(newComp)
			if thisComp and not thisComp.item == thisItem:
				thisComp.queue_free()
		else:
			if thisComp and thisComp.item == thisItem: thisComp.queue_free()

func _on_button_pressed() -> void:
	if Global.inventory.hasSpace(thisItem):
		Global.inventory.add_item(thisItem)
		groundNode.queue_free()
		if thisComp: thisComp.queue_free()
		queue_free()
