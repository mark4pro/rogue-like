extends Panel

@export var icon : TextureRect
@export var nameTxt : RichTextLabel
@export var stockTxt : RichTextLabel
@export var costTxt : RichTextLabel
@export var buyBttn : Button

@export var mode : int = 0
@export var item : BaseItem = null

func _ready() -> void:
	buyBttn.text = "Buy" if mode == 0 else "Sell"
	
	if item:
		icon.texture = item.itemIcon
		nameTxt.text = "[color=%s]%s[/color]" % [
			item.getRarity().color.to_html(),
			item.name,
		]
		stockTxt.text = "Stock: " + str(item.quantity)
		costTxt.text = "Cost: $" + str(item.cost)

func _process(delta: float) -> void:
	if not item or item.quantity <= 0: buyBttn.disabled = true
	if item: stockTxt.text = "Stock: " + str(item.quantity)

func _on_button_pressed() -> void:
	match mode:
		0:
			item.buy()
		1:
			pass
