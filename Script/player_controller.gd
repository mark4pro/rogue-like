extends RigidBody2D

@onready var sprint_timer = $Timer
@onready var cooldown_timer = $cooldown


@export var sprint_speed : float = 15000
@export var walk_speed : float = 7000

var speed : float = walk_speed

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("sprint") and cooldown_timer.time_left == 0:
		speed = sprint_speed
		sprint_timer.start()
	if Input.is_action_just_released("sprint"):
		speed = walk_speed
		sprint_timer.stop()
		cooldown_timer.start()
	
	var dir : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	
	linear_velocity = dir * speed * delta;


func _on_timer_timeout() -> void:
	speed = walk_speed
	cooldown_timer.start()
