extends Node
## Global signal bus.

signal paused_changed(paused: bool)
signal selection_changed(members: Array)
signal hour_changed(hour: int)
signal enemy_spotted(creature: Node)
signal combat_message(text: String)
signal talk_requested(villager: Node)
signal ui_opened(opened: bool)
signal story_effect(effect: String)
signal quests_changed
