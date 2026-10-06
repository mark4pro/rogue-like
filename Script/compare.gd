extends Control

# Hover popup for items (inventory, pickup menu). Lists every stat the item has and, for
# weapons/armour, compares against what's equipped: "Stat: (difference | value)".
# Green = better, red = worse, white = same or not comparable.

@onready var bg : ColorRect = %BG
@onready var nameTxt : Label = %Name
@onready var weapStats : VBoxContainer = %Stats

var item : BaseItem = null

const FONT_UID : String = "uid://dv68j0l4djo44"
const MIN_WIDTH : float = 300

var _font : FontFile = null

# better: 1 = higher is better, -1 = lower is better, 0 = neutral (always white)
func getCompColor(thisValue: float, equippedValue: float, better: int = 1) -> String:
	var comp : float = (thisValue - equippedValue) * better
	var result : Color = Color.WHITE
	if better != 0 and not is_zero_approx(comp):
		result = Color.GREEN if comp > 0 else Color.RED
	return result.to_html()

func fmt(v: float, decimals: int = 2) -> String:
	return str(Global.formatFloat(v, decimals))

func addLine(text: String) -> void:
	var l : RichTextLabel = RichTextLabel.new()
	l.add_theme_font_override("normal_font", _font)
	l.add_theme_font_size_override("normal_font_size", 18)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(MIN_WIDTH, 30)
	l.bbcode_enabled = true
	l.fit_content = true
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = "\t\t" + text
	weapStats.add_child(l)

# One stat row. Pass `equipped` (a number) to show the difference against the equipped item.
func addStat(label: String, value: float, equipped = null, better: int = 1, suffix: String = "", decimals: int = 2) -> void:
	if equipped == null:
		addLine("%s: %s%s" % [label, fmt(value, decimals), suffix])
		return
	var diff : float = value - float(equipped)
	var plus : String = "+" if diff > 0 else ""
	addLine("%s: ([color=%s]%s%s%s[/color] | %s%s)" % [
		label, getCompColor(value, float(equipped), better), plus, fmt(diff, decimals), suffix, fmt(value, decimals), suffix
	])

func addRarityAndPrice() -> void:
	if item.rarity >= 0:
		var r : Dictionary = item.getRarity()
		addLine("Rarity: [color=%s]%s[/color]" % [r.color.to_html(), r.txt])
	addLine("Cost: %s" % fmt(item.cost))

#region Weapons

func weaponKind(w: WeaponItem) -> String:
	match w.animationType:
		WeaponItem.animType.SWING: return "Melee"
		WeaponItem.animType.AIM_LASER: return "Laser"
		WeaponItem.animType.RANGE: return "Thrown" if w.throwable else "Projectile"
	return "Other"

func poolName(w: WeaponItem) -> String:
	return "Stamina" if w.getPool() == WeaponItem.poolType.STAMINA else "Mana"

func poolUnit(w: WeaponItem) -> String:
	match w.animationType:
		WeaponItem.animType.SWING: return " / swing"
		WeaponItem.animType.AIM_LASER: return " / sec"
		WeaponItem.animType.RANGE: return " / throw" if w.throwable else " / volley"
	return ""

func swingsPerSec(w: WeaponItem) -> float:
	return w.swingSpeedMulti / maxf(w.swingDuration, 0.01)

# A property of the item being compared against, or null when there's nothing to compare with
func other(obj: Object, prop: String) -> Variant:
	return obj.get(prop) if obj else null

func addWeapon(w: WeaponItem) -> void:
	var eq : WeaponItem = Global.weapon if Global.weapon and Global.weapon != w else null
	# Type-specific stats only compare against an equipped weapon of the same kind
	var same : WeaponItem = eq if eq and eq.animationType == w.animationType else null
	
	addLine("Type: %s" % weaponKind(w))
	addLine("Scaling: %s" % w.scalingText())
	if not w.getElements().is_empty(): addLine("Elements: %s" % _coloredElements(w))
	
	if eq:
		addLine("Damage: ([color=%s]%s[/color] | %s, [color=%s]%s[/color] | %s)" % [
			getCompColor(w.damage.x, eq.damage.x), fmt(w.damage.x - eq.damage.x), fmt(w.damage.x),
			getCompColor(w.damage.y, eq.damage.y), fmt(w.damage.y - eq.damage.y), fmt(w.damage.y),
		])
	else:
		addLine("Damage: %s - %s" % [fmt(w.damage.x), fmt(w.damage.y)])
	
	var eqCrit = null
	if eq: eqCrit = eq.critChance * 100.0
	addStat("Crit Chance", w.critChance * 100.0, eqCrit, 1, "%", 1)
	addStat("Crit Multiplier", w.critMulti, other(eq, "critMulti"), 1, "x")
	addStat("Knockback", w.knockback, other(eq, "knockback"))
	
	match w.animationType:
		WeaponItem.animType.SWING:
			# swings per second at base speed (before the player's attack speed stat)
			var eqSwings = null
			if same: eqSwings = swingsPerSec(same)
			addStat("Swing Speed", swingsPerSec(w), eqSwings, 1, " / sec")
		WeaponItem.animType.AIM_LASER:
			addStat("Attack Speed", w.laserAttackSpeed, other(same, "laserAttackSpeed"))
			addStat("Range", w.laserRange, other(same, "laserRange"))
		WeaponItem.animType.RANGE:
			addStat("Fire Rate", w.rangeFireSpeed, other(same, "rangeFireSpeed"), 1, " / sec")
			addStat("Projectiles", w.rangeSpawnAmount, other(same, "rangeSpawnAmount"))
			addStat("Spread", w.rangeSpreadAngle, other(same, "rangeSpreadAngle"), 0, " deg")
			addStat("Projectile Speed", w.rangeSpeed, other(same, "rangeSpeed"))
	
	# Pool cost: only comparable when both spend the same pool the same way (lower is better)
	var eqCost = null
	if same and same.getPool() == w.getPool(): eqCost = same.getPoolCost()
	addStat("%s Cost" % poolName(w), w.getPoolCost(), eqCost, -1, poolUnit(w), 1)
	
	if w.throwable and w.stackable: addLine("Amount: %d" % w.quantity)
	addRarityAndPrice()

#endregion

func _coloredElements(w: WeaponItem) -> String:
	var els : Dictionary = w.getElements()
	var parts : PackedStringArray = PackedStringArray()
	for e in els:
		parts.append("[color=%s]%s %d%%[/color]" % [StatusEffects.ELEMENT_COLORS.get(e, Color.WHITE).to_html(), StatusEffects.ELEMENT_NAMES.get(e, e), roundi(float(els[e]) * 100)])
	return ", ".join(parts)

func addArmor(a: ArmorItem) -> void:
	var eq : ArmorItem = Global.armor if Global.armor and Global.armor != a else null
	addStat("Defense", a.defense, other(eq, "defense"))
	var eqResist = null
	if eq: eqResist = eq.getKnockbackResist() * 100.0
	addStat("Knockback Resist", a.getKnockbackResist() * 100.0, eqResist, 1, "%", 1)
	# Every resistance either piece has (kinds first, then elements)
	for key in StatusEffects.DAMAGE_KINDS + StatusEffects.ELEMENTS:
		var mine : float = a.getResist(key)
		var theirs : float = eq.getResist(key) if eq else 0.0
		if is_zero_approx(mine) and is_zero_approx(theirs): continue
		var label : String = StatusEffects.KIND_NAMES.get(key, StatusEffects.ELEMENT_NAMES.get(key, key)) + " Resist"
		var eqVal = null
		if eq: eqVal = theirs * 100.0
		addStat(label, mine * 100.0, eqVal, 1, "%", 0)
	addRarityAndPrice()

func regenStatName(stat: int) -> String:
	match stat:
		RegenPotionItem.regen_stat.HEALTH: return "Health"
		RegenPotionItem.regen_stat.STAMINA: return "Stamina"
		RegenPotionItem.regen_stat.MANA: return "Mana"
	return "?"

func addConsumable() -> void:
	if item is HealthItem:
		addLine("Heals: %s instantly" % fmt(item.healthAmount))
	elif item is RegenPotionItem:
		addLine("Restores: %s %s" % [fmt(item.totalAmount), regenStatName(item.stat)])
		addLine("Over: %ss (%s / sec)" % [fmt(item.duration, 1), fmt(item.totalAmount / maxf(item.duration, 0.01), 1)])
	elif item is SpeedItem:
		addLine("Speed: +%s for 5s" % fmt(item.speed)) # the player's speedTimer winds it back down
	elif item is SprintItem:
		addLine("Stamina Regen: +%s / sec" % fmt(item.stamina))
		addLine("Lasts: %ss" % fmt(item.duration, 1))
	if item.stackable: addLine("Amount: %d" % item.quantity)
	addRarityAndPrice()

func _ready() -> void:
	global_position = get_global_mouse_position()
	_font = load(FONT_UID) as FontFile
	
	if item:
		nameTxt.text = " Name: " + Mutation.displayName(item)
		if Mutation.isMutated(item):
			nameTxt.add_theme_color_override("font_color", Mutation.textColor(item))
			addLine("[color=%s]Mutation: %s[/color]" % [Mutation.textColor(item).to_html(), Mutation.describe(item)])
		
		if item is WeaponItem:
			addWeapon(item)
		elif item is ArmorItem:
			addArmor(item)
		else:
			addConsumable()
	_fit()

func _fit() -> void:
	var w : float = MIN_WIDTH
	for c in weapStats.get_children():
		if c is Control: w = maxf(w, c.get_combined_minimum_size().x + 10)
	bg.size.x = w # the name label is anchored to stretch with the background
	weapStats.size.x = w
	bg.size.y = weapStats.size.y + 30

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	_fit()
