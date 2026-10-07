extends RefCounted
class_name Tasks

# Tasks: small goals tracked by counters (shown in the Quests page, Tasks tab).
# Gameplay calls Tasks.count("counter_name") when something happens; a task is done when its
# counter reaches the goal, and its reward is claimed from the Tasks tab.
# Progress lives in Global.taskProgress (counter -> amount) and Global.tasksClaimed (task ids),
# both saved per slot.
#
# Adding a task: append to LIST. Reward is an item file (uid), given once.

const LIST : Array[Dictionary] = [
	{
		"id": "dummy_practice",
		"title": "Practice Makes Perfect",
		"desc": "Hit the training dummy in the hub 100 times.",
		"counter": "dummy_hits",
		"goal": 100,
		"reward": "uid://dvnsfvejt0fof", # Straw Shell (unique)
	},
]

static func getTask(id: String) -> Dictionary:
	for t in LIST:
		if t.id == id: return t
	return {}

static func progress(t: Dictionary) -> int:
	return mini(int(Global.taskProgress.get(t.counter, 0)), int(t.goal))

static func isDone(t: Dictionary) -> bool:
	return progress(t) >= int(t.goal)

static func isClaimed(t: Dictionary) -> bool:
	return Global.tasksClaimed.has(t.id)

# How many tasks are done but not claimed yet (for the "!" hint)
static func claimable() -> int:
	var n : int = 0
	for t in LIST:
		if isDone(t) and not isClaimed(t): n += 1
	return n

# Something happened: bump a counter. Announces any task that just got completed.
static func count(counter: String, amount: int = 1) -> void:
	var before : int = int(Global.taskProgress.get(counter, 0))
	var after : int = before + amount
	Global.taskProgress[counter] = after
	for t in LIST:
		if t.counter == counter and before < int(t.goal) and after >= int(t.goal) and not isClaimed(t):
			Global.sendMessage("Task complete: %s! Claim it in Quests (J)" % t.title, 5.0, Color(1.0, 0.75, 0.3))

static func rewardItem(t: Dictionary) -> BaseItem:
	if not t.has("reward") or not ResourceLoader.exists(t.reward): return null
	return load(t.reward) as BaseItem

# Gives the reward (into the inventory, or at the player's feet if it's full). Returns success.
static func claim(t: Dictionary) -> bool:
	if not isDone(t) or isClaimed(t): return false
	var item : BaseItem = rewardItem(t)
	if item:
		if Global.inventory.hasSpace(item):
			Global.inventory.add_item(item)
		elif Global.player:
			item.drop(1, false, Global.player.global_position)
		else:
			return false
	Global.tasksClaimed.append(t.id)
	Global.sendMessage("Got %s!" % (item.name if item else t.title), 4.0, BaseItem.UNIQUE_COLOR if item and item.unique else Color.GOLD)
	return true
