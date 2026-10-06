extends RigidBody2D
class_name SpiderEyeBoss

# The Robotic Spider Eye, the first boss.
#
# Starts BROKEN in a forest clearing: just the eyeball, rolled over, sparking. Evil roaches carry
# scrap to it (BossSite). On the activation run day it WAKES: pushes everything away, smoke + flash,
# legs grow out, and the fight starts. It always knows where the player is (leaps across the map
# toward them when far) and uses:
#   Laser   a beam that tracks you a little slower than you can run
#   Volley  fans of acid eyeballs
#   Slam    jumps, lands on where you were, sends out a shockwave: roll through it or outrun it
# Below half health it attacks faster and slams send out two waves.
#
# The eye is the 3D eyeball from eye.tscn rendered to a texture; only the 3D eye turns to look
# at the player (clamped to max_look_angle), the sprite itself never rotates. The legs are
# 2-bone IK with planted feet that step when the body moves away from them.

signal defeated # BossSite listens so the boss doesn't come back

const EYE_SCENE : PackedScene = preload("res://Assets/prefabs/enemies/test/eye.tscn")
const LEG_TEX : Texture2D = preload("res://Assets/imgs/enemies/testing/eyeball_spider_leg_piece.png")
const GLOW : Texture2D = preload("res://Assets/imgs/Lights/Light_1.png")
const SHADOW_TEX : Texture2D = preload("res://Assets/imgs/effects/shadow.png")

enum State { BROKEN, WAKING, ACTIVE, DEAD }
enum Act { NONE, LASER, VOLLEY, SLAM_WINDUP, SLAM_AIR, RECOVER }

@export var display_name : String = "Robotic Spider Eye"

@export_category("Stats")
## Health at level 1 (scaled by level like other enemies, see EnemySpawner)
@export var base_health : float = 1500.0
@export var base_defense : float = 15.0
@export_range(0.0, 1.0) var status_resist : float = 0.4
@export var resistances : Dictionary = {"laser": 0.3, "acid": 0.4, "shadow": 0.2, "shock": -0.25}
@export var knockbackWeight : float = 8.0
@export_range(0.0, 0.8) var knockbackResist : float = 0.8

@export_category("Body")
@export var eye_scale : float = 0.85
## How high the eye's centre stands above the ground
@export var body_height : float = 32.0
@export var upper_leg : float = 26.0
@export var lower_leg : float = 30.0
@export var leg_reach : float = 52.0
@export var leg_thickness : float = 0.55
@export var step_distance : float = 18.0
@export var step_time : float = 0.14
## How far (degrees) the iris can turn away from facing the screen
@export var max_look_angle : float = 50.0
@export var look_speed : float = 6.0

@export_category("Movement")
@export var walk_speed : float = 34.0
@export var keep_distance : float = 85.0
## Farther than this from the player it leaps toward them instead of walking
@export var hunt_distance : float = 420.0
## The boss bar shows while the player is within this distance
@export var bar_distance : float = 600.0
## Pause between attacks
@export var idle_time : float = 0.9

@export_category("Laser")
@export var laser_weapon : WeaponItem = preload("res://Assets/weapons/spider_laser.tres")
@export var laser_range : float = 190.0
@export var laser_ticks : float = 6.0
@export var laser_damage_mult : float = 2.0
@export var laser_time : float = 2.4
## How quickly the beam swings after you (lower = easier to outrun)
@export var laser_track_speed : float = 2.5

@export_category("Volley")
@export var shot_weapon : WeaponItem = preload("res://Assets/weapons/eyeball.tres")
@export var shots_per_volley : int = 5
@export var shot_spread : float = 70.0
@export var volleys : int = 3
@export var volley_gap : float = 0.55
@export var shot_damage_mult : float = 0.08

@export_category("Body slam")
@export var slam_cooldown : float = 7.0
@export var slam_windup : float = 0.65
@export var slam_air_time : float = 0.75
@export var slam_height : float = 80.0
@export var slam_max_leap : float = 300.0
@export var slam_impact_radius : float = 34.0
@export var slam_impact_damage : float = 20.0
@export var shockwave_damage : float = 12.0
@export var shockwave_speed : float = 260.0
@export var shockwave_radius : float = 170.0
@export var shockwave_thickness : float = 14.0

@export_category("Wake up")
@export var wake_push_radius : float = 200.0
@export var wake_push_force : float = 70.0
## Seconds after waking before its first attack
@export var wake_grace : float = 1.5

@export_category("Rewards")
@export var exp_reward : float = 250.0
@export var money_range : Vector2i = Vector2i(150, 300)
@export var loot_drops : int = 4
@export_range(0.0, 1.0) var loot_rarity_bonus : float = 0.5

var state : int = State.BROKEN
var act : int = Act.NONE
var actT : float = 0.0

var level : int = 1
var maxHealth : float = 1500.0
var health : float = 1500.0
var defense : float = 15.0
var _dmgMult : float = 1.0
var enraged : bool = false

var statusFx : StatusEffects = null
var hitstun : float = 0.0
var knockbackVelocity : Vector2 = Vector2.ZERO

# Nodes
var visual : Node2D = null      # eye + legs, lifted above the ground origin
var legsBack : Node2D = null
var legsFront : Node2D = null
var eye : Sprite2D = null
var sprite : Sprite2D = null    # StatusEffects / StatusVisuals tint this (the eye)
var eye3d : Node3D = null
var shadow : Sprite2D = null
var coll : CollisionShape2D = null
var pupils : Array[Marker2D] = []
var sparks : CPUParticles2D = null
var bar : BossBar = null
var telegraph : Node2D = null

var laserSys : WeaponSys = WeaponSys.new()
var shotSys : WeaponSys = WeaponSys.new()

var legs : Array[Dictionary] = []
var eyeRadius : float = 29.0
var look : Vector3 = Vector3(0, 0, 1)
var lift : float = 0.0
var crouch : float = 0.0
var legGrow : float = 0.0
var repair : float = 0.0
var walk : Vector2 = Vector2.ZERO
var beamTarget : Vector2 = Vector2.ZERO
var slamCD : float = 3.0
var slamFrom : Vector2 = Vector2.ZERO
var slamTo : Vector2 = Vector2.ZERO
var travelLeap : bool = false
var volleyLeft : int = 0
var stateT : float = 0.0
var _shakeX : float = 0.0
var _camShake : float = 0.0
var _sparkT : float = 1.0
var _immuneCD : float = 0.0
var _rewarded : bool = false
var _ogEyeScale : Vector2 = Vector2.ONE

const BROKEN_LOOK : Vector3 = Vector3(0.55, -0.7, 0.45)
const BROKEN_TILT : float = 0.55

#region Setup

func _ready() -> void:
	gravity_scale = 0.0
	lock_rotation = true
	mass = 50.0
	collision_layer = 4  # enemy layer: the player's swords, bullets and lasers hit it
	collision_mask = 0   # steps over walls, trees and everything else
	add_to_group("enemies")
	add_to_group("boss")
	add_to_group("tree_cutout")
	
	eyeRadius = 32.0 * eye_scale * 0.92
	
	shadow = Sprite2D.new()
	shadow.texture = SHADOW_TEX
	shadow.modulate = Color(1, 1, 1, 0.45)
	var sw : float = eyeRadius * 3.0 / float(SHADOW_TEX.get_width())
	shadow.scale = Vector2(sw, sw * 0.32)
	add_child(shadow)
	
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	legsBack = Node2D.new()
	visual.add_child(legsBack)
	
	eye = EYE_SCENE.instantiate()
	eye.name = "Eye"
	eye.scale = Vector2.ONE * eye_scale
	_ogEyeScale = eye.scale
	var area : Node = eye.get_node_or_null("Area2D")
	if area: area.free() # the WIP scene's hit area would block our own lasers
	visual.add_child(eye)
	var vp : SubViewport = eye.get_node("SubViewport")
	vp.own_world_3d = true          # each eye renders only its own sphere
	eye.texture = vp.get_texture()  # per-instance texture (the scene's ViewportTexture is shared)
	eye3d = vp.get_node("Node3D")
	sprite = eye
	
	legsFront = Node2D.new()
	visual.add_child(legsFront)
	
	coll = CollisionShape2D.new()
	var circle : CircleShape2D = CircleShape2D.new()
	circle.radius = eyeRadius
	coll.shape = circle
	add_child(coll)
	
	for i in 2:
		var m : Marker2D = Marker2D.new()
		m.name = "Pupil_%d" % i
		add_child(m)
		pupils.append(m)
	
	_buildLegs()
	_buildSparks()
	
	laserSys.parentNode = self
	laserSys.weapon = laser_weapon.duplicate()
	laserSys.weapon.laserRange = laser_range
	laserSys.weapon.laserAttackSpeed = laser_ticks
	laserSys.spawnPos = [pupils[0]]
	
	shotSys.parentNode = self
	shotSys.weapon = shot_weapon.duplicate()
	shotSys.weapon.rangeSpawnAmount = shots_per_volley
	shotSys.weapon.rangeSpreadAngle = shot_spread
	shotSys.spawnPos = [pupils[0], pupils[1]]
	
	statusFx = StatusEffects.new(self)
	_applyLevel()
	
	look = BROKEN_LOOK.normalized()
	_updateLook(0.0)
	_updateVisual()
	_updateLegs(0.0)

func _buildLegs() -> void:
	# Right side angles (0 = right, 90 = toward the camera), the left side mirrors them
	var right : Array[float] = [-50.0, -15.0, 20.0, 55.0]
	var i : int = 0
	for a in right + right.map(func(x): return 180.0 - x):
		var rad : float = deg_to_rad(a)
		var front : bool = sin(rad) > 0.0
		var upper : Sprite2D = Sprite2D.new()
		var lower : Sprite2D = Sprite2D.new()
		for s in [upper, lower]:
			s.texture = LEG_TEX
			(legsFront if front else legsBack).add_child(s)
		legs.append({
			"angle": rad, "front": front, "group": (i + (1 if i >= 4 else 0)) % 2,
			"foot": global_position, "from": global_position, "to": global_position, "t": -1.0,
			"upper": upper, "lower": lower,
		})
		i += 1

func _buildSparks() -> void:
	sparks = CPUParticles2D.new()
	sparks.amount = 10
	sparks.lifetime = 0.45
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.emitting = false
	sparks.texture = GLOW
	sparks.direction = Vector2.UP
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 220)
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 110.0
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.06
	var g : Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0)])
	sparks.color_ramp = g
	var m : CanvasItemMaterial = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = m
	sparks.position = Vector2(eyeRadius * 0.4, -eyeRadius * 0.3)
	visual.add_child(sparks)

# Level from the day count like normal enemies (EnemySpawner's settings), no random variance
func _applyLevel() -> void:
	level = clampi(1 + int(Global.totalDays * EnemySpawner.level_per_total_day + Global.runDays * EnemySpawner.level_per_run_day), 1, stats.LEVEL_CAP)
	var above : int = level - 1
	maxHealth = base_health * (1.0 + EnemySpawner.health_per_level * above)
	health = maxHealth
	defense = base_defense + EnemySpawner.defense_per_level * above
	_dmgMult = 1.0 + EnemySpawner.damage_per_level * above
	laserSys.damageMult = _dmgMult * laser_damage_mult
	shotSys.damageMult = _dmgMult * shot_damage_mult

#endregion

#region Host interface (StatusEffects, Knockback, weapons)

func getMaxHealth() -> float: return maxHealth
func getDefense() -> float: return defense
func statusResist() -> float: return status_resist
func getResist(key: String) -> float: return StatusEffects.clampResist(float(resistances.get(key, 0.0)))
func getKnockbackResist() -> float: return knockbackResist
func knockbackDealtMult() -> float: return 1.0

# Stuns and freezes only make it stagger briefly
func applyHitstun(seconds: float) -> void:
	if state != State.ACTIVE: return
	hitstun = maxf(hitstun, minf(seconds * 0.35, 0.6))

func take_damage(data: Dictionary, attacker: Node) -> void:
	if get_tree().paused or state == State.DEAD: return
	if state != State.ACTIVE:
		_popup("Immune", Color(0.75, 0.75, 0.75))
		return
	var hit : Dictionary = StatusEffects.resolveHit(data, self)
	health -= hit.total
	var shown : Dictionary = data.duplicate()
	shown.value = hit.total
	var elemTotal : float = 0.0
	for e in hit.elements: elemTotal += hit.elements[e]
	var el : String = StatusEffects.dominantElement(hit.elements, hit.total - elemTotal)
	if el != "" and not shown.has("color"): shown.color = StatusEffects.ELEMENT_COLORS[el]
	Global.damageAnim(eye, hit.total * 0.3, _ogEyeScale)
	Global.damNumbers(coll, shown)
	if statusFx:
		for e in hit.elements: statusFx.addBuildup(e, hit.elements[e], data.get("attackerStats"), attacker)
	if bar: bar.setHealth(health / maxHealth)
	if not enraged and health <= maxHealth * 0.5:
		enraged = true
		Global.sendMessage("The eye is overheating!", 4.0, Color(1.0, 0.45, 0.3))
	if health <= 0.0: _die()

func _popup(text: String, c: Color) -> void:
	if _immuneCD > 0.0 or not Global.damNum or not Global.currentScene: return
	_immuneCD = 0.35
	var l : Label = Global.damNum.instantiate()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", c)
	l.position = visual.global_position + Vector2(randf_range(-8, 8), -eyeRadius)
	Global.currentScene.add_child(l)

#endregion

#region Repair / wake / death (called by BossSite)

# 0..1, how far the roaches have got (the eye sits up a little and sparks less)
func setRepair(p: float) -> void:
	repair = clampf(p, 0.0, 1.0)

# A roach dropped a piece in
func repairPing() -> void:
	if state == State.BROKEN and sparks: sparks.restart()

func wake() -> void:
	if state != State.BROKEN: return
	state = State.WAKING
	stateT = 0.0
	_applyLevel()
	_smokeBurst(48, 1.0)
	if Global.player and Global.player.global_position.distance_to(global_position) < 900.0:
		_flash()
	
	# Shove everything nearby away (roaches run off)
	var shove : Shockwave = Shockwave.new()
	shove.hurtsPlayer = false
	shove.pushGroups = []
	shove.speed = 600.0
	shove.maxRadius = wake_push_radius
	shove.thickness = 10.0
	shove.color = Color(1, 1, 1)
	shove.global_position = global_position
	Global.currentScene.add_child(shove)
	for r in get_tree().get_nodes_in_group("evil_roaches"):
		if r.has_method("flee"): r.flee(global_position)
	var pushed : Array = get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("evil_roaches")
	if Global.player: pushed.append(Global.player)
	for b in pushed:
		if b == self or not is_instance_valid(b) or not b is Node2D: continue
		if b.global_position.distance_to(global_position) <= wake_push_radius:
			Knockback.apply(b, b.global_position - global_position, wake_push_force, self)
	
	bar = BossBar.new()
	add_child(bar)
	bar.setBoss(display_name)
	bar.setHealth(1.0)
	Global.sendMessage("The %s has awoken!" % display_name, 5.0, Color(1.0, 0.4, 0.4))

func _die() -> void:
	state = State.DEAD
	stateT = 0.0
	act = Act.NONE
	walk = Vector2.ZERO
	collision_layer = 0
	_clearTelegraph()
	_smokeBurst(36, 0.8)
	_flash()
	Global.sendMessage("%s destroyed!" % display_name, 5.0, Color.GOLD)
	defeated.emit()

func _dropRewards() -> void:
	if _rewarded: return
	_rewarded = true
	var money : int = roundi(randi_range(money_range.x, money_range.y) * (1.0 + 0.1 * (level - 1)))
	Global.money += money
	Global.sendMessage("+$%d" % money, 4.0, Color.GOLD)
	
	Global.lootRarityBonus = loot_rarity_bonus
	if Global.lootList:
		for i in loot_drops:
			var item : BaseItem = Global.lootList.getRandom()
			if item: item.drop(1, false, global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
	Global.lootRarityBonus = 0.0
	
	if Global.playerStats:
		var levels : int = Global.playerStats.addExp(exp_reward * (1.0 + 0.25 * (level - 1)))
		if levels > 0:
			Global.sendMessage("LEVEL UP! Level %d (%d points to spend)" % [Global.playerStats.level, Global.playerStats.unspent_points], 4.0, Color.GOLD)

#endregion

#region Per frame

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	var v : Vector2 = Vector2.ZERO
	if state == State.ACTIVE:
		if act == Act.SLAM_AIR:
			v = (slamTo - slamFrom) / maxf(_airTime(), 0.01)
		elif hitstun <= 0.0:
			v = walk * (statusFx.speedMult() if statusFx else 1.0)
		v += knockbackVelocity
	knockbackVelocity *= pow(Global.KNOCKBACK_DECAY, delta)
	linear_velocity = v

func _process(delta: float) -> void:
	if get_tree().paused: return
	_immuneCD = maxf(_immuneCD - delta, 0.0)
	hitstun = maxf(hitstun - delta, 0.0)
	stateT += delta
	
	match state:
		State.BROKEN: _updateBroken(delta)
		State.WAKING: _updateWaking(delta)
		State.ACTIVE: _updateFight(delta)
		State.DEAD: _updateDeath(delta)
	
	if state == State.ACTIVE and statusFx and health > 0.0: statusFx.process(delta)
	_updateLook(delta)
	_updateVisual()
	_updateLegs(delta)
	_updateWeapons(delta)
	_updateCameraShake(delta)

func _updateBroken(delta: float) -> void:
	legGrow = 0.0
	_sparkT -= delta
	if _sparkT <= 0.0:
		sparks.restart()
		_sparkT = randf_range(0.8, 2.5) * (1.0 - repair * 0.5)

func _updateWaking(_delta: float) -> void:
	var g : float = clampf((stateT - 0.25) / 1.4, 0.0, 1.0)
	legGrow = 1.0 - pow(1.0 - g, 3.0)
	_shakeX = randf_range(-1.0, 1.0) * 3.0 * clampf(1.0 - stateT / 1.6, 0.0, 1.0)
	if stateT >= 1.9:
		state = State.ACTIVE
		_shakeX = 0.0
		act = Act.NONE
		actT = wake_grace
		slamCD = wake_grace + 3.0
		_plantFeet()

func _updateDeath(_delta: float) -> void:
	legGrow = clampf(1.0 - stateT / 1.0, 0.0, 1.0)
	lift = move_toward(lift, 0.0, _delta * 300.0)
	if stateT > 1.0: _dropRewards()
	if bar and stateT > 1.5: bar.setShown(false)
	if stateT > 2.0: visual.modulate.a = clampf(3.0 - stateT, 0.0, 1.0)
	if stateT > 3.1: queue_free()

func _airTime() -> float:
	return slam_air_time * (1.15 if travelLeap else 1.0)

func _updateFight(delta: float) -> void:
	var p : Node = Global.player
	if not is_instance_valid(p) or p.is_dead:
		walk = Vector2.ZERO
		if bar: bar.setShown(false)
		return
	var toP : Vector2 = p.global_position - global_position
	var dist : float = toP.length()
	var speedUp : float = 1.5 if enraged else 1.0
	slamCD -= delta * speedUp
	if bar: bar.setShown(dist < bar_distance)
	
	if hitstun > 0.0 and act in [Act.NONE, Act.LASER, Act.VOLLEY]:
		walk = Vector2.ZERO
		return
	
	match act:
		Act.NONE:
			actT -= delta * speedUp
			if dist > keep_distance + 30.0: walk = toP.normalized() * walk_speed
			elif dist < keep_distance - 40.0: walk = -toP.normalized() * walk_speed * 0.7
			else: walk = Vector2.ZERO
			if dist > hunt_distance:
				_startSlam(true)
			elif actT <= 0.0:
				if slamCD <= 0.0: _startSlam(false)
				elif dist < laser_range * 0.9 and randf() < 0.5: _startLaser(p)
				else: _startVolley()
		Act.LASER:
			actT -= delta
			walk = toP.normalized() * walk_speed * 0.35 if dist > keep_distance else Vector2.ZERO
			beamTarget = beamTarget.lerp(p.global_position, 1.0 - exp(-laser_track_speed * speedUp * delta))
			if actT <= 0.0: _endAttack()
		Act.VOLLEY:
			walk = Vector2.ZERO
			actT -= delta * speedUp
			if actT <= 0.0:
				_fireVolley(p)
				volleyLeft -= 1
				actT = volley_gap
				if volleyLeft <= 0: _endAttack()
		Act.SLAM_WINDUP:
			walk = Vector2.ZERO
			actT += delta
			var w : float = slam_windup * (0.6 if travelLeap else 1.0)
			crouch = 12.0 * clampf(actT / w, 0.0, 1.0)
			if telegraph: telegraph.set("alpha", clampf(actT / w, 0.0, 1.0))
			if actT >= w:
				act = Act.SLAM_AIR
				actT = 0.0
				slamFrom = global_position
				collision_layer = 0 # out of reach in the air
		Act.SLAM_AIR:
			actT += delta
			var f : float = clampf(actT / _airTime(), 0.0, 1.0)
			lift = sin(PI * f) * slam_height * (1.3 if travelLeap else 1.0)
			crouch = move_toward(crouch, 0.0, delta * 80.0)
			if f >= 1.0: _land()
		Act.RECOVER:
			walk = Vector2.ZERO
			actT -= delta * speedUp
			crouch = move_toward(crouch, 0.0, delta * 30.0)
			if actT <= 0.0: _endAttack()

func _endAttack() -> void:
	act = Act.NONE
	actT = idle_time

func _startLaser(p: Node) -> void:
	act = Act.LASER
	actT = laser_time
	# Starts a bit off to one side and swings onto you
	beamTarget = p.global_position + (p.global_position - global_position).orthogonal().normalized() * 60.0 * (1 if randf() < 0.5 else -1)

func _startVolley() -> void:
	act = Act.VOLLEY
	volleyLeft = volleys + (1 if enraged else 0)
	actT = 0.3

func _fireVolley(p: Node) -> void:
	var origin : Vector2 = (pupils[0].global_position + pupils[1].global_position) * 0.5
	var dir : Vector2 = (p.global_position - origin).normalized()
	for i in shotSys.weapon.rangeSpawnAmount:
		shotSys.spawnBullet(i, origin, dir, 1.0 / 60.0)

func _startSlam(travel: bool) -> void:
	var p : Node = Global.player
	if not is_instance_valid(p): return
	travelLeap = travel
	act = Act.SLAM_WINDUP
	actT = 0.0
	var target : Vector2 = p.global_position + p.linear_velocity * 0.25
	var offset : Vector2 = target - global_position
	if offset.length() > slam_max_leap: offset = offset.normalized() * slam_max_leap
	slamTo = global_position + offset
	if not travel: slamCD = slam_cooldown
	_clearTelegraph()
	telegraph = Telegraph.new()
	telegraph.radius = slam_impact_radius
	telegraph.global_position = slamTo
	Global.currentScene.add_child(telegraph)

func _land() -> void:
	global_position = slamTo
	lift = 0.0
	collision_layer = 4
	_clearTelegraph()
	_plantFeet()
	_camShake = 0.35
	act = Act.RECOVER
	actT = 0.5
	
	var p : Node = Global.player
	if is_instance_valid(p) and not p.is_rolling:
		var d : Vector2 = p.global_position - global_position
		if Vector2(d.x, d.y / Shockwave.GROUND_SQUASH).length() <= slam_impact_radius:
			var dmg : float = slam_impact_damage * _dmgMult
			p.take_damage({"value": dmg, "physical": dmg, "isCrit": true, "kind": "melee"}, self)
			Knockback.apply(p, d if d != Vector2.ZERO else Vector2.DOWN, 160.0, self)
	
	_shockwave()
	if enraged:
		get_tree().create_timer(0.35, false).timeout.connect(_shockwave)

func _shockwave() -> void:
	if not is_inside_tree() or state != State.ACTIVE: return
	var w : Shockwave = Shockwave.new()
	w.source = self
	w.damage = shockwave_damage * _dmgMult
	w.speed = shockwave_speed
	w.maxRadius = shockwave_radius
	w.thickness = shockwave_thickness
	w.global_position = global_position
	Global.currentScene.add_child(w)

func _clearTelegraph() -> void:
	if telegraph and is_instance_valid(telegraph): telegraph.queue_free()
	telegraph = null

func _updateWeapons(delta: float) -> void:
	var firing : bool = state == State.ACTIVE and act == Act.LASER and hitstun <= 0.0
	if firing: laserSys.attack()
	laserSys.update(delta, beamTarget)
	for l in laserSys.spawned:
		if is_instance_valid(l) and l is Line2D: l.width = 6.0

func _updateCameraShake(delta: float) -> void:
	if _camShake <= 0.0: return
	_camShake -= delta
	var p : Node = Global.player
	if not is_instance_valid(p) or not p.camera: return
	if _camShake <= 0.0:
		p.camera.offset = Vector2.ZERO
	else:
		var near : float = clampf(1.0 - p.global_position.distance_to(global_position) / 600.0, 0.0, 1.0)
		p.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * near

#endregion

#region Eye and body visuals

func _updateLook(delta: float) -> void:
	var target : Vector3 = BROKEN_LOOK.normalized()
	var p : Node = Global.player
	if state == State.BROKEN:
		target = BROKEN_LOOK.lerp(Vector3(0.35, -0.45, 0.8), repair * 0.5).normalized()
	elif state == State.DEAD:
		target = BROKEN_LOOK.normalized()
	elif is_instance_valid(p):
		var d : Vector2 = (p.global_position + Vector2(0, -8)) - visual.global_position
		var k : float = clampf(d.length() / 160.0, 0.0, 1.0) * sin(deg_to_rad(max_look_angle))
		var n : Vector2 = d.normalized()
		target = Vector3(n.x * k, -n.y * k, sqrt(1.0 - k * k))
	if delta <= 0.0: look = target
	else: look = look.slerp(target, 1.0 - exp(-look_speed * delta)).normalized()
	eye3d.basis = Basis.looking_at(look, Vector3.UP)
	
	# Laser / volley come out of the pupil
	var pupil : Vector2 = visual.global_position + Vector2(look.x, -look.y) * eyeRadius * 0.85
	pupils[0].global_position = pupil + Vector2(-2, 0)
	pupils[1].global_position = pupil + Vector2(2, 0)

func _updateVisual() -> void:
	var sitH : float = eyeRadius * 0.85
	var h : float = lerpf(sitH, body_height, legGrow) + lift - crouch
	visual.position = Vector2(_shakeX, -h)
	visual.z_index = 6 if lift > 12.0 else 0 # over the tree canopy while jumping
	coll.position = visual.position
	var s : float = 1.0 - clampf(lift / (slam_height * 1.3), 0.0, 1.0) * 0.55
	var sw : float = eyeRadius * 3.0 / float(SHADOW_TEX.get_width())
	shadow.scale = Vector2(sw, sw * 0.32) * s
	
	# Rolled over while broken (less as it's repaired), upright once awake
	var tilt : float = 0.0
	var shade : float = 1.0
	match state:
		State.BROKEN:
			tilt = BROKEN_TILT * (1.0 - repair * 0.4)
			shade = lerpf(0.55, 0.8, repair)
		State.WAKING:
			var f : float = clampf(stateT / 1.2, 0.0, 1.0)
			tilt = lerpf(BROKEN_TILT * 0.6, 0.0, f)
			shade = lerpf(0.8, 1.0, f)
		State.DEAD:
			var f : float = clampf(stateT / 1.0, 0.0, 1.0)
			tilt = lerpf(0.0, BROKEN_TILT, f)
			shade = lerpf(1.0, 0.5, f)
	if state != State.ACTIVE: eye.rotation = tilt
	eye.modulate = Color(shade, shade, shade * 1.05, 1.0)

# Puts every foot back on its rest spot (after landing or growing)
func _plantFeet() -> void:
	for leg in legs:
		leg.foot = _restFoot(leg)
		leg.t = -1.0

func _restFoot(leg: Dictionary) -> Vector2:
	var a : float = leg.angle
	return global_position + Vector2(cos(a), sin(a) * 0.62) * leg_reach * maxf(legGrow, 0.05)

func _updateLegs(delta: float) -> void:
	var grow : float = maxf(legGrow, 0.0)
	for leg in legs:
		leg.upper.visible = grow > 0.02
		leg.lower.visible = grow > 0.02
	if grow <= 0.02: return
	
	var airborne : bool = state == State.ACTIVE and act == Act.SLAM_AIR
	var planted : bool = state == State.ACTIVE and not airborne
	var stepTime : float = step_time * (0.75 if enraged else 1.0)
	var stepping : Array[int] = [0, 0]
	for leg in legs:
		if leg.t >= 0.0: stepping[leg.group] += 1
	
	var lead : Vector2 = linear_velocity.limit_length(80.0) * 0.18
	for leg in legs:
		var a : float = leg.angle
		var hip : Vector2 = Vector2(cos(a), sin(a) * 0.5) * eyeRadius * 0.72
		var footLocal : Vector2
		if airborne:
			# Legs tuck in and dangle under the eye
			footLocal = hip + Vector2(cos(a), sin(a) * 0.6) * leg_reach * 0.45 + Vector2(0, body_height * 0.55)
			leg.foot = visual.to_global(footLocal)
			leg.t = -1.0
		elif not planted:
			# Growing out of the eye / retracting
			leg.foot = _restFoot(leg)
			footLocal = visual.to_local(leg.foot)
		else:
			var desired : Vector2 = _restFoot(leg) + lead
			if leg.t < 0.0:
				var far : float = leg.foot.distance_to(desired)
				var other : int = 1 - leg.group
				if far > step_distance and (stepping[other] == 0 or far > step_distance * 2.2):
					leg.t = 0.0
					leg.from = leg.foot
					leg.to = desired
					stepping[leg.group] += 1
			var arc : float = 0.0
			if leg.t >= 0.0:
				leg.t = minf(leg.t + delta / stepTime, 1.0)
				var e : float = smoothstep(0.0, 1.0, leg.t)
				leg.to = leg.to.lerp(desired, 0.3) # keeps up with a moving body
				leg.foot = leg.from.lerp(leg.to, e)
				arc = sin(PI * leg.t) * 9.0
				if leg.t >= 1.0:
					leg.t = -1.0
					stepping[leg.group] = maxi(stepping[leg.group] - 1, 0)
			footLocal = visual.to_local(leg.foot) - Vector2(0, arc)
		_drawLeg(leg, hip, footLocal, grow)

# 2-bone IK in the visual's space; the knee bends up (screen up) so it reads as a spider
func _drawLeg(leg: Dictionary, hip: Vector2, foot: Vector2, grow: float) -> void:
	var u : float = upper_leg * grow
	var l : float = lower_leg * grow
	var d : Vector2 = foot - hip
	var reach : float = clampf(d.length(), absf(u - l) + 1.0, u + l - 0.5)
	var n : Vector2 = d.normalized() if d.length() > 0.001 else Vector2.DOWN
	var end : Vector2 = hip + n * reach
	var along : float = (u * u - l * l + reach * reach) / (2.0 * reach)
	var h : float = sqrt(maxf(u * u - along * along, 0.0))
	var base : Vector2 = hip + n * along
	var perp : Vector2 = Vector2(-n.y, n.x)
	var k1 : Vector2 = base + perp * h
	var k2 : Vector2 = base - perp * h
	var knee : Vector2 = k1 if k1.y < k2.y else k2
	_segment(leg.upper, hip, knee, leg_thickness)
	_segment(leg.lower, knee, end, leg_thickness * 0.8)

func _segment(s: Sprite2D, a: Vector2, b: Vector2, thick: float) -> void:
	s.position = (a + b) * 0.5
	s.rotation = (b - a).angle()
	s.scale = Vector2(maxf((b - a).length(), 0.1) / float(LEG_TEX.get_width()), thick)

func _smokeBurst(amount: int, size: float) -> void:
	var p : CPUParticles2D = CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.texture = GLOW
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = eyeRadius * 0.8
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.scale_amount_min = 0.3 * size
	p.scale_amount_max = 0.6 * size
	var c : Curve = Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 1))
	p.scale_amount_curve = c
	var g : Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(0.62, 0.62, 0.66, 0.85), Color(0.3, 0.3, 0.33, 0)])
	p.color_ramp = g
	p.z_index = 1
	p.position = visual.position
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

func _flash() -> void:
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	var rect : ColorRect = ColorRect.new()
	rect.color = Color(1, 1, 1, 0.9)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	Global.currentScene.add_child(layer)
	var tw : Tween = layer.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)

#endregion

# Red ring on the ground where a body slam will land
class Telegraph extends Node2D:
	var radius : float = 50.0
	var alpha : float = 0.0:
		set(v):
			alpha = v
			queue_redraw()
	
	func _ready() -> void:
		z_index = 6 # above the tree canopy so it's visible in the forest
		z_as_relative = false
	
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Shockwave.GROUND_SQUASH))
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.15, 0.1, alpha * 0.25))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.25, 0.15, alpha), 3.0)
