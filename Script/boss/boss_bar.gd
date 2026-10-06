extends CanvasLayer
class_name BossBar

# Big boss health bar across the top of the screen with the boss's name above it.
# A pale "lag" bar trails behind the red one so big hits read clearly.

const FONT_UID : String = "uid://dv68j0l4djo44" # Tiny5, same as the rest of the UI
const BAR_SIZE : Vector2 = Vector2(900, 26)
const TOP : float = 62.0

var nameLabel : Label = null
var bar : ProgressBar = null
var lagBar : ProgressBar = null
var root : Control = null

var _lagDelay : float = 0.0
var _shown : bool = false

func _init() -> void:
	layer = 4
	name = "BossBar"

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	add_child(root)
	
	var font : Font = load(FONT_UID)
	nameLabel = Label.new()
	nameLabel.add_theme_font_override("font", font)
	nameLabel.add_theme_font_size_override("font_size", 34)
	nameLabel.add_theme_constant_override("outline_size", 8)
	nameLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	nameLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centerTop(nameLabel, TOP, Vector2(BAR_SIZE.x, 44))
	root.add_child(nameLabel)
	
	lagBar = _makeBar(Color(1.0, 0.9, 0.65), true)
	bar = _makeBar(Color(0.82, 0.12, 0.16), false)

func _makeBar(fill: Color, withBg: bool) -> ProgressBar:
	var b : ProgressBar = ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centerTop(b, TOP + 46, BAR_SIZE)
	b.max_value = 1.0
	b.step = 0.0
	b.value = 1.0
	var bg : StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.08, 0.85) if withBg else Color(0, 0, 0, 0)
	if withBg:
		bg.set_border_width_all(4)
		bg.border_color = Color(0, 0, 0, 0.95)
	var fg : StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_border_width_all(4)
	fg.border_color = Color(0, 0, 0, 0) # keeps the fill inside the frame
	fg.draw_center = true
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	root.add_child(b)
	return b

# Horizontally centred, `top` px from the top of the screen
static func _centerTop(c: Control, top: float, sz: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -sz.x * 0.5
	c.offset_right = sz.x * 0.5
	c.offset_top = top
	c.offset_bottom = top + sz.y

func setBoss(displayName: String) -> void:
	if nameLabel: nameLabel.text = displayName

# frac: 0..1 health left
func setHealth(frac: float) -> void:
	if not bar: return
	if frac < bar.value: _lagDelay = 0.45
	bar.value = clampf(frac, 0.0, 1.0)
	if lagBar.value < bar.value: lagBar.value = bar.value

func setShown(on: bool) -> void:
	_shown = on

func _process(delta: float) -> void:
	if not root: return
	root.modulate.a = move_toward(root.modulate.a, 1.0 if _shown else 0.0, delta * 3.0)
	if _lagDelay > 0.0:
		_lagDelay -= delta
	elif lagBar.value > bar.value:
		lagBar.value = move_toward(lagBar.value, bar.value, delta * 0.5)
