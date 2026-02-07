extends Button

func _ready() -> void:
	self.pressed.connect(_on_pressed)

func _on_pressed():
	Global.resume_pressed_signal.emit()
