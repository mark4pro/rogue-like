extends ColorRect

@export var normColor : Color = Color("#6d6d6d")
@export var hoverColor : Color = Color("#848484")

var item : BaseItem = null
var touching : bool = false
var latch : bool = false

func _ready() -> void:
	$title.text = item.name

func _process(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): latch = false
	if touching:
		color = hoverColor
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not latch:
			item.drop(1, false)
			latch = true
	else:
		color = normColor

func _on_mouse_entered() -> void:
	touching = true

func _on_mouse_exited() -> void:
	touching = false
