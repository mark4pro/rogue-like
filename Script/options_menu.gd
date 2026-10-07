extends Control
class_name OptionsMenu

# Options menu, built entirely in code (no scene to keep in sync).
# Opened from the pause menu. Every change goes straight through Settings, which applies and saves it.
# Esc: cancels a rebind if one is waiting, otherwise closes the menu.

signal closed

const FONT : FontFile = preload("uid://dv68j0l4djo44")
const BG_COLOR : Color = Color(0.1477, 0.1477, 0.1477, 1)
const ROW_LABEL_WIDTH : float = 420.0

var tabs : TabContainer
var _listen_action : String = ""  # action waiting for a new key ("" = not rebinding)
var _listen_button : Button = null
var _bind_buttons : Dictionary = {} # action -> Button

func _ready() -> void:
	name = "OptionsMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	Settings.options_open = true
	_build()

func _exit_tree() -> void:
	Settings.options_open = false

func close() -> void:
	Settings.consume_pause()
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	# Rebinding: grab the next key / mouse button
	if _listen_action != "":
		var bind : InputEvent = null
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
				_stop_listening()
				Settings.consume_pause()
				get_viewport().set_input_as_handled()
				return
			var k : InputEventKey = InputEventKey.new()
			k.physical_keycode = event.physical_keycode
			k.keycode = event.keycode
			bind = k
		elif event is InputEventMouseButton and event.pressed:
			var m : InputEventMouseButton = InputEventMouseButton.new()
			m.button_index = event.button_index
			bind = m
		elif event is InputEventJoypadButton and event.pressed:
			var j : InputEventJoypadButton = InputEventJoypadButton.new()
			j.button_index = event.button_index
			bind = j
		if bind:
			Settings.set_bind(_listen_action, bind)
			_stop_listening()
			get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

#region Building

func _build() -> void:
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(1300, 820)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(960 - 650, 540 - 410)
	add_child(panel)
	
	var root : VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	
	var title : Label = Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	root.add_child(title)
	
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	
	_build_game_tab()
	_build_audio_tab()
	_build_graphics_tab()
	if Settings.is_editor():
		_build_debug_tab()
	_build_controls_tab()
	
	var bottom : HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	
	var reset : Button = Button.new()
	reset.text = "Reset tab to defaults"
	reset.pressed.connect(_on_reset_tab)
	bottom.add_child(reset)
	
	var back : Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size.x = 200
	back.pressed.connect(close)
	bottom.add_child(back)

func _rebuild(keep_tab: int) -> void:
	_stop_listening()
	_bind_buttons.clear()
	for c in get_children():
		c.free()
	_build()
	tabs.current_tab = clampi(keep_tab, 0, tabs.get_tab_count() - 1)

func _make_tab(tab_name: String, section: String) -> VBoxContainer:
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("section", section)
	tabs.add_child(scroll)
	
	var margin : MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	
	var box : VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box

func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var label : Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	row.add_child(label)
	return row

func _header(box: VBoxContainer, text: String) -> void:
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(label)

func _check(box: VBoxContainer, text: String, section: String, key: String) -> CheckButton:
	var row : HBoxContainer = _row(box, text)
	var cb : CheckButton = CheckButton.new()
	cb.button_pressed = Settings.get_value(section, key)
	cb.toggled.connect(func(on: bool): Settings.set_value(section, key, on))
	row.add_child(cb)
	return cb

func _option(box: VBoxContainer, text: String, section: String, key: String, items: Array) -> OptionButton:
	var row : HBoxContainer = _row(box, text)
	var ob : OptionButton = OptionButton.new()
	ob.custom_minimum_size.x = 420
	for item in items:
		ob.add_item(str(item))
	ob.selected = Settings.get_value(section, key)
	ob.item_selected.connect(func(i: int): Settings.set_value(section, key, i))
	row.add_child(ob)
	return ob

# Slider with a live value label. `setter` gets the new value; `fmt` turns a value into text.
func _slider(box: VBoxContainer, text: String, value: float, min_v: float, max_v: float, step: float, setter: Callable, fmt: Callable) -> HSlider:
	var row : HBoxContainer = _row(box, text)
	var s : HSlider = HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(420, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val : Label = Label.new()
	val.custom_minimum_size.x = 120
	val.text = fmt.call(value)
	row.add_child(val)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		setter.call(v))
	return s

func _build_game_tab() -> void:
	var box : VBoxContainer = _make_tab("Game", "game")
	_check(box, "Damage numbers", "game", "damage_numbers")
	_check(box, "Hit wobble", "game", "damage_tilt")
	_slider(box, "Camera zoom", Settings.get_value("game", "camera_zoom"), 4.0, 10.0, 0.5,
		func(v: float): Settings.set_value("game", "camera_zoom", v),
		func(v: float): return "%.1fx" % v)

func _build_audio_tab() -> void:
	var box : VBoxContainer = _make_tab("Audio", "audio")
	for i in AudioServer.bus_count:
		var bus : String = AudioServer.get_bus_name(i)
		if not Settings.audio.has(bus):
			continue
		var row : HBoxContainer = _row(box, bus)
		var s : HSlider = HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.value = roundf(Settings.audio[bus].volume * 100.0)
		s.custom_minimum_size = Vector2(420, 32)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(s)
		var val : Label = Label.new()
		val.custom_minimum_size.x = 100
		val.text = "%d%%" % int(s.value)
		row.add_child(val)
		var mute : CheckBox = CheckBox.new()
		mute.text = "Mute"
		mute.button_pressed = Settings.audio[bus].mute
		row.add_child(mute)
		s.value_changed.connect(func(v: float):
			val.text = "%d%%" % int(v)
			Settings.set_bus_volume(bus, v / 100.0))
		mute.toggled.connect(func(on: bool): Settings.set_bus_mute(bus, on))

func _build_graphics_tab() -> void:
	var box : VBoxContainer = _make_tab("Graphics", "graphics")
	_header(box, "Display")
	_option(box, "Window mode", "graphics", "window_mode", Settings.WINDOW_MODES)
	_check(box, "Borderless", "graphics", "borderless")
	var res_names : Array = []
	for r in Settings.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
	_option(box, "Resolution (windowed)", "graphics", "resolution", res_names)
	_option(box, "V-Sync", "graphics", "vsync", Settings.VSYNC_MODES)
	var fps_names : Array = []
	for f in Settings.MAX_FPS_VALUES:
		fps_names.append("Unlimited" if f == 0 else str(f))
	_option(box, "Max FPS", "graphics", "max_fps", fps_names)
	_header(box, "Quality")
	_option(box, "Anti-aliasing", "graphics", "msaa", Settings.MSAA_MODES)
	_check(box, "Shadows", "graphics", "shadows")
	_check(box, "Particles", "graphics", "particles")

func _build_debug_tab() -> void:
	var box : VBoxContainer = _make_tab("Debug", "debug")
	_check(box, "Show FPS", "debug", "show_fps")
	_check(box, "Enemy vision cones", "debug", "vision_cones")
	_check(box, "Blood moons", "debug", "blood_moons")
	_check(box, "Biome overlay", "debug", "biome_overlay")
	_slider(box, "Time scale", Settings.get_value("debug", "time_scale"), 0.1, 3.0, 0.1,
		func(v: float): Settings.set_value("debug", "time_scale", v),
		func(v: float): return "%.1fx" % v)

func _build_controls_tab() -> void:
	var box : VBoxContainer = _make_tab("Controls", "controls")
	var hint : Label = Label.new()
	hint.text = "Click a binding, then press a key or mouse button. Esc cancels."
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(hint)
	for action in Settings.rebindable_actions():
		var row : HBoxContainer = _row(box, _pretty(action))
		var b : Button = Button.new()
		b.custom_minimum_size.x = 420
		b.text = Settings.action_text(action)
		b.pressed.connect(_start_listening.bind(action, b))
		row.add_child(b)
		_bind_buttons[action] = b
		var reset : Button = Button.new()
		reset.text = "Reset"
		reset.pressed.connect(func():
			_stop_listening()
			Settings.reset_bind(action)
			b.text = Settings.action_text(action))
		row.add_child(reset)

#endregion

#region Rebinding / reset

func _start_listening(action: String, b: Button) -> void:
	_stop_listening()
	_listen_action = action
	_listen_button = b
	b.text = "Press a key..."

func _stop_listening() -> void:
	if _listen_button and is_instance_valid(_listen_button):
		_listen_button.text = Settings.action_text(_listen_action)
	_listen_action = ""
	_listen_button = null

func _on_reset_tab() -> void:
	var page : Control = tabs.get_current_tab_control()
	if page and page.has_meta("section"):
		Settings.reset_section(page.get_meta("section"))
		_rebuild(tabs.current_tab)

static func _pretty(action: String) -> String:
	return action.replace("_", " ").capitalize()

func _make_theme() -> Theme:
	var t : Theme = Theme.new()
	t.default_font = FONT
	t.default_font_size = 32
	return t

#endregion
