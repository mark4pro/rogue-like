extends BaseItem
class_name RegenPotionItem

# Restores a stat gradually instead of all at once (Snail Meds stay the instant heal).
# The player keeps the active effects; drinking another potion stacks a second effect.

enum regen_stat {
	HEALTH,
	STAMINA,
	MANA
}

@export_category("Regen Potion")
@export var stat : regen_stat = regen_stat.HEALTH
## Total amount restored over the whole duration.
@export var totalAmount : float = 60
## Seconds it takes to restore totalAmount.
@export var duration : float = 8

func use() -> void:
	var p : Node = Global.player
	if not p or not p.has_method("addRegen"): return
	# addRegen refuses stats the player doesn't have yet (mana), so the potion isn't wasted
	if not p.addRegen(stat, totalAmount, duration): return
	quantity -= 1
