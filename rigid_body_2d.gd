extends RigidBody2D
@export var speed:float=100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var dir: Vector2=Vector2(Input.get_axis("left", "right"),Input.get_axis("up","down")).normalized()
	
	linear_velocity=dir*speed*delta;
	gravity_scale=0
