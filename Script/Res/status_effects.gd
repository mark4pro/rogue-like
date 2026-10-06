extends RefCounted
class_name StatusEffects

# Elements, damage resolution and status effects, shared by the player and enemies.
#
# A hit carries physical damage (reduced by defense and the melee/projectile/laser resistance)
# plus elemental damage per element (reduced by that element's resistance). Elemental damage
# also fills a status meter per element; when a meter fills, its status triggers:
#
#   Fire   -> Burn     damage over time (Wet puts it out instead)
#   Water  -> Wet      primes: puts out Burn, Wet + Ice = Freeze, Wet + Shock = burst damage
#   Ice    -> Chill    slows; a second trigger while Chilled (or Wet) = Freeze (can't move/attack)
#   Shock  -> Stun     short stun, chains to nearby enemies
#   Shadow -> Weaken   deals less damage
#   Acid   -> Blind    smaller vision (darker screen for the player) + corrosion that refreshes
#   Slime  -> Sticky   slows
#   Venom  -> Poison   stacking damage over time (bee weapons, scales with Beeness)
#
# Hosts (player, enemy) implement: getMaxHealth(), getDefense(), getResist(key), statusResist(),
# applyHitstun(s), take_damage(data, attacker), and have `sprite` for the tint.

const ELEMENTS : Array[String] = ["fire", "water", "ice", "shock", "shadow", "acid", "slime", "venom"]
const ELEMENT_NAMES : Dictionary = {
	"fire": "Fire", "water": "Water", "ice": "Ice", "shock": "Shock",
	"shadow": "Shadow", "acid": "Acid", "slime": "Slime", "venom": "Venom",
}
const ELEMENT_COLORS : Dictionary = {
	"fire": Color(1.0, 0.5, 0.15), "water": Color(0.3, 0.55, 1.0), "ice": Color(0.6, 0.92, 1.0),
	"shock": Color(1.0, 0.95, 0.3), "shadow": Color(0.62, 0.4, 0.9), "acid": Color(0.65, 0.88, 0.2),
	"slime": Color(0.45, 0.82, 0.3), "venom": Color(0.85, 0.92, 0.1),
}
## Physical resistance keys (which kind of hit), alongside the elements
const DAMAGE_KINDS : Array[String] = ["melee", "projectile", "laser"]
const KIND_NAMES : Dictionary = {"melee": "Melee", "projectile": "Projectile", "laser": "Laser"}

const RESIST_CAP : float = 0.6
const WEAKNESS_CAP : float = -0.5

#region Tuning
const METER_MAX : float = 100.0
const BUILDUP_SCALE : float = 120.0   # meter per hit = elemental damage dealt / target max HP * this (~3 strong elemental hits)
const METER_DECAY : float = 12.0      # meter drained per second (faster with status resistance)
const DOT_TICK : float = 0.5          # seconds between damage-over-time ticks

const BURN_TIME : float = 4.0
const BURN_DPS : float = 0.03         # of max HP per second
const WET_TIME : float = 6.0
const CHILL_TIME : float = 4.0
const CHILL_SLOW : float = 0.4
const FREEZE_TIME : float = 1.5
const STUN_TIME : float = 0.8
const CHAIN_RANGE : float = 70.0
const CHAIN_TARGETS : int = 2
const CHAIN_SHARE : float = 0.5       # chained targets take this share of the triggering hit
const WET_SHOCK_BURST : float = 0.08  # of max HP
const WEAKEN_TIME : float = 5.0
const WEAKEN_MULT : float = 0.7       # weakened targets deal 30% less
const BLIND_TIME : float = 5.0
const BLIND_VISION : float = 0.4
const CORRODE_DPS : float = 0.02
const STICKY_TIME : float = 4.0
const STICKY_SLOW : float = 0.35
const POISON_TIME : float = 6.0
const POISON_DPS_PER_STACK : float = 0.01
const POISON_MAX_STACKS : int = 5
#endregion

var host : Node = null
var meters : Dictionary = {}    # element -> 0..METER_MAX
var timers : Dictionary = {}    # status -> seconds left
var potency : Dictionary = {}   # status -> damage multiplier from the attacker (Magic, Beeness)
var poisonStacks : int = 0
var dotSource : Node = null
var _dotTimer : float = 0.0

func _init(h: Node) -> void:
	host = h

#region Damage resolution

# What a hit actually deals to `target`. Returns {"total": float, "elements": {element: dealt}}.
# Status damage (burn ticks, bursts) has data.status = true and ignores defense and resistances.
static func resolveHit(data: Dictionary, target: Node) -> Dictionary:
	if data.get("status", false):
		return {"total": float(data.value), "elements": {}}
	var physical : float = float(data.get("physical", data.value))
	var kind : String = data.get("kind", "")
	if kind != "": physical *= 1.0 - target.getResist(kind)
	physical *= 100.0 / (100.0 + maxf(target.getDefense(), -50.0))
	var dealt : Dictionary = {}
	var total : float = maxf(physical, 0.0)
	var els : Dictionary = data.get("elements", {})
	for e in els:
		var amt : float = maxf(float(els[e]) * (1.0 - target.getResist(e)), 0.0)
		dealt[e] = amt
		total += amt
	return {"total": total, "elements": dealt}

static func clampResist(v: float) -> float:
	return clampf(v, WEAKNESS_CAP, RESIST_CAP)

# The element doing most of this hit's damage (for the damage number colour), or ""
static func dominantElement(dealt: Dictionary, physical: float) -> String:
	var best : String = ""
	var bestAmt : float = physical
	for e in dealt:
		if dealt[e] > bestAmt:
			best = e
			bestAmt = dealt[e]
	return best

#endregion

#region Buildup and triggers

func addBuildup(element: String, dealt: float, st: stats, attacker: Node) -> void:
	if dealt <= 0.0 or not ELEMENTS.has(element): return
	var amount : float = dealt / maxf(host.getMaxHealth(), 1.0) * BUILDUP_SCALE
	if st: amount *= st.buildupMult()
	amount *= 1.0 - host.statusResist()
	if element == "ice" and has("wet"): amount *= 2.0 # ice takes faster on wet targets
	meters[element] = float(meters.get(element, 0.0)) + amount
	if meters[element] >= METER_MAX:
		meters[element] = 0.0
		trigger(element, st, attacker, dealt)

func has(status: String) -> bool:
	return float(timers.get(status, 0.0)) > 0.0

func trigger(element: String, st: stats, attacker: Node, dealt: float) -> void:
	var pot : float = st.elementalPotency() if st else 1.0
	match element:
		"fire":
			if has("wet"):
				timers.erase("wet") # water puts the fire out
				popup("Fizzle", element)
				return
			timers["burn"] = BURN_TIME
			potency["burn"] = pot
			dotSource = attacker
			popup("Burn", element)
		"water":
			timers["wet"] = WET_TIME
			if has("burn"): timers.erase("burn")
			popup("Wet", element)
		"ice":
			if has("chill") or has("wet"):
				timers.erase("chill")
				timers.erase("wet")
				timers["freeze"] = FREEZE_TIME
				host.applyHitstun(FREEZE_TIME)
				popup("Freeze", element)
			else:
				timers["chill"] = CHILL_TIME
				popup("Chill", element)
		"shock":
			host.applyHitstun(STUN_TIME)
			timers["stun"] = STUN_TIME # for the visuals
			popup("Stun", element)
			if has("wet"):
				timers.erase("wet")
				host.take_damage({"value": host.getMaxHealth() * WET_SHOCK_BURST * pot, "isCrit": true, "status": true, "color": ELEMENT_COLORS.shock}, attacker)
			_chain(dealt, attacker)
		"shadow":
			timers["weaken"] = WEAKEN_TIME
			popup("Weaken", element)
		"acid":
			timers["blind"] = BLIND_TIME
			potency["blind"] = pot
			dotSource = attacker
			popup("Blind", element)
		"slime":
			timers["sticky"] = STICKY_TIME
			popup("Sticky", element)
		"venom":
			poisonStacks = mini(poisonStacks + 1, POISON_MAX_STACKS)
			timers["poison"] = POISON_TIME
			var bee : float = 1.0 + (st.dim("beeness") if st else 0.0)
			potency["poison"] = pot * bee
			dotSource = attacker
			popup("Poison x%d" % poisonStacks, element)

# Shock jumps to the nearest others of the same side (enemies chain to enemies)
func _chain(dealt: float, attacker: Node) -> void:
	if not host.is_in_group("enemies"): return
	var hostPos : Vector2 = host.global_position
	var others : Array = host.get_tree().get_nodes_in_group("enemies").filter(func(o):
		return o != host and is_instance_valid(o) and o.global_position.distance_to(hostPos) <= CHAIN_RANGE)
	others.sort_custom(func(a, b): return a.global_position.distance_to(hostPos) < b.global_position.distance_to(hostPos))
	for i in mini(CHAIN_TARGETS, others.size()):
		var o : Node = others[i]
		o.take_damage({"value": dealt * CHAIN_SHARE, "isCrit": false, "status": true, "color": ELEMENT_COLORS.shock}, attacker)
		o.applyHitstun(STUN_TIME * 0.5)
		if "statusFx" in o and o.statusFx:
			o.statusFx.timers["stun"] = maxf(float(o.statusFx.timers.get("stun", 0.0)), STUN_TIME * 0.5)

#endregion

#region Per frame

func process(delta: float) -> void:
	var drain : float = METER_DECAY * (1.0 + host.statusResist()) * delta
	for e in meters.keys():
		meters[e] = maxf(float(meters[e]) - drain, 0.0)
	for s in timers.keys():
		timers[s] = float(timers[s]) - delta
		if timers[s] <= 0.0:
			timers.erase(s)
			if s == "poison": poisonStacks = 0
	
	_dotTimer -= delta
	if _dotTimer <= 0.0:
		_dotTimer = DOT_TICK
		var dps : float = 0.0
		var color : Color = Color.WHITE
		if has("burn"):
			dps += BURN_DPS * float(potency.get("burn", 1.0))
			color = ELEMENT_COLORS.fire
		if has("blind"):
			dps += CORRODE_DPS * float(potency.get("blind", 1.0))
			color = ELEMENT_COLORS.acid
		if has("poison"):
			dps += POISON_DPS_PER_STACK * poisonStacks * float(potency.get("poison", 1.0))
			color = ELEMENT_COLORS.venom
		if dps > 0.0:
			var src : Node = dotSource if is_instance_valid(dotSource) else null
			host.take_damage({"value": host.getMaxHealth() * dps * DOT_TICK, "isCrit": false, "status": true, "color": color}, src)
	
	_visuals(delta)

func speedMult() -> float:
	var m : float = 1.0
	if has("chill"): m *= 1.0 - CHILL_SLOW
	if has("sticky"): m *= 1.0 - STICKY_SLOW
	return m

func damageDealtMult() -> float:
	return WEAKEN_MULT if has("weaken") else 1.0

func visionMult() -> float:
	return BLIND_VISION if has("blind") else 1.0

func blindAmount() -> float:
	return clampf(float(timers.get("blind", 0.0)) / 0.5, 0.0, 1.0) # fades out over the last half second

# Particles and sprite tint per status (see status_visuals.gd)
var visuals : StatusVisuals = null

func _visuals(delta: float) -> void:
	if not visuals: visuals = StatusVisuals.new(self)
	visuals.update(delta)

func popup(text: String, element: String) -> void:
	if not Global.currentScene or not Global.damNum: return
	var l : Label = Global.damNum.instantiate()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", ELEMENT_COLORS.get(element, Color.WHITE))
	l.position = host.global_position + Vector2(randf_range(-6, 6), -22)
	Global.currentScene.add_child(l)

#endregion
