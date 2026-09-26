class_name Settings
extends RefCounted
## Player settings in user://settings.cfg: volumes and auto-pause triggers.

const PATH := "user://settings.cfg"

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in Audio.volume:
		Audio.volume[k] = float(cfg.get_value("audio", k, Audio.volume[k]))
	for k in TacticalPause.settings:
		TacticalPause.settings[k] = bool(cfg.get_value("pause", k, TacticalPause.settings[k]))

static func save() -> void:
	var cfg := ConfigFile.new()
	for k in Audio.volume:
		cfg.set_value("audio", k, Audio.volume[k])
	for k in TacticalPause.settings:
		cfg.set_value("pause", k, TacticalPause.settings[k])
	cfg.save(PATH)
