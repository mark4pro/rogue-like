extends BaseItem
class_name ArmorItem

@export_category("Weapon")
@export var armorScene : PackedScene = null

@export_category("Weapon Stats")
@export var baseDefense : float = 20
@export var defenseVar : float = 0.2
## Fraction of knockback ignored (0.15 = 15%). Rarity adds a bit on top; total capped by Knockback.RESIST_CAP.
@export_range(0.0, 0.8, 0.01) var knockbackResist : float = 0.15

## Themed resistances before rolling: key -> base value. Keys are damage kinds (melee, projectile,
## laser) and elements (fire, water, ice, shock, shadow, acid, slime, venom). Negative = a weakness
## (not scaled by rarity). Read from the armor's file by name, so copies saved earlier get them too.
@export var baseResists : Dictionary = {}

@export_category("Rolled Stats")
@export var defense : float
## Rolled from baseResists (rarity raises them, +-15% variance), capped at StatusEffects.RESIST_CAP
@export var resists : Dictionary = {}

func rollStats() -> void:
	if Global.sceneIndex != 0:
		setDay = Global.runDays
	else:
		var per = lerp(0.5, 1.0, Global.performance)
		setDay = Global.meta * per
	
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Global.rng
	
	rarity = BaseItem.rollRarity(rng, setDay)
	
	var rarityMult : float = 1.0 + rarity * 0.25
	
	var curve : float = pow(setDay, 1.2)
	var progMult : float = 1.0 + curve * 0.01
	
	if defense == 0 and baseDefense != 0:
		var defVar : float = baseDefense * defenseVar
		var lowDef = (baseDefense - defVar) * rarityMult * progMult
		var highDef = (baseDefense + defVar) * rarityMult * progMult
		defense = randf_range(lowDef, highDef) * uniqueMult()
	
	if resists.is_empty(): rollResists(rng)
	
	if cost == 0 and baseCost != 0:
		var costVariance : float = baseCost * costVar
		cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	
	shopPrice = cost - roundi(cost * 0.15)
	
	Global.rng = randi()
	rolled = true

#region Resistances

const TEMPLATE_DIR : String = "res://Assets/armor"
static var _templateResists : Dictionary = {} # armor name -> baseResists
static var _templatesLoaded : bool = false

static func _loadTemplates() -> void:
	_templatesLoaded = true
	var d : DirAccess = DirAccess.open(TEMPLATE_DIR)
	if not d: return
	for f in d.get_files():
		var file : String = f.trim_suffix(".remap")
		if not file.ends_with(".tres"): continue
		var res : Resource = load(TEMPLATE_DIR + "/" + file)
		if res is ArmorItem and not res.baseResists.is_empty():
			_templateResists[res.name] = res.baseResists

func getBaseResists() -> Dictionary:
	if not _templatesLoaded: _loadTemplates()
	return _templateResists.get(name, baseResists)

func rollResists(rng: RandomNumberGenerator = null) -> void:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(name) ^ (max(rarity, 0) * 7919) ^ int(defense * 100)
	var base : Dictionary = getBaseResists()
	var rarityMult : float = (1.0 + max(rarity, 0) * 0.15) * uniqueMult()
	resists = {}
	for k in base:
		var v : float = float(base[k])
		if v > 0.0: v *= rarityMult * rng.randf_range(0.85, 1.15)
		resists[k] = StatusEffects.clampResist(v)

# Rolled resistance for a damage kind or element (rolls once, lazily, for armor saved before resistances)
func getResist(key: String) -> float:
	if resists.is_empty() and not getBaseResists().is_empty(): rollResists()
	return float(resists.get(key, 0.0))

#endregion

# Worked out live (not rolled) so armour that was already rolled and saved still gets it
func getKnockbackResist() -> float:
	return clampf(knockbackResist * (1.0 + max(rarity, 0) * 0.15) * uniqueMult(), 0.0, Knockback.RESIST_CAP)

func use() -> void:
	pass

func equip() -> void:
	Global.armor = self

func unequip() -> void:
	if Global.armor == self:
		Global.armor = null
