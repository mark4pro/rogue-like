extends RefCounted
class_name Mutation

# Mutated weapons: a rare roll (CHANCE, a little more with Luck) when a weapon rolls its stats.
# A mutation picks a random strain, which decides both its colour palette and its effect, then
# adds random stat boosts on top. The strain colour is jittered a little so no two look the same.
#
#   Elemental strains  the element's colour, +35% of that element on every hit
#   Gilded             gold, much higher crit chance, worth a lot more
#   Feral              crimson, a lot more damage and knockback
#   Void               deep violet, much bigger crits
#   Prismatic          very rare, rainbow, everything a bit better
#
# Only non-stacking weapons mutate (thrown stacks would merge with normal ones by name).
# Everything is stored on the weapon (WeaponItem.mutation...), so it saves with it.

const CHANCE : float = 0.06
const LUCK_CHANCE : float = 0.1   # x the player's rarity luck (up to +2.5%)
const ELEMENT_SHARE : float = 0.35
const SHADER : Shader = preload("res://Assets/shaders/mutation.gdshader")

const STRAINS : Dictionary = {
	"fire": {"name": "Blazing", "weight": 7, "element": "fire"},
	"water": {"name": "Tidal", "weight": 7, "element": "water"},
	"ice": {"name": "Frozen", "weight": 7, "element": "ice"},
	"shock": {"name": "Charged", "weight": 7, "element": "shock"},
	"shadow": {"name": "Umbral", "weight": 7, "element": "shadow"},
	"acid": {"name": "Corrosive", "weight": 7, "element": "acid"},
	"slime": {"name": "Oozing", "weight": 7, "element": "slime"},
	"venom": {"name": "Venomous", "weight": 5, "element": "venom"},
	"gilded": {"name": "Gilded", "weight": 10, "color": Color(1.0, 0.78, 0.22)},
	"feral": {"name": "Feral", "weight": 10, "color": Color(0.82, 0.1, 0.14)},
	"void": {"name": "Void", "weight": 10, "color": Color(0.36, 0.14, 0.62)},
	"prismatic": {"name": "Prismatic", "weight": 3, "color": Color(1, 1, 1)},
}

# Not the weapon files themselves (enemies roll their shared weapon resource), only real copies
static func canMutate(w: WeaponItem) -> bool:
	return w != null and not w.stackable and w.mutation == "" and w.resource_path == ""

# Called at the end of WeaponItem.rollStats
static func roll(w: WeaponItem, rng: RandomNumberGenerator) -> void:
	if not canMutate(w): return
	if rng.randf() >= CHANCE + Global.rarityRollBonus() * LUCK_CHANCE: return
	apply(w, _pickStrain(rng), rng)

static func _pickStrain(rng: RandomNumberGenerator) -> String:
	var total : float = 0.0
	for k in STRAINS: total += STRAINS[k].weight
	var r : float = rng.randf() * total
	for k in STRAINS:
		r -= STRAINS[k].weight
		if r <= 0.0: return k
	return STRAINS.keys().back()

# Mutates `w` with a strain (random if ""). Also used for testing / future quest rewards.
static func apply(w: WeaponItem, strain: String = "", rng: RandomNumberGenerator = null) -> void:
	if not rng:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if strain == "" or not STRAINS.has(strain): strain = _pickStrain(rng)
	var s : Dictionary = STRAINS[strain]
	var notes : PackedStringArray = PackedStringArray()
	
	# Colour: the strain's colour, nudged a little so each one is its own
	var base : Color = s.get("color", StatusEffects.ELEMENT_COLORS.get(s.get("element", ""), Color.WHITE))
	var h : float = fposmod(base.h + rng.randf_range(-0.035, 0.035), 1.0)
	w.mutationColor = Color.from_hsv(h, clampf(base.s * rng.randf_range(0.85, 1.1), 0.0, 1.0), clampf(base.v * rng.randf_range(0.9, 1.05), 0.0, 1.0))
	w.mutationSeed = rng.randf()
	w.mutation = strain
	
	# Strain effect
	match strain:
		"gilded":
			var c : float = rng.randf_range(0.08, 0.15)
			w.critChance += c
			w.cost = roundi(w.cost * 2.0)
			notes.append("+%d%% crit chance" % roundi(c * 100))
		"feral":
			var d : float = rng.randf_range(0.2, 0.35)
			w.damage *= 1.0 + d
			w.knockback *= 1.5
			notes.append("+%d%% damage, +50%% knockback" % roundi(d * 100))
		"void":
			var m : float = rng.randf_range(0.6, 1.2)
			w.critMulti += m
			notes.append("+%sx crit damage" % str(snappedf(m, 0.1)))
		"prismatic":
			w.damage *= 1.2
			w.critChance *= 1.2
			w.critMulti *= 1.2
			w.knockback *= 1.2
			notes.append("+20% to every stat")
		_:
			w.mutationElement = s.element
			notes.append("+%d%% %s" % [roundi(ELEMENT_SHARE * 100), StatusEffects.ELEMENT_NAMES[s.element]])
	
	# Random boosts on top: always more damage, sometimes one more stat
	var dmg : float = rng.randf_range(0.15, 0.35)
	w.damage *= 1.0 + dmg
	notes.append("+%d%% damage" % roundi(dmg * 100))
	if rng.randf() < 0.5:
		match rng.randi_range(0, 2):
			0:
				var c2 : float = rng.randf_range(0.05, 0.1)
				w.critChance += c2
				notes.append("+%d%% crit chance" % roundi(c2 * 100))
			1:
				var m2 : float = rng.randf_range(0.3, 0.7)
				w.critMulti += m2
				notes.append("+%sx crit damage" % str(snappedf(m2, 0.1)))
			2:
				var k : float = rng.randf_range(0.3, 0.7)
				w.knockback *= 1.0 + k
				notes.append("+%d%% knockback" % roundi(k * 100))
	w.cost = roundi(w.cost * 1.5)
	w.shopPrice = w.cost - roundi(w.cost * 0.15)
	w.mutationNotes = notes

#region Display

static func isMutated(item) -> bool:
	return item is WeaponItem and item.mutation != ""

static func strainName(item) -> String:
	return STRAINS.get(item.mutation, {}).get("name", "Mutated") if isMutated(item) else ""

# "Mutated Purple Sword" (plain text)
static func displayName(item: BaseItem) -> String:
	return ("Mutated " + item.name) if isMutated(item) else item.name

# Colour used for the word "Mutated" in text (prismatic shows white)
static func textColor(item) -> Color:
	if not isMutated(item): return Color.WHITE
	return item.mutationColor.lightened(0.25)

# BBCode name: "Mutated" in the mutation colour, the name in its rarity colour
static func nameBB(item: BaseItem) -> String:
	var n : String = "[color=%s]%s[/color]" % [item.getRarity().color.to_html(), item.name]
	if not isMutated(item): return n
	return "[color=%s]Mutated[/color] %s" % [textColor(item).to_html(), n]

# "Blazing: +35% Fire, +24% damage"
static func describe(item) -> String:
	if not isMutated(item): return ""
	return "%s: %s" % [strainName(item), ", ".join(item.mutationNotes)]

#endregion

#region Visuals

static var _mats : Dictionary = {} # item instance id -> ShaderMaterial

static func materialFor(item: WeaponItem) -> ShaderMaterial:
	var id : int = item.get_instance_id()
	if _mats.has(id): return _mats[id]
	var m : ShaderMaterial = ShaderMaterial.new()
	m.shader = SHADER
	_setParams(m, item)
	_mats[id] = m
	return m

const DROP_SHADOW : Shader = preload("res://Assets/shaders/drop_shadow.gdshader")
const SHADOW_SHADER : Shader = preload("res://Assets/shaders/mutation_shadow.gdshader")

# One sprite / icon. Clears our material again when the item isn't mutated.
# Sprites using the drop shadow get the drop shadow + mutation shader with the same settings.
static func applyTo(ci: CanvasItem, item) -> void:
	if not ci: return
	var cur : Material = ci.material
	if isMutated(item):
		if cur and cur.has_meta("mutation_mat") and cur.get_meta("mutation_item", 0) == item.get_instance_id():
			return # already done
		if cur and cur.has_meta("mutation_mat"):
			cur = cur.get_meta("orig_mat", null) # was mutated for another item: start from the original
		if cur is ShaderMaterial and cur.shader == DROP_SHADOW:
			var m : ShaderMaterial = ShaderMaterial.new()
			m.shader = SHADOW_SHADER
			for u in DROP_SHADOW.get_shader_uniform_list():
				m.set_shader_parameter(u.name, cur.get_shader_parameter(u.name))
			_setParams(m, item)
			m.set_meta("orig_mat", cur)
			ci.material = m
		elif cur == null:
			ci.material = materialFor(item)
		# any other custom material is left alone
	elif cur and cur.has_meta("mutation_mat"):
		ci.material = cur.get_meta("orig_mat", null)

static func _setParams(m: ShaderMaterial, item: WeaponItem) -> void:
	m.set_shader_parameter("base_color", item.mutationColor)
	m.set_shader_parameter("prismatic", item.mutation == "prismatic")
	m.set_shader_parameter("seed", item.mutationSeed)
	m.set_meta("mutation_mat", true)
	m.set_meta("mutation_item", item.get_instance_id())

# A whole weapon scene (swung weapon, bullet, placed torch): every sprite, and lasers get the colour
static func applyTree(root: Node, item) -> void:
	if not root or not isMutated(item): return
	var nodes : Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		if n is Sprite2D or n is AnimatedSprite2D or n is TextureRect:
			applyTo(n, item)
		elif n is Line2D:
			_tintLine(n, item)

static func _tintLine(l: Line2D, item: WeaponItem) -> void:
	var c : Color = item.mutationColor
	if item.mutation == "prismatic": c = Color.from_hsv(item.mutationSeed, 0.75, 1.0)
	if l.gradient:
		var g : Gradient = l.gradient.duplicate()
		for i in g.get_point_count():
			var old : Color = g.get_color(i)
			var shade : Color = c.darkened(0.45) if i == 0 else c
			g.set_color(i, Color(shade, old.a))
		l.gradient = g
	else:
		l.default_color = Color(c, l.default_color.a)

#endregion
