extends BaseItem
class_name WeaponItem

@export_category("Weapon")
@export var weaponScene : PackedScene = null

@export_category("Weapon Stats")
@export var baseDamage : float = 100
@export var damageVar : float = 0.2

@export_category("Rolled Stats")
@export var damage : Vector2
@export var critChance : float
@export var critMulti : float
@export var rarity : int

var setDay : int = 0

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
	
	var variance : float = baseDamage * damageVar
	damage.x = (baseDamage - variance) * rarityMult * progMult
	damage.y = (baseDamage + variance) * rarityMult * progMult
	
	critChance = rng.randf_range(0.05, 0.15) * rarityMult * progMult
	critMulti = rng.randf_range(1.5, 2.5)
	
	var costVariance : float = cost * costVar
	cost = rng.randf_range(cost - costVariance, cost + costVariance) * rarityMult * progMult
	
	Global.rng = randi()
	rolled = true

func genDamage() -> Dictionary:
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
