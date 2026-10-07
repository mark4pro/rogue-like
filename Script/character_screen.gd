extends Control
class_name CharacterScreen

# Third inventory page (Inventory / Pickup / Character), also opened with the "character" key.
# Left: level, EXP, points to spend and a + per attribute. Right: every stat as base -> final with
# where the bonus comes from, plus the equipped weapon and armor.
# Built in code; sits in the player's inventoryUI CanvasLayer like the other pages.

const FONT_UID : String = "uid://dv68j0l4djo44"
const BG_COLOR : Color = Color(0.21, 0.16534, 0.1491, 1)
const MENU_SIZE : Vector2 = Vector2(1000, 600)
const UP_COLOR : String = "#9be564"   # improved by stats
const SRC_COLOR : String = "#b8a99a"  # "(+15 Vitality)"

var st : stats = null
var _font : FontFile = null

#region Hover tips
# Shown when hovering an attribute name or any stat line. "Up to" values are at 100 points
# (the first 50 points give about two thirds of it, see stats.dim).
const ATTRIBUTE_TIPS : Dictionary = {
	"strength": "Strength: up to +60% melee and thrown damage,\nand weapons with Strength scaling hit harder.\nUp to +100% knockback dealt.",
	"vitality": "Vitality: +3 max HP per point.\nUp to 150% armor defense, +35% knockback resist,\n+30% status resist and +15% melee resist.",
	"stamina": "Stamina: +2 max stamina per point.\nUp to +100% stamina regen, and up to -50% roll cooldown,\nroll wind-up, roll cost and melee stamina cost.",
	"speed": "Speed: up to +40% walk, sprint and roll speed,\nand up to +50% attack speed (swings and fire rate).",
	"rogue": "Rogue: up to +30% crit chance and +1.5x crit damage.\nWeapons with Rogue scaling hit harder.",
	"magic": "Magic: +2 max mana per point. Up to +60% projectile\nand +50% laser damage, +100% mana regen,\n-50% projectile mana cost and +50% elemental and status damage.",
	"focus": "Focus: lasers. Up to +100% laser damage, +50% range,\n+50% tick speed and -50% beam mana cost.",
	"luck": "Luck: better item rarity, up to +50% drop chance,\n+50% status buildup and a little crit chance.",
	"beeness": "Beeness: makes your venom poison much stronger.",
}

const STAT_TIPS : Dictionary = {
	"Max HP": "How much damage you can take. Vitality adds 3 per point.",
	"Max Stamina": "Spent by sprinting, rolling, melee swings and thrown weapons.",
	"Stamina Regen": "Stamina recovered per second while not sprinting.",
	"Max Mana": "Spent by projectiles and lasers.",
	"Mana Regen": "Mana recovered per second, a moment after you last cast.",
	"Walk Speed": "How fast you move normally.",
	"Sprint Speed": "How fast you move while sprinting (drains stamina).",
	"Roll Speed": "How fast a roll carries you. You can't be hit while rolling.",
	"Roll Cooldown": "Seconds before you can roll again.",
	"Roll Cost": "Stamina spent per roll.",
	"Attack Speed": "Multiplies swing speed and fire rate.",
	"Knockback Dealt": "How hard your hits push enemies.",
	"Knockback Resist": "How much less you get pushed (capped at 80% with armor).",
	"Bonus Crit Chance": "Added to every weapon's crit chance (capped at 60%).",
	"Bonus Crit Damage": "Added to every weapon's crit multiplier.",
	"Elemental Potency": "Multiplies elemental damage and status damage (burn, poison...).",
	"Status Buildup": "How fast your elemental hits fill enemies' status meters.",
	"Status Resist": "Status meters fill slower on you and drain faster.",
	"Rarity Luck": "Added to item rarity rolls: rarer drops and shop items.",
	"Drop Chance": "Multiplies the chance enemies drop items.",
	"Damage": "Damage range per hit, before the target's defense and resistances.",
	"Scaling": "Which attributes make this weapon hit harder.\nS is the best grade, E the weakest.",
	"Elements": "Share of each hit dealt as an element. Fills status meters.",
	"Crit Chance": "Chance for a hit to crit.",
	"Crit Multiplier": "Crits deal this many times the damage.",
	"Knockback": "How hard this weapon pushes enemies.",
	"Stamina Cost": "Stamina spent per swing or throw.",
	"Mana Cost": "Mana spent per volley, or per second for lasers.",
	"Range": "How far the beam reaches.",
	"Tick Speed": "How often the beam deals damage.",
	"Fire Rate": "Volleys per second.",
	"Swings": "Swings per second.",
	"Defense": "Reduces physical damage taken (100 defense = half damage).",
	"Resist": "Less damage of this kind or element (capped at 60%). Negative is a weakness.",
	"Mutation": "Mutated weapons are recoloured and boosted. The strain decides the effect.",
	"Proficiency": "Using a weapon type on enemies levels it (max 5).\nEach level: +6% damage, -6% cost, +6% speed.",
	"Projectiles": "Multi-shot weapons split their damage: a whole volley\nlanding on one target is worth 1.6 single shots.",
}

# Wraps a stat name in a hover hint if there's a tip for it (element-coloured names included)
func tipped(statName: String) -> String:
	var plain : String = statName
	var rx : RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
	plain = rx.sub(plain, "", true)
	var tip : String = STAT_TIPS.get(plain, "")
	if tip == "" and plain.ends_with(" Resist") and plain != "Knockback Resist" and plain != "Status Resist":
		tip = STAT_TIPS.Resist
	if tip == "": return statName
	return tipped_raw(statName, tip)

func tipped_raw(text: String, tip: String) -> String:
	# Quoted, so apostrophes in the tip don't end it early
	return "[hint=\"%s\"]%s[/hint]" % [tip.replace("]", ")").replace("[", "(").replace("\"", "'"), text]
#endregion

var _levelLbl : Label
var _expBar : ProgressBar
var _expLbl : Label
var _pointsLbl : Label
var _rows : Dictionary = {} # attribute -> {value: Label, plus: Button}
var _details : RichTextLabel
var _refreshT : float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_UID) as FontFile
	st = Global.playerStats
	
	# Same footprint and look as the Inventory page
	set_anchors_preset(Control.PRESET_CENTER)
	position = get_viewport_rect().size / 2 + Vector2(-520, -320)
	modulate = Color(1, 1, 1, 0.5647059)
	
	var bg : ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.size = MENU_SIZE
	add_child(bg)
	
	var title : Label = _label("Character", 64)
	title.size = Vector2(MENU_SIZE.x, 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(title)
	
	# --- Left column: level and attributes
	var left : VBoxContainer = VBoxContainer.new()
	left.position = Vector2(30, 80)
	left.size = Vector2(430, 500)
	left.add_theme_constant_override("separation", 4)
	bg.add_child(left)
	
	_levelLbl = _label("", 30)
	left.add_child(_levelLbl)
	
	_expBar = ProgressBar.new()
	_expBar.custom_minimum_size = Vector2(420, 22)
	_expBar.show_percentage = false
	var fill : StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.7, 0.2)
	var back : StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.08, 0.07)
	_expBar.add_theme_stylebox_override("fill", fill)
	_expBar.add_theme_stylebox_override("background", back)
	left.add_child(_expBar)
	
	_expLbl = _label("", 18)
	left.add_child(_expLbl)
	
	_pointsLbl = _label("", 24)
	left.add_child(_pointsLbl)
	
	for a in stats.ATTRIBUTES:
		var row : HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(420, 34)
		var nameLbl : Label = _label(stats.ATTRIBUTE_NAMES[a], 24)
		nameLbl.custom_minimum_size = Vector2(180, 0)
		nameLbl.tooltip_text = ATTRIBUTE_TIPS.get(a, "")
		nameLbl.mouse_filter = Control.MOUSE_FILTER_PASS
		nameLbl.mouse_default_cursor_shape = Control.CURSOR_HELP
		var valueLbl : Label = _label("", 24)
		valueLbl.custom_minimum_size = Vector2(150, 0)
		var plus : Button = Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(44, 32)
		plus.add_theme_font_override("font", _font)
		plus.add_theme_font_size_override("font_size", 24)
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(_on_plus.bind(a))
		row.add_child(nameLbl)
		row.add_child(valueLbl)
		row.add_child(plus)
		left.add_child(row)
		_rows[a] = {"value": valueLbl, "plus": plus, "row": row}
	
	# --- Right column: stat breakdown
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(490, 80)
	scroll.size = Vector2(490, 505)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.custom_minimum_size = Vector2(470, 0)
	# Every style slot uses Tiny5 so [b] headings don't fall back to the default font
	for slot in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		_details.add_theme_font_override(slot, _font)
	for slot in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		_details.add_theme_font_size_override(slot, 18)
	_details.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_details)
	
	refresh()

func _label(text: String, fontSize: int) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fontSize)
	return l

func _on_plus(a: String) -> void:
	# Shift-click spends 5 at once
	var times : int = 5 if Input.is_key_pressed(KEY_SHIFT) else 1
	for i in times:
		if not st.raise(a): break
	refresh()

func _process(delta: float) -> void:
	if not visible: return
	if st != Global.playerStats: st = Global.playerStats
	_refreshT -= delta
	if _refreshT <= 0.0:
		_refreshT = 0.25
		refresh()

#region Text helpers

func fmt(v: float, decimals: int = 1) -> String:
	return str(Global.formatFloat(v, decimals))

func pct(v: float) -> String:
	return "%s%%" % fmt(v * 100.0)

# "Name: base -> final (+x Source)" or just "Name: value" when nothing changes it
func line(statName: String, base: float, final: float, source: String = "", isPct: bool = false, suffix: String = "") -> String:
	statName = tipped(statName)
	var b : String = (pct(base) if isPct else fmt(base)) + suffix
	var f : String = (pct(final) if isPct else fmt(final)) + suffix
	if is_equal_approx(base, final):
		return "%s: %s\n" % [statName, b]
	var src : String = " [color=%s](%s)[/color]" % [SRC_COLOR, source] if source != "" else ""
	return "%s: %s -> [color=%s]%s[/color]%s\n" % [statName, b, UP_COLOR, f, src]

#endregion

func refresh() -> void:
	if not st: return
	
	# Left column
	_levelLbl.text = "Level %d%s" % [st.level, "  (max)" if st.level >= stats.LEVEL_CAP else ""]
	var need : float = st.expToNext()
	_expBar.max_value = need
	_expBar.value = st.xp
	_expLbl.text = "EXP %s / %s" % [fmt(st.xp, 0), fmt(need, 0)] if st.level < stats.LEVEL_CAP else "EXP maxed"
	_pointsLbl.text = "Points to spend: %d" % st.unspent_points
	_pointsLbl.add_theme_color_override("font_color", Color.GOLD if st.unspent_points > 0 else Color.WHITE)
	
	for a in _rows:
		var r : Dictionary = _rows[a]
		# Beeness stays hidden until the rare-bee quest unlocks it
		r.row.visible = a != "beeness" or st.beeness_unlocked
		r.value.text = "%d / %d" % [st.attr(a), stats.ATTRIBUTE_CAP]
		r.plus.disabled = not st.canRaise(a)
	
	_details.text = _bodyText() + "\n" + _profText() + "\n" + _weaponText() + "\n" + _armorText()

func _bodyText() -> String:
	var t : String = "[b]Body[/b]\n"
	var hpSrc : String = "+%d level, +%d Vitality" % [roundi(st.max_health * (st.levelHealthMult() - 1.0)), 3 * st.attr("vitality")]
	t += line("Max HP", st.max_health, st.maxHealth(), hpSrc)
	t += line("Max Stamina", st.max_stamina, st.maxStamina(), "+%d Stamina" % (2 * st.attr("stamina")))
	t += line("Stamina Regen", st.stamina_regen, st.staminaRegen(), "Stamina", false, " / sec")
	t += line("Max Mana", st.max_mana, st.maxMana(), "+%d Magic" % (2 * st.attr("magic")))
	t += line("Mana Regen", st.mana_regen, st.manaRegen(), "Magic", false, " / sec")
	t += line("Walk Speed", st.walk_speed, st.walkSpeed(), "Speed")
	t += line("Sprint Speed", st.sprint_speed, st.sprintSpeed(), "Speed")
	t += line("Roll Speed", st.roll_speed, st.rollSpeed(), "Speed")
	t += line("Roll Cooldown", st.roll_cooldown, st.rollCooldown(), "Stamina", false, "s")
	t += line("Roll Cost", st.roll_stamina_cost, st.rollStaminaCost(), "Stamina")
	t += line("Attack Speed", st.attack_speed, st.attackSpeed(), "Speed", true)
	t += line("Knockback Dealt", 1.0, st.knockbackDealtMult(), "Strength", true)
	t += line("Knockback Resist", st.knockback_resist, st.knockbackResist(), "Vitality, before armor", true)
	t += line("Bonus Crit Chance", 0.0, st.critChanceBonus(), "Rogue, Luck", true)
	t += line("Bonus Crit Damage", 0.0, st.critDamageBonus(), "Rogue", false, "x")
	t += line("Elemental Potency", 1.0, st.elementalPotency(), "Magic", true)
	t += line("Status Buildup", 1.0, st.buildupMult(), "Luck", true)
	t += line("Status Resist", 0.0, st.statusResist(), "Vitality", true)
	t += line("Rarity Luck", 0.0, st.rarityBonus(), "Luck")
	t += line("Drop Chance", 1.0, st.dropChanceMult(), "Luck", true)
	return t

func _profText() -> String:
	var t : String = "[b]%s[/b]\n" % tipped_raw("Weapon Proficiency", STAT_TIPS.Proficiency)
	for p in stats.PROFICIENCIES:
		var lvl : int = st.profLevel(p)
		var bonus : String = ""
		if lvl > 0:
			bonus = ", +%s damage, -%s cost, +%s speed" % [pct(st.profDamageMult(p) - 1.0), pct(1.0 - st.profCostMult(p)), pct(st.profSpeedMult(p) - 1.0)]
		if lvl >= stats.PROFICIENCY_CAP:
			t += "%s: %d (max) [color=%s](%s)[/color]\n" % [stats.PROFICIENCY_NAMES[p], lvl, SRC_COLOR, bonus.trim_prefix(", ")]
		else:
			var lo : float = stats.profXpForLevel(lvl)
			var hi : float = stats.profXpForLevel(lvl + 1)
			var progress : float = (st.profXp(p) - lo) / (hi - lo)
			t += "%s: %d [color=%s](%s to next%s)[/color]\n" % [stats.PROFICIENCY_NAMES[p], lvl, SRC_COLOR, pct(progress), bonus]
	return t

func _weaponText() -> String:
	var w : WeaponItem = Global.weapon
	if not w: return "[b]Weapon[/b]\nNothing equipped\n"
	var t : String = "[b]Weapon: %s[/b]\n" % Mutation.nameBB(w)
	if Mutation.isMutated(w):
		t += "[color=%s]%s: %s[/color]\n" % [Mutation.textColor(w).to_html(), tipped("Mutation"), Mutation.describe(w)]
	t += "%s: %s\n" % [tipped("Scaling"), w.scalingText()]
	if not w.getElements().is_empty():
		var parts : PackedStringArray = PackedStringArray()
		var els : Dictionary = w.getElements()
		for e in els:
			parts.append("[color=%s]%s %d%%[/color]" % [StatusEffects.ELEMENT_COLORS[e].to_html(), StatusEffects.ELEMENT_NAMES[e], roundi(float(els[e]) * 100)])
		t += "%s: %s" % [tipped("Elements"), ", ".join(parts)]
		if st.elementalPotency() > 1.0: t += " [color=%s](+%s potency, Magic)[/color]" % [SRC_COLOR, pct(st.elementalPotency() - 1.0)]
		t += "\n"
	var pType : String = stats.profType(w)
	var profM : float = st.profDamageMult(pType)
	var classM : float = st.classDamageMult(pType)
	var lvlM : float = st.levelDamageMult()
	var m : float = w.scalingMult(st) * profM * classM * lvlM
	if is_equal_approx(m, 1.0):
		t += "%s: %s - %s\n" % [tipped("Damage"), fmt(w.damage.x), fmt(w.damage.y)]
	else:
		var parts : PackedStringArray = PackedStringArray()
		if w.scalingMult(st) > 1.0: parts.append("+%s scaling" % pct(w.scalingMult(st) - 1.0))
		if classM > 1.0: parts.append("+%s %s" % [pct(classM - 1.0), stats.classDamageSource(pType)])
		if lvlM > 1.0: parts.append("+%s level" % pct(lvlM - 1.0))
		if profM > 1.0: parts.append("+%s proficiency" % pct(profM - 1.0))
		t += tipped("Damage") + ": %s - %s -> [color=%s]%s - %s[/color] [color=%s](%s)[/color]\n" % [
			fmt(w.damage.x), fmt(w.damage.y), UP_COLOR, fmt(w.damage.x * m), fmt(w.damage.y * m), SRC_COLOR, ", ".join(parts)]
	if w.animationType == WeaponItem.animType.RANGE and w.rangeSpawnAmount > 1:
		var share : float = minf(1.0, WeaponSys.VOLLEY_TOTAL / w.rangeSpawnAmount)
		t += "%s: %d [color=%s](each deals %s of the damage above)[/color]\n" % [tipped("Projectiles"), w.rangeSpawnAmount, SRC_COLOR, pct(share)]
	var critSrc : String = "melee bonus, Rogue, Luck" if w.animationType == WeaponItem.animType.SWING else "Rogue, Luck"
	t += line("Crit Chance", w.critChance, w.critChanceWith(st), critSrc, true)
	t += line("Crit Multiplier", w.critMulti, w.critMultiWith(st), "melee bonus, Rogue" if w.animationType == WeaponItem.animType.SWING else "Rogue", false, "x")
	t += line("Knockback", w.knockback, w.knockback * st.knockbackDealtMult(), "Strength")
	
	var ws : WeaponSys = WeaponSys.new()
	ws.weapon = w
	ws.wielderStats = st
	ws.trackProficiency = true # read-only here: poolCost() includes the proficiency reduction
	var pool : String = "Stamina" if w.getPool() == WeaponItem.poolType.STAMINA else "Mana"
	var src : String = "Stamina" if w.getPool() == WeaponItem.poolType.STAMINA else ("Focus" if w.animationType == WeaponItem.animType.AIM_LASER else "Magic")
	t += line("%s Cost" % pool, w.getPoolCost(), ws.poolCost(), src + ", proficiency")
	if w.animationType == WeaponItem.animType.AIM_LASER:
		t += line("Range", w.laserRange, ws.laserRange(), "Focus")
		t += line("Tick Speed", w.laserAttackSpeed, ws.laserTickSpeed(), "Focus")
	elif w.animationType == WeaponItem.animType.RANGE:
		# Base already includes the player's base attack speed; only Speed and proficiency are bonuses
		var fr : float = w.rangeFireSpeed * st.attack_speed
		t += line("Fire Rate", fr, fr * (st.attackSpeed() / st.attack_speed) * st.profSpeedMult(pType), "Speed, proficiency", false, " / sec")
	elif w.animationType == WeaponItem.animType.SWING:
		var sps : float = w.swingSpeedMulti / maxf(w.swingDuration, 0.01) * st.attack_speed
		t += line("Swings", sps, sps * (st.attackSpeed() / st.attack_speed) * st.profSpeedMult(pType), "Speed, proficiency", false, " / sec")
	return t

func _armorText() -> String:
	var a : ArmorItem = Global.armor
	if not a: return "[b]Armor[/b]\nNothing equipped\n"
	var t : String = "[b]Armor: [color=%s]%s[/color][/b]\n" % [a.getRarity().color.to_html(), a.name]
	t += line("Defense", a.defense, a.defense * st.armorEfficiency(), "Vitality: %s armor efficiency" % pct(st.armorEfficiency()))
	var total : float = minf(st.knockbackResist() + a.getKnockbackResist(), Knockback.RESIST_CAP)
	t += line("Knockback Resist", a.getKnockbackResist(), total, "with Vitality, cap 80%", true)
	t += _resistText(a)
	return t

# Damage kind and elemental resistances (armor rolls, plus Vitality's bit of melee), cap 60%
func _resistText(a: ArmorItem) -> String:
	var t : String = ""
	for key in StatusEffects.DAMAGE_KINDS + StatusEffects.ELEMENTS:
		var base : float = a.getResist(key) if a else 0.0
		var final : float = base
		if key == "melee": final += st.meleeResistBonus()
		final = StatusEffects.clampResist(final)
		if is_zero_approx(base) and is_zero_approx(final): continue
		var label : String = StatusEffects.KIND_NAMES.get(key, StatusEffects.ELEMENT_NAMES.get(key, key)) + " Resist"
		if StatusEffects.ELEMENTS.has(key):
			label = "[color=%s]%s[/color]" % [StatusEffects.ELEMENT_COLORS[key].to_html(), label]
		t += line(label, base, final, "Vitality" if key == "melee" else "", true)
	return t
