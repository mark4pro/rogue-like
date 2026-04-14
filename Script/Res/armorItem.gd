extends BaseItem
class_name ArmorItem

@export_category("Weapon")
@export var armorScene : PackedScene = null

@export_category("Weapon Stats")
@export var baseDefense : float = 20
@export var defenseVar : float = 0.2

@export_category("Rolled Stats")
@export var defense : float

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
	
	if defense == 0 and baseDefense != 0:
		var defVar : float = baseDefense * defenseVar
		var lowDef = (baseDefense - defVar) * rarityMult * progMult
		var highDef = (baseDefense + defVar) * rarityMult * progMult
		defense = randf_range(lowDef, highDef)
	
	if cost == 0 and baseCost != 0:
		var costVariance : float = baseCost * costVar
		cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	
	Global.rng = randi()
	rolled = true

func use() -> void:
	pass

func equip() -> void:
	Global.armor = self

func unequip() -> void:
	if Global.armor == self:
		Global.armor = null
