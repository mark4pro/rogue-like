extends Resource
class_name stats

# Player stats: base values, attributes (spent from level-up points) and every derived stat.
# Gameplay code reads the derived getters (maxHealth(), walkSpeed() ...), never attributes
# directly. See the Stats & Progression design doc for the caps.
#
# Base values are ~20% below the old feel on purpose; attributes raise them back up.

## Bump this whenever the BASE values change. Older saves get fresh base values on load
## (Global.loadGame) but keep their progression (attributes, level, EXP, points).
const CURRENT_VERSION : int = 2
@export var version : int = 0

#region Attributes and levels

const ATTRIBUTES : Array[String] = ["strength", "vitality", "stamina", "speed", "rogue", "magic", "focus", "luck", "beeness"]
const ATTRIBUTE_NAMES : Dictionary = {
	"strength": "Strength", "vitality": "Vitality", "stamina": "Stamina", "speed": "Speed",
	"rogue": "Rogue", "magic": "Magic", "focus": "Focus", "luck": "Luck", "beeness": "Beeness",
}
const ATTRIBUTE_CAP : int = 100
const LEVEL_CAP : int = 100

@export_category("Progression")
@export var level : int = 1
@export var xp : float = 0
@export var unspent_points : int = 0
## attribute name -> points (0..100). Missing keys count as 0.
@export var attributes : Dictionary = {}
## Beeness unlocks from the rare-bee quest
@export var beeness_unlocked : bool = false

func attr(name: String) -> int:
	return int(attributes.get(name, 0))

func canRaise(name: String) -> bool:
	if unspent_points <= 0 or attr(name) >= ATTRIBUTE_CAP: return false
	if name == "beeness" and not beeness_unlocked: return false
	return true

func raise(name: String) -> bool:
	if not canRaise(name): return false
	attributes[name] = attr(name) + 1
	unspent_points -= 1
	emit_changed()
	return true

# Respec (shopkeeper, later): everything back into the pool
func resetAttributes() -> void:
	var total : int = 0
	for a in ATTRIBUTES: total += attr(a)
	attributes.clear()
	unspent_points += total
	emit_changed()

func expToNext(lvl: int = level) -> float:
	return roundf(40.0 * pow(lvl, 1.5))

# 3 points per level early on, then 2, then 1 to slow progression later
static func pointsForLevel(lvl: int) -> int:
	if lvl <= 10: return 3
	if lvl <= 30: return 2
	return 1

# Returns how many levels were gained
func addExp(amount: float) -> int:
	if level >= LEVEL_CAP or amount <= 0: return 0
	xp += amount
	var gained : int = 0
	while level < LEVEL_CAP and xp >= expToNext():
		xp -= expToNext()
		level += 1
		unspent_points += pointsForLevel(level)
		gained += 1
	if level >= LEVEL_CAP: xp = 0
	if gained > 0: emit_changed()
	return gained

#region Weapon proficiency
# Using a weapon type on enemies levels that type (cap 10, levels slowly). Each level:
# +3% damage, -3% stamina/mana cost, +3% activation speed (swing / fire rate / beam start).
# Separate from attribute points and never reset by a respec.

const PROFICIENCIES : Array[String] = ["melee", "thrown", "projectile", "laser"]
const PROFICIENCY_NAMES : Dictionary = {"melee": "Melee", "thrown": "Thrown", "projectile": "Projectile", "laser": "Laser"}
const PROFICIENCY_CAP : int = 10
const PROF_PER_LEVEL : float = 0.03

## proficiency type -> total proficiency EXP
@export var proficiency : Dictionary = {}

static func profType(w: WeaponItem) -> String:
	if not w: return ""
	match w.animationType:
		WeaponItem.animType.SWING: return "melee"
		WeaponItem.animType.AIM_LASER: return "laser"
		WeaponItem.animType.RANGE: return "thrown" if w.throwable else "projectile"
	return ""

# Total proficiency EXP needed to reach a level: 25, 100, 225 ... 2500 for level 10
static func profXpForLevel(lvl: int) -> float:
	return 25.0 * lvl * lvl

func profXp(t: String) -> float:
	return float(proficiency.get(t, 0.0))

func profLevel(t: String) -> int:
	var xpNow : float = profXp(t)
	var lvl : int = 0
	while lvl < PROFICIENCY_CAP and xpNow >= profXpForLevel(lvl + 1):
		lvl += 1
	return lvl

# Returns the new level if it went up, else 0
func addProficiency(t: String, amount: float) -> int:
	if t == "" or amount <= 0: return 0
	var before : int = profLevel(t)
	if before >= PROFICIENCY_CAP: return 0
	proficiency[t] = profXp(t) + amount
	var after : int = profLevel(t)
	return after if after > before else 0

func profDamageMult(t: String) -> float: return 1.0 + PROF_PER_LEVEL * profLevel(t)
func profCostMult(t: String) -> float: return 1.0 - PROF_PER_LEVEL * profLevel(t)
func profSpeedMult(t: String) -> float: return 1.0 + PROF_PER_LEVEL * profLevel(t)

#endregion

#region Respec

## Price = base + per point spent ("high price"); tune here
const RESPEC_BASE_PRICE : int = 150
const RESPEC_PRICE_PER_POINT : int = 30

func pointsSpent() -> int:
	var total : int = 0
	for a in ATTRIBUTES: total += attr(a)
	return total

func respecPrice() -> int:
	return RESPEC_BASE_PRICE + RESPEC_PRICE_PER_POINT * pointsSpent()

#endregion

# Diminishing curve for percentage stats: 0..100 points -> 0..1.
# The first 50 points give ~65% of the maximum, the last 50 the remaining ~35%.
func dim(name: String) -> float:
	var x : float = clampf(attr(name) / float(ATTRIBUTE_CAP), 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 1.5)

#endregion

#region Base values

@export_category("Base Stats")
@export var base_defense : float = 20
@export var max_health : float = 100
@export var max_stamina : float = 100
@export var stamina_regen : float = 4             # was 5
@export var stamina_exhausted_regen : float = 12  # was 15
@export var stamina_drain : float = 25
## Stamina spent per roll; can't roll while exhausted or without enough stamina
@export var roll_stamina_cost : float = 20
@export var max_mana : float = 100
@export var mana_regen : float = 8                # was 10
## Seconds after spending mana before it starts regenerating
@export var mana_regen_delay : float = 1.0

@export_category("Base Combat")
## Multiplies swing speed and ranged fire rate for the player's weapons
@export var attack_speed : float = 0.8            # was 1.0 (no stat)
## Resistance from the player themselves before Vitality; armour adds on top
@export var knockback_resist : float = 0.0

@export_category("Base Movement")
@export var sprint_speed : float = 12             # was 15
@export var walk_speed : float = 5.6              # was 7
@export var roll_speed : float = 8                # was 10
@export var roll_rot_speed : float = 6            # was 7 (how fast the roll spins / how long it lasts)
## Seconds between rolls
@export var roll_cooldown : float = 2.5           # was 2.0

@export_category("Modifiers")
@export var mod_speed : float = 0

func reset_mods() -> void:
	mod_speed = 0

#endregion

#region Derived stats (what gameplay reads)

# Vitality
func maxHealth() -> float: return max_health + 3.0 * attr("vitality")
func armorEfficiency() -> float: return 1.0 + 0.5 * dim("vitality")          # up to 150% of armour defence
func knockbackResist() -> float: return knockback_resist + 0.35 * dim("vitality") # armour adds on top, total capped at 80%

# Strength (weapon damage comes through scaling grades, see WeaponItem)
func knockbackDealtMult() -> float: return 1.0 + 1.0 * dim("strength")       # up to +100%

# Stamina
func maxStamina() -> float: return max_stamina + 2.0 * attr("stamina")
func staminaRegen() -> float: return stamina_regen * (1.0 + dim("stamina"))   # up to +100%
func exhaustedRegen() -> float: return stamina_exhausted_regen * (1.0 + dim("stamina"))
func rollCooldown() -> float: return roll_cooldown * (1.0 - 0.5 * dim("stamina")) # down to -50%
func rollWindupSpeed() -> float: return 1.0 / (1.0 - 0.5 * dim("stamina"))   # wind-up time down to -50%
func meleeStaminaCostMult() -> float: return 1.0 - 0.5 * dim("stamina")      # down to -50%
func rollStaminaCost() -> float: return roll_stamina_cost * meleeStaminaCostMult()

# Speed
func speedMoveMult() -> float: return 1.0 + 0.4 * dim("speed")               # up to +40%
func walkSpeed() -> float: return walk_speed * speedMoveMult()
func sprintSpeed() -> float: return sprint_speed * speedMoveMult()
func rollSpeed() -> float: return roll_speed * (1.0 + 0.4 * dim("speed"))
func rollRotSpeed() -> float: return roll_rot_speed * (1.0 + 0.4 * dim("speed")) # roll keeps its distance, just faster
func attackSpeed() -> float: return attack_speed * (1.0 + 0.5 * dim("speed")) # swing speed and fire rate, up to +50%

# Rogue / Luck
func critChanceBonus() -> float: return 0.30 * dim("rogue") + 0.05 * dim("luck")
func critDamageBonus() -> float: return 1.5 * dim("rogue")                   # added to the weapon's crit multiplier
func rarityBonus() -> float: return 0.25 * dim("luck")                       # added to item rarity rolls
func dropChanceMult() -> float: return 1.0 + 0.5 * dim("luck")

# Magic
func maxMana() -> float: return max_mana + 2.0 * attr("magic")
func manaRegen() -> float: return mana_regen * (1.0 + dim("magic"))          # up to +100%
func projectileManaCostMult() -> float: return 1.0 - 0.5 * dim("magic")      # down to -50%

# Elements (see StatusEffects)
func elementalPotency() -> float: return 1.0 + 0.5 * dim("magic")          # elemental damage and status damage, up to +50%
func buildupMult() -> float: return 1.0 + 0.5 * dim("luck")                # how fast hits fill status meters, up to +50%
func statusResist() -> float: return 0.3 * dim("vitality")                 # slower buildup, faster meter drain, up to 30%
func meleeResistBonus() -> float: return 0.15 * dim("vitality")            # a little melee resistance, armor adds on top

# Focus
func laserRangeMult() -> float: return 1.0 + 0.5 * dim("focus")              # up to +50%
func beamManaCostMult() -> float: return 1.0 - 0.5 * dim("focus")            # down to -50%
func laserTickMult() -> float: return 1.0 + 0.5 * dim("focus")               # beam damage ticks, up to +50%

#endregion
