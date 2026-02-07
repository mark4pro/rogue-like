extends RigidBody2D

@onready var sprite : AnimatedSprite2D = $RotPoint/Sprite2D
@onready var rot_point : Node2D = $RotPoint
@onready var health_bar : TextureRect = $UI/HealthBar
@onready var stamina_bar : ProgressBar = $UI/StaminaBar
@onready var roll_cooldown_bar : ProgressBar = $UI/RollCooldownBar
@onready var roll_cooldown : Timer = $roll_cooldown
@onready var left_grass : GPUParticles2D = $leftGrass
@onready var right_grass : GPUParticles2D = $rightGrass
@onready var Inventory_UI : CanvasLayer = $InventoryUI

@export_category("Stats")
@export var max_health : float = 100
@export var health : float = max_health
@export var max_stamina : float = 100
@export var stamina : float = max_stamina
@export var stamina_regen : float = 5
@export var stamina_exhausted_regen : float = 15
@export var stamina_drain : float = 25

@export_category("Movement")
@export var sprint_speed : float = 15
@export var walk_speed : float = 7
@export var roll_speed : float = 10
@export var roll_rot_speed : float = 7

@export_category("UI")
@export var stamina_norm_color : Color
@export var stamina_exh_color : Color

var anim : String = ""

var regen_stamina : bool = false
var can_sprint : bool = true
var is_rolling : bool = false
var can_roll : bool = true
var is_moving : bool = false
var is_sprinting : bool = false

var dir : Vector2 = Vector2.ZERO
var speed : float = walk_speed

var roll_state : int = 0 #0: not rolling, 1: start roll, 2: roll logic, 3: end roll

var rspeed : float = roll_speed
var roll_target : Vector2 = Vector2.ZERO
var roll_dir : Vector2 = Vector2.ZERO

func _ready():
	Inventory_UI.visible = false
	Global.set_player_reference(self)

func take_damage(amount: float):
	if not is_rolling and not get_tree().paused:
		health -= amount

func _process(delta: float) -> void:
	anim = sprite.animation
	#Clamp health
	health = clamp(health, 0, max_health)
	
	#Movement check
	is_moving = not dir == Vector2.ZERO
	is_sprinting = speed == sprint_speed
	can_sprint = not regen_stamina and stamina > 0
	regen_stamina = not can_sprint and stamina < max_stamina
	roll_state =  roll_state % 4
	
	#Activate sprint
	if Input.is_action_pressed("sprint") and can_sprint and is_moving:
		speed = sprint_speed
	if Input.is_action_just_released("sprint") or not is_moving:
		speed = walk_speed
	
	if not get_tree().paused:
		roll_cooldown.paused = false
		
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
			sprite.speed_scale = 3
		else:
			sprite.speed_scale = 1
		
		#Walk animation state
		if not dir == Vector2.ZERO:
			sprite.play("walk")
		else:
			if anim == "walk":
				sprite.stop()
		
		#Roll animation state
		match roll_state:
			0:
				if anim != "walk": sprite.animation = "walk"
			1:
				if anim != "start_roll": sprite.play("start_roll")
				if not sprite.is_playing(): sprite.play("start_roll")
			2:
				if anim != "roll": sprite.play("roll")
				if not sprite.is_playing(): sprite.play("roll")
			3:
				if anim != "end_roll": sprite.play("end_roll")
				if not sprite.is_playing(): sprite.play("end_roll")
		
		#Activate roll
		if Input.is_action_just_pressed("roll") and not is_rolling and can_roll:
			roll_target = $Camera2D.get_global_mouse_position()
			roll_dir = roll_target - position
			roll_dir = roll_dir.normalized()
			is_rolling = true
			can_roll = false
			roll_state += 1
		
		#Flip sprite and rotation based on movement direction
		if linear_velocity.x < 0:
			sprite.flip_h = true
		elif linear_velocity.x > 0:
			sprite.flip_h = false
		
		#Flip sprite and rotation based on roll direction
		if is_rolling:
			if roll_dir.x < 0:
				sprite.flip_h = true
				rspeed = -roll_rot_speed
			elif roll_dir.x > 0:
				sprite.flip_h = false
				rspeed = roll_rot_speed
	
		#Finish roll and start cool down
		#Had to change this since _process updates before _physics_process thus if rotation = 0
		#	and triggering this at the wrong time.
		if (rot_point.rotation_degrees >= 360 or rot_point.rotation_degrees <= -360) and is_rolling:
			rot_point.rotation = 0
			roll_cooldown.start()
			is_rolling = false 
			roll_state += 1
		
		#Particles
		if is_moving and not is_rolling:
			left_grass.emitting = not sprite.flip_h
			right_grass.emitting = sprite.flip_h
			left_grass.visible = not sprite.flip_h
			right_grass.visible = sprite.flip_h
		else:
			left_grass.emitting = false
			right_grass.emitting = false
			left_grass.visible = false
			right_grass.visible = false
		
		#Death
		if not health > 0:
			queue_free() #change this later
	else:
		sprite.pause()
		roll_cooldown.paused = true
		left_grass.visible = false
		right_grass.visible = false
	
	#Update the UI here
	var maxHBSize : float = health_bar.texture.get_width() * 5
	health_bar.size.x = (health / max_health) * maxHBSize
	stamina_bar.value = (stamina / max_stamina) * 100
	if can_sprint:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_norm_color
	else:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_exh_color
	
	roll_cooldown_bar.value = (1 - (roll_cooldown.time_left / roll_cooldown.wait_time)) * 100
	roll_cooldown_bar.visible = roll_cooldown.time_left > 0
	
	if Input.is_action_just_pressed("inventory"):
		Inventory_UI.visible = !Inventory_UI.visible
		get_tree().paused = !get_tree().paused
	
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = !get_tree().paused

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		#Move player
		if not is_rolling and roll_state == 0:
			dir = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
		else:
			dir = Vector2.ZERO #Don't move when rolling
		linear_velocity = dir * speed * 1000 * delta;
		
		#Roll logic
		if is_rolling and roll_state != 1:
			rot_point.rotation += rspeed * delta
			apply_impulse(roll_dir * roll_speed * 1000 * delta)

func _on_roll_cooldown_timeout() -> void:
	can_roll = true

func _on_sprite_2d_animation_finished() -> void:
	if anim == "start_roll" or anim == "end_roll":
		roll_state += 1
