extends RigidBody2D

@onready var sprint_timer = $Timer
@export var current_speed:float=7000
var sprint_speed:float=15000
var walk_speed:float=7000
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var dir: Vector2=Vector2(Input.get_axis("left", "right"),Input.get_axis("up","down")).normalized()
	
	linear_velocity=dir*current_speed*delta;
	gravity_scale=0

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("sprint"):
		if not sprint_timer.is_stopped():
			current_speed = sprint_speed
			sprint_timer.start()
	
	else:
		current_speed = walk_speed
		sprint_timer.stop()
	if sprint_timer.is_stopped():
		current_speed = walk_speed
	
	var dir: Vector2=Vector2(Input.get_axis("left", "right"),Input.get_axis("up","down")).normalized()
	
	linear_velocity=dir*current_speed*delta;
	gravity_scale=0


func _on_timer_timeout() -> void:
	current_speed = walk_speed
