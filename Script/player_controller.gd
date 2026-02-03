extends RigidBody2D

@onready var health_bar = $CanvasLayer/TextureProgressBar
@onready var roll_cooldown = $roll_cooldown
@onready var sprint_timer = $Timer
@onready var cooldown_timer = $cooldown
var roll : bool = false
var health = 100
var max_health = 100
var can_roll : bool = true

@export var sprint_speed : float = 15000
@export var walk_speed : float = 7000

var speed : float = walk_speed

func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	
func take_damage(amount):
	health -= amount
	health = clamp(health, 0, max_health)
	health_bar.value = health

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("sprint") and cooldown_timer.time_left == 0:
		speed = sprint_speed
		$Sprite2D.speed_scale = 3
		sprint_timer.start()
	if Input.is_action_just_released("sprint"):
		speed = walk_speed
		$Sprite2D.speed_scale = 1
		sprint_timer.stop()
		cooldown_timer.start()
	
	var dir : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	
	linear_velocity = dir * speed * delta;
	
	if linear_velocity != Vector2.ZERO and not roll:
		$Sprite2D.play("walk")
	
	if Input.is_action_just_pressed("roll") and not roll and can_roll:
		roll = true
		can_roll = false
	
	if dir == Vector2.ZERO:
		$Sprite2D.stop()
	
	if roll:
		$Sprite2D.stop()
		$Sprite2D.rotation += 7 * delta
		
	$Sprite2D.rotation_degrees = int($Sprite2D.rotation_degrees) % 360
	
	if $Sprite2D.rotation_degrees == 0 and roll:
		$Sprite2D.rotation = 0
		roll_cooldown.start()
		roll = false 
	
	if linear_velocity.x < 0:
		$Sprite2D.flip_h = true
	elif linear_velocity.x > 0:
		$Sprite2D.flip_h = false

func _on_timer_timeout() -> void:
	speed = walk_speed
	$Sprite2D.speed_scale = 1
	cooldown_timer.start()


func _on_roll_cooldown_timeout() -> void:
	can_roll = true
