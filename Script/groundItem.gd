extends Node2D

@export var item : BaseItem

@onready var item_sprite : Sprite2D = $Icon

func _ready() -> void:
	if rotation == 0:
		rotation_degrees = randf_range(0, 360)
	# Only the icon is scaled, so the pickup area stays the same size for every item
	var s : float = groundScaleFor(item)
	item_sprite.scale = Vector2(s, s)
	item_sprite.texture = item.itemIcon
	if not item.rolled: item.rollStats()
	Mutation.applyTo(item_sprite, item)

# Ground items match how big the item looks when equipped/thrown: the scale its weapon (or armor)
# scene draws the same icon at. Items without such a scene (potions...) keep their groundScale.
static var _scaleCache : Dictionary = {} # scene path -> scale (or -1 when it can't be worked out)

static func groundScaleFor(it: BaseItem) -> float:
	var scn : PackedScene = null
	if "weaponScene" in it: scn = it.weaponScene
	elif "armorScene" in it: scn = it.armorScene
	if not scn or not it.itemIcon:
		return it.groundScale
	if not _scaleCache.has(scn.resource_path):
		_scaleCache[scn.resource_path] = _sceneSpriteScale(scn, it.itemIcon)
	var s : float = _scaleCache[scn.resource_path]
	return s if s > 0.0 else it.groundScale

# Scale of the first Sprite2D in the scene showing this texture (including its parents' scale)
static func _sceneSpriteScale(scn: PackedScene, tex: Texture2D) -> float:
	var inst : Node = scn.instantiate()
	var result : float = -1.0
	var sprites : Array = [inst] if inst is Sprite2D else []
	sprites.append_array(inst.find_children("*", "Sprite2D", true, false))
	for spr in sprites:
		if spr.texture != tex: continue
		var sc : Vector2 = Vector2.ONE
		var n : Node = spr
		while n:
			if n is Node2D: sc *= n.scale
			if n == inst: break
			n = n.get_parent()
		result = absf(sc.x)
		break
	inst.free()
	return result
