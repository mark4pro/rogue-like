extends Control

@onready var bg : ColorRect = $BG
@onready var nameTxt : Label = $BG/Name
@onready var stats : VBoxContainer = $BG/Stats

var item : BaseItem = null

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
			newLabel.text = "\t\tHeals: " + str(Global.formatFloat(item.healthAmount))
			stats.add_child(newLabel.duplicate())
		if item is WeaponItem:
			if Global.weapon and not item == Global.weapon:
				var damComp : Vector2 = Vector2(item.damage.x - Global.weapon.damage.x, item.damage.y - Global.weapon.damage.y)
				
				var damMinColor : Color = Color.GREEN
				if damComp.x == 0: damMinColor = Color.WHITE
				if damComp.x < 0: damMinColor = Color.RED
				
				var damMaxColor : Color = Color.GREEN
				if damComp.y == 0: damMaxColor = Color.WHITE
				if damComp.y < 0: damMaxColor = Color.RED
				
				newLabel.text = "\t\tDamage range: ([color=%s]%s[/color] | %s, [color=%s]%s[/color] | %s)" % [
					damMinColor.to_html(),
					str(Global.formatFloat(damComp.x)),
					str(Global.formatFloat(item.damage.x)),
					damMaxColor.to_html(),
					str(Global.formatFloat(damComp.y)),
					str(Global.formatFloat(item.damage.y))
				]
				
				stats.add_child(newLabel.duplicate())
				
				var critChanceComp : float = item.critChance - Global.weapon.critChance
				
				var critChanceColor : Color = Color.GREEN
				if critChanceComp == 0: critChanceColor = Color.WHITE
				if critChanceComp < 0: critChanceColor = Color.RED
				
				newLabel.text = "\t\tCrit Chance: ([color=%s]%s[/color] | %s)" % [
					critChanceColor.to_html(),
					str(Global.formatFloat(critChanceComp)),
					str(Global.formatFloat(item.critChance))
				]
				
				stats.add_child(newLabel.duplicate())
				
				var critMultiComp : float = item.critMulti - Global.weapon.critMulti
				
				var critMultiColor : Color = Color.GREEN
				if critMultiComp == 0: critMultiColor = Color.WHITE
				if critMultiComp < 0: critMultiColor = Color.RED
				
				newLabel.text = "\t\tCrit Chance: ([color=%s]%s[/color] | %s)" % [
					critMultiColor.to_html(),
					str(Global.formatFloat(critMultiComp)),
					str(Global.formatFloat(item.critMulti))
				]
				
				stats.add_child(newLabel.duplicate())
			if not Global.weapon or item == Global.weapon:
				newLabel.text = "\t\tDamage range: (%s, %s)" % [
					str(Global.formatFloat(item.damage.x)),
					str(Global.formatFloat(item.damage.y))
				]
				
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Chance: (%s)" % [
					str(Global.formatFloat(item.critChance))
				]
				
				stats.add_child(newLabel.duplicate())
				
				newLabel.text = "\t\tCrit Chance: (%s)" % [
					str(Global.formatFloat(item.critMulti))
				]
				
				stats.add_child(newLabel.duplicate())
			
			var thisRarity : String = ""
			var rarityColor : Color = Color.WEB_GRAY
			
			match item.rarity:
				0: 
					thisRarity = "Common"
					rarityColor = Color.WEB_GRAY
				1:
					thisRarity = "Uncommon"
					rarityColor = Color.GREEN_YELLOW
				2:
					thisRarity = "Rare"
					rarityColor = Color.ROYAL_BLUE
				3:
					thisRarity = "Epic"
					rarityColor = Color.WEB_PURPLE
				4:
					thisRarity = "Legend"
					rarityColor = Color.GOLDENROD
				5:
					thisRarity = "Historical"
					rarityColor = Color.BLACK
			
			newLabel.text = "\t\tRarity: ([color=%s]%s[/color])" % [
				rarityColor.to_html(),
				str(thisRarity)
			]
			
			stats.add_child(newLabel.duplicate())
	
	bg.size.y = stats.size.y + 30

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position()
	bg.size.y = stats.size.y + 30
	nameTxt.size.x = bg.size.x
	stats.size.x = bg.size.x
