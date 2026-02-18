extends Control

func _ready():
	var tween = create_tween()
	tween.parallel().tween_property(self, "position:y", position.y - 10, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
