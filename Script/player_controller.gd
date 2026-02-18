extends RigidBody2D

@onready var sprite : AnimatedSprite2D = $RotPoint/Sprite2D
@onready var rot_point : Node2D = $RotPoint
@onready var health_bar : TextureRect = $UI/HealthBar
@onready var stamina_bar : ProgressBar = $UI/StaminaBar
@onready var roll_cooldown_bar : ProgressBar = $UI/RollCooldownBar
@onready var roll_cooldown : Timer = $roll_cooldown
@onready var left_grass : GPUParticles2D = $leftGrass
@onready var right_grass : GPUParticles2D = $rightGrass
@onready var Inventory_UI : CanvasLayer = $inventoryUI
@onready var camera : Camera2D = $Camera2D
@onready var pauseMenu : CanvasLayer = $pauseMenu
@onready var deathScreen : CanvasLayer = $deathMenu
@onready var weaponPivot : Node2D = $RotPoint/WeaponRotPoint/WeaponPivot
@onready var weaponRot : Node2D = $RotPoint/WeaponRotPoint
@onready var weaponAnim : AnimationPlayer = $Weapon

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

var is_dead : bool = false
var played_death_anim : bool = false

var dir : Vector2 = Vector2.ZERO
var speed : float = walk_speed

var roll_state : int = 0 #0: not rolling, 1: start roll, 2: roll logic, 3: end roll

var rspeed : float = roll_speed
var roll_target : Vector2 = Vector2.ZERO
var roll_dir : Vector2 = Vector2.ZERO

var bounds : CollisionPolygon2D = null

var oldWeapon : WeaponItem = null

func _ready():
	$UI.visible = true
	Inventory_UI.visible = false
	pauseMenu.visible = false
	deathScreen.visible = false
	Global.inventoryUI = $inventoryUI/inventory
	
	var boundsChk = get_tree().get_nodes_in_group("Bounds")
	if not boundsChk.is_empty(): bounds = boundsChk[0].get_node_or_null("CollisionPolygon2D")
	
	if bounds:
		var minX = INF
		var maxX = -INF
		var minY = INF
		var maxY = -INF
		
		for p in bounds.polygon:
			minX = min(minX, p.x)
			maxX = max(maxX, p.x)
			minY = min(minY, p.y)
			maxY = max(maxY, p.y)
		
		var topLeft = Vector2(minX, minY)
		var bottomRight = Vector2(maxX, maxY)
		
		camera.limit_left = int(topLeft.x)
		camera.limit_top = int(topLeft.y)
		camera.limit_right = int(bottomRight.x)
		camera.limit_bottom = int(bottomRight.y)

func take_damage(data: Dictionary):
	if not is_rolling and not get_tree().paused:
		health -= data.value

func _process(delta: float) -> void:
	$UI/FPS.text = "FPS: " + str(Engine.get_frames_per_second())
	anim = sprite.animation
	
	#Clamp health
	health = clamp(health, 0, max_health)
	is_dead = not health > 0
	deathScreen.visible = is_dead
	
	if is_dead:
		if not played_death_anim:
			sprite.call_deferred("play", "death")
			played_death_anim = true
		$Shadow.visible = sprite.frame < sprite.sprite_frames.get_frame_count("death") - 1
		rot_point.rotation = 0
		roll_cooldown.stop()
		is_rolling = false 
		roll_state = 0
		Inventory_UI.visible = false
	else:
		played_death_anim = false
	
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
		Global.messageTimer.paused = false
		
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
			if anim == "walk": sprite.stop()
		
		#Roll animation state
		match roll_state:
			0:
				if anim != "walk" and not is_dead: sprite.animation = "walk"
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
		if Input.is_action_just_pressed("roll") and not is_rolling and can_roll and not is_dead:
			roll_target = camera.get_global_mouse_position()
			roll_dir = roll_target - position
			roll_dir = roll_dir.normalized()
			is_rolling = true
			can_roll = false
			roll_state += 1
		
		#Flip sprite and rotation based on movement direction
		if linear_velocity.x < 0:
			rot_point.scale.x = -1
		elif linear_velocity.x > 0:
			rot_point.scale.x = 1
		
		#Flip sprite and rotation based on roll direction
		if is_rolling:
			if roll_dir.x < 0:
				rspeed = -roll_rot_speed
				rot_point.scale.x = -1
			elif roll_dir.x > 0:
				rspeed = roll_rot_speed
				rot_point.scale.x = 1
		
		if rot_point.scale.x == -1:
			$CollisionShape2D.position.x = 1.5
		else:
			$CollisionShape2D.position.x = -1.5
		
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
			left_grass.emitting = not rot_point.scale.x == -1
			right_grass.emitting = rot_point.scale.x == -1
			left_grass.visible = not rot_point.scale.x == -1
			right_grass.visible = rot_point.scale.x == -1
		else:
			left_grass.emitting = false
			right_grass.emitting = false
			left_grass.visible = false
			right_grass.visible = false
	else:
		sprite.pause()
		roll_cooldown.paused = true
		left_grass.visible = false
		right_grass.visible = false
		Global.messageTimer.paused = true
	
	#Weapon stuff
	var hasWeapon = weaponPivot.get_child_count() > 0
	
	if Global.weapon and not oldWeapon == Global.weapon:
		oldWeapon = Global.weapon
		if hasWeapon: weaponPivot.get_children()[0].queue_free()
		
		var newWeapon : Node2D = Global.weapon.weaponScene.instantiate()
		newWeapon.name = "weapon"
		newWeapon.animPlayer = $Weapon
		newWeapon.sprite = sprite
		newWeapon.entity = self
		newWeapon.weapon = Global.weapon
		
		weaponPivot.add_child(newWeapon)
	
	if not Global.weapon and hasWeapon:
		weaponPivot.get_children()[0].queue_free()
		oldWeapon = null
	
	if hasWeapon and not get_tree().paused:
		var wAngle : float = (get_global_mouse_position() - global_position).angle()
		weaponRot.rotation = wAngle if not rot_point.scale.x == -1 else -wAngle + deg_to_rad(180)
		
		var atEnd : bool = weaponAnim.current_animation_position == weaponAnim.current_animation_length
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not weaponAnim.is_playing():
			if Global.weapon.animString == "swing":
				if not atEnd:
					weaponAnim.play(Global.weapon.animString)
				else:
					weaponAnim.play_backwards(Global.weapon.animString)
			else:
				weaponAnim.play(Global.weapon.animString)
	
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
	
	if Input.is_action_just_pressed("inventory") and not pauseMenu.visible and not is_dead:
		Global.inventoryUI.gen_inventory()
		Inventory_UI.visible = !Inventory_UI.visible
		get_tree().paused = !get_tree().paused
	
	#pause menu 
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = !get_tree().paused
		pauseMenu.visible = !pauseMenu.visible

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		#Move player
		if not is_rolling and roll_state == 0 and not is_dead:
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

func _on_message_timer_timeout() -> void:
	var ms : Array[Node] = Global.messageBox.get_children()
	if not ms.is_empty(): ms[0].queue_free()
