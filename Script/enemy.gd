extends RigidBody2D

@export var nav : NavigationAgent2D = null
@export var eye : Marker2D = null
@export var laserEyes : Array[Marker2D] = []
@export var sprite : Sprite2D = null
@export var coll : Node2D = null
@export var healthBar : ProgressBar = null

@export_category("Base Stats")
@export var weapon : WeaponItem = null
@export var maxHealth : float = 100
@export var health : float = 100
@export var defense : float = 10

@export_category("Pools")
## Swings and thrown weapons spend stamina, projectiles and lasers spend mana (same rules as the player)
@export var maxStamina : float = 100
@export var staminaRegen : float = 15
@export var maxMana : float = 100
@export var manaRegen : float = 10
@export var manaRegenDelay : float = 1.0

var stamina : float = 0
var mana : float = 0
var staminaExhausted : bool = false # hit 0: no swings until back to half
var manaRegenWait : float = 0

@export_category("EXP")
## EXP for killing a level 1 enemy of this type (higher levels give more, see giveExp)
@export var expReward : float = 12

@export_category("Level")
## How this enemy type spends its level-up points (weights, any scale), e.g. a spider leans
## Speed, a brute Strength and Vitality, a caster Magic or Focus
@export var attributeWeights : Dictionary = {"strength": 0.35, "vitality": 0.35, "speed": 0.15, "rogue": 0.15}
## Show the level by the health bar in red when it's at least this many levels above the player
const RED_LEVEL_GAP : int = 5

var level : int = 1
var eStats : stats = null      # same stats code as the player (weapon scaling, crits, resistances...)
var _levelApplied : bool = false
var levelLabel : Label = null

@export_category("Loot")
@export var moneyChance : float = 0.5
@export var moneyRange : Vector2i = Vector2i(2, 5)
@export var useGlobalLootList : bool = true
@export var localLootList : LootList = null
@export var lootChance : float = 0.3
@export var lootAmount : Vector2i = Vector2i(1, 2)
@export var equipDropChance : float = 0.1

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

var knockbackVelocity : Vector2 = Vector2.ZERO

@export_category("Knockback")
## Heavy enemies (2-3) barely move, light ones (0.5) fly
@export var knockbackWeight : float = 1.0
## Fraction of knockback ignored (0-0.8)
@export_range(0.0, 0.8, 0.01) var knockbackResist : float = 0.0

@export_category("Bite")
## Melee bite for enemies that fight up close without a weapon (the worm). 0 = no bite.
## Scales with level like weapon damage, plus the enemy's Strength.
@export var biteDamage : float = 0.0
## How close (px, centre to centre) the player has to be for a bite
@export var biteRange : float = 20.0
@export var biteCooldown : float = 1.1
## Time from the lunge starting to the bite landing (the player can roll or step out)
@export var biteWindup : float = 0.18
@export var biteKnockback : float = 35.0
@export var biteLunge : float = 7.0

var _biteCD : float = 0.0
var _biting : bool = false
var _spriteBasePos : Vector2 = Vector2.ZERO

@export_category("Resistances")
## Damage kind / element -> resistance (0.6 max), negative = weakness, e.g. {"fire": -0.25, "slime": 0.4}
@export var resistances : Dictionary = {}

var statusFx : StatusEffects = null

var hitstun : float = 0.0
var slamArmed : bool = false
var slamAttacker : Node = null
var dt : float = 0

var collPosX : float = 0

var ogScale : Vector2 = Vector2.ONE

func take_damage(data: Dictionary, attacker: Node):
	if not get_tree().paused:
		var hit : Dictionary = StatusEffects.resolveHit(data, self)
		health -= hit.total
		var shown : Dictionary = data.duplicate()
		shown.value = hit.total
		var elemTotal : float = 0.0
		for e in hit.elements: elemTotal += hit.elements[e]
		var el : String = StatusEffects.dominantElement(hit.elements, hit.total - elemTotal)
		if el != "" and not shown.has("color"): shown.color = StatusEffects.ELEMENT_COLORS[el]
		Global.damageAnim(sprite, hit.total, ogScale)
		Global.damNumbers(coll, shown)
		if is_instance_valid(attacker): thisAI.engage(attacker)
		if statusFx:
			for e in hit.elements: statusFx.addBuildup(e, hit.elements[e], data.get("attackerStats"), attacker)

# --- Elements / status host (used by StatusEffects) -----------------------------
func getMaxHealth() -> float: return maxHealth
func getDefense() -> float: return defense
func statusResist() -> float: return eStats.statusResist() if eStats else 0.0

func getResist(key: String) -> float:
	var r : float = float(resistances.get(key, 0.0))
	if key == "melee" and eStats: r += eStats.meleeResistBonus()
	return StatusEffects.clampResist(r)

# --- Pools (used by WeaponSys) -------------------------------------------------
func hasPool(pool: int, amount: float) -> bool:
	match pool:
		WeaponItem.poolType.STAMINA:
			return not staminaExhausted and stamina >= amount
		WeaponItem.poolType.MANA:
			return mana >= amount
	return true

func spendPool(pool: int, amount: float, force: bool = false) -> bool:
	var paid : bool = hasPool(pool, amount)
	match pool:
		WeaponItem.poolType.STAMINA:
			if paid or force:
				stamina = max(stamina - amount, 0)
				if stamina <= 0: staminaExhausted = true
		WeaponItem.poolType.MANA:
			if paid:
				mana -= amount
				manaRegenWait = manaRegenDelay
	return paid

#region Level

# Called by EnemySpawner before add_child. Buys attribute points with the same per-level table as
# the player, spreads them by attributeWeights, then applies them once.
func setLevel(lvl: int) -> void:
	if _levelApplied: return
	_levelApplied = true
	level = clampi(lvl, 1, stats.LEVEL_CAP)
	eStats = stats.new()
	eStats.level = level
	
	var points : int = 0
	for l in range(2, level + 1): points += stats.pointsForLevel(l)
	_spreadPoints(points)
	
	# Built-in boost per level (so a level 20 enemy is tough whatever its build)
	var above : int = level - 1
	var vit : int = eStats.attr("vitality")
	maxHealth *= (1.0 + EnemySpawner.health_per_level * above) * (1.0 + 0.04 * vit) # +4% per Vitality point
	health = maxHealth
	defense += EnemySpawner.defense_per_level * above + 0.5 * vit
	weapSys.damageMult = 1.0 + EnemySpawner.damage_per_level * above
	
	# Attribute-driven stats, same formulas as the player
	speed *= eStats.speedMoveMult()
	maxStamina += 2.0 * eStats.attr("stamina")
	maxMana += 2.0 * eStats.attr("magic")
	staminaRegen *= 1.0 + eStats.dim("stamina")
	manaRegen *= 1.0 + eStats.dim("magic")
	weapSys.wielderStats = eStats # weapon scaling grades, crit bonuses, cost reductions, laser range

func _spreadPoints(points: int) -> void:
	var total : float = 0.0
	for a in attributeWeights: total += maxf(float(attributeWeights[a]), 0.0)
	if total <= 0.0 or points <= 0: return
	var given : int = 0
	for a in attributeWeights:
		var n : int = int(points * maxf(float(attributeWeights[a]), 0.0) / total)
		eStats.attributes[a] = mini(n, stats.ATTRIBUTE_CAP)
		given += n
	# Leftover points (from rounding down) go to the heaviest weights first
	var order : Array = attributeWeights.keys()
	order.sort_custom(func(x, y): return float(attributeWeights[x]) > float(attributeWeights[y]))
	var i : int = 0
	while given < points and i < 100:
		var a : String = order[i % order.size()]
		if eStats.attr(a) < stats.ATTRIBUTE_CAP:
			eStats.attributes[a] = eStats.attr(a) + 1
			given += 1
		i += 1

# Strength: how much harder this enemy's hits push (used by Knockback.apply)
func knockbackDealtMult() -> float:
	return eStats.knockbackDealtMult() if eStats else 1.0

func _buildLevelLabel() -> void:
	if not healthBar or levelLabel: return
	levelLabel = Label.new()
	levelLabel.name = "Level"
	levelLabel.add_theme_font_override("font", load("uid://dv68j0l4djo44"))
	levelLabel.add_theme_font_size_override("font_size", 20)
	levelLabel.add_theme_constant_override("outline_size", 6)
	levelLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	levelLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	levelLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	levelLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Just left of the bar, in the bar's (scaled) UI space
	levelLabel.size = Vector2(70, healthBar.size.y + 8)
	levelLabel.position = healthBar.position + Vector2(-levelLabel.size.x - 4, -4)
	healthBar.get_parent().add_child(levelLabel)
	_updateLevelLabel()

func _updateLevelLabel() -> void:
	if not levelLabel: return
	levelLabel.text = "Lv %d" % level
	var playerLevel : int = Global.playerStats.level if Global.playerStats else 1
	var high : bool = level >= playerLevel + RED_LEVEL_GAP
	levelLabel.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25) if high else Color.WHITE)

#endregion

var expGiven : bool = false

# Higher level enemies give more, scaled by how far above or below the player they are
func giveExp() -> void:
	if expGiven or not Global.playerStats: return
	expGiven = true
	var gap : int = level - Global.playerStats.level
	var amount : float = expReward * (1.0 + 0.25 * (level - 1)) * clampf(1.0 + 0.1 * gap, 0.25, 2.0)
	var levels : int = Global.playerStats.addExp(amount)
	if levels > 0:
		Global.sendMessage("LEVEL UP! Level %d (%d points to spend)" % [Global.playerStats.level, Global.playerStats.unspent_points], 4.0, Color.GOLD)

func getKnockbackResist() -> float:
	return minf(knockbackResist + (eStats.knockbackResist() if eStats else 0.0), Knockback.RESIST_CAP)

func applyHitstun(seconds: float) -> void:
	hitstun = maxf(hitstun, seconds)

func updatePools(delta: float) -> void:
	stamina = min(stamina + staminaRegen * delta, maxStamina)
	if staminaExhausted and stamina >= maxStamina * 0.5: staminaExhausted = false
	
	if manaRegenWait > 0:
		manaRegenWait -= delta
	else:
		mana = min(mana + manaRegen * delta, maxMana)

func _ready() -> void:
	# Enemies placed by hand (not by the spawner) are level 1
	if not _levelApplied: setLevel(1)
	stamina = maxStamina
	mana = maxMana
	_buildLevelLabel()
	statusFx = StatusEffects.new(self)
	add_to_group("enemies") # shock chains between these
	
	# Wall slam detection needs contact reports
	contact_monitor = true
	max_contacts_reported = 4
	
	if nav and eye and sprite and coll:
		thisAI.body = self
		thisAI.weapSys = weapSys
		thisAI.baseNode = eye
		thisAI.navAgent = nav
		nav.connect("velocity_computed", velocity_computed)
		
		collPosX = coll.position.x
		ogScale = sprite.scale
		_spriteBasePos = sprite.position
	else:
		print("Please check nav, eye, sprite, and coll!")
	
	weapSys.spawnPos.resize(laserEyes.size())
	add_to_group("tree_cutout")

func _process(delta: float) -> void:
	if nav and eye and sprite and coll:
		thisAI.coneSteps = coneSteps
		thisAI.speed = speed
		thisAI.stopDist = stopDist
		thisAI.wonderUpdate = wonderUpdate
		thisAI.visionRange = visionRange * (statusFx.visionMult() if statusFx else 1.0) # Acid blinds
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
			var mods : Dictionary = EnemySpawner.lootMods() # blood moon kills drop better loot
			
			giveExp()
			
			if randomChk <= moneyChance: Global.money += roundi(randi_range(moneyRange.x, moneyRange.y) * mods.money)
			
			# Items roll their rarity as they land, so the bonus only needs to be set while dropping
			Global.lootRarityBonus = mods.rarity
			
			if randomChk <= lootChance * mods.loot_chance * Global.playerStats.dropChanceMult(): # Luck
				var thisLootList : LootList = Global.lootList if useGlobalLootList else localLootList
				if thisLootList:
					for i in range(randi_range(lootAmount.x, lootAmount.y) + mods.extra):
						var item : BaseItem = thisLootList.getRandom()
						if item: item.drop(1, false, global_position)
			
			if randomChk <= equipDropChance * mods.equip:
				if weapon: weapon.drop(1, false, global_position)
			
			Global.lootRarityBonus = 0.0
			
			queue_free()
		
		#Fix scale for the vision cone
		var visionConeChk : Node2D = eye.get_node_or_null("Cone")
		
		if visionConeChk:
			visionConeChk.scale = Vector2.ONE / sprite.global_scale
		
		#Default to wonder if player isn't loaded
		if not Global.player:
			thisAI.disengage()
		
		#Unload when far away
		if Global.player and global_position.distance_to(Global.player.global_position) > 1000:
			queue_free()
		
		#Flip logic
		var flipChck : float = linear_velocity.x - knockbackVelocity.x
		if flipChck < 0:
			sprite.scale.x = -ogScale.x
			coll.position.x = -collPosX
		if flipChck > 0:
			sprite.scale.x = ogScale.x
			coll.position.x = collPosX
		
		#Weapon system setup
		weapSys.parentNode = self
		weapSys.posOffset = Vector2(0, 0)
		for i in laserEyes:
			var index : int = laserEyes.find(i)
			weapSys.spawnPos[index] = i
		weapSys.weapon = weapon
		if not get_tree().paused:
			updatePools(delta)
			hitstun = maxf(hitstun - delta, 0)
			if statusFx and health > 0: statusFx.process(delta)
			# The player can level up mid-fight, so the red/white level colour is re-checked
			if (Engine.get_process_frames() + get_instance_id()) % 30 == 0: _updateLevelLabel() # staggered across enemies
		# Stunned: stop beams / held fire (the AI won't start new attacks either)
		if hitstun > 0 and weapon and weapon.animationType != WeaponItem.animType.SWING:
			weapSys.isAttacking = false
		if Global.player: weapSys.update(delta, Global.player.position)
		thisAI.update(delta)
		_updateBite(delta)

#region Bite

func _updateBite(delta: float) -> void:
	if biteDamage <= 0.0 or get_tree().paused: return
	_biteCD = maxf(_biteCD - delta, 0.0)
	var p : Node = Global.player
	if _biting or _biteCD > 0.0 or hitstun > 0.0 or not is_instance_valid(p) or p.is_dead: return
	if thisAI.currentState != DefaultAI.state.CHASE: return
	if global_position.distance_to(p.global_position) > biteRange: return
	_startBite(p)

# Lunge at the player, bite at the end of the windup if they're still in reach, pull back
func _startBite(p: Node) -> void:
	_biting = true
	_biteCD = biteCooldown
	var dir : Vector2 = (p.global_position - global_position).normalized()
	var tw : Tween = create_tween()
	tw.tween_property(sprite, "position", _spriteBasePos - dir * 2.0, biteWindup * 0.6) # rear back
	tw.tween_property(sprite, "position", _spriteBasePos + dir * biteLunge, biteWindup * 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(_biteHit)
	tw.tween_property(sprite, "position", _spriteBasePos, 0.15)
	tw.tween_callback(func(): _biting = false)

func _biteHit() -> void:
	var p : Node = Global.player
	if not is_instance_valid(p) or p.is_dead or p.is_rolling or hitstun > 0.0: return
	if global_position.distance_to(p.global_position) > biteRange + 6.0: return
	var dmg : float = biteDamage * weapSys.damageMult * (1.0 + 0.5 * (eStats.dim("strength") if eStats else 0.0))
	if statusFx: dmg *= statusFx.damageDealtMult() # Weaken
	p.take_damage({"value": dmg, "physical": dmg, "isCrit": false, "kind": "melee"}, self)
	Knockback.apply(p, p.global_position - global_position, biteKnockback, self)

#endregion

func _physics_process(delta: float) -> void:
		dt = delta
		if not get_tree().paused: Knockback.checkSlam(self)

func velocity_computed(safe_velocity: Vector2) -> void:
	knockbackVelocity = knockbackVelocity.limit_length(Global.MAX_KNOCKBACK)
	# Hitstun: only the knockback moves it
	var walk : Vector2 = safe_velocity if hitstun <= 0 else Vector2.ZERO
	if statusFx: walk *= statusFx.speedMult() # Chill / Sticky
	linear_velocity = walk + knockbackVelocity
	knockbackVelocity *= pow(Global.KNOCKBACK_DECAY, dt)
