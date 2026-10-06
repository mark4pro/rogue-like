extends Node2D
class_name BossSite

# Where the broken Robotic Spider Eye lies (Worldgen places one per run in a forest clearing).
# While the player is nearby, evil roaches fetch scrap pieces from around the clearing and drop
# them into the eye. The repair is on a timer: on run day `activate_run_day` the eye wakes up and
# the fight starts, wherever the player is (it hunts them down).

const PIECE_TEX : Texture2D = preload("res://Assets/imgs/enemies/testing/eyeball_spider_leg_piece.png")

## The eye wakes when the run's day counter ("Days:" on the HUD) reaches this
@export var activate_run_day : int = 5
@export var roach_count : int = 5
@export var piece_count : int = 7
@export var piece_min_distance : float = 70.0
@export var piece_max_distance : float = 220.0
## Roaches and scrap only exist while the player is this close (the repair timer runs regardless)
@export var active_range : float = 1100.0

var boss : SpiderEyeBoss = null
var piecesNode : Node2D = null
var roaches : Array[Node] = []
var activated : bool = false
var defeated : bool = false
var _spawnT : float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	add_to_group("boss_site")
	piecesNode = Node2D.new()
	piecesNode.name = "Pieces"
	piecesNode.y_sort_enabled = true
	add_child(piecesNode)
	boss = SpiderEyeBoss.new()
	boss.name = "RoboticSpiderEye"
	add_child(boss)
	boss.defeated.connect(func(): defeated = true)

# 0..1 toward the wake-up day
func progress() -> float:
	return clampf((Global.runDays + Global.timeOfDay) / float(maxi(activate_run_day, 1)), 0.0, 1.0)

func _process(delta: float) -> void:
	if get_tree().paused: return
	roaches = roaches.filter(func(r): return is_instance_valid(r))
	if activated or defeated or not is_instance_valid(boss):
		return
	
	boss.setRepair(progress())
	if Global.runDays >= activate_run_day:
		activate()
		return
	
	var p : Node = Global.player
	var near : bool = is_instance_valid(p) and p.global_position.distance_to(global_position) <= active_range
	if near: _keepPopulated(delta)
	else: _clearHelpers()

# Wake the boss now (also handy for testing from the debugger)
func activate() -> void:
	if activated: return
	activated = true
	for c in piecesNode.get_children(): c.queue_free()
	boss.wake() # shoves everything away and sends the roaches running
	roaches.clear()

func _keepPopulated(delta: float) -> void:
	_spawnT -= delta
	if _spawnT > 0.0: return
	_spawnT = 0.4
	if piecesNode.get_child_count() < piece_count:
		_spawnPiece()
	if roaches.size() < roach_count:
		var r : EvilRoach = EvilRoach.new()
		r.site = self
		r.position = to_local(_randomGround(piece_min_distance, piece_max_distance))
		add_child(r)
		roaches.append(r)

func _clearHelpers() -> void:
	for r in roaches: r.queue_free()
	roaches.clear()
	for c in piecesNode.get_children(): c.queue_free()

func _spawnPiece() -> void:
	var s : Sprite2D = Sprite2D.new()
	s.texture = PIECE_TEX
	s.scale = Vector2.ONE * randf_range(0.3, 0.4)
	s.rotation = randf() * TAU
	s.modulate = Color(0.78, 0.8, 0.88)
	s.position = piecesNode.to_local(_randomGround(piece_min_distance, piece_max_distance))
	piecesNode.add_child(s)

# Random walkable forest spot in a ring around the eye
func _randomGround(minD: float, maxD: float) -> Vector2:
	var pos : Vector2 = global_position
	for i in 24:
		var a : float = randf() * TAU
		pos = global_position + Vector2(cos(a), sin(a) * 0.75) * randf_range(minD, maxD)
		if not Worldgen.loaded or Worldgen.world.is_empty(): return pos
		var cell : Vector2i = Worldgen.cell_at(pos)
		if Worldgen.in_bounds(cell):
			var t : WorldTile = Worldgen.get_tile(cell)
			if t.is_walkable and Worldgen.is_forest(t): return pos
	return pos

#region Used by EvilRoach

# Nearest piece nobody else is fetching
func claimPiece(roach: Node2D) -> Node2D:
	var best : Node2D = null
	var bestD : float = INF
	for c in piecesNode.get_children():
		if c.is_queued_for_deletion() or c.has_meta("claimed"): continue
		var d : float = c.global_position.distance_to(roach.global_position)
		if d < bestD:
			bestD = d
			best = c
	if best: best.set_meta("claimed", true)
	return best

# Where a roach drops its piece: the edge of the eye on its side
func dropPoint(roach: Node2D) -> Vector2:
	var d : Vector2 = roach.global_position - global_position
	if d.length() < 0.1: d = Vector2.RIGHT
	return global_position + Vector2(d.normalized().x * 24.0, d.normalized().y * 12.0)

func delivered(_roach: Node2D) -> void:
	if is_instance_valid(boss): boss.repairPing()

#endregion
