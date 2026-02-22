extends Sprite2D

func _ready():
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.finished.connect(queue_free)
