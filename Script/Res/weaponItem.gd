extends BaseItem
class_name WeaponItem

enum animType {
	SWING,
	AIM,
	AIM_LASER,
	RANGE,
}

@export_category("Weapon")
@export var weaponScene : PackedScene = null

@export_category("Weapon Stats")
@export var baseDamage : float = 100
@export var damageVar : float = 0.2
@export var baseKnBck : float = 20
@export var KnBckVar : float = 0.2

@export_category("Animation")
@export var animationType : animType = animType.SWING
@export_category("Swing")
@export var swingRadius : Vector2 = Vector2(5, 5)
@export var swingAngleRange : Vector2 = Vector2(30, -30)
@export var swingRestAngle : float = -45
@export var swingZRange : Vector2 = Vector2(-1, 1)
@export var swingSteps : int = 30
@export var swingDuration : float = 1
@export var swingSpeedMulti : float = 2
@export_category("Laser")
@export var laserRange : float = 100
@export var laserActivateSpeed : float = 5
@export var laserDeactivateSpeed : float = 5
@export var laserAttackSpeed : float = 1
@export_category("Range")
@export var rangeSpawnAmount : int = 1
@export var rangePerSpawnDelay : float = 0
@export var rangeSpreadAngle : float = 0
@export var rangeFireSpeed : float = 2
@export var rangeZOffset : int = 1
@export var rangeSpeed : float = 25
@export_category("Rolled Stats")
@export var damage : Vector2
@export var critChance : float
@export var critMulti : float
@export var knockback : float

func rollStats() -> void:
	if Global.sceneIndex != 0:
		setDay = Global.runDays
	else:
		var per = lerp(0.5, 1.0, Global.performance)
		setDay = Global.meta * per
	
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Global.rng
	
	var dayBias : float = setDay * 0.015
	
	var roll : float = clamp(rng.randf() + dayBias, 0.0, 0.999)
	rarity = int(roll * 6)
	
	var rarityMult : float = 1.0 + rarity * 0.25
	
	var curve : float = pow(setDay, 1.2)
	var progMult : float = 1.0 + curve * 0.01
	
	if damage == Vector2.ZERO and baseDamage != 0:
		var damVar : float = baseDamage * damageVar
		damage.x = (baseDamage - damVar) * rarityMult * progMult
		damage.y = (baseDamage + damVar) * rarityMult * progMult
	
	if critChance == 0: critChance = rng.randf_range(0.05, 0.15) * rarityMult * progMult
	if critMulti == 0: critMulti = rng.randf_range(1.5, 2.5)
	
	if knockback == 0 and baseKnBck != 0:
		var knBckVar : float = baseKnBck * KnBckVar
		knockback = randf_range((baseKnBck - knBckVar) * rarityMult * progMult, (baseKnBck + knBckVar) * rarityMult * progMult)
	
	if cost == 0 and baseCost != 0:
		var costVariance : float = baseCost * costVar
		cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	
	Global.rng = randi()
	rolled = true

func genDamage() -> Dictionary:
	if not rolled: rollStats()
	
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Global.rng
	
	var dmg : float = rng.randf_range(damage.x, damage.y)
	var isCrit : bool = rng.randf() < critChance
	
	if isCrit:
		dmg *= critMulti
	
	Global.rng = randi()
	return {"value": dmg, "isCrit": isCrit}

func use() -> void:
	pass

func equip() -> void:
	Global.weapon = self

func unequip() -> void:
	if Global.weapon == self:
		Global.weapon = null
