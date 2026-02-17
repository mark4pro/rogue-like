extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	# Animate the label rising and fading
	var tween = create_tween()
	tween.parallel().tween_property(self, "position:y", position.y - 50, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free) # Remove node when done
