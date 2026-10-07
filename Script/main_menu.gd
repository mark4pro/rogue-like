extends Node2D

# Main menu: the player's snail (wearing their equipped shell) walks forever through an endless
# grass field while the camera follows it. Continue: the snail curls up, rolls off the screen,
# the screen fades out and the hub loads.
#
# Global's scene manager is held off while Global.inMenu is true (it would otherwise swap
# straight to the hub), and so are the day clock and the world pre-generation.

const FONT_UID : String = "uid://dv68j0l4djo44"
const PLAYER_SCENE : String = "uid://bjts4lj4357yt"
const DEFAULT_SHELL : String = "uid://daewd31d0gobn"
const TILESET : String = "uid://b42gidbr1gvoe"
const GRASS_TILE : Vector2i = Vector2i(0, 0)
const TILE : float = 32.0
const TREE_SCENE : String = "uid://biahn66yel13i"
const GRASS_TEX : String = "uid://bre07aypqooa3"

@export var walk_speed : float = 60.0        # px / sec
@export var camera_zoom : float = 6.0
@export var roll_spin : float = 14.0         # rad / sec while rolling away
@export var roll_accel : float = 450.0       # px / sec^2
@export var tree_chance : float = 0.35       # per column of tiles, top and bottom edge each
@export var tuft_chance : float = 0.6        # grass tufts per column

var camera : Camera2D = null
var ground : TileMapLayer = null
var decor : Node2D = null
var snail : Node2D = null
var rotPoint : Node2D = null
var body : AnimatedSprite2D = null
var shell : Node2D = null
var trail : SlimeTrail = null
var ui : CanvasLayer = null
var menu : Control = null
var fade : ColorRect = null
var continueBttn : Button = null

var speed : float = 0.0
var rolling : bool = false
var leaving : bool = false
var _builtTo : int = -999999   # last tile column filled
var _clearedTo : int = -999999
var _treeScene : PackedScene = null
var _grassTex : Texture2D = null
var _options : Control = null
var _font : Font = null
var mainBox : VBoxContainer = null
var slotPanel : VBoxContainer = null
var _slotMode : String = ""     # "new" | "load" | "weapon" (picking the starting weapon)
var _pendingSlot : int = -1     # slot a new game goes into, while picking the weapon

const STARTER_CHOICES : Array = [
	["melee", "Melee", "Swing a blade up close"],
	["ranged", "Ranged", "Shoot projectiles from afar"],
	["laser", "Laser", "Hold a burning beam on them"],
]
var _armed : String = ""        # button key waiting for a confirming second click

func _enter_tree() -> void:
	Global.inMenu = true

func _ready() -> void:
	add_to_group("main_menu")
	y_sort_enabled = true
	speed = walk_speed
	_treeScene = load(TREE_SCENE)
	_grassTex = load(GRASS_TEX)
	
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load(TILESET)
	ground.navigation_enabled = false
	ground.collision_enabled = false
	ground.z_index = -10
	add_child(ground)
	
	decor = Node2D.new()
	decor.name = "Decor"
	decor.y_sort_enabled = true
	add_child(decor)
	
	_buildSnail()
	
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * camera_zoom
	camera.offset = Vector2(55, -6) # snail on the left third, the menu on the right
	add_child(camera)
	camera.make_current()
	
	_buildUI()
	_extendWorld()

#region Snail (same nodes and offsets as the player scene)

func _buildSnail() -> void:
	snail = Node2D.new()
	snail.name = "Snail"
	snail.z_index = 3 # same as the player: above the slime trail (z 2)
	add_child(snail)
	
	var shadow : Sprite2D = Sprite2D.new()
	shadow.texture = load("uid://b70aujp6bewbx")
	shadow.modulate = Color(1, 1, 1, 0.39)
	shadow.position = Vector2(0, 10.9)
	shadow.scale = Vector2(0.746, 0.095)
	shadow.show_behind_parent = true
	snail.add_child(shadow)
	
	rotPoint = Node2D.new()
	rotPoint.position = Vector2(0, 4)
	snail.add_child(rotPoint)
	
	body = AnimatedSprite2D.new()
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = Vector2(2, -4)
	body.sprite_frames = _playerFrames()
	body.speed_scale = 4.0
	rotPoint.add_child(body)
	body.play("walk")
	
	var offset : Node2D = Node2D.new()
	offset.position = Vector2(0.5, 0.5)
	body.add_child(offset)
	shell = Node2D.new()
	shell.position = Vector2(-8, 4)
	offset.add_child(shell)
	
	_refreshShell()

# Puts the current save's equipped shell on the snail (again after picking a slot)
func _refreshShell() -> void:
	for c in shell.get_children():
		c.queue_free()
	var armorScene : PackedScene = Global.armor.armorScene if Global.armor and Global.armor.armorScene else load(DEFAULT_SHELL)
	var armor : Node = armorScene.instantiate()
	_snapShellToPixels(armor)
	shell.add_child(armor)

# The walk / roll animations straight from the player scene
func _playerFrames() -> SpriteFrames:
	var p : Node = load(PLAYER_SCENE).instantiate()
	var frames : SpriteFrames = (p.get_node("RotPoint/Sprite2D") as AnimatedSprite2D).sprite_frames
	p.free()
	return frames

# Same as the player: even-sized shells sit half a pixel off otherwise
func _snapShellToPixels(armor: Node) -> void:
	var s : Sprite2D = armor as Sprite2D
	if not s or not s.texture or not s.centered: return
	var size : Vector2 = s.texture.get_size()
	if s.region_enabled: size = s.region_rect.size
	size /= Vector2(s.hframes, s.vframes)
	s.offset = Vector2(0.5 if int(size.x) % 2 == 0 else 0.0, -0.5 if int(size.y) % 2 == 0 else 0.0)

# Where the shell sits so it spins around rotPoint (same as player_controller.rollShellPos)
func _rollShellPos() -> Vector2:
	var kidOffset : Vector2 = Vector2.ZERO
	for c in shell.get_children():
		if c is Sprite2D:
			kidOffset = c.offset
			break
	return -(body.position + shell.get_parent().position) - kidOffset

#endregion

#region Endless field

# Fills tile columns ahead of the camera and drops the ones behind it, with trees along the top
# and bottom edges and grass tufts scattered around
func _extendWorld() -> void:
	var half : Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var center : Vector2 = camera.get_screen_center_position()
	var firstCol : int = floori((center.x - half.x) / TILE) - 2
	var lastCol : int = ceili((center.x + half.x) / TILE) + 2
	var topRow : int = floori((center.y - half.y) / TILE) - 2
	var botRow : int = ceili((center.y + half.y) / TILE) + 2
	
	if _builtTo < firstCol - 1: _builtTo = firstCol - 1
	while _builtTo < lastCol:
		_builtTo += 1
		for y in range(topRow, botRow + 1):
			ground.set_cell(Vector2i(_builtTo, y), 0, GRASS_TILE)
		_decorateColumn(_builtTo, center.y, half.y)
	
	# Forget what's well behind the camera
	if _clearedTo < firstCol - 6:
		for x in range(maxi(_clearedTo, firstCol - 40), firstCol - 4):
			for y in range(topRow - 2, botRow + 3):
				ground.erase_cell(Vector2i(x, y))
		_clearedTo = firstCol - 4
		var edge : float = (firstCol - 4) * TILE
		for d in decor.get_children():
			if d.position.x < edge: d.queue_free()

func _decorateColumn(col: int, centerY: float, halfH: float) -> void:
	var x : float = col * TILE
	# Trees frame the top and bottom of the screen, never in the snail's lane
	for side in [-1, 1]:
		if randf() < tree_chance:
			var t : Node2D = _treeScene.instantiate()
			t.position = Vector2(x + randf_range(-10, 10), centerY + side * randf_range(halfH * 0.75, halfH + 20.0))
			t.rotation = randf() * TAU
			decor.add_child(t)
	if randf() < tuft_chance and _grassTex:
		var g : Sprite2D = Sprite2D.new()
		g.texture = _grassTex
		var s : float = randf_range(10.0, 16.0) / float(_grassTex.get_height())
		g.scale = Vector2(s, s)
		g.flip_h = randf() < 0.5
		var y : float = centerY + randf_range(-halfH * 0.7, halfH * 0.7)
		if absf(y - snail.position.y) < 6.0: y += 14.0 # keep the snail's path clear
		g.position = Vector2(x + randf_range(0, TILE), y)
		g.offset = Vector2(0, -float(_grassTex.get_height()) * 0.5) # sorts by its base
		decor.add_child(g)

#endregion

func _process(delta: float) -> void:
	if rolling:
		speed += roll_accel * delta
		rotPoint.rotation += roll_spin * delta
	snail.position.x += speed * delta
	
	# The camera follows the walk, but stays put once the snail rolls off
	if not rolling:
		camera.position.x = snail.position.x
	_extendWorld()
	
	if not rolling:
		var slimePos : Vector2 = snail.global_position + Vector2(0, 10)
		if not trail or not is_instance_valid(trail) or not trail.extend(slimePos):
			trail = SlimeTrail.new()
			add_child(trail)
			trail.extend(slimePos)
	
	if rolling and not leaving:
		var half : float = get_viewport_rect().size.x / camera.zoom.x * 0.5
		if snail.position.x > camera.get_screen_center_position().x + half + 30.0:
			_leave()

#region Menu

func _buildUI() -> void:
	var font : Font = load(FONT_UID)
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu)
	
	var title : Label = Label.new()
	title.text = "Snail Rogue"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 128)
	title.add_theme_constant_override("outline_size", 24)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.9))
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(1000, 150)
	title.size = Vector2(820, 160)
	menu.add_child(title)
	
	_font = font
	var box : VBoxContainer = VBoxContainer.new()
	box.position = Vector2(1170, 380)
	box.size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 18)
	menu.add_child(box)
	mainBox = box
	
	continueBttn = _button("Continue", font, _on_continue)
	box.add_child(continueBttn)
	box.add_child(_button("New Game", font, func(): _openSlots("new")))
	var loadBttn : Button = _button("Load Game", font, func(): _openSlots("load"))
	loadBttn.name = "Load"
	box.add_child(loadBttn)
	box.add_child(_button("Options", font, _on_options))
	box.add_child(_button("Quit", font, func(): get_tree().quit()))
	_refreshMainButtons()
	
	slotPanel = VBoxContainer.new()
	slotPanel.position = Vector2(1050, 360)
	slotPanel.size = Vector2(720, 0)
	slotPanel.add_theme_constant_override("separation", 14)
	slotPanel.visible = false
	menu.add_child(slotPanel)
	
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	
	# Fade in from black on boot
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)

func _button(text: String, font: Font, action: Callable, minSize: Vector2 = Vector2(480, 96), fontSize: int = 48) -> Button:
	var b : Button = Button.new()
	b.text = text
	b.custom_minimum_size = minSize
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", fontSize)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = {
			"normal": Color(0.12, 0.1, 0.09, 0.72), "hover": Color(0.24, 0.2, 0.16, 0.85),
			"pressed": Color(0.3, 0.26, 0.2, 0.9), "focus": Color(0.24, 0.2, 0.16, 0.85),
			"disabled": Color(0.12, 0.1, 0.09, 0.4),
		}[state]
		sb.set_border_width_all(4)
		sb.border_color = Color(0.98, 0.93, 0.8, 0.9) if state in ["hover", "focus"] else Color(0, 0, 0, 0.6)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(action)
	return b

func _on_options() -> void:
	if _options and is_instance_valid(_options): return
	_options = OptionsMenu.new()
	_options.closed.connect(func():
		_options = null
		menu.visible = true
		_refreshMainButtons())
	ui.add_child(_options)
	menu.visible = false

# Continue / Load are only usable when there's a save to use
func _refreshMainButtons() -> void:
	continueBttn.disabled = not Global.slotExists(Global.saveSlot)
	continueBttn.text = "Continue" if continueBttn.disabled else "Continue  (Slot %d)" % Global.saveSlot
	mainBox.get_node("Load").disabled = not Global.anySlotExists()
	for b in mainBox.get_children():
		if not b.disabled:
			b.grab_focus()
			break

#region Save slots

func _openSlots(mode: String) -> void:
	_slotMode = mode
	_armed = ""
	_buildSlotPanel()
	mainBox.visible = false
	slotPanel.visible = true

func _closeSlots() -> void:
	slotPanel.visible = false
	mainBox.visible = true
	_refreshMainButtons()

func _buildSlotPanel() -> void:
	for c in slotPanel.get_children():
		slotPanel.remove_child(c)
		c.queue_free()
	
	if _slotMode == "weapon":
		_buildWeaponChoice()
		return
	
	var head : Label = Label.new()
	head.text = "New Game - pick a slot" if _slotMode == "new" else "Load Game"
	head.add_theme_font_override("font", _font)
	head.add_theme_font_size_override("font_size", 52)
	head.add_theme_constant_override("outline_size", 14)
	head.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.9))
	head.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slotPanel.add_child(head)
	
	var firstFocus : Button = null
	for slot in range(1, Global.SLOT_COUNT + 1):
		var info : Dictionary = Global.slotInfo(slot)
		var row : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slotPanel.add_child(row)
		
		var key : String = "slot%d" % slot
		var text : String = "Slot %d   -   Empty" % slot
		if info.get("corrupt", false):
			text = "Slot %d   -   Unreadable save" % slot
		elif not info.is_empty():
			text = "Slot %d   -   Lv %d   $%d   Day %d\nPlayed %s" % [slot, info.level, info.money, info.days, Global.formatPlayTime(info.get("time", 0.0))]
		if _armed == key:
			text = "Overwrite Slot %d? Click again" % slot
		
		var b : Button = _button(text, _font, _on_slot.bind(slot), Vector2(600 if not info.is_empty() else 720, 104), 32)
		b.disabled = _slotMode == "load" and (info.is_empty() or info.get("corrupt", false))
		row.add_child(b)
		if not b.disabled and not firstFocus: firstFocus = b
		if _armed == key: firstFocus = b
		
		# Delete (second click confirms)
		if not info.is_empty():
			var dKey : String = "del%d" % slot
			var d : Button = _button("Sure?" if _armed == dKey else "X", _font, _on_delete.bind(slot), Vector2(110, 104), 32 if _armed == dKey else 44)
			d.tooltip_text = "Delete this save"
			row.add_child(d)
			if _armed == dKey: firstFocus = d
	
	var back : Button = _button("Back", _font, _closeSlots)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slotPanel.add_child(back)
	(firstFocus if firstFocus else back).grab_focus()

func _on_slot(slot: int) -> void:
	if rolling: return
	var key : String = "slot%d" % slot
	if _slotMode == "new":
		if Global.slotExists(slot) and _armed != key:
			_armed = key
			_buildSlotPanel()
			return
		# Next: pick the starting weapon
		_pendingSlot = slot
		_slotMode = "weapon"
		_armed = ""
		_buildSlotPanel()
		return
	else:
		if not Global.loadSlot(slot): return
	_refreshShell()
	_on_continue()

func _buildWeaponChoice() -> void:
	var head : Label = Label.new()
	head.text = "Choose your starting weapon"
	head.add_theme_font_override("font", _font)
	head.add_theme_font_size_override("font_size", 52)
	head.add_theme_constant_override("outline_size", 14)
	head.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.9))
	head.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slotPanel.add_child(head)
	
	var first : Button = null
	for c in STARTER_CHOICES:
		var b : Button = _button("%s\n%s" % [c[1], c[2]], _font, _on_weapon_choice.bind(c[0]), Vector2(720, 110), 34)
		slotPanel.add_child(b)
		if not first: first = b
	
	var back : Button = _button("Back", _font, func():
		_slotMode = "new"
		_pendingSlot = -1
		_buildSlotPanel())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slotPanel.add_child(back)
	first.grab_focus()

func _on_weapon_choice(kind: String) -> void:
	if rolling or _pendingSlot == -1: return
	Global.startNewGame(_pendingSlot, kind)
	_pendingSlot = -1
	_refreshShell()
	_on_continue()

func _on_delete(slot: int) -> void:
	var key : String = "del%d" % slot
	if _armed != key:
		_armed = key
		_buildSlotPanel()
		return
	Global.deleteSlot(slot)
	_armed = ""
	# Deleted the slot Continue points at: switch to another save (or a blank character)
	if Global.saveSlot == slot:
		var other : int = -1
		for s in range(1, Global.SLOT_COUNT + 1):
			if Global.slotExists(s):
				other = s
				break
		if other != -1: Global.loadSlot(other)
		else: Global.resetState()
		_refreshShell()
	if _slotMode == "load" and not Global.anySlotExists():
		_closeSlots()
		return
	_buildSlotPanel()

#endregion

# Curl up, then roll off the right side of the screen
func _on_continue() -> void:
	if rolling: return
	# Continue from the main list: make sure the state is exactly that slot's save
	if mainBox.visible:
		if not Global.loadSlot(Global.saveSlot): return
		_refreshShell()
	for p in [mainBox, slotPanel]:
		for b in p.find_children("*", "Button", true, false): b.disabled = true
	create_tween().tween_property(menu, "modulate:a", 0.0, 0.35)
	if trail and is_instance_valid(trail): trail.retire()
	speed = 0.0
	body.play("start_roll")
	await body.animation_finished
	shell.position = _rollShellPos()
	body.play("roll")
	speed = walk_speed
	rolling = true

func _leave() -> void:
	leaving = true
	var tw : Tween = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func(): Global.inMenu = false) # Global's scene manager loads the hub

#endregion
