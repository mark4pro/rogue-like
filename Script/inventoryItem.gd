extends TextureRect

@export var item : BaseItem = null

var touching : bool = false

func _ready() -> void:
	if item: texture = item.itemIcon
	else: $Amount.visible = false

func _process(_delta: float) -> void:
	$BG.size = size
	if item:
		$Amount.text = str(item.quantitiy)
		if item.quantitiy <= 0:
			item = null
			texture = null
		if touching and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var newContext : Control = Global.contextMenu.instantiate()
			newContext.position = get_viewport().get_mouse_position()
			newContext.item = item
			Global.player.Inventory_UI.add_child(newContext)
	else:
		$Amount.visible = false

func _on_mouse_entered() -> void:
	touching = true

func _on_mouse_exited() -> void:
	touching = false
