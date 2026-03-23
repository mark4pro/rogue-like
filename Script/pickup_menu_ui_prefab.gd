extends ColorRect

@export var compareUI : PackedScene = null
var groundNode : Node2D = null

func _ready() -> void:
	$Name.text = "\t[color=%s]%s[/color]" % [
		groundNode.item.getRarity().color.to_html(),
		str(groundNode.item.name)
	]

func _process(_delta: float) -> void:
	if not Global.inventory.hasSpace(groundNode.item):
		$Button.disabled = true
	else:
		$Button.disabled = false
	
	if compareUI:
		var thisComp : Control = Global.player.Pickup_UI.get_node_or_null("Compare")
		
		var mousePos : Vector2 = get_viewport().get_mouse_position()
			
		var touching : bool = mousePos.x >= global_position.x and mousePos.x <= global_position.x + size.x \
		and mousePos.y >= global_position.y and mousePos.y <= global_position.y + size.y
		
		if touching:
			if not thisComp:
				var newComp : Control = compareUI.instantiate()
				newComp.item = groundNode.item
				Global.player.Pickup_UI.add_child(newComp)
			if thisComp and not thisComp.item == groundNode.item:
				thisComp.queue_free()
		else:
			if thisComp and thisComp.item == groundNode.item: thisComp.queue_free()

func _on_button_pressed() -> void:
	if Global.inventory.hasSpace(groundNode.item):
		Global.inventory.add_item(groundNode.item)
		groundNode.queue_free()
		queue_free()
