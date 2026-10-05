extends Line2D
class_name SlimeTrail

# One continuous slime trail behind the snail.
# The player calls extend() while moving; points older than `lifetime` get dropped from the tail,
# and the gradient / width curve fade and thin the tail out. A thin lighter line on top makes it
# look wet. Frees itself once it has fully faded.

@export var lifetime : float = 0.8          # seconds before a point disappears
@export var max_length : float = 48.0       # px; the tail is trimmed so the trail is never longer than this
@export var min_point_dist : float = 2.0    # px between points (smaller = smoother, more points)
@export var max_jump : float = 40.0         # a bigger jump (roll, teleport) starts a new trail instead of a long straight line
@export var slime_color : Color = Color(0.42, 0.75, 0.19)
@export var slime_alpha : float = 0.3
@export var trail_width : float = 7.0
@export var shine_color : Color = Color(0.8, 1.0, 0.65)
@export var shine_alpha : float = 0.35
@export var shine_width : float = 2.0

var _times : PackedFloat64Array = PackedFloat64Array() # creation time of each point (seconds)
var _shine : Line2D = null
var _retired : bool = false

func _ready() -> void:
	z_index = 1 # same layer the old slime sprites used
	width = trail_width
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = false
	gradient = _fade_gradient(slime_color, slime_alpha)
	width_curve = _taper_curve()
	
	_shine = Line2D.new()
	_shine.width = shine_width
	_shine.joint_mode = Line2D.LINE_JOINT_ROUND
	_shine.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_shine.end_cap_mode = Line2D.LINE_CAP_ROUND
	_shine.antialiased = false
	_shine.gradient = _fade_gradient(shine_color, shine_alpha)
	_shine.width_curve = width_curve
	_shine.position = Vector2(0, -1) # catch the light slightly off-centre
	add_child(_shine)

# Adds the snail's current position. Returns false if this trail is retired
# (the caller should start a new SlimeTrail).
func extend(global_pos: Vector2) -> bool:
	if _retired:
		return false
	var p : Vector2 = to_local(global_pos)
	var n : int = get_point_count()
	
	# First call: a committed point plus a floating head, both under the snail
	if n == 0:
		add_point(p)
		add_point(p)
		_times.append(_now())
		_times.append(_now())
		_sync_shine()
		return true
	
	# The last point is a floating head that follows the snail every frame;
	# a new point is committed once the head is min_point_dist from the last committed one
	if get_point_position(n - 1).distance_to(p) > max_jump:
		_retired = true # leave this one to fade, the next call makes a new trail
		return false
	set_point_position(n - 1, p)
	_times[n - 1] = _now()
	if get_point_position(n - 2).distance_to(p) >= min_point_dist:
		add_point(p)
		_times.append(_now())
	_sync_shine()
	return true

func retire() -> void:
	_retired = true

func is_retired() -> bool:
	return _retired

func _process(_delta: float) -> void:
	var cutoff : float = _now() - lifetime
	var removed : bool = false
	while get_point_count() > 0 and _times[0] < cutoff:
		remove_point(0)
		_times.remove_at(0)
		removed = true
	# Length cap: walk back from the head and drop everything past max_length
	var n : int = get_point_count()
	if n > 2:
		var total : float = 0.0
		var keep_from : int = 0
		for i in range(n - 1, 0, -1):
			total += get_point_position(i).distance_to(get_point_position(i - 1))
			if total > max_length:
				keep_from = i - 1
				break
		if keep_from > 0:
			for i in keep_from:
				remove_point(0)
			_times = _times.slice(keep_from)
			removed = true
	if removed:
		_sync_shine()
	if get_point_count() == 0 and (_retired or _times.is_empty()):
		queue_free()

func _sync_shine() -> void:
	if _shine:
		_shine.points = points

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Tail (oldest end, offset 0) fades to nothing, head is fully visible
func _fade_gradient(c: Color, a: float) -> Gradient:
	var g : Gradient = Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(c, 0.0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(c, a))
	g.add_point(0.4, Color(c, a * 0.75))
	return g

# Thin at the tail, full width from 30% up to the head
func _taper_curve() -> Curve:
	var curve : Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 1.0))
	return curve
