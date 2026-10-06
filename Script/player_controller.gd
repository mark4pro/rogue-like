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

@onready var messageBox : VBoxContainer = %MessageBox
@onready var messageTimer : Timer = %MessageTimer

var pStats : stats = Global.playerStats

@export_category("Stats")
@export var health : float = pStats.maxHealth()
@export var stamina : float = pStats.maxStamina()
@export var mana : float = pStats.maxMana()

@export_category("UI")
@export var stamina_norm_color : Color
@export var stamina_exh_color : Color
@export var mana_color : Color = Color(0.22, 0.45, 0.95)
## Bar colour flashed when an attack can't be paid for (the "fizzle")
@export var pool_fizzle_color : Color = Color(0.85, 0.2, 0.2)

var mana_bar : ProgressBar = null
var characterNode : CharacterScreen = null # third inventory page (state 2)
var manaRegenWait : float = 0
var poolFlash : Array[float] = [0.0, 0.0] # indexed by WeaponItem.poolType

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
var speed : float = pStats.walkSpeed()

var roll_state : int = 0 #0: not rolling, 1: start roll, 2: roll logic, 3: end roll

var rspeed : float = pStats.rollSpeed()
var roll_target : Vector2 = Vector2.ZERO
var roll_dir : Vector2 = Vector2.ZERO

var knockbackVelocity : Vector2 = Vector2.ZERO
# Knockback rework (see Knockback): heavier = pushed less; hitstun blocks moving/attacking;
# slamArmed is set by a knockback hit so hitting a wall right after deals slam damage
var knockbackWeight : float = 1.0
var hitstun : float = 0.0
var slamArmed : bool = false
var slamAttacker : Node = null

var bounds : CollisionPolygon2D = null

var weapSys : WeaponSys = WeaponSys.new()
var defaultEyePos : Array[Vector2] = []

var placeLatch : bool = false

var dialogueT : float = 0

var inventoryState : int = 0

var ogScale : Vector2 = Vector2.ONE

var oldArmor : ArmorItem = null

var slimeTrail : SlimeTrail = null

# Active heal/restore-over-time effects from potions: {stat, rate (per sec), time (sec left)}
var regenEffects : Array[Dictionary] = []

func _ready():
	ui.visible = true
	Inventory_UI.visible = false
	pauseMenu.visible = false
	deathScreen.visible = false
	Global.inventoryUI = Inventory_Node
	
	ogScale = sprite.scale
	
	buildManaBar()
	
	characterNode = CharacterScreen.new()
	characterNode.name = "character"
	characterNode.visible = false
	Inventory_UI.add_child(characterNode)
	Inventory_UI.move_child(characterNode, Pickup_Node.get_index() + 1) # under the < > buttons
	
	# Wall slam detection needs contact reports
	contact_monitor = true
	max_contacts_reported = 4
	roll_cooldown.wait_time = pStats.rollCooldown()
	
	statusFx = StatusEffects.new(self)
	buildBlindOverlay()
	
	var boundsChk = get_tree().get_nodes_in_group("Bounds")
	if not boundsChk.is_empty(): bounds = boundsChk[0].get_node_or_null("CollisionPolygon2D")
	
	#init spawnPos array with correct size
	weapSys.spawnPos.resize(eyes.size())
	
	#Store start local positions
	for i in eyes:
		defaultEyePos.append(i.position)
	
	if bounds:
		var minX : float = INF
		var maxX : float = -INF
		var minY : float = INF
		var maxY : float = -INF
		
		for p in bounds.polygon:
			minX = min(minX, p.x)
			maxX = max(maxX, p.x)
			minY = min(minY, p.y)
			maxY = max(maxY, p.y)
		
		var topLeft : Vector2 = bounds.to_global(Vector2(minX, minY))
		var bottomRight : Vector2 = bounds.to_global(Vector2(maxX, maxY))
		
		camera.limit_left = int(topLeft.x)
		camera.limit_top = int(topLeft.y)
		camera.limit_right = int(bottomRight.x)
		camera.limit_bottom = int(bottomRight.y)

# The Shell node sits under Offset (0.5, 0.5), which lines up odd-sized shells (15x13) with the
# body's pixels. An even-sized shell (16 wide) would land half a pixel off, so shift it back
# by half a pixel on that axis. +0.5 on x keeps its back (left) edge where the 15x13 shells' is.
func snapShellToPixels(armor: Node) -> void:
	var s : Sprite2D = armor as Sprite2D
	if not s or not s.texture or not s.centered:
		return
	var size : Vector2 = s.texture.get_size()
	if s.region_enabled:
		size = s.region_rect.size
	size /= Vector2(s.hframes, s.vframes)
	s.offset = Vector2(
		0.5 if int(size.x) % 2 == 0 else 0.0,
		-0.5 if int(size.y) % 2 == 0 else 0.0
	)

func calc_defense() -> float:
	var result : float = pStats.base_defense
	
	if Global.armor:
		result += Global.armor.defense * pStats.armorEfficiency() # Vitality: up to 150% of armour defence
	
	return result

# The mana bar is a copy of the stamina bar stacked right above it; the roll bar and FPS
# label move up to make room.
func buildManaBar() -> void:
	mana_bar = stamina_bar.duplicate()
	mana_bar.name = "ManaBar"
	var barHeight : float = stamina_bar.offset_bottom - stamina_bar.offset_top
	mana_bar.offset_top = stamina_bar.offset_top - barHeight
	mana_bar.offset_bottom = stamina_bar.offset_top
	# The fill style is a shared resource and the stamina bar recolours its own every frame
	mana_bar.add_theme_stylebox_override("fill", stamina_bar.get_theme_stylebox("fill").duplicate())
	mana_bar.add_theme_stylebox_override("background", stamina_bar.get_theme_stylebox("background").duplicate())
	ui.add_child(mana_bar)
	ui.move_child(mana_bar, stamina_bar.get_index() + 1)
	
	for c in [roll_cooldown_bar, fpsTxt]:
		c.offset_top -= barHeight
		c.offset_bottom -= barHeight

# --- Pools (used by WeaponSys) -------------------------------------------------
func hasPool(pool: int, amount: float) -> bool:
	match pool:
		WeaponItem.poolType.STAMINA:
			return can_sprint and stamina >= amount # can_sprint is false while exhausted
		WeaponItem.poolType.MANA:
			return mana >= amount
	return true

# force: spend whatever is there even if it isn't enough (melee swings slowly instead of not at all)
func spendPool(pool: int, amount: float, force: bool = false) -> bool:
	if is_dead: return false
	var paid : bool = hasPool(pool, amount)
	match pool:
		WeaponItem.poolType.STAMINA:
			if paid or force: stamina = max(stamina - amount, 0)
		WeaponItem.poolType.MANA:
			if paid:
				mana -= amount
				manaRegenWait = pStats.mana_regen_delay
	return paid

func poolFizzle(pool: int) -> void:
	if pool >= 0 and pool < poolFlash.size(): poolFlash[pool] = 0.25

# Called by RegenPotionItem. stat: 0 health, 1 stamina, 2 mana. Returns false if it can't apply.
func addRegen(stat: int, amount: float, duration: float) -> bool:
	if is_dead: return false
	duration = max(duration, 0.01)
	regenEffects.append({"stat": stat, "rate": amount / duration, "time": duration})
	return true

func updateRegen(delta: float) -> void:
	if is_dead:
		regenEffects.clear()
		return
	
	for e in regenEffects:
		var step : float = min(delta, e.time)
		e.time -= step
		var gain : float = e.rate * step
		match e.stat:
			RegenPotionItem.regen_stat.HEALTH:
				health = min(health + gain, pStats.maxHealth())
			RegenPotionItem.regen_stat.STAMINA:
				stamina = min(stamina + gain, pStats.maxStamina())
			RegenPotionItem.regen_stat.MANA:
				mana = min(mana + gain, pStats.maxMana())
	
	for i in range(regenEffects.size() - 1, -1, -1):
		if regenEffects[i].time <= 0: regenEffects.remove_at(i)

# --- Knockback (used by Knockback.apply) ----------------------------------------
func getKnockbackResist() -> float:
	var r : float = pStats.knockbackResist()
	if Global.armor: r += Global.armor.getKnockbackResist()
	return minf(r, Knockback.RESIST_CAP)

# Strength: how much harder this player's hits push (used by Knockback.apply)
func knockbackDealtMult() -> float:
	return pStats.knockbackDealtMult()

func applyHitstun(seconds: float) -> void:
	if is_rolling or is_dead: return
	hitstun = maxf(hitstun, seconds)

# --- Elements / status host (used by StatusEffects) -----------------------------
var statusFx : StatusEffects = null
var blindOverlay : TextureRect = null

func getMaxHealth() -> float: return pStats.maxHealth()
func getDefense() -> float: return calc_defense()
func statusResist() -> float: return pStats.statusResist()

# Damage kind or element resistance: armor (rolled) + Vitality's bit of melee resistance
func getResist(key: String) -> float:
	var r : float = Global.armor.getResist(key) if Global.armor else 0.0
	if key == "melee": r += pStats.meleeResistBonus()
	return StatusEffects.clampResist(r)

func buildBlindOverlay() -> void:
	var grad : Gradient = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.95))
	grad.set_offset(0, 0.25)
	grad.set_offset(1, 0.7)
	var tex : GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	blindOverlay = TextureRect.new()
	blindOverlay.name = "BlindOverlay"
	blindOverlay.texture = tex
	blindOverlay.stretch_mode = TextureRect.STRETCH_SCALE
	blindOverlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blindOverlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blindOverlay.modulate.a = 0.0
	ui.add_child(blindOverlay)
	ui.move_child(blindOverlay, 0) # under the HUD

func take_damage(data: Dictionary, attacker: Node):
	if not is_rolling and not get_tree().paused:
		var hit : Dictionary = StatusEffects.resolveHit(data, self)
		health -= hit.total
		var shown : Dictionary = data.duplicate()
		shown.value = hit.total
		var el : String = StatusEffects.dominantElement(hit.elements, hit.total - _sum(hit.elements))
		if el != "" and not shown.has("color"): shown.color = StatusEffects.ELEMENT_COLORS[el]
		Global.damageAnim(sprite, hit.total, ogScale)
		Global.damNumbers(collShape, shown)
		if statusFx:
			for e in hit.elements: statusFx.addBuildup(e, hit.elements[e], data.get("attackerStats"), attacker)

func _sum(d: Dictionary) -> float:
	var t : float = 0.0
	for k in d: t += float(d[k])
	return t

func _process(delta: float) -> void:
	fpsTxt.text = "FPS: " + str(Engine.get_frames_per_second())
	anim = sprite.animation
	
	#Clamp health
	health = clamp(health, 0, pStats.maxHealth())
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
	is_sprinting = speed == pStats.sprintSpeed()
	can_sprint = not regen_stamina and stamina > 0
	regen_stamina = not can_sprint and stamina < pStats.maxStamina()
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
		speed = pStats.sprintSpeed()
	if Input.is_action_just_released("sprint") or not is_moving:
		speed = pStats.walkSpeed()
	
	if not get_tree().paused:
		roll_cooldown.paused = false
		Global.messageTimer.paused = false
		
		#Drain stamina if sprinting
		if is_moving and is_sprinting and can_sprint:
			stamina -= pStats.stamina_drain * delta
		
		#Regen stamina if stamina isn't full (doesn't stop strinting)
		if not is_sprinting and can_sprint and stamina < pStats.maxStamina():
			stamina += pStats.staminaRegen() * delta
		
		#Regen stamina if fully drained (stops strinting)
		if regen_stamina:
			stamina += pStats.exhaustedRegen() * delta
		
		hitstun = maxf(hitstun - delta, 0)
		
		#Status effects (burn, chill, blind...)
		if statusFx and not is_dead:
			statusFx.process(delta)
			if blindOverlay: blindOverlay.modulate.a = statusFx.blindAmount()
		
		#Mana regen (waits a moment after casting)
		if manaRegenWait > 0:
			manaRegenWait -= delta
		elif mana < pStats.maxMana():
			mana = min(mana + pStats.manaRegen() * delta, pStats.maxMana())
		
		for i in range(poolFlash.size()):
			poolFlash[i] = max(poolFlash[i] - delta, 0)
		
		#Potion effects (heal / restore over time)
		updateRegen(delta)
		
		#Set speed back to walk speed
		if not can_sprint:
			speed = pStats.walkSpeed()
		
		#Set animation speed
		if is_sprinting:
			sprite.speed_scale = 3
		else:
			sprite.speed_scale = 1
		# Stamina shortens the curl-up / uncurl animations around a roll
		if roll_state == 1 or roll_state == 3:
			sprite.speed_scale = pStats.rollWindupSpeed()
		
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
		var rollPressed : bool = Input.is_action_just_pressed("roll") and not is_rolling and can_roll \
		and not is_dead and hitstun <= 0
		if rollPressed and not spendPool(WeaponItem.poolType.STAMINA, pStats.rollStaminaCost()):
			poolFizzle(WeaponItem.poolType.STAMINA) # too tired to roll
		elif rollPressed:
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
				rspeed = -pStats.rollRotSpeed()
				rot_point.scale.x = -1
			elif roll_dir.x > 0:
				rspeed = pStats.rollRotSpeed()
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
			roll_cooldown.start(pStats.rollCooldown())
			is_rolling = false 
			roll_state += 1
		
		#Slime trail: one Line2D that grows behind the snail (replaces a fading sprite per frame)
		if is_moving:
			var slimePos : Vector2 = global_position + Vector2(0, 10)
			if not slimeTrail or not is_instance_valid(slimeTrail) or slimeTrail.get_parent() != Global.currentScene \
			or not slimeTrail.extend(slimePos):
				if slimeTrail and is_instance_valid(slimeTrail): slimeTrail.retire()
				slimeTrail = SlimeTrail.new()
				Global.currentScene.add_child(slimeTrail)
				slimeTrail.extend(slimePos)
	else:
		sprite.pause()
		roll_cooldown.paused = true
		Global.messageTimer.paused = true
	
	weapSys.parentNode = self
	weapSys.attackSpeedMult = pStats.attackSpeed()
	weapSys.wielderStats = pStats
	weapSys.trackProficiency = true
	weapSys.posOffset = Vector2(0, 5)
	weapSys.rotOffset = rot_point.rotation
	for i in eyes:
		var index : int = eyes.find(i)
		weapSys.spawnPos[index] = i
	weapSys.weapon = Global.weapon if not is_dead else null
	weapSys.update(delta, get_global_mouse_position())
	if not get_tree().paused and not Input.is_action_pressed("place") \
	and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
	and not weapSys.isAttacking and not inDialogue and hitstun <= 0:
		weapSys.attack()
	# Stunned: beams and held-fire weapons stop (a swing already underway finishes)
	if hitstun > 0 and weapSys.weapon and weapSys.weapon.animationType != WeaponItem.animType.SWING:
		weapSys.isAttacking = false
	
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
		var newArmor : Node = Global.armor.armorScene.instantiate()
		snapShellToPixels(newArmor)
		shell.add_child(newArmor)
	
	if not Global.armor and shell.get_child_count() == 0:
		var newArmor : Node = default_shell.instantiate()
		snapShellToPixels(newArmor)
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
	health_bar.size.x = (health / pStats.maxHealth()) * maxHBSize
	stamina_bar.value = (stamina / pStats.maxStamina()) * 100
	if poolFlash[WeaponItem.poolType.STAMINA] > 0:
		stamina_bar.get_theme_stylebox("fill").bg_color = pool_fizzle_color
	elif can_sprint:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_norm_color
	else:
		stamina_bar.get_theme_stylebox("fill").bg_color = stamina_exh_color
	
	if mana_bar:
		mana = clamp(mana, 0, pStats.maxMana())
		mana_bar.value = (mana / pStats.maxMana()) * 100
		var manaFlash : bool = poolFlash[WeaponItem.poolType.MANA] > 0
		mana_bar.get_theme_stylebox("fill").bg_color = pool_fizzle_color if manaFlash else mana_color
	
	roll_cooldown_bar.value = (1 - (roll_cooldown.time_left / roll_cooldown.wait_time)) * 100
	roll_cooldown_bar.visible = roll_cooldown.time_left > 0
	
	if Global.sceneIndex == 0:
		daysTxt.text = "Days: " + str(Global.totalDays)
	else:
		daysTxt.text = "Days: " + str(Global.runDays)
	
	moneyTxt.text = "$" + str(Global.money)
	
	var dbck : CanvasLayer = get_node_or_null("debugMenu")
	
	#pause menu (the options menu uses Esc itself to close / cancel a rebind)
	if Input.is_action_just_pressed("pause") and Settings.pause_input_free():
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
				2:
					Inventory_Node.visible = false
					Pickup_Node.visible = false
			if characterNode: characterNode.visible = inventoryState == 2
		
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
		
		#character screen (third inventory page)
		if Input.is_action_just_pressed("character") and not pauseMenu.visible and not dbck \
		 and not inDialogue:
			if inventoryState == 2 or not Inventory_UI.visible:
				Inventory_Node.visible = false
				Inventory_UI.visible = !Inventory_UI.visible
				get_tree().paused = !get_tree().paused
			inventoryState = 2
		
		#debug menu
		if Input.is_action_just_pressed("debug") and not pauseMenu.visible and not Inventory_UI.visible \
		 and not inDialogue:
			if not dbck:
				var dbmenu : CanvasLayer = load("uid://vuvv7u5owupe").instantiate()
				dbmenu.name = "debugMenu"
				add_child(dbmenu)
			else:
				dbck.queue_free()
			get_tree().paused = !get_tree().paused

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		#Move player
		if not is_rolling and roll_state == 0 and not is_dead and hitstun <= 0:
			dir = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
		else:
			dir = Vector2.ZERO #Don't move when rolling
		knockbackVelocity = knockbackVelocity.limit_length(Global.MAX_KNOCKBACK)
		var slow : float = statusFx.speedMult() if statusFx else 1.0 # Chill / Sticky
		linear_velocity = (dir * (speed + pStats.mod_speed) * slow * 1000 * delta) + knockbackVelocity;
		knockbackVelocity *= pow(Global.KNOCKBACK_DECAY, delta)
		Knockback.checkSlam(self)
		
		#Roll logic
		if is_rolling and roll_state != 1:
			rot_point.rotation += rspeed * delta
			apply_impulse(roll_dir * pStats.rollSpeed() * 1000 * delta)

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

# Pages: 0 Inventory, 1 Pickup, 2 Character. The arrows cycle through them.
const INVENTORY_PAGES : int = 3

func _on_left_button_down() -> void:
	inventoryState = (inventoryState + INVENTORY_PAGES - 1) % INVENTORY_PAGES
	if inventoryState == 0: Inventory_Node.gen_inventory()

func _on_right_button_down() -> void:
	inventoryState = (inventoryState + 1) % INVENTORY_PAGES
	if inventoryState == 0: Inventory_Node.gen_inventory()

# Where the shell has to sit so its centre is exactly on rot_point (the roll's spin pivot).
# The roll frame of the body is empty, so the shell is all you see spinning; off-centre it wobbles.
func rollShellPos() -> Vector2:
	var kidOffset : Vector2 = Vector2.ZERO
	for c in shell.get_children():
		if c is Sprite2D and not c.is_queued_for_deletion():
			kidOffset = c.offset
			break
	return -(sprite.position + shell.get_parent().position) - kidOffset

const WALK_SHELL_POS : Vector2 = Vector2(-8, 4)

# Slide from the walking spot toward the roll spot in whole pixels (f = 0..1)
func slideShell(f: float) -> void:
	if f >= 1.0:
		shell.position = rollShellPos()
		return
	var target : Vector2 = rollShellPos()
	shell.position = Vector2(roundf(lerpf(WALK_SHELL_POS.x, target.x, f)), WALK_SHELL_POS.y)

func _on_sprite_2d_frame_changed() -> void:
	var fIndex : int = sprite.frame
		
	match sprite.animation:
		"walk":
			shell.position = WALK_SHELL_POS
			
			#Move eyes with the walk animation
			var offset = fIndex
			if fIndex > 4: offset = 8 - fIndex
			
			for i in eyes:
				var index : int = eyes.find(i)
				i.position.x = defaultEyePos[index].x + offset
		"start_roll":
			if fIndex < 6: slideShell(0.0)
			if fIndex == 6: slideShell(0.125)
			if fIndex == 7: slideShell(0.5)
			if fIndex == 8: slideShell(0.75)
		"roll":
			slideShell(1.0)
		"end_roll":
			if fIndex == 0: slideShell(0.75)
			if fIndex == 1: slideShell(0.5)
			if fIndex == 2: slideShell(0.125)
			if fIndex > 2: slideShell(0.0)
