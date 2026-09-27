class_name Settings
extends RefCounted
## Player settings in user://settings.cfg: volumes, auto-pause triggers and graphics quality.

const PATH := "user://settings.cfg"
const QUALITY := ["low", "medium", "high"]

static var graphics := "high"

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in Audio.volume:
		Audio.volume[k] = float(cfg.get_value("audio", k, Audio.volume[k]))
	for k in TacticalPause.settings:
		TacticalPause.settings[k] = bool(cfg.get_value("pause", k, TacticalPause.settings[k]))
	graphics = String(cfg.get_value("video", "graphics", graphics))
	if not QUALITY.has(graphics):
		graphics = "high"

static func save() -> void:
	var cfg := ConfigFile.new()
	for k in Audio.volume:
		cfg.set_value("audio", k, Audio.volume[k])
	for k in TacticalPause.settings:
		cfg.set_value("pause", k, TacticalPause.settings[k])
	cfg.set_value("video", "graphics", graphics)
	cfg.save(PATH)

## Apply the graphics level to a scene's environment and sun. SSAO, glow and SSIL need the
## Forward+ renderer; on the Compatibility fallback they are simply ignored.
static func apply_graphics(env: Environment, sun: DirectionalLight3D, vp: Viewport) -> void:
	var level := QUALITY.find(graphics)
	# the Compatibility fallback (no Vulkan) mis-renders glow on the background; keep it plain
	var fplus := RenderingServer.get_rendering_device() != null
	env.ssao_enabled = level >= 1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = level >= 1 and fplus
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssil_enabled = level >= 2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if level == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [40.0, 60.0, 80.0][level]
	sun.shadow_blur = [0.5, 1.0, 1.5][level]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][level]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
