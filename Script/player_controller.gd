extends RigidBody2D

@export var snail_slime: PackedScene
@export var default_shell: PackedScene

@onready var camera : Camera2D = %Camera2D
@onready var sprite : AnimatedSprite2D = %Sprite2D
@onready var shadow : Sprite2D = %Shadow
@onready var shell : Node2D = %Shell
@onready var collShape : CollisionPolygon2D = %CollisionShape2D
@onready var rot_point : Node2D = %RotPoint
@onready var eyes : Array[Marker2D] = [%Eye_1, %Eye_2]

@onready var roll_cooldown : Timer = %roll_cooldown
@onready var boostTimer : Timer = %speedTimer

@onready var health_bar : TextureRect = %HealthBar
@onready var stamina_bar : ProgressBar = %StaminaBar
@onready var roll_cooldown_bar : ProgressBar = %RollCooldownBar

@onready var fpsTxt : Label = %FPS
@onready var daysTxt : Label = %Days
@onready var moneyTxt : Label = %Money

@onready var ui : CanvasLayer = %UI
@onready var Inventory_UI : CanvasLayer = %inventoryUI
@onready var Pickup_Node : Control = %pickup
@onready var Inventory_Node : Control = %inventory
@onready var pauseMenu : CanvasLayer = %pauseMenu
@onready var deathScreen : CanvasLayer = %deathMenu

var pStats : stats = Global.playerStats

@export_category("Stats")
@export var health : float = pStats.max_health
@export var stamina : float = pStats.max_stamina

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
var speed : float = pStats.walk_speed

var roll_state : int = 0 #0: not rolling, 1: start roll, 2: roll logic, 3: end roll

var rspeed : float = pStats.roll_speed
var roll_target : Vector2 = Vector2.ZERO
var roll_dir : Vector2 = Vector2.ZERO

var knockbackVelocity : Vector2 = Vector2.ZERO

var bounds : CollisionPolygon2D = null

var weapSys : WeaponSys = WeaponSys.new()
var defaultEyePos : Array[Vector2] = []

var placeLatch : bool = false

var dialogueT : float = 0

var inventoryState : int = 0

var ogScale : Vector2 = Vector2.ONE

var oldArmor : ArmorItem = null

func _ready():
	ui.visible = true
	Inventory_UI.visible = false
	pauseMenu.visible = false
	deathScreen.visible = false
	Global.inventoryUI = Inventory_Node
	
	ogScale = sprite.scale
	
	var boundsChk = get_tree().get_nodes_in_group("Bounds")
	if not boundsChk.is_empty(): bounds = boundsChk[0].get_node_or_null("CollisionPolygon2D")
	
	#init spawnPos array with correct size
	weapSys.spawnPos.resize(eyes.size())
	
	#Store start local positions
	for i in eyes: defaultEyePos.append(i.position)
	
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
		
		var topLeft = bounds.to_global(Vector2(minX, minY))
		var bottomRight = bounds.to_global(Vector2(maxX, maxY))
		
		camera.limit_left = int(topLeft.x)
		camera.limit_top = int(topLeft.y)
		camera.limit_right = int(bottomRight.x)
		camera.limit_bottom = int(bottomRight.y)

func calc_defense() -> float:
	var result : float = pStats.base_defense
	if Global.armor: result + Global.armor.defense
	return result

func take_damage(data: Dictionary, attacker: Node):
	if not is_rolling and not get_tree().paused:
		health -= data.value * (100 / (100 + calc_defense()))
		Global.damageAnim(sprite, data.value, ogScale)
		Global.damNumbers(collShape, data)

func _process(delta: float) -> void:
	fpsTxt.text = "FPS: " + str(Engine.get_frames_per_second())
	anim = sprite.animation
	
	#Clamp health
	health = clamp(health, 0, pStats.max_health)
	is_dead = not health > 0
	deathScreen.visible = is_dead
	
	if is_dead:
		if not played_death_anim:
			sprite.call_deferred("play", "death")
			played_death_anim = true
		rot_point.rotation = 0
		roll_cooldown.stop()
		is_rolling = false 
		roll_state = 0
		Inventory_UI.visible = false
	else:
		played_death_anim = false
	
	#Movement check
	is_moving = not dir == Vector2.ZERO
	is_sprinting = speed == pStats.sprint_speed
	can_sprint = not regen_stamina and stamina > 0
	regen_stamina = not can_sprint and stamina < pStats.max_stamina
	roll_state =  roll_state % 4
	
	#Is in dialogue
	var inDialogue : bool = false
	var dialChk : Array[Node] = get_tree().get_nodes_in_group("dialogue")
	
	#Added delay to stop activating weapons during last mouse click in dialogue
	if dialChk.size() > 0:
		inDialogue = true
		dialogueT = 0
	else:
		if dialogueT < 1:
			inDialogue = true
			dialogueT += 1 * delta
		else:
			inDialogue = false
	
	#Activate sprint
	if Input.is_action_pressed("sprint") and can_sprint and is_moving:
		speed = pStats.sprint_speed
	if Input.is_action_just_released("sprint") or not is_moving:
		speed = pStats.walk_speed
	
	if not get_tree().paused:
		roll_cooldown.paused = false
		Global.messageTimer.paused = false
		
		#Drain stamina if sprinting
		if is_moving and is_sprinting and can_sprint:
			stamina -= pStats.stamina_drain * delta
		
		#Regen stamina if stamina isn't full (doesn't stop strinting)
		if not is_sprinting and can_sprint and stamina < pStats.max_stamina:
			stamina += pStats.stamina_regen * delta
		
		#Regen stamina if fully drained (stops strinting)
		if regen_stamina:
			stamina += pStats.stamina_exhausted_regen * delta
		
		#Set speed back to walk speed
		if not can_sprint:
			speed = pStats.walk_speed
		
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
			
		#speed boost timer
		pStats.mod_speed = max(0, pStats.mod_speed)
		if pStats.mod_speed != 0 and boostTimer.is_stopped(): boostTimer.start()
		
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
		var flipChck : float = linear_velocity.x - knockbackVelocity.x
		if flipChck < -0.01:
			rot_point.scale.x = -1
		elif flipChck > 0.01:
			rot_point.scale.x = 1
		
		#Flip sprite and rotation based on roll direction
		if is_rolling:
			if roll_dir.x < 0:
				rspeed = -pStats.roll_rot_speed
				rot_point.scale.x = -1
			elif roll_dir.x > 0:
				rspeed = pStats.roll_rot_speed
				rot_point.scale.x = 1
		
		if rot_point.scale.x == -1:
			collShape.position.x = 1.5
		else:
			collShape.position.x = -1.5
		
		#Finish roll and start cool down
		#Had to change this since _process updates before _physics_process thus if rotation = 0
		#	and triggering this at the wrong time.
		if (rot_point.rotation_degrees >= 360 or rot_point.rotation_degrees <= -360) and is_rolling:
			rot_point.rotation = 0
			roll_cooldown.start()
			is_rolling = false 
			roll_state += 1
		
		#Particles
		if is_moving:
			var trail : Sprite2D = snail_slime.instantiate()
			Global.currentScene.add_child(trail) 
			trail.global_position = global_position + Vector2(0, 10)
	else:
		sprite.pause()
		roll_cooldown.paused = true
		Global.messageTimer.paused = true
	
	weapSys.parentNode = self
	weapSys.posOffset = Vector2(0, 5)
	weapSys.rotOffset = rot_point.rotation
	for i in eyes:
		var index : int = eyes.find(i)
		weapSys.spawnPos[index] = i
	weapSys.weapon = Global.weapon if not is_dead else null
	weapSys.update(delta, get_global_mouse_position())
	if not get_tree().paused and not Input.is_action_pressed("place") \
	and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
	and not weapSys.isAttacking and not inDialogue:
		weapSys.attack()
	
	#Armor
	if shell.get_child_count() > 0:
		if not Global.armor:
			for c in shell.get_children():
				if c.is_in_group("default_shell"): continue
				c.queue_free()
			
			oldArmor = null
		
		if oldArmor != Global.armor:
			for c in shell.get_children():
				c.queue_free()
	
	if Global.armor and shell.get_child_count() == 0:
		oldArmor = Global.armor
		var newArmor = Global.armor.armorScene.instantiate()
		shell.add_child(newArmor)
	
	if not Global.armor and shell.get_child_count() == 0:
		var newArmor = default_shell.instantiate()
		shell.add_child(newArmor)
	
	#Place item
	if Global.weapon and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
	and Input.is_action_pressed("place") and not placeLatch and not inDialogue:
		Global.weapon.place(get_global_mouse_position())
		placeLatch = true
	
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not Input.is_action_pressed("place"):
		placeLatch = false
	
	#Update the UI here
	var maxHBSize : float = health_bar.texture.get_width() * 5
	health_bar.size.x = (health / pStats.max_health) * maxHBSize
	stamina_bar.value = (stamina / pStats.max_stamina) * 100
	if can_sprint:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_norm_color
	else:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_exh_color
	
	roll_cooldown_bar.value = (1 - (roll_cooldown.time_left / roll_cooldown.wait_time)) * 100
	roll_cooldown_bar.visible = roll_cooldown.time_left > 0
	
	if Global.sceneIndex == 0:
		daysTxt.text = "Days: " + str(Global.totalDays)
	else:
		daysTxt.text = "Days: " + str(Global.runDays)
	
	moneyTxt.text = "$" + str(Global.money)
	
	var dbck : CanvasLayer = get_node_or_null("debugMenu")
	
	#pause menu 
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = !get_tree().paused
		if not Inventory_UI.visible and not dbck:
			pauseMenu.visible = !pauseMenu.visible
		else:
			Inventory_UI.visible = false
			if dbck: dbck.queue_free()
	
	if not is_dead:
		if Inventory_UI.visible:
			match inventoryState:
				0:
					Inventory_Node.visible = true
					Pickup_Node.visible = false
				1:
					Inventory_Node.visible = false
					Pickup_Node.visible = true
		
		#inventory menu
		if Input.is_action_just_pressed("inventory") and not pauseMenu.visible and not dbck \
		 and not inDialogue:
			if inventoryState != 0 or not Inventory_UI.visible: Inventory_Node.gen_inventory()
			if inventoryState == 0 or not Inventory_UI.visible: 
				Inventory_UI.visible = !Inventory_UI.visible
				get_tree().paused = !get_tree().paused
			inventoryState = 0
		
		#pickup menu
		if Input.is_action_just_pressed("pickup") and not pauseMenu.visible and not dbck \
		 and not inDialogue:
			if inventoryState == 1 or not Inventory_UI.visible: 
				Inventory_Node.visible = false
				Inventory_UI.visible = !Inventory_UI.visible
				get_tree().paused = !get_tree().paused
			inventoryState = 1
		
		#debug menu
		if Input.is_action_just_pressed("debug") and not pauseMenu.visible and not Inventory_UI.visible \
		 and not inDialogue:
			if not dbck:
				var dbmenu : CanvasLayer = load("res://Assets/prefabs/ui/debug.tscn").instantiate()
				dbmenu.name = "debugMenu"
				add_child(dbmenu)
			else:
				dbck.queue_free()
			get_tree().paused = !get_tree().paused

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		#Move player
		if not is_rolling and roll_state == 0 and not is_dead:
			dir = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
		else:
			dir = Vector2.ZERO #Don't move when rolling
		knockbackVelocity = knockbackVelocity.limit_length(Global.MAX_KNOCKBACK)
		linear_velocity = (dir * (speed + pStats.mod_speed) * 1000 * delta) + knockbackVelocity;
		knockbackVelocity *= pow(Global.KNOCKBACK_DECAY, delta)
		
		#Roll logic
		if is_rolling and roll_state != 1:
			rot_point.rotation += rspeed * delta
			apply_impulse(roll_dir * pStats.roll_speed * 1000 * delta)

func _on_roll_cooldown_timeout() -> void:
	can_roll = true

func _on_sprite_2d_animation_finished() -> void:
	if anim == "start_roll" or anim == "end_roll":
		roll_state += 1

func _on_message_timer_timeout() -> void:
	var ms : Array[Node] = Global.messageBox.get_children()
	if not ms.is_empty(): ms[0].queue_free()

func _on_speed_timer_timeout() -> void:
	pStats.mod_speed -= 5

func _on_left_button_down() -> void:
	if inventoryState > 0:
		inventoryState = max(1 - inventoryState, 0)
	else:
		inventoryState = 1
	if inventoryState == 0: Inventory_Node.gen_inventory()

func _on_right_button_down() -> void:
	if inventoryState < 1:
		inventoryState = max(1 + inventoryState, 1)
	else:
		inventoryState = 0
	if inventoryState == 0: Inventory_Node.gen_inventory()

func _on_sprite_2d_frame_changed() -> void:
	var fIndex : int = sprite.frame
		
	match sprite.animation:
		"walk":
			shell.position.x = -8
			
			#Move eyes with the walk animation
			var offset = fIndex
			if fIndex > 4: offset = 8 - fIndex
			
			for i in eyes:
				var index : int = eyes.find(i)
				i.position.x = defaultEyePos[index].x + offset
		"start_roll":
			if fIndex < 6: shell.position.x = -8
			if fIndex == 6: shell.position.x = -7
			if fIndex == 7: shell.position.x = -4
			if fIndex == 8: shell.position.x = -2
		"roll":
			shell.position.x = 0
		"end_roll":
			if fIndex == 0: shell.position.x = -2
			if fIndex == 1: shell.position.x = -4
			if fIndex == 2: shell.position.x = -7
			if fIndex > 2: shell.position.x = -8
