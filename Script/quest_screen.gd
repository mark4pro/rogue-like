extends Control
class_name QuestScreen

# Fourth inventory page (Inventory / Pickup / Character / Quests), also opened with J.
# Tabs along the top; "Tasks" is the first (Tasks.LIST: progress bar, reward, Claim button).
# Built in code; sits in the player's inventoryUI CanvasLayer like the other pages.

const FONT_UID : String = "uid://dv68j0l4djo44"
const BG_COLOR : Color = Color(0.21, 0.16534, 0.1491, 1)
const CARD_COLOR : Color = Color(0.14, 0.11, 0.1, 0.9)
const MENU_SIZE : Vector2 = Vector2(1000, 600)
const DONE_COLOR : Color = Color(0.6, 0.9, 0.4)
const DIM_COLOR : Color = Color(0.72, 0.66, 0.6)

var _font : FontFile = null
var _tabs : TabBar = null
var _pages : Array[Control] = []
var _taskRows : Dictionary = {} # task id -> {bar, count, claim, title}
var _refreshT : float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_UID) as FontFile
	
	# Same footprint and look as the other pages
	set_anchors_preset(Control.PRESET_CENTER)
	position = get_viewport_rect().size / 2 + Vector2(-520, -320)
	modulate = Color(1, 1, 1, 0.5647059)
	
	var bg : ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.size = MENU_SIZE
	add_child(bg)
	
	var title : Label = _label("Quests", 64)
	title.size = Vector2(MENU_SIZE.x, 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg.add_child(title)
	
	_tabs = TabBar.new()
	_tabs.position = Vector2(30, 78)
	_tabs.size = Vector2(MENU_SIZE.x - 60, 40)
	_tabs.add_theme_font_override("font", _font)
	_tabs.add_theme_font_size_override("font_size", 26)
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.add_tab("Tasks")
	_tabs.tab_changed.connect(_on_tab)
	bg.add_child(_tabs)
	
	_pages.append(_buildTasksPage(bg))
	_on_tab(0)
	refresh()

func _label(text: String, fontSize: int, color: Color = Color.WHITE) -> Label:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fontSize)
	l.add_theme_color_override("font_color", color)
	return l

func _on_tab(i: int) -> void:
	for p in _pages.size():
		_pages[p].visible = p == i

#region Tasks tab

func _buildTasksPage(bg: Control) -> Control:
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(30, 128)
	scroll.size = Vector2(MENU_SIZE.x - 60, MENU_SIZE.y - 148)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	
	var list : VBoxContainer = VBoxContainer.new()
	list.custom_minimum_size = Vector2(MENU_SIZE.x - 80, 0)
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	
	for t in Tasks.LIST:
		list.add_child(_taskCard(t))
	return scroll

func _taskCard(t: Dictionary) -> Control:
	var card : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = CARD_COLOR
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	
	# Left: title, description, progress
	var info : VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var titleLbl : Label = _label(t.title, 30)
	info.add_child(titleLbl)
	var desc : Label = _label(t.desc, 20, DIM_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	
	var progRow : HBoxContainer = HBoxContainer.new()
	progRow.add_theme_constant_override("separation", 10)
	info.add_child(progRow)
	var bar : ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(380, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = int(t.goal)
	var fill : StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.7, 0.2)
	var back : StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.06, 0.05)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	progRow.add_child(bar)
	var countLbl : Label = _label("", 22)
	progRow.add_child(countLbl)
	
	# Right: reward and Claim
	var rewardBox : VBoxContainer = VBoxContainer.new()
	rewardBox.custom_minimum_size = Vector2(230, 0)
	rewardBox.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(rewardBox)
	rewardBox.add_child(_label("Reward", 18, DIM_COLOR))
	var item : BaseItem = Tasks.rewardItem(t)
	var rewardRow : HBoxContainer = HBoxContainer.new()
	rewardRow.add_theme_constant_override("separation", 8)
	rewardBox.add_child(rewardRow)
	if item:
		var icon : TextureRect = TextureRect.new()
		icon.texture = item.itemIcon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rewardRow.add_child(icon)
		var nameLbl : Label = _label(item.name + ("\nUnique" if item.unique else ""), 20, BaseItem.UNIQUE_COLOR if item.unique else Color.WHITE)
		nameLbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rewardRow.add_child(nameLbl)
	
	var claim : Button = Button.new()
	claim.custom_minimum_size = Vector2(200, 44)
	claim.add_theme_font_override("font", _font)
	claim.add_theme_font_size_override("font_size", 24)
	claim.focus_mode = Control.FOCUS_NONE
	claim.pressed.connect(_on_claim.bind(t.id))
	rewardBox.add_child(claim)
	
	_taskRows[t.id] = {"bar": bar, "count": countLbl, "claim": claim, "title": titleLbl}
	return card

func _on_claim(id: String) -> void:
	Tasks.claim(Tasks.getTask(id))
	refresh()

#endregion

func _process(delta: float) -> void:
	if not visible: return
	_refreshT -= delta
	if _refreshT <= 0.0:
		_refreshT = 0.25
		refresh()

func refresh() -> void:
	for t in Tasks.LIST:
		var r : Dictionary = _taskRows.get(t.id, {})
		if r.is_empty(): continue
		var p : int = Tasks.progress(t)
		var done : bool = Tasks.isDone(t)
		var claimed : bool = Tasks.isClaimed(t)
		r.bar.value = p
		r.count.text = "%d / %d" % [p, int(t.goal)]
		r.title.add_theme_color_override("font_color", DONE_COLOR if done else Color.WHITE)
		r.claim.disabled = not done or claimed
		r.claim.text = "Claimed" if claimed else ("Claim" if done else "In progress")
