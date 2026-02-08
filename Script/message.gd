extends ColorRect

@onready var label : Label = $Label
@onready var pBar : ProgressBar = $ProgressBar

@export var ms : String = ""
@export var c : Color = Color.WHITE
@export var bg : Color = Color("4a4a4a")
@export var time : float = 2.0

func _ready() -> void:
	color = bg
	label.text = ms
	label.add_theme_color_override("font_color", c)
