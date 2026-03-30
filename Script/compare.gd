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
				newLabel.text = "\t\tDamage range: ([color=%s]%s[/color] | %s, [color=%s]%s[/color] | %s)" % [
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
				
			if not Global.weapon or item == Global.weapon:
				newLabel.text = "\t\tDamage range: (%s, %s)" % [
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
	position = get_viewport().get_mouse_position()
	bg.size.y = stats.size.y + 30
	nameTxt.size.x = bg.size.x
	stats.size.x = bg.size.x
