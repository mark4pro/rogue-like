extends Control

@export var pickupItemUI : PackedScene = null
@export var vBoxContainer : VBoxContainer = null

enum SortMode { RARITY, NAME, TYPE, NEAREST }
const SORT_NAMES : Array[String] = ["Rarity", "Name", "Type", "Nearest"]
const TOOLBAR_HEIGHT : float = 44.0

# Kept between openings (and between pickup menus) for the session
static var sortMode : int = SortMode.RARITY
static var showPlaced : bool = false

var loaded : bool = false
var countLabel : Label = null
var sortDrop : OptionButton = null
var placedToggle : CheckBox = null

func _ready() -> void:
	_buildToolbar()

# A row under the Pickup title: sort dropdown, show-placed toggle, and the item count
func _buildToolbar() -> void:
	var title : Label = get_node_or_null("ColorRect/Label")
	var scroll : Control = get_node_or_null("ColorRect/ScrollContainer")
	if not title or not scroll: return
	var panel : Control = title.get_parent()
	var top : float = title.position.y + title.size.y
	
	# Make room: the list starts below the toolbar
	scroll.position.y += TOOLBAR_HEIGHT
	scroll.size.y -= TOOLBAR_HEIGHT
	
	var bar : HBoxContainer = HBoxContainer.new()
	bar.name = "Toolbar"
	bar.position = Vector2(16, top + 4)
	bar.size = Vector2(panel.size.x - 32, TOOLBAR_HEIGHT - 8)
	bar.add_theme_constant_override("separation", 16)
	panel.add_child(bar)
	
	var sortLabel : Label = Label.new()
	sortLabel.text = "Sort:"
	sortLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(sortLabel)
	
	sortDrop = OptionButton.new()
	for n in SORT_NAMES: sortDrop.add_item(n)
	sortDrop.selected = sortMode
	sortDrop.custom_minimum_size = Vector2(170, 0)
	sortDrop.focus_mode = Control.FOCUS_NONE
	sortDrop.item_selected.connect(func(i: int):
		sortMode = i
		loaded = false)
	bar.add_child(sortDrop)
	
	placedToggle = CheckBox.new()
	placedToggle.text = "Show placed"
	placedToggle.button_pressed = showPlaced
	placedToggle.focus_mode = Control.FOCUS_NONE
	placedToggle.toggled.connect(func(on: bool):
		showPlaced = on
		loaded = false)
	bar.add_child(placedToggle)
	
	var spacer : Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	
	countLabel = Label.new()
	countLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countLabel.modulate = Color(1, 1, 1, 0.8)
	bar.add_child(countLabel)
	
	for c in [sortLabel, countLabel]:
		var f : Font = title.get_theme_font("font")
		if f: c.add_theme_font_override("font", f)
		c.add_theme_font_size_override("font_size", 24)

func _process(_delta: float) -> void:
	if pickupItemUI and vBoxContainer:
		if visible:
			var contextChk : Control = get_parent().get_node_or_null("ContextMenu")
			if contextChk: contextChk.queue_free()
		
		if not loaded and $"..".visible:
			if vBoxContainer.get_child_count() > 0:
				for i in vBoxContainer.get_children():
					i.queue_free()
			for i in nearbyItems():
				var newItem : ColorRect = pickupItemUI.instantiate()
				newItem.groundNode = i
				vBoxContainer.add_child(newItem)
			loaded = true
		if loaded and not $"..".visible: loaded = false
		
		if countLabel and visible:
			var n : int = 0
			for c in vBoxContainer.get_children():
				if not c.is_queued_for_deletion(): n += 1
			countLabel.text = "%d item%s" % [n, "" if n == 1 else "s"]

# Ground items in pickup range (placed things like lit torches only if the toggle is on),
# ordered by the sort dropdown
func nearbyItems() -> Array:
	var found : Array = []
	var from : Vector2 = Global.player.global_position
	for i in get_tree().get_nodes_in_group("items"):
		if from.distance_to(i.global_position) > Global.pickupRange:
			continue
		var item : BaseItem = itemOf(i)
		if not item or (not showPlaced and isPlaced(i, item)):
			continue
		found.append(i)
	
	found.sort_custom(func(a, b):
		var ia : BaseItem = itemOf(a)
		var ib : BaseItem = itemOf(b)
		match sortMode:
			SortMode.NAME:
				pass
			SortMode.TYPE:
				# Weapons, armor, then items; rarest first inside each
				var order : Array = [BaseItem.sort_type.WEAPON, BaseItem.sort_type.ARMOR, BaseItem.sort_type.ITEM]
				var ta : int = order.find(ia.sortType)
				var tb : int = order.find(ib.sortType)
				if ta != tb: return ta < tb
				if ia.rarity != ib.rarity: return ia.rarity > ib.rarity
			SortMode.NEAREST:
				var da : float = from.distance_squared_to(a.global_position)
				var db : float = from.distance_squared_to(b.global_position)
				if da != db: return da < db
			_: # RARITY
				if ia.rarity != ib.rarity: return ia.rarity > ib.rarity
		return ia.name.naturalnocasecmp_to(ib.name) < 0)
	return found

static func itemOf(n: Node) -> BaseItem:
	if "item" in n and n.item: return n.item
	if "weapSys" in n and n.weapSys and n.weapSys.weapon: return n.weapSys.weapon
	return null

# Something placed in the world (a lit torch) rather than an item lying on the ground
static func isPlaced(n: Node, item: BaseItem) -> bool:
	return item.placedScene != null and n.scene_file_path == item.placedScene.resource_path
