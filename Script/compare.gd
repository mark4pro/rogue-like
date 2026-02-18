extends Control

@onready var bg : ColorRect = $BG
@onready var nameTxt : Label = $BG/Name
@onready var stats : VBoxContainer = $BG/Stats

var item : BaseItem = null

func _ready() -> void:
	nameTxt.size.x = bg.size.x
	stats.size.x = bg.size.x
	
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
			var weaponDam : Vector2 = Vector2.ZERO if not Global.weapon else Global.weapon.damage
			
			var damComp : Vector2 = Vector2(item.damage.x - weaponDam.x, item.damage.y - weaponDam.y)
			
			var damMinColor : Color = Color.GREEN
			if damComp.x == 0: damMinColor = Color.WHITE
			if damComp.x < 0: damMinColor = Color.RED
			
			var damMaxColor : Color = Color.GREEN
			if damComp.y == 0: damMaxColor = Color.WHITE
			if damComp.y < 0: damMaxColor = Color.RED
			
			if Global.weapon and not item == Global.weapon:
				newLabel.text = "\t\tDamage range: ([color=%s]%s[/color] | %s, [color=%s]%s[/color] | %s)" % [
					damMinColor.to_html(),
					str(damComp.x),
					str(Global.formatFloat(item.damage.x)),
					damMaxColor.to_html(),
					str(damComp.y),
					str(Global.formatFloat(item.damage.y))
				]
			if not Global.weapon or item == Global.weapon:
				newLabel.text = "\t\tDamage range: (%s, %s)" % [
					str(Global.formatFloat(item.damage.x)),
					str(Global.formatFloat(item.damage.y))
				]
			
			
			stats.add_child(newLabel.duplicate())
	
	bg.size.y = stats.size.y + 30

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position()
	bg.size.y = stats.size.y + 30
