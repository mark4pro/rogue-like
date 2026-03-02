extends RigidBody2D

@export var nav : NavigationAgent2D = null
@export var eye : Marker2D = null
@export var sprite : Sprite2D = null
@export var coll : CollisionShape2D = null
@export var healthBar : ProgressBar = null

@export_category("Base Stats")
@export var weapon : WeaponItem = null
@export var maxHealth : float = 100
@export var health : float = 100

@export_category("Loot")
@export var moneyChance : float = 0.5
@export var moneyRange : Vector2i = Vector2i(2, 5)

var weapSys : WeaponSys = WeaponSys.new()
var thisAI : DefaultAI = DefaultAI.new()

@export_category("For Vision Cone")
@export var coneSteps : int = 12
@export_category("Movement")
@export var speed : float = 7
@export var stopDist : float = 65
@export var wonderUpdate : float = 2
@export_category("Vision")
@export var visionRange : float = 100
@export var visionAngle : float = 90
@export var timeUntilChase : float = 1
@export var timeUntilChaseEnd : float = 3

func take_damage(data: Dictionary, attacker: Node):
	if not get_tree().paused:
		health -= data.value
		Global.damageAnim(sprite, data.value)
		Global.damNumbers(coll, data)
		thisAI.engage(attacker)

func _ready() -> void:
	if nav and eye and sprite and coll:
		thisAI.body = self
		thisAI.weapSys = weapSys
		thisAI.baseNode = eye
		thisAI.navAgent = nav
		nav.connect("velocity_computed", velocity_computed)
	else:
		print("Please check nav, eye, sprite, and coll!")

func _process(delta: float) -> void:
	if nav and eye and sprite and coll:
		thisAI.coneSteps = coneSteps
		thisAI.speed = speed
		thisAI.stopDist = stopDist
		thisAI.wonderUpdate = wonderUpdate
		thisAI.visionRange = visionRange
		thisAI.visionAngle = visionAngle
		thisAI.timeUntilChase = timeUntilChase
		thisAI.timeUntilChaseEnd = timeUntilChaseEnd
		thisAI.eyePos = eye.global_position
		thisAI.isFlipped = sprite.scale.x == -1
		
		#Health shit
		health = clamp(health, 0, maxHealth)
		if healthBar: healthBar.value = (health / maxHealth) * 100
		if health <= 0:
			var randomChk : float = randf()
			if randomChk < moneyChance: Global.money += randi_range(moneyRange.x, moneyRange.y)
			queue_free()
		
		#Default to wonder if player isn't loaded
		if not Global.player:
			thisAI.disengage()
		
		#Unload when far away
		if Global.player and global_position.distance_to(Global.player.global_position) > 1000:
			queue_free()
		
		#Flip logic
		if linear_velocity.x < 0:
			sprite.scale.x = -1
			coll.position.x = -1
		if linear_velocity.x > 0:
			sprite.scale.x = 1
			coll.position.x = 1
		
		#Weapon system setup
		weapSys.parentNode = self
		weapSys.posOffset = Vector2(0, 0)
		weapSys.weapon = weapon
		if Global.player: weapSys.update(delta, Global.player.position)
		
		thisAI.update(delta)

func velocity_computed(safe_velocity: Vector2) -> void:
	linear_velocity = safe_velocity
