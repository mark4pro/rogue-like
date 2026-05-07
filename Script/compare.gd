extends Control

@onready var bg : ColorRect = $BG
@onready var nameTxt : Label = $BG/Name
@onready var stats : VBoxContainer = $BG/Stats

var item : BaseItem = null

func getCompColor(thisProperty, equippedProperty) -> String:
	var comp : float = thisProperty - equippedProperty
				
	var result : Color = Color.GREEN
	if comp == 0: result = Color.WHITE
	if comp < 0: result = Color.RED
	
	return result.to_html()

func _ready() -> void:
	if item:
		nameTxt.text = " Name: " + item.name
		
		var newLabel : RichTextLabel = RichTextLabel.new()
		var fontFile = load("res://Assets/fonts/tiny5/Tiny5-Regular.ttf") as FontFile
		newLabel.add_theme_font_override("normal_font", fontFile)
		newLabel.add_theme_font_size_override("font_size", 18)
		newLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		newLabel.custom_minimum_size = Vector2(300, 30)
		newLabel.bbcode_enabled = true
		
		if item is HealthItem:
			newLabel.text = "\t\tHeals: %s" % [str(Global.formatFloat(item.healthAmount))]
			stats.add_child(newLabel.duplicate())
			
			newLabel.text = "\t\tCost: %s" % [
				str(Global.formatFloat(item.cost))
			]
			stats.add_child(newLabel.duplicate())
		
		if item is WeaponItem:
			if Global.weapon and not item == Global.weapon:
				newLabel.text = "\t\tDamage: ([color=%s]%s[/color] | %s, [color=%s]%s[/color] | %s)" % [
					getCompColor(item.damage.x, Global.weapon.damage.x),
					str(Global.formatFloat(item.damage.x - Global.weapon.damage.x)),
					str(Global.formatFloat(item.damage.x)),
					getCompColor(item.damage.y, Global.weapon.damage.y),
					str(Global.formatFloat(item.damage.y - Global.weapon.damage.y)),
					str(Global.formatFloat(item.damage.y))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Chance: ([color=%s]%s[/color] | %s)" % [
					getCompColor(item.critChance, Global.weapon.critChance),
					str(Global.formatFloat(item.critChance - Global.weapon.critChance)),
					str(Global.formatFloat(item.critChance))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Multiplier: ([color=%s]%s[/color] | %s)" % [
					getCompColor(item.critMulti, Global.weapon.critMulti),
					str(Global.formatFloat(item.critMulti - Global.weapon.critMulti)),
					str(Global.formatFloat(item.critMulti))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tKnockback: ([color=%s]%s[/color] | %s)" % [
					getCompColor(item.knockback, Global.weapon.knockback),
					str(Global.formatFloat(item.knockback - Global.weapon.knockback)),
					str(Global.formatFloat(item.knockback))
				]
				stats.add_child(newLabel.duplicate())
				
				if item.animationType == WeaponItem.animType.AIM_LASER:
					var attackSpeed : float = 0
					if Global.weapon.animationType == WeaponItem.animType.AIM_LASER:
						attackSpeed = Global.weapon.laserAttackSpeed
					
					newLabel.text = "\t\tAttack Speed: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.laserAttackSpeed, attackSpeed),
						str(Global.formatFloat(item.laserAttackSpeed - attackSpeed)),
						str(Global.formatFloat(item.laserAttackSpeed))
					]
					stats.add_child(newLabel.duplicate())
					
					var attackRange : float = 0
					if Global.weapon.animationType == WeaponItem.animType.AIM_LASER:
						attackRange = Global.weapon.laserRange
					
					newLabel.text = "\t\tRange: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.laserRange, attackRange),
						str(Global.formatFloat(item.laserRange - attackRange)),
						str(Global.formatFloat(item.laserRange))
					]
					stats.add_child(newLabel.duplicate())
				
				if item.animationType == WeaponItem.animType.RANGE:
					var attackSpeed : float = 0
					if Global.weapon.animationType == WeaponItem.animType.RANGE:
						attackSpeed = Global.weapon.rangeFireSpeed
					
					newLabel.text = "\t\tAttack Speed: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.rangeFireSpeed, attackSpeed),
						str(Global.formatFloat(item.rangeFireSpeed - attackSpeed)),
						str(Global.formatFloat(item.rangeFireSpeed))
					]
					stats.add_child(newLabel.duplicate())
					
					var amount : float = 0
					if Global.weapon.animationType == WeaponItem.animType.RANGE:
						amount = Global.weapon.rangeSpawnAmount
					
					newLabel.text = "\t\tAmount: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.rangeSpawnAmount, amount),
						str(Global.formatFloat(item.rangeSpawnAmount - amount)),
						str(Global.formatFloat(item.rangeSpawnAmount))
					]
					stats.add_child(newLabel.duplicate())
					
					var spread : float = 0
					if Global.weapon.animationType == WeaponItem.animType.RANGE:
						spread = Global.weapon.rangeSpreadAngle
					
					newLabel.text = "\t\tSpread: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.rangeSpreadAngle, spread),
						str(Global.formatFloat(item.rangeSpreadAngle - spread)),
						str(Global.formatFloat(item.rangeSpreadAngle))
					]
					stats.add_child(newLabel.duplicate())
					
					var speed : float = 0
					if Global.weapon.animationType == WeaponItem.animType.RANGE:
						speed = Global.weapon.rangeSpeed
					
					newLabel.text = "\t\tProjectile Speed: ([color=%s]%s[/color] | %s)" % [
						getCompColor(item.rangeSpeed, speed),
						str(Global.formatFloat(item.rangeSpeed - speed)),
						str(Global.formatFloat(item.rangeSpeed))
					]
					stats.add_child(newLabel.duplicate())
			
			if not Global.weapon or item == Global.weapon:
				newLabel.text = "\t\tDamage: (%s, %s)" % [
					str(Global.formatFloat(item.damage.x)),
					str(Global.formatFloat(item.damage.y))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Chance: %s" % [
					str(Global.formatFloat(item.critChance))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Multiplier: %s" % [
					str(Global.formatFloat(item.critMulti))
				]
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tKnockback: %s" % [
					str(Global.formatFloat(item.knockback))
				]
				stats.add_child(newLabel.duplicate())
				
				if item.animationType == WeaponItem.animType.AIM_LASER:
					newLabel.text = "\t\tAttack Speed: %s" % [
						str(Global.formatFloat(item.laserAttackSpeed))
					]
					stats.add_child(newLabel.duplicate())
					
					newLabel.text = "\t\tRange: %s" % [
						str(Global.formatFloat(item.laserRange))
					]
					stats.add_child(newLabel.duplicate())
				
				if item.animationType == WeaponItem.animType.RANGE:
					newLabel.text = "\t\tAttack Speed: %s" % [
						str(Global.formatFloat(item.rangeFireSpeed))
					]
					stats.add_child(newLabel.duplicate())
					
					newLabel.text = "\t\tAmount: %s" % [
						str(Global.formatFloat(item.rangeSpawnAmount))
					]
					stats.add_child(newLabel.duplicate())
					
					newLabel.text = "\t\tSpread: %s" % [
						str(Global.formatFloat(item.rangeSpreadAngle))
					]
					stats.add_child(newLabel.duplicate())
					
					newLabel.text = "\t\tProjectile Speed: %s" % [
						str(Global.formatFloat(item.rangeSpeed))
					]
					stats.add_child(newLabel.duplicate())
			
			newLabel.text = "\t\tRarity: [color=%s]%s[/color]" % [
				item.getRarity().color.to_html(),
				str(item.getRarity().txt)
			]
			stats.add_child(newLabel.duplicate())
			
			newLabel.text = "\t\tCost: %s" % [
				str(Global.formatFloat(item.cost))
			]
			stats.add_child(newLabel.duplicate())
		
		if item is ArmorItem:
			if Global.armor and not item == Global.armor:
				newLabel.text = "\t\tDefense: ([color=%s]%s[/color] | %s)" % [
					getCompColor(item.defense, Global.armor.defense),
					str(Global.formatFloat(item.defense - Global.armor.defense)),
					str(Global.formatFloat(item.defense))
				]
				stats.add_child(newLabel.duplicate())
			
			if not Global.armor or item == Global.armor:
				newLabel.text = "\t\tDefense: %s" % [
					str(Global.formatFloat(item.defense))
				]
				stats.add_child(newLabel.duplicate())
			
			newLabel.text = "\t\tRarity: [color=%s]%s[/color]" % [
				item.getRarity().color.to_html(),
				str(item.getRarity().txt)
			]
			stats.add_child(newLabel.duplicate())
			
			newLabel.text = "\t\tCost: %s" % [
				str(Global.formatFloat(item.cost))
			]
			stats.add_child(newLabel.duplicate())
	bg.size.y = stats.size.y + 30

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	bg.size.y = stats.size.y + 30
	nameTxt.size.x = bg.size.x
	stats.size.x = bg.size.x
