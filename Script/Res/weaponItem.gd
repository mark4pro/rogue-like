extends BaseItem
class_name WeaponItem

enum animType {
	SWING,
	AIM,
	AIM_LASER,
	RANGE,
}

# Which resource a weapon spends: the body (stamina) or magic (mana)
enum poolType {
	STAMINA,
	MANA,
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
@export var swingZRange : Vector2i = Vector2i(-1, 1)
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
@export_category("Scaling")
## attribute -> grade ("S", "A", "B", "C", "D", "E"), e.g. {"strength": "A", "rogue": "C"}.
## Each grade adds a share of the rolled damage per attribute point (A at 100 points = +100%).
## Empty = a default for the weapon type (see getScaling).
@export var scaling : Dictionary = {}
@export_category("Elements")
## element -> share of the damage dealt as that element, e.g. {"fire": 0.5} = half fire, half physical.
## Elemental damage fills status meters (see StatusEffects). Read from the weapon's file by name.
@export var elements : Dictionary = {}
@export_category("Pool Cost")
## Stamina per swing / throw, mana per volley, or mana per SECOND for lasers.
## -1 = automatic from the weapon type (and weight for melee and thrown weapons).
@export var poolCost : float = -1
## Auto: melee and throwables use stamina, projectiles and lasers use mana.
@export_enum("Auto", "Stamina", "Mana") var poolUse : int = 0
@export_category("Mutation")
## Set by Mutation.roll when the weapon rolls (empty = normal). See mutation.gd.
@export var mutation : String = ""
@export var mutationColor : Color = Color.WHITE
@export var mutationSeed : float = 0.0
@export var mutationElement : String = ""
@export var mutationNotes : PackedStringArray = PackedStringArray()
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
	
	rarity = BaseItem.rollRarity(rng, setDay)
	
	var rarityMult : float = 1.0 + rarity * 0.25
	
	var curve : float = pow(setDay, 1.2)
	var progMult : float = 1.0 + curve * 0.01
	
	if damage == Vector2.ZERO and baseDamage != 0:
		var damVar : float = baseDamage * damageVar
		damage.x = (baseDamage - damVar) * rarityMult * progMult
		damage.y = (baseDamage + damVar) * rarityMult * progMult
	
	if unique: damage *= uniqueMult() # unique weapons: +15% on top of the rolled rarity
	if critChance == 0: critChance = rng.randf_range(0.05, 0.15) * rarityMult * progMult
	if critMulti == 0: critMulti = rng.randf_range(1.5, 2.5)
	
	if knockback == 0 and baseKnBck != 0:
		var knBckVar : float = baseKnBck * KnBckVar
		knockback = randf_range((baseKnBck - knBckVar) * rarityMult * progMult, (baseKnBck + knBckVar) * rarityMult * progMult)
	
	if cost == 0 and baseCost != 0:
		var costVariance : float = baseCost * costVar
		cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	
	shopPrice = cost - roundi(cost * 0.15)
	
	Mutation.roll(self, rng) # rare: recoloured with a strain effect and boosted stats
	
	Global.rng = randi()
	rolled = true

# Rolls this copy as a plain Common with no mutation (starter weapons, enemies' own weapons)
func rollCommon() -> void:
	var oldBonus : float = Global.lootRarityBonus
	Global.lootRarityBonus = -10.0 # forces the lowest tier whatever the day / Luck
	mutation = "_"                 # blocks Mutation.canMutate
	rollStats()
	mutation = ""
	Global.lootRarityBonus = oldBonus

const GRADE_MULT : Dictionary = {"S": 1.2, "A": 1.0, "B": 0.75, "C": 0.5, "D": 0.3, "E": 0.15}
const GRADE_ORDER : Array[String] = ["S", "A", "B", "C", "D", "E"]
const CRIT_CHANCE_CAP : float = 0.6

# Grades come from the weapon's file (looked up by name), so copies saved before grades
# existed, or before a grade was tweaked, always use the current design. Falls back to this
# copy's own `scaling`, then to a default for the weapon type.
const TEMPLATE_DIRS : Array[String] = ["res://Assets/weapons", "res://Assets/items"]
static var _templateScaling : Dictionary = {} # weapon name -> scaling
static var _templateElements : Dictionary = {} # weapon name -> elements
static var _templatesLoaded : bool = false

static func _loadTemplates() -> void:
	_templatesLoaded = true
	for dir in TEMPLATE_DIRS:
		var d : DirAccess = DirAccess.open(dir)
		if not d: continue
		for f in d.get_files():
			var file : String = f.trim_suffix(".remap") # exported builds list remapped files
			if not file.ends_with(".tres"): continue
			var res : Resource = load(dir + "/" + file)
			if res is WeaponItem:
				if not res.scaling.is_empty(): _templateScaling[res.name] = res.scaling
				_templateElements[res.name] = res.elements

func getElements() -> Dictionary:
	if not _templatesLoaded: _loadTemplates()
	var els : Dictionary = _templateElements[name] if _templateElements.has(name) else elements
	if mutationElement == "": return els
	# Elemental mutations add their element on top (total share capped at 100%)
	els = els.duplicate()
	els[mutationElement] = minf(float(els.get(mutationElement, 0.0)) + Mutation.ELEMENT_SHARE, 1.0)
	var total : float = 0.0
	for e in els: total += float(els[e])
	if total > 1.0:
		for e in els: els[e] = float(els[e]) / total
	return els

# Which physical resistance a hit from this weapon checks (thrown counts as projectile)
func damageKind() -> String:
	match animationType:
		animType.SWING: return "melee"
		animType.AIM_LASER: return "laser"
	return "projectile"

# "Fire 50%, Shock 20%"
func elementsText() -> String:
	var els : Dictionary = getElements()
	if els.is_empty(): return "None"
	var parts : PackedStringArray = PackedStringArray()
	for e in els: parts.append("%s %d%%" % [StatusEffects.ELEMENT_NAMES.get(e, e), roundi(float(els[e]) * 100)])
	return ", ".join(parts)

func getScaling() -> Dictionary:
	if not _templatesLoaded: _loadTemplates()
	if _templateScaling.has(name): return _templateScaling[name]
	if not scaling.is_empty(): return scaling
	match animationType:
		animType.SWING: return {"strength": "C"}
		animType.AIM_LASER: return {"focus": "C"}
		animType.RANGE: return {"strength": "C"} if throwable else {"magic": "C"}
	return {}

# Damage multiplier from the wielder's attributes (1.0 with no stats, e.g. enemies)
func scalingMult(st: stats) -> float:
	if not st: return 1.0
	var mult : float = 1.0
	var sc : Dictionary = getScaling()
	for a in sc:
		mult += GRADE_MULT.get(str(sc[a]).to_upper(), 0.0) * st.attr(a) / float(stats.ATTRIBUTE_CAP)
	return mult

# "Strength A, Rogue C" (best grade first)
func scalingText() -> String:
	var sc : Dictionary = getScaling()
	var keys : Array = sc.keys()
	keys.sort_custom(func(a, b): return GRADE_ORDER.find(str(sc[a]).to_upper()) < GRADE_ORDER.find(str(sc[b]).to_upper()))
	var parts : PackedStringArray = PackedStringArray()
	for a in keys: parts.append("%s %s" % [stats.ATTRIBUTE_NAMES.get(a, a), str(sc[a]).to_upper()])
	return ", ".join(parts)

## Melee weapons crit more often and harder than ranged ones (worked out live, so swords already
## in saves get it too): the payoff for fighting up close
const MELEE_CRIT_CHANCE : float = 0.08
const MELEE_CRIT_MULTI : float = 0.25

func baseCritChance() -> float:
	return critChance + (MELEE_CRIT_CHANCE if animationType == animType.SWING else 0.0)

func baseCritMulti() -> float:
	return critMulti + (MELEE_CRIT_MULTI if animationType == animType.SWING else 0.0)

func critChanceWith(st: stats) -> float:
	var cc : float = baseCritChance()
	if not st: return cc
	return maxf(cc, minf(cc + st.critChanceBonus(), CRIT_CHANCE_CAP))

func critMultiWith(st: stats) -> float:
	return baseCritMulti() + (st.critDamageBonus() if st else 0.0)

# st: the wielder's stats (the player), or null for enemies / placed things
func genDamage(st: stats = null) -> Dictionary:
	if not rolled: rollStats()
	
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Global.rng
	
	var dmg : float = rng.randf_range(damage.x, damage.y) * scalingMult(st)
	var isCrit : bool = rng.randf() < critChanceWith(st)
	
	if isCrit:
		dmg *= critMultiWith(st)
	
	Global.rng = randi()
	return {"value": dmg, "isCrit": isCrit}

func getPool() -> int:
	if poolUse == 1: return poolType.STAMINA
	if poolUse == 2: return poolType.MANA
	if animationType == animType.SWING or throwable: return poolType.STAMINA
	return poolType.MANA

func getPoolCost() -> float:
	if poolCost >= 0: return poolCost
	match animationType:
		animType.SWING:
			return 6.0 + weight * 4.0
		animType.AIM_LASER:
			return 15.0
		animType.RANGE:
			if throwable: return 4.0 + weight * 2.0
			# multi-shot weapons cost more per volley, but not linearly (a 30-pellet blast isn't 30x)
			return 8.0 + sqrt(max(rangeSpawnAmount - 1, 0)) * 4.0
	return 0.0

func use() -> void:
	pass

func equip() -> void:
	Global.weapon = self

func unequip() -> void:
	if Global.weapon == self:
		Global.weapon = null
