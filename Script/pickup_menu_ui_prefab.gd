extends ColorRect

@export var compareUI : PackedScene = null
var groundNode : Node2D = null
var thisComp : Control = null
var thisItem : BaseItem = null
# Second button next to Take: "Equip" (weapons / armor: take it and wear it) or "Use" (consumables)
var actionBttn : Button = null
var actionMode : String = "" # "equip" | "use" | ""

func _ready() -> void:
	if "item" in groundNode:
		thisItem = groundNode.item
	if "weapSys" in groundNode:
		thisItem = groundNode.weapSys.weapon
	if not thisItem:
		print("Can't find item on ground node: ", groundNode.name)
		queue_free()
		return
	
	$Name.text = "\t%s x%s" % [Mutation.nameBB(thisItem), str(thisItem.quantity)]
	_buildActionButton()

func _buildActionButton() -> void:
	if thisItem.equippable and thisItem.itemType in [BaseItem.item_type.WEAPON, BaseItem.item_type.ARMOR] and not thisItem.stackable:
		actionMode = "equip"
	elif not thisItem.equippable and thisItem.itemType == BaseItem.item_type.USABLE and not thisItem.questItem:
		actionMode = "use"
	if actionMode == "": return
	var take : Button = $Button
	actionBttn = take.duplicate(0) # same look, no signal
	actionBttn.name = "Action"
	actionBttn.text = "Equip" if actionMode == "equip" else "Use"
	add_child(actionBttn)
	actionBttn.pressed.connect(_on_action_pressed)
	# Sit just left of Take once both have their size
	await get_tree().process_frame
	if not is_instance_valid(actionBttn): return
	var w : float = actionBttn.get_combined_minimum_size().x
	actionBttn.offset_left = take.offset_left - take.size.x - 8 - w
	actionBttn.offset_right = take.offset_left - take.size.x - 8

func _on_action_pressed() -> void:
	match actionMode:
		"equip":
			if not Global.inventory.hasSpace(thisItem): return
			Global.inventory.add_item(thisItem) # adds a copy
			var mine : BaseItem = Global.inventory.data.back()
			mine.equip()
			_done()
		"use":
			thisItem.use() # heals etc. and takes one off the stack on the ground
			if thisItem.quantity <= 0:
				_done()
			else:
				$Name.text = "\t%s x%s" % [Mutation.nameBB(thisItem), str(thisItem.quantity)]

func _done() -> void:
	groundNode.queue_free()
	if thisComp: thisComp.queue_free()
	queue_free()

func _process(_delta: float) -> void:
	if not Global.inventory.hasSpace(thisItem):
		$Button.disabled = true
	else:
		$Button.disabled = false
	if actionBttn and actionMode == "equip": actionBttn.disabled = $Button.disabled
	
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
