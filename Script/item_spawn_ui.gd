extends ColorRect

var item : BaseItem = null

func _ready() -> void:
	$title.text = item.name
