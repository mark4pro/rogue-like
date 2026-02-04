extends RigidBody2D

@onready var health_bar = $UI/HealthBar
@onready var stamina_bar = $UI/StaminaBar
@onready var roll_cooldown_bar = $UI/RollCooldownBar
@onready var roll_cooldown = $roll_cooldown

@export_category("Stats")
@export var max_health = 100
@export var health = max_health
@export var max_stamina = 100
@export var stamina = max_stamina
@export var stamina_regen = 5
@export var stamina_exhausted_regen = 15
@export var stamina_drain = 25

@export_category("Movement")
@export var sprint_speed : float = 15
@export var walk_speed : float = 7
@export var roll_speed : float = 10
@export var roll_rot_speed : float = 7

@export_category("UI")
@export var stamina_norm_color : Color
@export var stamina_exh_color : Color

var regen_stamina : bool = false
var can_sprint : bool = true
var is_rolling : bool = false
var can_roll : bool = true
var is_moving : bool = false
var is_sprinting : bool = false

var dir : Vector2 = Vector2.ZERO
var speed : float = walk_speed

var rspeed : float = roll_speed
var roll_target : Vector2 = Vector2.ZERO
var roll_dir : Vector2 = Vector2.ZERO

func _ready() -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	
func take_damage(amount: float):
	if not is_rolling:
		health -= amount
	print(str(health))

func _process(delta: float) -> void:
	#Clamp health
	health = clamp(health, 0, max_health)
	
	#Movement check
	is_moving = not dir == Vector2.ZERO
	is_sprinting = speed == sprint_speed
	can_sprint = not regen_stamina and stamina > 0
	regen_stamina = not can_sprint and stamina < max_stamina
	
	#Activate sprint
	if Input.is_action_just_pressed("sprint") and can_sprint:
		speed = sprint_speed
	if Input.is_action_just_released("sprint"):
		speed = walk_speed
	
	#Drain stamina if sprinting
	if is_moving and is_sprinting and can_sprint:
		stamina -= stamina_drain * delta
	
	#Regen stamina if stamina isn't full (doesn't stop strinting)
	if not is_sprinting and can_sprint and stamina < max_stamina:
		stamina += stamina_regen * delta
	
	#Regen stamina if fully drained (stops strinting)
	if regen_stamina:
		stamina += stamina_exhausted_regen * delta
	
	#Set speed back to walk speed
	if not can_sprint:
		speed = walk_speed
	
	#Set animation speed
	if is_sprinting:
		$Sprite2D.speed_scale = 3
	else:
		$Sprite2D.speed_scale = 1
	
	#Walk animation state
	if not dir == Vector2.ZERO:
		$Sprite2D.play("walk")
	else:
		$Sprite2D.stop()
	if is_rolling:
		$Sprite2D.stop()
	
	#Activate roll
	if Input.is_action_just_pressed("roll") and not is_rolling and can_roll:
		roll_target = $Camera2D.get_global_mouse_position()
		roll_dir = roll_target - position
		roll_dir = roll_dir.normalized()
		is_rolling = true
		can_roll = false
	
	#Flip sprite and rotation based on movement direction
	if linear_velocity.x < 0:
		$Sprite2D.flip_h = true
	elif linear_velocity.x > 0:
		$Sprite2D.flip_h = false
	
	#Flip sprite and rotation based on roll direction
	if is_rolling:
		if roll_dir.x < 0:
			$Sprite2D.flip_h = true
			rspeed = -roll_rot_speed
		elif roll_dir.x > 0:
			$Sprite2D.flip_h = false
			rspeed = roll_rot_speed
	
	#Finish roll and start cool down
	#Had to change this since _process updates before _physics_process thus if rotation = 0
	#	and triggering this at the wrong time.
	if ($Sprite2D.rotation_degrees >= 360 or $Sprite2D.rotation_degrees <= -360) and is_rolling:
		$Sprite2D.rotation = 0
		roll_cooldown.start()
		is_rolling = false 
	
	if not health > 0:
		queue_free() #change this later
	
	#Update the UI here
	health_bar.value = (health / max_health) * 100
	stamina_bar.value = (stamina / max_stamina) * 100
	if can_sprint:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_norm_color
	else:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_exh_color
	
	roll_cooldown_bar.value = (1 - (roll_cooldown.time_left / roll_cooldown.wait_time)) * 100
	roll_cooldown_bar.visible = roll_cooldown.time_left > 0

func _physics_process(delta: float) -> void:
	#Move player
	if not is_rolling:
		dir = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	else:
		dir = Vector2.ZERO #Don't move when rolling
	linear_velocity = dir * speed * 1000 * delta;
	
	#Roll logic
	if is_rolling:
		$Sprite2D.rotation += rspeed * delta
		apply_impulse(roll_dir * roll_speed * 1000 * delta)

func _on_roll_cooldown_timeout() -> void:
	can_roll = true
