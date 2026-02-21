extends Sprite2D
@onready var sprite = $Sprite2D
@onready var timer = $Timer

func _ready():
	# Fades the sprite out using a Tween
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5) # Fade to 0 alpha in 0.5s
	fade.finished.connect(queue_free) # Delete node after fade
	
	
