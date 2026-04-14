extends BaseItem
class_name ArmorItem

@export_category("Weapon")
@export var armorScene : PackedScene = null

@export_category("Weapon Stats")
@export var baseDeffence : float = 20
@export var deffenceVar : float = 0.2

@export_category("Rolled Stats")
@export var deffence : float

func rollStats() -> void:
	#if Global.sceneIndex != 0:
		#setDay = Global.runDays
	#else:
		#var per = lerp(0.5, 1.0, Global.performance)
		#setDay = Global.meta * per
	#
	#var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	#rng.seed = Global.rng
	#
	#var dayBias : float = setDay * 0.015
	#
	#var roll : float = clamp(rng.randf() + dayBias, 0.0, 0.999)
	#rarity = int(roll * 6)
	#
	#var rarityMult : float = 1.0 + rarity * 0.25
	#
	#var curve : float = pow(setDay, 1.2)
	#var progMult : float = 1.0 + curve * 0.01
	#
	#if damage == Vector2.ZERO and baseDamage != 0:
		#var damVar : float = baseDamage * damageVar
		#damage.x = (baseDamage - damVar) * rarityMult * progMult
		#damage.y = (baseDamage + damVar) * rarityMult * progMult
	#
	#if critChance == 0: critChance = rng.randf_range(0.05, 0.15) * rarityMult * progMult
	#if critMulti == 0: critMulti = rng.randf_range(1.5, 2.5)
	#
	#if knockback == 0 and baseKnBck != 0:
		#var knBckVar : float = baseKnBck * KnBckVar
		#knockback = randf_range((baseKnBck - knBckVar) * rarityMult * progMult, (baseKnBck + knBckVar) * rarityMult * progMult)
	#
	#if cost == 0 and baseCost != 0:
		#var costVariance : float = baseCost * costVar
		#cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	#
	#Global.rng = randi()
	rolled = true

func use() -> void:
	pass

func equip() -> void:
	Global.armor = self

func unequip() -> void:
	if Global.armor == self:
		Global.armor = null
