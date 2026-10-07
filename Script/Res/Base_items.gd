extends Resource
class_name BaseItem

enum item_type {
	USABLE,
	WEAPON,
	ARMOR
}

enum hotbar_type {
	NONE,
	WEAPON,
	ITEM
}

enum sort_type {
	ITEM,
	WEAPON,
	ARMOR
}

@export_category("Base Item")
@export var name : String = ""
@export_category("Icon")
@export var itemIcon : Texture2D
@export var iconScale : float = 1.3
@export_range(0, 360, 0.1) var iconRotOffset : float = 0
@export_category("Ground")
@export var groundScale : float = 1
@export_category("Placed")
@export var placedScene : PackedScene = null
@export_category("Base Item Descriptors")
@export var itemType : item_type = item_type.USABLE
@export var equippable : bool = false
@export var stackable : bool = true
@export var throwable : bool = false
@export var placable : bool = false
@export var hotBarType : hotbar_type = hotbar_type.NONE
@export var sortType : sort_type = sort_type.ITEM
@export_category("Base Item Data")
@export var weight : float = 1.0
@export var baseCost : float = 30
@export var costVar : float = 0.2
@export var sellable : bool = true
@export var rolled : bool = false
@export var quantity : int = 1
@export_category("Unique")
## One-of-a-kind items (task / quest rewards). They roll a normal rarity, then get UNIQUE_BONUS on
## top of their stats, show as "Unique (tier)" and set sellable = false in their file.
@export var unique : bool = false
@export_category("Quest")
## Quest items do nothing on their own (no Use button); a quest checks for them later
@export var questItem : bool = false
@export_multiline var description : String = ""
@export_category("Rolled Stats")
@export var rarity : int = -1
@export var cost : int
@export var shopPrice : int

var setDay : int = 0

const UNIQUE_BONUS : float = 0.15
const UNIQUE_COLOR : Color = Color(1.0, 0.55, 0.12)
## Stat multiplier on top of the rolled rarity: x1.15 for unique items, x1 otherwise
func uniqueMult() -> float:
	return 1.0 + UNIQUE_BONUS if unique else 1.0

## Rarity odds for a roll at day 0 with no Luck:
##   Common 55%, Uncommon 25%, Rare 12%, Epic 5.5%, Legend 2.2%, Historical 0.3%
## (was a flat 1-in-6 per tier, so a top-tier weapon turned up within a run or two).
## Bonuses (later days, Luck, blood moon, the boss) multiply the odds of every tier above Common
## by 1 / (1 - bonus): +0.25 = x1.33, +0.5 = x2, capped at x10. (Adding the bonus to the roll
## instead pushed everything past the top of the table into Historical.)
const RARITY_THRESHOLDS : Array[float] = [0.55, 0.80, 0.92, 0.975, 0.997]
const DAY_RARITY_BIAS : float = 0.015 # bonus per day of the roll: day 5 x1.08, day 20 x1.43

static func rollRarity(rng: RandomNumberGenerator, day: float) -> int:
	var u : float = rng.randf()
	var bonus : float = day * DAY_RARITY_BIAS + Global.rarityRollBonus()
	if bonus < 0.0: return 0 # forced Common (starter weapons, enemies' own weapons)
	var v : float = 1.0 - (1.0 - u) * (1.0 - minf(bonus, 0.9))
	for i in RARITY_THRESHOLDS.size():
		if v < RARITY_THRESHOLDS[i]: return i
	return RARITY_THRESHOLDS.size()

func rollStats() -> void:
	if Global.sceneIndex != 0:
		setDay = Global.runDays
	else:
		var per = lerp(0.5, 1.0, Global.performance)
		setDay = Global.meta * per
	
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Global.rng
	
	rarity = BaseItem.rollRarity(rng, setDay)
	
	var rarityMult : float = 1.0 + rarity * 0.25
	
	var curve : float = pow(setDay, 1.2)
	var progMult : float = 1.0 + curve * 0.01
	
	if cost == 0:
		var costVariance : float = baseCost * costVar
		cost = roundi(rng.randf_range(baseCost - costVariance, baseCost + costVariance) * rarityMult * progMult)
	
	shopPrice = cost - roundi(cost * 0.15)
	
	Global.rng = randi()
	rolled = true

# Which hot bar this goes in. Weapons whose file never set a hot bar type (left at NONE) still
# go in the weapon bar, so every weapon can be slotted (also fixes copies already in saves).
func hotbarKind() -> int:
	if hotBarType == hotbar_type.NONE and itemType == item_type.WEAPON:
		return hotbar_type.WEAPON
	return hotBarType

func getRarity() -> Dictionary:
	var result : Dictionary = {
		"txt":"",
		"color":Color.WEB_GRAY
	}
	
	match rarity:
		0: 
			result.txt = "Common"
			result.color = Color.WEB_GRAY
		1:
			result.txt = "Uncommon"
			result.color = Color.GREEN_YELLOW
		2:
			result.txt = "Rare"
			result.color = Color.ROYAL_BLUE
		3:
			result.txt = "Epic"
			result.color = Color.WEB_PURPLE
		4:
			result.txt = "Legend"
			result.color = Color.GOLDENROD
		5:
			result.txt = "Historical"
			result.color = Color.BLACK
	
	if unique:
		result.txt = "Unique (%s)" % result.txt
		result.color = UNIQUE_COLOR
	
	return result

func use() -> void:
	pass

func equip() -> void:
	pass

func unequip() -> void:
	pass

func buy(amount: int = 1, limited: bool = true) -> void:
	if not stackable: amount = 1
	amount = clampi(amount, 1, quantity)
	
	var totalCost : int = cost * amount
	
	if Global.money < totalCost: return
	Global.money -= totalCost
	
	var newItem : BaseItem = self.duplicate()
	newItem.quantity = amount
	
	Global.inventory.add_item(newItem)
	if limited: quantity -= amount

func sell(amount: int = 1) -> void:
	if not stackable: amount = 1
	amount = clampi(amount, 1, quantity)
	
	var totalCost : int = shopPrice * amount
	
	Global.money += totalCost
	unequip()
	quantity -= amount

func drop(amount: int = 1, decrement: bool = true, pos = null) -> void:
	var thisDropPos : Vector2 = Global.player.global_position if not pos else pos
	
	if not stackable: amount = 1
	amount = clampi(amount, 1, quantity)
	unequip()
	
	if stackable:
		var groundItems : Array[Node] = Global.getGroundItems()
		
		if groundItems.size() != 0:
			for i in groundItems:
				var base : Node2D = i
				
				if thisDropPos.distance_to(base.global_position) > Global.pickupRange: continue
				
				if base.item.name == name:
					base.item.quantity += amount
					if decrement: quantity -= amount
					return
	
	var newGroundItem : Node2D = load("uid://b5eq6i6you4bx").instantiate()
	newGroundItem.name = name
	newGroundItem.position = thisDropPos
	var newItem : BaseItem = self.duplicate()
	newItem.quantity = amount
	newGroundItem.item = newItem
	if decrement: quantity -= amount
	Global.currentScene.add_child(newGroundItem)

func place(pos: Vector2) -> void:
	if placable and equippable:
		var newItem : BaseItem = self.duplicate()
		newItem.quantity = 1
		newItem.spawnPlaced(pos)
		quantity -= 1

# Spawns this item's placedScene in the world with THIS item on it (no copy).
# Used by place() and by Global.genGroundItems() to bring placed things back after a save.
func spawnPlaced(pos: Vector2, rot: float = 0.0) -> Node2D:
	var newPlacedScene : Node2D = placedScene.instantiate()
	newPlacedScene.name = name
	newPlacedScene.global_position = pos
	newPlacedScene.rotation = rot
	newPlacedScene.z_index = 3
	newPlacedScene.add_to_group("items")
	
	if "item" in newPlacedScene:
		newPlacedScene.item = self
	
	if "weapSys" in newPlacedScene:
		var newWeapSys : WeaponSys = WeaponSys.new()
		newWeapSys.weapon = self
		newPlacedScene.weapSys = newWeapSys
	
	Mutation.applyTree(newPlacedScene, self)
	Global.currentScene.add_child(newPlacedScene)
	return newPlacedScene
