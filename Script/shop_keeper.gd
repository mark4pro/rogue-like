extends Node2D

@onready var idleTimer : Timer = $Idle

@export var rest : bool = true
@export var wave : bool = false

@export var inRange : bool = false

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if inRange:
		idleTimer.stop()
		rest = false
	else:
		if idleTimer.is_stopped(): idleTimer.start()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		inRange = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		inRange = false

func _on_idle_timeout() -> void:
	rest = true
