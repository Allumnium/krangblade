extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const CODEX = preload("res://scripts/codex.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const SFX = preload("res://scripts/match_sfx.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RULES = preload("res://scripts/lobby_rules.gd")
const COLORS = RULES.EMPIRE_COLORS
const CONSOLE_WIDE_WIDTH: float = 1240.0
const OVERVIEW_WIDTH: float = 286.0
const YARD_WIDTH: float = 252.0
const HEADER_HEIGHT: float = 54.0
const LENS_STRIP_WIDTH: float = 32.0
const KEYBOARD_PAN_SPEED: float = 420.0
const AUTOCAST_SLOTS = {"auto_wander": "wander", "auto_mine": "mine", "auto_salvage": "salvage", "auto_repair": "repair", "auto_trade": "trade", "auto_farm": "farm", "collect": "collect", "auto_retreat": "retreat"}
const SYSTEM_WORLD_RADIUS: float = ECONOMY.SYSTEM_WORLD_RADIUS
const MIN_ZOOM: float = 0.5
const OVERVIEW_ART_MAX_MULTIPLIER: float = 4.0
const OVERVIEW_SHIP_MAX_MULTIPLIER: float = 12.0
const OVERVIEW_ART_NORMAL_ZOOM: float = 16.0
const OVERVIEW_MAX_ZOOM: float = 64.0
const FIGHTER_HULL_LENGTH: float = 22.0
const CLOSEUP_SCREEN_FRACTION: float = 0.6
const SNAPSHOT_SECONDS: float = 0.2
const THRUST_FADE_RATE: float = 5.0
const THRUST_DEAD_ZONE: float = 0.06
const TRADE_MAX_EXTRA_HEIGHT: float = 48.0
# Projected system radius in logical screen pixels, independent of selection.
const PLANET_FADE_START: float = 40.0
const PLANET_FADE_FULL: float = 100.0
const PLANET_FADE_SECONDS: float = 0.22
const STAR_TEXTURE_SIZE: int = 256
const STAR_TEXTURE_CORE: float = 74.0
const STAR_SPARK_COUNT: int = 9

# Keep construction recipes graphical even in the engine's native tooltip
# popup. Non-construction buttons still use the standard text tooltip.
class CostButton extends Button:
	var recipe: Dictionary = {}
	var missing: Array[String] = []
	var crew_icon: Texture2D
	var fast_tooltip: bool = false

	func _get_tooltip(_at_position: Vector2) -> String:
		return "" if fast_tooltip else tooltip_text

	func _make_custom_tooltip(for_text: String) -> Object:
		if recipe.is_empty():
			return null
		var panel := PanelContainer.new()
		panel.theme = HUD.compact()
		panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101b29"), Color("#6385a4"), 8, 3))
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 6)
		panel.add_child(body)
		var lines: PackedStringArray = for_text.split("\n", true, 1)
		var title := Label.new()
		title.text = lines[0]
		title.add_theme_color_override("font_color", HUD.ACCENT)
		title.add_theme_font_size_override("font_size", 14)
		body.add_child(title)
		var costs := GridContainer.new()
		costs.columns = mini(3, recipe.size())
		costs.add_theme_constant_override("h_separation", 12)
		costs.add_theme_constant_override("v_separation", 4)
		body.add_child(costs)
		for resource in recipe:
			var pair := HBoxContainer.new()
			pair.add_theme_constant_override("separation", 4)
			costs.add_child(pair)
			var symbol := TextureRect.new()
			HUD.fixed_icon(symbol, crew_icon if resource == "Population" else HUD.resource_icon(resource, 24), 24)
			pair.add_child(symbol)
			var amount := Label.new()
			amount.text = "%.0f%s" % [float(recipe[resource]), "" if resource == "Population" else "t"]
			if missing.has(resource):
				amount.add_theme_color_override("font_color", Color("#ff7777"))
			pair.add_child(amount)
		if lines.size() > 1 and not lines[1].is_empty():
			var details := Label.new()
			details.text = lines[1]
			body.add_child(details)
		return panel

var session: Node
var settings := ConfigFile.new()
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var music_muted: bool = false
var sfx_muted: bool = false
var sound_mixer: Node
var sound_elapsed: float = -1.0
var sound_destruction_sequence: int = 0
var sound_objectives: Dictionary = {}
var sound_hulls: Dictionary = {}
var sound_structures: Dictionary = {}
var tactical_alerts: Dictionary = {}
var tactical_hit_rects: Array[Dictionary] = []
var tactical_durability: Dictionary = {}
var tactical_positions: Dictionary = {}
var tactical_friendly: Array[int] = []
var tactical_next_scan: int = 0
var tactical_last_damage_sequence: int = 0
var tactical_initialized: bool = false
const ALERT_APPROACH_RANGE: float = 1200.0
const ALERT_LIFETIME_MS: int = 10000
const ALERT_REPEAT_MS: int = 15000
var background_music: AudioStreamPlayer
var known_upgrade_jobs: Dictionary = {}
var upgrade_audio_initialized: bool = false
var map_canvas: Control
var health_batch: MultiMeshInstance2D
var ring_batch: MultiMeshInstance2D
var health_entries: Array = []
var ring_entries: Array = []
var cargo_batch: MultiMeshInstance2D
var cargo_glow_batch: MultiMeshInstance2D
var cargo_entries: Array = []
var cargo_glow_entries: Array = []
var pose_frame: int = -1
var pose_revision: Array = []
var pose_world_cache: Dictionary = {}
var beam_batch: MultiMeshInstance2D
var projectile_batch: MultiMeshInstance2D
var beam_instances: Array = []
var projectile_instances: Array = []
var exhaust_batch: MultiMeshInstance2D
var exhaust_instances: Array = []
var exhaust_extents: Dictionary = {}
var overview_batches: Dictionary = {}
var overview_instances: Dictionary = {}
var overview_dot_textures: Dictionary = {}
var territory_layer: Control
var territory_image: ColorRect
var territory_material: ShaderMaterial
var territory_sites: ImageTexture
var territory_site_count: int = 0
var territory_radius: float = 1.0
var territory_last: Array[Color] = []
var territory_region_cache: Dictionary = {}
var territory_region_graph: Dictionary = {}
var territory_influence_texture: ImageTexture
var territory_seed: int = -1
var header_panel: PanelContainer
var inspector_panel: PanelContainer
var inspector_slot: Control
var overview_panel: PanelContainer
var console_panel: PanelContainer
var minimap: Control
var minimap_pan_drag: bool = false
var time_panel: PanelContainer
var lens_column: VBoxContainer
var console_columns: HBoxContainer
var console_center: VBoxContainer
var console_center_spacer: Control
var console_right_body: VBoxContainer
var console_profile: Control
var empty_selection: Label
var command_grids: Dictionary = {}
var command_hotkeys: Dictionary = {}
var hotkey_entries: Dictionary = {}
var hotkey_overrides: Dictionary = {}
var hotkey_dialog: AcceptDialog
var hotkey_status: Label
var hotkey_pickers: Dictionary = {}
var keyboard_pan_percent: float = 100.0
var mouse_pan_percent: float = 100.0
var wheel_zoom_percent: float = 100.0
var station_commands: VBoxContainer
var station_primary_grid: GridContainer
var station_select_yards_button: Button
var station_upgrade_buttons: Dictionary = {}
var weapon_details: Label
var station_build_grid: GridContainer
var station_trade: VBoxContainer
var station_trade_back: Button
var station_build_buttons: Dictionary = {}
var station_icons: Dictionary = {}
var station_card: String = "primary"
var station_selected_index: int = -1
var station_queue: HFlowContainer
var station_queue_rows: Dictionary = {}
var station_details: VBoxContainer
var station_queue_panel: VBoxContainer
var station_queue_heading: Label
var asteroid_shape_cache: Dictionary = {}
var asteroid_frame_meshes: Array[ArrayMesh] = []
var asteroid_cache_seed: int = -1
var population_label: Label
var raw_antimatter_label: Label
var population_delta_label: Label
var zoom: float = 1.0
var camera_world: Vector2 = Vector2.INF
var follow_units: bool = false
var drag_button: int = 0
var ship_visuals: Dictionary = {}
var ship_offsets: Dictionary = {}
const SHIP_WORLD_SCALE: float = 1.5
const FIGHTER_MUZZLE: float = 12.0
const MINER_MUZZLE: Vector2 = Vector2(10.0, 3.75)
const FREIGHTER_OUTLINE: Array[Vector2] = [Vector2(23, 4), Vector2(19, 8), Vector2(-20, 8), Vector2(-20, -8), Vector2(19, -8), Vector2(23, -4)]
const DESTRUCTION_LIFETIME: float = 1.35
const MAX_VISIBLE_DESTRUCTIONS: int = 32
var last_destruction_sequence: int = 0
var ship_destructions: Array = []
# Authored top-down silhouette and interior panel geometry in hull-local
# coordinates (forward, lateral). Freighter has five paired cargo rows.
const HULL_OUTLINES: Dictionary = {
	"scout": [Vector2(12, 0), Vector2(4, 2), Vector2(-2, 5), Vector2(-8, 5), Vector2(-6, 2), Vector2(-10, 1.8), Vector2(-10, -1.8), Vector2(-6, -2), Vector2(-8, -5), Vector2(-2, -5), Vector2(4, -2)],
	"cruiser": [Vector2(25, 0), Vector2(19, 4), Vector2(13, 5), Vector2(6, 13), Vector2(-5, 13), Vector2(-9, 7), Vector2(-19, 7), Vector2(-25, 4), Vector2(-25, 0), Vector2(-25, -4), Vector2(-19, -7), Vector2(-9, -7), Vector2(-5, -13), Vector2(6, -13), Vector2(13, -5), Vector2(19, -4)],
	"destroyer": [Vector2(44, 0), Vector2(38, 7), Vector2(32, 7), Vector2(29, 18), Vector2(20, 20), Vector2(8, 16), Vector2(1, 10), Vector2(-12, 10), Vector2(-18, 23), Vector2(-32, 23), Vector2(-40, 17), Vector2(-40, 9), Vector2(-44, 6), Vector2(-44, 0), Vector2(-44, -6), Vector2(-40, -9), Vector2(-40, -17), Vector2(-32, -23), Vector2(-18, -23), Vector2(-12, -10), Vector2(1, -10), Vector2(8, -16), Vector2(20, -20), Vector2(29, -18), Vector2(32, -7), Vector2(38, -7)],
	"science_ship": [Vector2(14, 0), Vector2(12, 7), Vector2(7, 12), Vector2(0, 14), Vector2(-7, 12), Vector2(-12, 7), Vector2(-14, 0), Vector2(-12, -7), Vector2(-7, -12), Vector2(0, -14), Vector2(7, -12), Vector2(12, -7)],
	"fighter": [Vector2(12, 0), Vector2(6, 2.5), Vector2(2.5, 3), Vector2(-3, 8), Vector2(-7, 7.5), Vector2(-6, 3), Vector2(-10, 2.5), Vector2(-10, -2.5), Vector2(-6, -3), Vector2(-7, -7.5), Vector2(-3, -8), Vector2(2.5, -3), Vector2(6, -2.5)],
	"miner": [Vector2(10, 5), Vector2(6, 5), Vector2(3, 7), Vector2(-5, 7), Vector2(-8, 4), Vector2(-8, -4), Vector2(-5, -7), Vector2(3, -7), Vector2(6, -5), Vector2(10, -5), Vector2(10, -2.5), Vector2(5, -2.5), Vector2(4, 0), Vector2(5, 2.5), Vector2(10, 2.5)],
	"colony_ship": [Vector2(13, 0), Vector2(8, 3), Vector2(5, 3.5), Vector2(3, 6.5), Vector2(-5, 7), Vector2(-9, 4), Vector2(-11, 3), Vector2(-11, -3), Vector2(-9, -4), Vector2(-5, -7), Vector2(3, -6.5), Vector2(5, -3.5), Vector2(8, -3)]
}
const HULL_PANELS: Dictionary = {
	"scout": [
		[Color("#a3b8c9"), [Vector2(11, 0), Vector2(3, 1.5), Vector2(-7, 1.5), Vector2(-8, 0), Vector2(-7, -1.5), Vector2(3, -1.5)]],
		[Color("#21364c"), [Vector2(5, 0), Vector2(1, 1.3), Vector2(-2, 1), Vector2(-2, -1), Vector2(1, -1.3)]],
		[Color("#556e87"), [Vector2(-1, 2), Vector2(-3, 4.5), Vector2(-7, 4.5), Vector2(-5, 2)]],
		[Color("#556e87"), [Vector2(-1, -2), Vector2(-3, -4.5), Vector2(-7, -4.5), Vector2(-5, -2)]],
		[Color("#9de6ff"), [Vector2(-9, 1.3), Vector2(-10, 1.3), Vector2(-10, -1.3), Vector2(-9, -1.3)]]
	],
	"cruiser": [
		[Color("#7189a2"), [Vector2(24, 0), Vector2(17, 3), Vector2(8, 4), Vector2(-19, 5), Vector2(-24, 0), Vector2(-19, -5), Vector2(8, -4), Vector2(17, -3)]],
		[Color("#b3c7da"), [Vector2(18, 0), Vector2(9, 2.8), Vector2(-13, 3.5), Vector2(-19, 0), Vector2(-13, -3.5), Vector2(9, -2.8)]],
		[Color("#21364c"), [Vector2(10, 0), Vector2(5, 2.1), Vector2(-1, 2.1), Vector2(-4, 0), Vector2(-1, -2.1), Vector2(5, -2.1)]],
		[Color("#394f65"), [Vector2(12, 5), Vector2(5, 12), Vector2(-4, 12), Vector2(-8, 6)]],
		[Color("#394f65"), [Vector2(12, -5), Vector2(5, -12), Vector2(-4, -12), Vector2(-8, -6)]],
		[Color("#a9bed1"), [Vector2(8, 7), Vector2(4, 10), Vector2(-2, 10), Vector2(0, 7)]],
		[Color("#a9bed1"), [Vector2(8, -7), Vector2(4, -10), Vector2(-2, -10), Vector2(0, -7)]],
		[Color("#bfd0df"), [Vector2(17, 2), Vector2(20, 2), Vector2(20, 3.5), Vector2(17, 3.5)]],
		[Color("#bfd0df"), [Vector2(17, -2), Vector2(20, -2), Vector2(20, -3.5), Vector2(17, -3.5)]],
		[Color("#21364c"), [Vector2(-10, 3.8), Vector2(-18, 3.8), Vector2(-21, 5.5), Vector2(-10, 5.5)]],
		[Color("#21364c"), [Vector2(-10, -3.8), Vector2(-18, -3.8), Vector2(-21, -5.5), Vector2(-10, -5.5)]],
		[Color("#9de6ff"), [Vector2(-22, 1.8), Vector2(-25, 1.8), Vector2(-25, 3.6), Vector2(-22, 3.6)]],
		[Color("#9de6ff"), [Vector2(-22, -1.8), Vector2(-25, -1.8), Vector2(-25, -3.6), Vector2(-22, -3.6)]]
	],
	"destroyer": [
		[Color("#60758c"), [Vector2(43, 0), Vector2(33, 5), Vector2(20, 8), Vector2(-33, 7), Vector2(-43, 0), Vector2(-33, -7), Vector2(20, -8), Vector2(33, -5)]],
		[Color("#b7c9db"), [Vector2(36, 0), Vector2(21, 4), Vector2(-13, 5), Vector2(-28, 0), Vector2(-13, -5), Vector2(21, -4)]],
		[Color("#203247"), [Vector2(15, 0), Vector2(8, 3.5), Vector2(-2, 3.5), Vector2(-7, 0), Vector2(-2, -3.5), Vector2(8, -3.5)]],
		[Color("#4b637a"), [Vector2(-9, 0), Vector2(-15, 5), Vector2(-28, 4), Vector2(-34, 0), Vector2(-28, -4), Vector2(-15, -5)]],
		[Color("#9de6ff"), [Vector2(-41, 4), Vector2(-44, 4), Vector2(-44, -4), Vector2(-41, -4)]],
		[Color("#394f65"), [Vector2(32, 8), Vector2(28, 17), Vector2(20, 19), Vector2(9, 15), Vector2(3, 9)]],
		[Color("#394f65"), [Vector2(32, -8), Vector2(28, -17), Vector2(20, -19), Vector2(9, -15), Vector2(3, -9)]],
		[Color("#a9bed1"), [Vector2(28, 9), Vector2(25, 15), Vector2(20, 16), Vector2(13, 13), Vector2(10, 9)]],
		[Color("#a9bed1"), [Vector2(28, -9), Vector2(25, -15), Vector2(20, -16), Vector2(13, -13), Vector2(10, -9)]],
		[Color("#bfd0df"), [Vector2(28, 11), Vector2(31, 11), Vector2(30, 14), Vector2(27, 14)]],
		[Color("#bfd0df"), [Vector2(28, -11), Vector2(31, -11), Vector2(30, -14), Vector2(27, -14)]],
		[Color("#bfd0df"), [Vector2(17, 15), Vector2(22, 15), Vector2(22, 17), Vector2(17, 17)]],
		[Color("#bfd0df"), [Vector2(17, -15), Vector2(22, -15), Vector2(22, -17), Vector2(17, -17)]],
		[Color("#263c52"), [Vector2(14, 6), Vector2(6, 6), Vector2(3, 9), Vector2(12, 9)]],
		[Color("#263c52"), [Vector2(14, -6), Vector2(6, -6), Vector2(3, -9), Vector2(12, -9)]],
		[Color("#7189a2"), [Vector2(-13, 9), Vector2(-19, 22), Vector2(-31, 22), Vector2(-39, 16), Vector2(-39, 9)]],
		[Color("#7189a2"), [Vector2(-13, -9), Vector2(-19, -22), Vector2(-31, -22), Vector2(-39, -16), Vector2(-39, -9)]],
		[Color("#a9bed1"), [Vector2(-18, 10), Vector2(-21, 19), Vector2(-30, 19), Vector2(-35, 15), Vector2(-32, 10)]],
		[Color("#a9bed1"), [Vector2(-18, -10), Vector2(-21, -19), Vector2(-30, -19), Vector2(-35, -15), Vector2(-32, -10)]],
		[Color("#24384d"), [Vector2(-23, 12), Vector2(-24, 17), Vector2(-30, 17), Vector2(-32, 13)]],
		[Color("#24384d"), [Vector2(-23, -12), Vector2(-24, -17), Vector2(-30, -17), Vector2(-32, -13)]],
		[Color("#9de6ff"), [Vector2(-36, 10), Vector2(-40, 10), Vector2(-40, 15), Vector2(-36, 15)]],
		[Color("#9de6ff"), [Vector2(-36, -10), Vector2(-40, -10), Vector2(-40, -15), Vector2(-36, -15)]],
		[Color("#8ea7bd"), [Vector2(-3, 6), Vector2(-9, 6), Vector2(-12, 8), Vector2(-3, 8)]],
		[Color("#8ea7bd"), [Vector2(-3, -6), Vector2(-9, -6), Vector2(-12, -8), Vector2(-3, -8)]]
	],
	"science_ship": [[Color("#7e9eb9"), [Vector2(12, 0), Vector2(8, 8), Vector2(0, 12), Vector2(-8, 8), Vector2(-12, 0), Vector2(-8, -8), Vector2(0, -12), Vector2(8, -8)]], [Color("#23374d"), [Vector2(7, 0), Vector2(5, 5), Vector2(0, 7), Vector2(-5, 5), Vector2(-7, 0), Vector2(-5, -5), Vector2(0, -7), Vector2(5, -5)]]],
	"fighter": [
		[Color("#6b493e"), [Vector2(2.5, 3), Vector2(-3, 8), Vector2(-7, 7.5), Vector2(-5, 3)]],
		[Color("#6b493e"), [Vector2(2.5, -3), Vector2(-3, -8), Vector2(-7, -7.5), Vector2(-5, -3)]],
		[Color("#ffcb9f"), [Vector2(11, 0), Vector2(5, 1.4), Vector2(-4, 1.5), Vector2(-7, 0), Vector2(-4, -1.5), Vector2(5, -1.4)]],
		[Color("#203b52"), [Vector2(6, 0), Vector2(2, 1.7), Vector2(-1, 1.2), Vector2(-1, -1.2), Vector2(2, -1.7)]],
		[Color("#e4a26f"), [Vector2(-3, 6), Vector2(-4.8, 7), Vector2(-6, 6), Vector2(-5, 4.5)]],
		[Color("#e4a26f"), [Vector2(-3, -6), Vector2(-4.8, -7), Vector2(-6, -6), Vector2(-5, -4.5)]],
		[Color("#263746"), [Vector2(-7, 2.2), Vector2(-10, 2.2), Vector2(-10, 0.4), Vector2(-7, 0.4)]],
		[Color("#263746"), [Vector2(-7, -2.2), Vector2(-10, -2.2), Vector2(-10, -0.4), Vector2(-7, -0.4)]],
		[Color("#a0eaff"), [Vector2(-9.3, 2), Vector2(-10, 2), Vector2(-10, 0.7), Vector2(-9.3, 0.7)]],
		[Color("#a0eaff"), [Vector2(-9.3, -2), Vector2(-10, -2), Vector2(-10, -0.7), Vector2(-9.3, -0.7)]]
	],
	"miner": [
		[Color("#66753e"), [Vector2(3, 6), Vector2(-4, 6), Vector2(-7, 3), Vector2(-3, 3), Vector2(2, 3)]],
		[Color("#66753e"), [Vector2(3, -6), Vector2(-4, -6), Vector2(-7, -3), Vector2(-3, -3), Vector2(2, -3)]],
		[Color("#dfe6ba"), [Vector2(4, 0), Vector2(2, 3), Vector2(-2, 3), Vector2(-4, 0), Vector2(-2, -3), Vector2(2, -3)]],
		[Color("#203b52"), [Vector2(3, 0), Vector2(1, 1.7), Vector2(-1, 1.7), Vector2(-1, -1.7), Vector2(1, -1.7)]],
		[Color("#344435"), [Vector2(-3, 5.5), Vector2(-5.5, 5.2), Vector2(-6, 3.4), Vector2(-3, 3.4)]],
		[Color("#344435"), [Vector2(-3, -5.5), Vector2(-5.5, -5.2), Vector2(-6, -3.4), Vector2(-3, -3.4)]],
		[Color("#b0f4a8"), [Vector2(9.5, 4.6), Vector2(7, 4.6), Vector2(7, 2.9), Vector2(9.5, 2.9)]],
		[Color("#b0f4a8"), [Vector2(9.5, -4.6), Vector2(7, -4.6), Vector2(7, -2.9), Vector2(9.5, -2.9)]],
		[Color("#9de6ff"), [Vector2(-7, 2.5), Vector2(-8, 2.5), Vector2(-8, -2.5), Vector2(-7, -2.5)]]
	],
	"colony_ship": [
		[Color("#695a88"), [Vector2(3, 6.5), Vector2(-5, 7), Vector2(-8, 4), Vector2(-4, 3), Vector2(3, 3)]],
		[Color("#695a88"), [Vector2(3, -6.5), Vector2(-5, -7), Vector2(-8, -4), Vector2(-4, -3), Vector2(3, -3)]],
		[Color("#e0d5f5"), [Vector2(12, 0), Vector2(7, 2.4), Vector2(-7, 2.4), Vector2(-9, 0), Vector2(-7, -2.4), Vector2(7, -2.4)]],
		[Color("#35465f"), [Vector2(9, 0), Vector2(5, 1.6), Vector2(3, 1.3), Vector2(3, -1.3), Vector2(5, -1.6)]],
		[Color("#35465f"), [Vector2(2, 5.7), Vector2(-1, 5.7), Vector2(-1, 3.8), Vector2(2, 3.8)]],
		[Color("#35465f"), [Vector2(-2, 5.8), Vector2(-5, 5.8), Vector2(-5, 3.8), Vector2(-2, 3.8)]],
		[Color("#35465f"), [Vector2(2, -5.7), Vector2(-1, -5.7), Vector2(-1, -3.8), Vector2(2, -3.8)]],
		[Color("#35465f"), [Vector2(-2, -5.8), Vector2(-5, -5.8), Vector2(-5, -3.8), Vector2(-2, -3.8)]],
		[Color("#a9e5f2"), [Vector2(1.6, 5.3), Vector2(-0.6, 5.3), Vector2(-0.6, 4.5), Vector2(1.6, 4.5)]],
		[Color("#a9e5f2"), [Vector2(-2.4, 5.3), Vector2(-4.6, 5.3), Vector2(-4.6, 4.5), Vector2(-2.4, 4.5)]],
		[Color("#a9e5f2"), [Vector2(1.6, -5.3), Vector2(-0.6, -5.3), Vector2(-0.6, -4.5), Vector2(1.6, -4.5)]],
		[Color("#a9e5f2"), [Vector2(-2.4, -5.3), Vector2(-4.6, -5.3), Vector2(-4.6, -4.5), Vector2(-2.4, -4.5)]],
		[Color("#293b54"), [Vector2(-7, 2.8), Vector2(-11, 2.8), Vector2(-11, -2.8), Vector2(-7, -2.8)]],
		[Color("#9de6ff"), [Vector2(-10, 2), Vector2(-11, 2), Vector2(-11, -2), Vector2(-10, -2)]]
	]
}
var interaction_scroll: ScrollContainer
var interaction_panel: VBoxContainer
var logistics_lens: Button
var active_lens: String = "logistics"
var logistics_overlay: Control
var objectives_overlay: Control
var match_chat_edit: LineEdit
var conquest_buttons: Dictionary = {}
var objective_refresh_buttons: Dictionary = {}
var conquest_category: String = "economic"
var conquest_dialog: Window
var conquest_cards: VBoxContainer
var conquest_card_signature: String = ""
var empire_dialog: AcceptDialog
var empire_rows: VBoxContainer
var empire_controls: Dictionary = {}
var empire_signature: String = ""
var conquest_pulse_time: float = 0.0
const OBJECTIVES_WIDTH: float = 328.0
var global_resource_fills: Dictionary = {}
var global_resource_segments: Dictionary = {}
var global_resource_strips: Dictionary = {}
var send_colony_button: Button
var selected: int = -1
var selected_body: int = -1
var selected_yard: int = -1
var selected_yard_count: int = 0
var building_selection_kind: String = ""
var selected_buildings: Dictionary = {}
var parked_building_types: Dictionary = {}
var building_group_panel: VBoxContainer
var building_group_grid: GridContainer
var building_group_title: Label
var building_group_rows: Dictionary = {}
var selection_double_click: bool = false
var yard_overview: VBoxContainer
var yard_title: Label
var yard_context: Label
var yard_status: Label
var yard_detail: Label
var yard_costs: GridContainer
var yard_progress: ProgressBar
var yard_upgrades: Dictionary = {}
var yard_cancel: Button
var selected_ship_id: int = -1
var selected_units: Array[int] = []
var command_kind: String = ""
var command_selection: Array[int] = []
var control_groups: Dictionary = {}
var last_control_group_recall: int = -1
var last_control_group_recall_ms: int = -1000
var control_group_strip: HBoxContainer
var global_selection_strip: VBoxContainer
var control_group_buttons: Dictionary = {}
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selecting_units: bool = false
var formation_button: int = 0
var formation_path := PackedVector2Array()
var formation_length: float = 0.0
var formation_mode: String = ""
var formation_append: bool = false
var formation_force_position: bool = false
var selected_field: int = -1
var field_command_grid: GridContainer
var field_commands: Dictionary = {}
var planet_overview: VBoxContainer
var body_overview: VBoxContainer
var body_title: Label
var body_context: Label
var body_status: Label
var ship_overview: VBoxContainer
var ship_title: Label
var ship_detail: Label
var ship_population: Label
var fleet_scroll: ScrollContainer
var fleet_overview: VBoxContainer
var fleet_title: Label
var fleet_detail: Label
var hold_button: Button
var unload_button: Button
var yard_command_scroll: VBoxContainer
var yard_command_card: VBoxContainer
var yard_command_grid: GridContainer
var yard_commands: Dictionary = {}
var yard_top_slots: Array[Control] = []
var yard_bottom_slots: Array[Control] = []
var yard_row_spacers: Array[Control] = []
var yard_layout_key := Vector3i(-1, -1, -1)
var production_icons: Dictionary = {}
var hull_textures: Dictionary = {}
var shield_textures: Dictionary = {}
var yard_queue: HFlowContainer
var yard_queue_rows: Dictionary = {}
var command_card: GridContainer
var command_buttons: Dictionary = {}
var pending_command: String = ""
var selection_grid: GridContainer
var selection_tiles: Dictionary = {}
var selection_icons: Dictionary = {}
var selection_portrait: VBoxContainer
var selection_portrait_art: TextureRect
var selection_portrait_health: Label
var selection_portrait_shield: Label
var selection_portrait_icons: Dictionary = {}
var fleet_cargo: HBoxContainer
var fleet_cargo_footer: HBoxContainer
var fleet_cargo_labels: Dictionary = {}
var initial_selection_done: bool = false
var global_resource_labels: Dictionary = {}
var global_resource_delta_labels: Dictionary = {}
var global_resource_tiles: Dictionary = {}
var resource_hover_panel: PanelContainer
var resource_hover_label: Label
var hovered_resource: String = ""
var global_population_label: Label
var year_label: Label
var time_buttons: Dictionary = {}
var game_visual_clock: float = 0.0
var transfer_visuals: Dictionary = {}
var transfer_visual_seed: int = -1
var orbit_visual_time: float = -1.0
var orbit_sample_time: float = -1.0
var orbit_sample_age: float = 0.0
var orbit_seed: int = -1
var info: Label
var visual_clock: float = 0.0
var system_visuals: Dictionary = {}
var star_textures: Dictionary = {}
var resource_glow_texture: Texture2D
var system_visual_seed: int = -1
var planet_detail_alpha: Dictionary = {}
var planet_detail_seed: int = -1
var trade_sliders: Dictionary = {}
var trade_checks: Dictionary = {}
var trade_check_icons: Dictionary = {}
var trade_stock_labels: Dictionary = {}
var population_icons: Dictionary = {}
var production_summary: VBoxContainer
var production_values: Dictionary = {}
var system_owner_label: Label
var leave: Button
var match_menu: AcceptDialog
var codex: Window
var match_result_dialog: AcceptDialog
var match_result_shown: bool = false
var defeated_shown: bool = false
var menu_exit: Button

class TradeRange extends Control:
	signal committed(minimum: float, maximum: float)
	var lower: float = 50.0
	var upper: float = 80.0
	var stock_percent: float = 0.0
	var stock_color: Color = Color.WHITE
	var enabled: bool = true
	var import_enabled: bool = true
	var export_enabled: bool = true
	var active_handle: int = -1
	const PAD: float = 10.0
	const TRACK_Y: float = 13.0

	func set_range(minimum: float, maximum: float) -> void:
		active_handle = -1
		lower = clampf(minimum, 0.0, 100.0)
		upper = clampf(maximum, 0.0, 100.0)
		queue_redraw()

	func set_stock(amount: float, maximum: float, tint: Color) -> void:
		stock_percent = clampf(100.0 * amount / maxf(maximum, 1.0), 0.0, 100.0)
		stock_color = Color("#b9c8d6")
		queue_redraw()

	func _x(value: float) -> float:
		return PAD + maxf(1.0, size.x - PAD * 2.0) * value / 100.0

	func _value(x: float) -> float:
		return roundf(clampf((x - PAD) / maxf(1.0, size.x - PAD * 2.0) * 100.0, 0.0, 100.0))

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var low_color := Color("#c9d6e2") if enabled else Color("#667687")
		var high_color := Color("#c9d6e2") if enabled else Color("#667687")
		var left: String = "Import < %d%%" % roundi(lower)
		var right: String = "Export > %d%%" % roundi(upper)

		var lo := Vector2(_x(lower), TRACK_Y)
		var hi := Vector2(_x(upper), TRACK_Y)
		draw_line(Vector2(PAD, TRACK_Y), Vector2(size.x - PAD, TRACK_Y), Color("#344960"), 5.0, true)
		if stock_percent > 0.0:
			draw_line(Vector2(PAD, TRACK_Y), Vector2(_x(stock_percent), TRACK_Y), stock_color, 7.0, true)
		# Offset the handles vertically when their values meet, keeping both visible.
		var overlap: bool = absf(lo.x - hi.x) < 13.0
		if overlap:
			lo.y -= 5.0
			hi.y += 5.0
		if import_enabled:
			draw_circle(lo, 7.0, low_color)
		if export_enabled:
			draw_circle(hi, 7.0, high_color)

	func _move_handle(x: float) -> void:
		if active_handle == 0:
			lower = _value(x)
			if export_enabled:
				upper = maxf(upper, lower)
		elif active_handle == 1:
			upper = _value(x)
			if import_enabled:
				lower = minf(lower, upper)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var lo := Vector2(_x(lower), TRACK_Y)
				var hi := Vector2(_x(upper), TRACK_Y)
				if absf(lo.x - hi.x) < 13.0:
					lo.y -= 5.0
					hi.y += 5.0
				if not import_enabled and not export_enabled:
					return
				active_handle = 0 if import_enabled and (not export_enabled or event.position.distance_to(lo) < event.position.distance_to(hi)) else 1
				_move_handle(event.position.x)
			elif active_handle >= 0:
				_move_handle(event.position.x)
				active_handle = -1
				committed.emit(lower, upper)
			accept_event()
		elif event is InputEventMouseMotion and active_handle >= 0:
			_move_handle(event.position.x)
			accept_event()

func _ready() -> void:
	theme = HUD.create()
	session = get_node("/root/GameSession")
	session.connect("phase_changed", _refresh)
	session.connect("status_changed", _refresh)
	session.connect("economy_changed", _on_economy_changed)
	sound_mixer = SFX.new()
	background_music = AudioStreamPlayer.new()
	background_music.stream = preload("res://assets/music/peaceful3.mp3")
	add_child(background_music)
	_load_settings()
	_apply_settings()
	add_child(sound_mixer)
	get_tree().node_added.connect(_sound_button_added)
	session.connect("chat_changed", _sound_chat)
	_build_ui()
	hotkey_entries["focus"] = {"scope": "General", "title": "Focus selection", "default": KEY_F}
	_load_hotkey_overrides()
	_build_resource_hover()
	_apply_settings()
	_on_economy_changed()
	session.call("match_scene_loaded")

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_sound_button_added):
		get_tree().node_added.disconnect(_sound_button_added)
	if Input.mouse_mode == Input.MOUSE_MODE_CONFINED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(background_music):
		background_music.stop()

func _label(value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable, parent: Container, with_recipe: bool = false) -> Button:
	var b: Button = CostButton.new()
	b.text = text
	b.pressed.connect(action)
	b.custom_minimum_size.y = 23 if is_instance_valid(console_panel) and console_panel.is_ancestor_of(parent) else 32
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_script(BACKDROP)
	background.name = "SpaceBackdrop"
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_territory_layer()
	map_canvas = Control.new()
	add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.offset_left = 8
	map_canvas.offset_top = 0
	map_canvas.offset_right = -8
	map_canvas.offset_bottom = -8
	map_canvas.clip_contents = false
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.gui_input.connect(_map_input)
	map_canvas.draw.connect(_draw_map)
	logistics_overlay = Control.new()
	map_canvas.add_child(logistics_overlay)
	logistics_overlay.z_index = 3
	logistics_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logistics_overlay.draw.connect(_draw_logistics_overlay)
	objectives_overlay = Control.new()
	map_canvas.add_child(objectives_overlay)
	objectives_overlay.z_index = 3
	objectives_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objectives_overlay.draw.connect(_draw_objectives_overlay)
	match_chat_edit = LineEdit.new()
	match_chat_edit.placeholder_text = "All players · Enter to send · Esc to cancel"
	match_chat_edit.max_length = 250
	match_chat_edit.z_index = 5
	map_canvas.add_child(match_chat_edit)
	match_chat_edit.hide()
	match_chat_edit.focus_exited.connect(_close_match_chat)
	for category in ECONOMY.REWARD_CATEGORIES:
		var button := Button.new()
		map_canvas.add_child(button)
		button.z_index = 4
		button.focus_mode = Control.FOCUS_NONE
		_style_objective_header_button(button, Color("#e9cb7c"))
		button.text = "Upgrade"
		button.pressed.connect(_open_conquest_upgrades.bind(category))
		conquest_buttons[category] = button
		var refresh := Button.new()
		map_canvas.add_child(refresh)
		refresh.z_index = 4
		refresh.focus_mode = Control.FOCUS_NONE
		_style_objective_header_button(refresh, HUD.ACCENT)
		refresh.text = "↻"
		refresh.pressed.connect(_request_objective_refresh.bind(category))
		objective_refresh_buttons[category] = refresh
	conquest_dialog = Window.new()
	conquest_dialog.title = "Choose an upgrade"
	conquest_dialog.theme = theme
	conquest_dialog.transient = true
	conquest_dialog.exclusive = true
	conquest_dialog.unresizable = true
	conquest_dialog.visible = false
	add_child(conquest_dialog)
	conquest_dialog.close_requested.connect(conquest_dialog.hide)
	var conquest_background := PanelContainer.new()
	conquest_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	conquest_background.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#45617b"), 14, 4))
	conquest_dialog.add_child(conquest_background)
	var conquest_scroll := ScrollContainer.new()
	conquest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	conquest_background.add_child(conquest_scroll)
	conquest_cards = VBoxContainer.new()
	conquest_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conquest_cards.add_theme_constant_override("separation", 10)
	conquest_scroll.add_child(conquest_cards)
	_layout_conquest_button()
	_build_exhaust_batch()
	beam_batch = _build_effect_batch(false)
	projectile_batch = _build_effect_batch(true)
	health_batch = _build_effect_batch(false)
	health_batch.z_index = 2
	ring_batch = _build_ring_batch()
	cargo_batch = _build_effect_batch(false)
	cargo_glow_batch = _build_effect_batch(false)
	cargo_glow_batch.texture = _resource_glow()
	cargo_batch.z_index = 1
	cargo_glow_batch.z_index = 1
	map_canvas.resized.connect(_map_resized)
	header_panel = PanelContainer.new()
	header_panel.z_index = 4
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_panel)
	var header_style := StyleBoxEmpty.new()
	header_style.set_content_margin_all(6.0)
	header_panel.add_theme_stylebox_override("panel", header_style)
	header_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_panel.offset_left = 8
	header_panel.offset_right = -8
	header_panel.offset_top = 8
	header_panel.offset_bottom = 8 + HEADER_HEIGHT
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	header_panel.add_child(row)
	year_label = _global_stat(row, "%d A.D." % ECONOMY.START_YEAR, HUD.ACCENT)
	_build_global_bar(row)
	global_population_label = _global_stat(row, "0", Color("#b9d9ed"), true)
	var header_spacer := Control.new()
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_spacer)
	var help := _button("", _open_codex, row)
	help.icon = _command_icon('<circle cx="16" cy="16" r="13"/><path d="M11 12Q11 6 17 7Q23 8 21 13Q20 15 17 17V20M17 25H17.1"/>', 24)
	help.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.expand_icon = true
	help.add_theme_constant_override("icon_max_width", 24)
	help.custom_minimum_size.x = 36
	help.tooltip_text = "Warbound Codex"
	help.focus_mode = Control.FOCUS_NONE
	leave = _button("MENU", _open_menu, row)
	codex = CODEX.new()
	codex.hide()
	add_child(codex)
	match_menu = AcceptDialog.new()
	match_menu.title = "Menu"
	match_menu.theme = theme
	match_menu.exclusive = true
	match_menu.dialog_close_on_escape = true
	match_menu.unresizable = true
	match_menu.ok_button_text = "Resume"
	add_child(match_menu)
	menu_exit = match_menu.add_button("Leave match", false, "leave")
	HUD.action(match_menu.get_ok_button())
	HUD.action(menu_exit, Color("#e9a276"))
	match_menu.custom_action.connect(_menu_action)
	_build_settings_menu()
	match_result_dialog = AcceptDialog.new()
	match_result_dialog.theme = theme
	match_result_dialog.unresizable = true
	match_result_dialog.ok_button_text = "Review map"
	add_child(match_result_dialog)
	match_result_dialog.add_button("Leave match", false, "leave")
	match_result_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"leave":
			match_result_dialog.hide()
			_leave())
	# One reserved, bottom-anchored command deck. The camera uses the map
	# rectangle above it regardless of selection or visible inspector content.
	console_panel = PanelContainer.new()
	console_panel.z_index = 4
	console_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(console_panel)
	console_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	console_panel.offset_left = 8
	console_panel.offset_right = -8
	console_panel.offset_bottom = -8
	console_panel.theme = HUD.compact()
	console_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	console_profile = Control.new()
	console_profile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_profile.z_index = -1
	console_panel.add_child(console_profile)
	console_profile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	console_profile.draw.connect(_draw_console_profile)
	console_profile.resized.connect(console_profile.queue_redraw)
	var deck := HBoxContainer.new()
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.add_theme_constant_override("separation", 4)
	console_panel.add_child(deck)
	minimap = Control.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.focus_mode = Control.FOCUS_NONE
	minimap.tooltip_text = "Left click or drag: camera · Right click: command · Shift: queue"
	minimap.clip_contents = true
	minimap.size_flags_horizontal = Control.SIZE_FILL
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck.add_child(minimap)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	minimap.resized.connect(minimap.queue_redraw)
	# A persistent vertical lens strip belongs immediately beside the minimap.
	lens_column = VBoxContainer.new()
	lens_column.custom_minimum_size.x = LENS_STRIP_WIDTH
	lens_column.size_flags_horizontal = Control.SIZE_FILL
	lens_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lens_column.add_theme_constant_override("separation", 3)
	deck.add_child(lens_column)
	lens_column.draw.connect(func() -> void:
		lens_column.draw_rect(Rect2(Vector2.ZERO, lens_column.size), HUD.CONSOLE_BACKGROUND))
	lens_column.resized.connect(lens_column.queue_redraw)
	_build_lens_buttons(lens_column)
	# The center and contextual command panel remain independent of selection.
	console_columns = deck
	console_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_selection = _label("Select a system, ship or asteroid field", 14)
	empty_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_selection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_selection.add_theme_color_override("font_color", HUD.MUTED)
	console_center = VBoxContainer.new()
	console_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_columns.add_child(console_center)
	console_center_spacer = Control.new()
	console_center_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_center.add_child(console_center_spacer)
	_build_control_group_strip()
	_build_global_selection_strip()
	console_center.add_child(empty_selection)
	# Keep the right wing's footprint in the normal deck; its actual panel
	# may extend upward for Trade without resizing the minimap or camera.
	inspector_slot = Control.new()
	inspector_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspector_slot.size_flags_horizontal = Control.SIZE_FILL
	inspector_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_columns.add_child(inspector_slot)
	inspector_panel = PanelContainer.new()
	inspector_slot.add_child(inspector_panel)
	inspector_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspector_slot.resized.connect(_layout_right_panel)
	# Both wings use the same fixed width; only the center expands.
	inspector_panel.size_flags_horizontal = Control.SIZE_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#284661"), 3, 3))
	# Simulation controls are global, not contextual commands.
	time_panel = PanelContainer.new()
	time_panel.z_index = 4
	add_child(time_panel)
	time_panel.theme = HUD.compact()
	time_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0b1624"), Color("#345570"), 4, 3))
	time_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	var time_toolbar := HBoxContainer.new()
	time_toolbar.alignment = BoxContainer.ALIGNMENT_BEGIN
	time_panel.add_child(time_toolbar)
	_build_time_controls(time_toolbar)
	# Tabs and fleet commands each own a bounded scroll viewport. A
	# ScrollContainer around a TabContainer collapses its page to zero height.
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_child(body)
	console_right_body = body
	overview_panel = PanelContainer.new()
	console_center.add_child(overview_panel)
	overview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_panel.add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#284661"), 3, 3))
	var selection_content := VBoxContainer.new()
	overview_panel.add_child(selection_content)
	var selection_row := HBoxContainer.new()
	selection_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_row.add_theme_constant_override("separation", 8)
	selection_content.add_child(selection_row)
	_build_selection_portrait(selection_row)
	var overview_scroll := ScrollContainer.new()
	overview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	selection_row.add_child(overview_scroll)
	var overview := VBoxContainer.new()
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview.add_theme_constant_override("separation", 3)
	overview_scroll.add_child(overview)
	planet_overview = VBoxContainer.new()
	planet_overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	planet_overview.add_theme_constant_override("separation", 3)
	overview.add_child(planet_overview)
	_build_body_overview(overview)
	_build_yard_overview(overview)
	building_group_panel = VBoxContainer.new()
	overview.add_child(building_group_panel)
	building_group_title = _label("", 16)
	building_group_panel.add_child(building_group_title)
	building_group_grid = GridContainer.new()
	building_group_grid.columns = 6
	building_group_grid.add_theme_constant_override("h_separation", 3)
	building_group_grid.add_theme_constant_override("v_separation", 3)
	building_group_panel.add_child(building_group_grid)
	building_group_panel.hide()
	ship_overview = VBoxContainer.new()
	ship_overview.add_theme_constant_override("separation", 4)
	overview.add_child(ship_overview)
	ship_title = _label("", 16)
	ship_overview.add_child(ship_title)
	selection_grid = GridContainer.new()
	selection_grid.columns = 6
	selection_grid.add_theme_constant_override("h_separation", 3)
	selection_grid.add_theme_constant_override("v_separation", 3)
	ship_overview.add_child(selection_grid)
	ship_detail = _label("", 13)
	ship_overview.add_child(ship_detail)
	var crew_row := HBoxContainer.new()
	ship_overview.add_child(crew_row)
	ship_population = _label("", 13)
	ship_population.autowrap_mode = TextServer.AUTOWRAP_OFF
	ship_population.add_theme_color_override("font_color", Color("#b9d9ed"))
	crew_row.add_child(ship_population)
	crew_row.hide()
	weapon_details = _label("", 12)
	overview.add_child(weapon_details)
	weapon_details.hide()
	fleet_scroll = ScrollContainer.new()
	fleet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	fleet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(fleet_scroll)
	fleet_overview = VBoxContainer.new()
	fleet_overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_overview.add_theme_constant_override("separation", 3)
	fleet_scroll.add_child(fleet_overview)
	fleet_title = _label("", 16)
	ship_overview.add_child(fleet_title)
	fleet_detail = _label("", 14)
	ship_overview.add_child(fleet_detail)
	_build_command_card(fleet_overview)
	_build_yard_command_card(body)
	fleet_cargo_footer = HBoxContainer.new()
	selection_content.add_child(fleet_cargo_footer)
	var cargo_title: Label = _label("CARGO", 11)
	cargo_title.add_theme_color_override("font_color", HUD.MUTED)
	cargo_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	fleet_cargo_footer.add_child(cargo_title)
	var cargo_scroll := ScrollContainer.new()
	cargo_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cargo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	fleet_cargo_footer.add_child(cargo_scroll)
	fleet_cargo = HBoxContainer.new()
	fleet_cargo.add_theme_constant_override("separation", 7)
	cargo_scroll.add_child(fleet_cargo)
	_build_fleet_cargo_row()
	fleet_cargo_footer.hide()
	_build_field_command_card(fleet_overview)
	var system_header := HBoxContainer.new()
	planet_overview.add_child(system_header)
	info = _label("", 14)
	info.clip_text = true
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_header.add_child(info)
	system_owner_label = _label("", 11)
	system_owner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	system_owner_label.clip_text = true
	system_owner_label.custom_minimum_size.x = 72
	system_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	system_header.add_child(system_owner_label)
	var station_columns := HBoxContainer.new()
	station_columns.add_theme_constant_override("separation", 8)
	station_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	planet_overview.add_child(station_columns)
	population_label = _label("", 13)
	population_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	population_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	population_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	station_details = VBoxContainer.new()
	station_details.add_theme_constant_override("separation", 3)
	station_details.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	station_columns.add_child(station_details)
	var population_row: HBoxContainer = _population_row(station_details)
	population_row.add_child(population_label)
	population_delta_label = _label("", 11)
	population_delta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	population_row.add_child(population_delta_label)
	production_summary = HUD.section(station_details, "Resources", true)
	production_summary.get_child(0).hide()
	production_summary.add_theme_constant_override("separation", 1)
	_build_production_summary()
	raw_antimatter_label = _label("", 12)
	raw_antimatter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	raw_antimatter_label.add_theme_color_override("font_color", HUD.COLORS[ECONOMY.ANTIMATTER])
	production_summary.add_child(raw_antimatter_label)
	raw_antimatter_label.hide()
	station_queue_panel = VBoxContainer.new()
	station_queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_queue_panel.custom_minimum_size.x = 65
	station_columns.add_child(station_queue_panel)
	station_queue_heading = _label("Queue (0)", 11)
	station_queue_heading.add_theme_color_override("font_color", HUD.MUTED)
	station_queue_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	station_queue_panel.add_child(station_queue_heading)
	station_queue = _build_centered_queue(station_queue_panel)
	station_queue.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	station_queue.alignment = FlowContainer.ALIGNMENT_BEGIN
	station_queue_panel.hide()
	interaction_scroll = ScrollContainer.new()
	interaction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	interaction_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(interaction_scroll)
	interaction_panel = VBoxContainer.new()
	interaction_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_panel.add_theme_constant_override("separation", 8)
	interaction_scroll.add_child(interaction_panel)
	var neutral_grid: GridContainer = _ability_grid(interaction_panel)
	send_colony_button = _station_button(neutral_grid, "Send\nColony", "transform", _send_colony)
	_set_button_hint(send_colony_button, "Send the nearest idle Colony to this sector")
	_fill_ability_grid(neutral_grid)
	_build_station_command_card(body)
	var trade_page: GridContainer = _inspector_page("Trade")
	for resource in ECONOMY.RESOURCES:
		var logistics: VBoxContainer = HUD.section(trade_page, "", true)
		logistics.get_child(0).hide()
		logistics.add_theme_constant_override("separation", 0)
		logistics.get_parent().add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#233e56"), 1, 3))
		var trade_row := HBoxContainer.new()
		logistics.add_child(trade_row)
		var resource_icon := TextureRect.new()
		HUD.fixed_icon(resource_icon, HUD.resource_icon(resource, 14), 14)
		trade_row.add_child(resource_icon)
		var name_label := _label(resource, 11)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", HUD.COLORS[resource])
		trade_row.add_child(name_label)
		var stock_label := _label("", 10)
		stock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		stock_label.custom_minimum_size.x = 64
		stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		trade_row.add_child(stock_label)
		trade_stock_labels[resource] = stock_label
		var slider := TradeRange.new()
		slider.custom_minimum_size.y = 26
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f t." % ECONOMY.TRADE_REFERENCE
		slider.committed.connect(_apply_thresholds.bind(resource))
		logistics.add_child(slider)
		trade_sliders[resource] = slider
		var switch_inset := MarginContainer.new()
		switch_inset.add_theme_constant_override("margin_left", 8)
		switch_inset.add_theme_constant_override("margin_right", 6)
		logistics.add_child(switch_inset)
		logistics.move_child(switch_inset, slider.get_index())
		var switches := HBoxContainer.new()
		switches.add_theme_constant_override("separation", 6)
		switch_inset.add_child(switches)
		var incoming := CheckBox.new()
		incoming.text = "Import"
		incoming.tooltip_text = "Enable imports below the left threshold"
		incoming.add_theme_font_size_override("font_size", 10)
		_compact_trade_check(incoming)
		incoming.button_pressed = true
		switches.add_child(incoming)
		var outgoing := CheckBox.new()
		outgoing.text = "Export"
		outgoing.tooltip_text = "Enable exports above the right threshold"
		outgoing.add_theme_font_size_override("font_size", 10)
		_compact_trade_check(outgoing)
		outgoing.button_pressed = true
		incoming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outgoing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		switches.add_child(outgoing)
		trade_checks[resource] = [incoming, outgoing]
		incoming.toggled.connect(_trade_toggle.bind(resource))
		outgoing.toggled.connect(_trade_toggle.bind(resource))
	for grid in command_grids.values():
		for card in grid.get_children():
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resized.connect(_layout_console)
	inspector_panel.resized.connect(_layout_command_grids)
	inspector_slot.resized.connect(_layout_command_grids)
	inspector_panel.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(_layout_command_grids)
	lens_column.resized.connect(console_profile.queue_redraw)
	console_columns.resized.connect(console_profile.queue_redraw)
	_layout_console()

func _layout_console() -> void:
	if not is_instance_valid(console_panel) or not is_instance_valid(station_commands):
		return
	# Keep a stable, useful map at both normal and small window sizes.
	var height: float = roundf(minf(clampf(size.y * 0.36, 220.0, 320.0), maxf(135.0, size.y - HEADER_HEIGHT - 180.0)))
	console_panel.offset_top = -8.0 - height
	# Draw the space scene behind the HUD rather than clipping it at a
	# horizontal line. Camera framing still uses the unobstructed play area.
	map_canvas.offset_bottom = -8.0
	territory_layer.offset_bottom = map_canvas.offset_bottom
	diagnostic_label.offset_bottom = -20.0 - height
	diagnostic_label.offset_top = -44.0 - height
	# Symmetric wings occupy at most 48% of the deck together at the
	# usual window sizes. The center receives all remaining width.
	var wing_width: float = clampf(floorf((size.x - 28.0 - LENS_STRIP_WIDTH) * 0.24), 180.0, 320.0)
	minimap.custom_minimum_size.x = wing_width
	inspector_slot.custom_minimum_size.x = wing_width
	inspector_panel.custom_minimum_size.x = wing_width
	if is_instance_valid(time_panel):
		time_panel.offset_left = 8.0
		time_panel.offset_right = 8.0 + wing_width
		time_panel.offset_bottom = console_panel.offset_top - 3.0
		time_panel.offset_top = time_panel.offset_bottom - 31.0
	if is_instance_valid(control_group_strip):
		_layout_control_group_strip()
	if is_instance_valid(global_selection_strip):
		global_selection_strip.position = Vector2(8.0, size.y + console_panel.offset_top - 36.0 - global_selection_strip.size.y)
	# SC2-style raised wings: minimap and commands use the full deck height;
	# selection details begin 20% lower, leaving more map visible centrally.
	console_center_spacer.custom_minimum_size.y = roundf(height * 0.20)
	console_profile.queue_redraw()
	# Do not force the center wider than its allotted column.
	overview_panel.custom_minimum_size.x = 0.0
	_layout_right_panel()
	_layout_command_grids()

func _layout_right_panel() -> void:
	if not is_instance_valid(inspector_slot) or not is_instance_valid(inspector_panel):
		return
	var extra: float = 0.0
	if station_card == "trade" and station_selected_index >= 0 and is_instance_valid(station_commands) and station_commands.visible and command_grids.has("Trade") and is_instance_valid(station_trade_back):
		var page: GridContainer = command_grids["Trade"]
		var padding: float = inspector_panel.get_theme_stylebox("panel").get_minimum_size().y
		var required: float = page.get_combined_minimum_size().y + station_trade_back.get_combined_minimum_size().y + float(station_trade.get_theme_constant("separation")) + padding + 4.0
		var top_limit: float = header_panel.global_position.y + header_panel.size.y + 4.0
		var available: float = maxf(0.0, inspector_slot.global_position.y - top_limit)
		# Three resources usually fit in the standard wing. Extend only to
		# cover a small shortfall; the scroll viewport handles smaller windows.
		extra = ceilf(clampf(required - inspector_slot.size.y, 0.0, minf(TRADE_MAX_EXTRA_HEIGHT, available)))
	inspector_panel.offset_top = -extra
	console_profile.queue_redraw()

func _draw_console_profile() -> void:
	# The three physical panel silhouettes are drawn independently. The
	# center starts lower; the left minimap and right commands extend into
	# the map instead of sharing a rectangular full-width background.
	if not is_instance_valid(console_center) or not is_instance_valid(inspector_panel):
		return
	var bounds: Rect2 = Rect2(Vector2.ZERO, console_profile.size)
	var center_left: float = console_center.global_position.x - console_profile.global_position.x
	var right_left: float = inspector_panel.global_position.x - console_profile.global_position.x
	var center_top: float = console_center_spacer.global_position.y + console_center_spacer.size.y - console_profile.global_position.y
	var fill: Color = HUD.CONSOLE_BACKGROUND
	var edge := Color("#345570")
	var left_width: float = lens_column.global_position.x + lens_column.size.x - console_profile.global_position.x
	var left_rect := Rect2(Vector2.ZERO, Vector2(left_width, bounds.size.y))
	var center_rect := Rect2(Vector2(center_left, center_top), Vector2(console_center.size.x, maxf(0.0, bounds.size.y - center_top)))
	var right_top: float = inspector_panel.global_position.y - console_profile.global_position.y
	var right_rect := Rect2(Vector2(right_left, right_top), Vector2(maxf(0.0, bounds.size.x - right_left), maxf(0.0, bounds.size.y - right_top)))
	var rects: Array[Rect2] = [left_rect]
	if overview_panel.visible:
		rects.append(center_rect)
	if console_right_body.visible:
		rects.append(right_rect)
	for rect in rects:
		if rect.has_area():
			console_profile.draw_rect(rect, fill)
			console_profile.draw_rect(rect.grow(-0.5), edge, false, 1.0)

func _layout_command_grids() -> void:
	var width: float = inspector_panel.size.x - 34.0
	var padding: Vector2 = inspector_panel.get_theme_stylebox("panel").get_minimum_size()
	var slot_width: float = maxf(36.0, floorf((inspector_panel.custom_minimum_size.x - padding.x - 9.0) / 4.0))
	var slot_height: float = floorf((inspector_slot.size.y - padding.y - 9.0) / 4.0) if inspector_slot.size.y > 0.0 else 52.0
	var slot_size := Vector2(slot_width, maxf(32.0, slot_height))
	for grid in [command_card, field_command_grid, yard_command_grid, station_primary_grid, station_build_grid]:
		if not is_instance_valid(grid):
			continue
		for slot in grid.get_children():
			slot.custom_minimum_size = slot_size
			var face: Control = slot
			if not slot is Button and slot.get_child_count() > 0 and slot.get_child(0) is Button:
				face = slot.get_child(0)
			if not face is Button or not face.has_meta("caption"):
				continue
			var caption: Label = face.get_meta("caption")
			var font: Font = caption.get_theme_font("font")
			var font_size: int = 11
			for line in caption.text.split("\n"):
				while font_size > 8 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > slot_width - 4.0:
					font_size -= 1
			caption.add_theme_font_size_override("font_size", font_size)
	if is_instance_valid(station_trade_back):
		station_trade_back.custom_minimum_size = Vector2(slot_width, 36.0)
	if is_instance_valid(selection_grid):
		selection_grid.columns = maxi(1, floori(maxf(38.0, console_center.size.x - 20.0) / 41.0))
		building_group_grid.columns = selection_grid.columns
	if is_instance_valid(selection_portrait):
		var portrait_width: float = clampf(floorf(console_center.size.x * 0.22), 70.0, 108.0)
		selection_portrait.custom_minimum_size.x = portrait_width
		selection_portrait_art.custom_minimum_size.y = minf(portrait_width, 90.0)
	for title in command_grids:
		var grid: GridContainer = command_grids[title]
		var cell_width: float = 160.0 if title == "Trade" else 222.0
		grid.columns = clampi(floori(width / cell_width), 1, 3)
	_layout_right_panel()

func _minimap_area() -> Rect2:
	var bounds: Vector2 = _map_size().max(Vector2.ONE)
	var available: Vector2 = (minimap.size - Vector2(12, 12)).max(Vector2.ONE)
	var scale: float = minf(available.x / bounds.x, available.y / bounds.y)
	var extent: Vector2 = bounds * scale
	return Rect2((minimap.size - extent) * 0.5, extent)

func _minimap_point(point: Vector2, area: Rect2) -> Vector2:
	return area.position + point / _map_size().max(Vector2.ONE) * area.size

func _minimap_input(event: InputEvent) -> void:
	if match_menu.visible or (is_instance_valid(codex) and codex.visible):
		return
	var move_camera: bool = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			minimap_pan_drag = event.pressed and pending_command.is_empty()
			move_camera = minimap_pan_drag
		if event.pressed and not _state().is_empty() and (event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and not pending_command.is_empty())):
			_minimap_order(event)
			minimap.accept_event()
			return
	elif event is InputEventMouseMotion:
		move_camera = minimap_pan_drag and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if move_camera and not _state().is_empty():
		var area: Rect2 = _minimap_area()
		var fraction: Vector2 = ((event.position - area.position) / area.size).clamp(Vector2.ZERO, Vector2.ONE)
		var world: Vector2 = fraction * _map_size()
		follow_units = false
		_center_world(world)
		_position_territory()
		map_canvas.queue_redraw()
		minimap.queue_redraw()
	minimap.accept_event()

func _minimap_order(mouse: InputEventMouseButton) -> void:
	var state: Dictionary = _state()
	var area: Rect2 = _minimap_area()
	if not area.has_point(mouse.position):
		return
	var world: Vector2 = (mouse.position - area.position) / area.size * _map_size()
	var hint: Dictionary = {"world": world, "entity": -1, "field": -1, "wreck": -1}
	var graph: Dictionary = ECONOMY.military_graph(state)
	var count: int = state["planets"].size()
	var nearest: float = 5.0
	var node_hit: int = -1
	# Star markers are background landmarks, not implicit destinations or
	# station targets. Only actual entity/service orders use marker hits.
	if not mouse.alt_pressed and pending_command not in ["move", "patrol", "guard", "rally"]:
		var poses: Dictionary = _ship_poses(state)
		nearest = 3.0
		for id in poses:
			var ship_point: Vector2 = poses[id]["world"]
			var distance: float = mouse.position.distance_to(_minimap_point(ship_point, area))
			if distance < nearest:
				nearest = distance
				hint["entity"] = id
		if int(hint["entity"]) == -1:
			nearest = 5.0
			for node in ECONOMY.military_pois(state, _me()):
				if node < count:
					if not ECONOMY.has_station(state["planets"][node]):
						continue
					var station_point: Vector2 = ECONOMY.station_position(state, node, float(state["elapsed"]))
					var distance: float = mouse.position.distance_to(_minimap_point(station_point, area))
					if distance < nearest:
						nearest = distance
						node_hit = node
						hint["entity"] = ECONOMY.station_target_id(state, node)
						hint["field"] = -1
				else:
					var distance: float = mouse.position.distance_to(_minimap_point(graph["points"][node], area))
					if distance < nearest:
						nearest = distance
						node_hit = node
						hint["field"] = node - count
						hint["entity"] = -1
		if pending_command == "load" or (node_hit < 0 and int(hint["entity"]) == -1):
			nearest = 3.0
			for pile in state.get("salvage", {}).values():
				var distance: float = mouse.position.distance_to(_minimap_point(pile["position"], area))
				if distance < nearest:
					nearest = distance
					hint["wreck"] = int(pile["id"])
	var point: Vector2 = _screen_point(hint["world"])
	var mode: String = pending_command
	if mode in ["repair", "unload", "load", "collect", "guard"]:
		_execute_pending_command(point, mouse.shift_pressed, hint)
	elif mode == "rally" or (mode.is_empty() and selected_yard >= 0):
		_set_rally_at(point)
		pending_command = ""
		_refresh_command_mode()
	else:
		_command_at(point, mouse.alt_pressed, mode == "patrol", mode not in ["attack", "patrol"], mode == "attack", mouse.shift_pressed, mode.is_empty(), hint)
		if not mouse.shift_pressed:
			pending_command = ""
			_refresh_command_mode()

func _draw_minimap() -> void:
	var surface := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(surface, HUD.CONSOLE_BACKGROUND)
	minimap.draw_rect(surface.grow(-0.5), Color("#345570"), false, 1.0)
	var state: Dictionary = _state()
	if state.is_empty() or minimap.size.x < 12.0 or minimap.size.y < 12.0:
		return
	var area: Rect2 = _minimap_area()
	minimap.draw_rect(area, Color("#090f17"))
	for i in range(1, 5):
		var x: float = area.position.x + area.size.x * float(i) / 5.0
		var y: float = area.position.y + area.size.y * float(i) / 5.0
		minimap.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("#142437"))
		minimap.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("#142437"))
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	var count: int = state["planets"].size()
	var viewer: int = _me()
	var locations: Array[Vector2] = []
	var known: Array[bool] = []
	for i in range(points.size()):
		locations.append(_minimap_point(points[i], area))
		known.append(ECONOMY.discovered(state, viewer, "planets" if i < count else "fields", i if i < count else i - count))
		if known[i] and i < territory_last.size() and territory_last[i].a > 0.0:
			var radius: float = clampf(territory_radius * area.size.x / _map_size().x, 3.0, 12.0) * (1.0 if i < count else 0.68)
			var influence: Color = territory_last[i]
			minimap.draw_circle(locations[i], radius, Color(influence, 0.17 * influence.a))
	var edges: Array = graph["edges"]
	var layout: Dictionary = ECONOMY.highway_regions(graph)
	for i in range(edges.size()):
		var a: int = int(edges[i][0])
		var b: int = int(edges[i][1])
		var sections: int = int(layout["counts"][i])
		var width: float = clampf(2.0 * ECONOMY.lane_radius(graph, a, b) * area.size.x / _map_size().x, 1.0, 8.0)
		for j in range(sections):
			var start: Vector2 = locations[a].lerp(locations[b], float(j) / sections)
			var finish: Vector2 = locations[a].lerp(locations[b], float(j + 1) / sections)
			var tint: Color = Color("#39546c") if known[a] and known[b] else Color("#182b3b")
			var weight_index: int = int(layout["starts"][i]) + j
			if known[a] and known[b] and weight_index < territory_last.size():
				var influence: Color = territory_last[weight_index]
				if influence.a > 0.0:
					minimap.draw_line(start, finish, Color(influence, 0.25 * influence.a), width, true)
				tint = tint.lerp(Color(influence, 1.0), influence.a)
			minimap.draw_line(start, finish, tint, 1.0, true)
	for i in range(points.size()):
		var tint := Color("#34485a")
		if i < count:
			var owner: int = int(state["planets"][i]["owner"])
			if known[i]:
				tint = _empire_color(owner) if owner > 0 else Color("#a3b0bb")
			minimap.draw_circle(locations[i], 2.4 if owner > 0 and known[i] else 1.8, tint)
		elif known[i]:
			var special: bool = bool(state["map"]["fields"][i - count].get("antimatter", false))
			tint = HUD.COLORS[ECONOMY.ANTIMATTER] if special else Color("#b8a87a")
			minimap.draw_rect(Rect2(locations[i] - Vector2.ONE * 1.8, Vector2.ONE * 3.6), tint, false, 1.0)
		if (i < count and i == selected and selected_units.is_empty() and selected_field < 0) or (i >= count and i - count == selected_field):
			minimap.draw_arc(locations[i], 4.5, 0.0, TAU, 12, HUD.ACCENT, 1.0, true)
	for pile in state.get("salvage", {}).values():
		var point: Vector2 = _minimap_point(pile["position"], area)
		if area.has_point(point):
			minimap.draw_circle(point, 1.0, HUD.COLORS[pile["resource"]])
	# Mirror the main map's live hull visibility and interpolation; do not
	# reveal undiscovered system ownership.
	for ship in state["ships"]:
		if not _ship_visible(state, ship):
			continue
		var id: int = int(ship["id"])
		var visual: Dictionary = ship_visuals.get(id, {})
		var world: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
		var point: Vector2 = _minimap_point(world, area)
		if area.has_point(point):
			minimap.draw_circle(point, 1.5, _empire_color(int(ship["owner"])))
			if selected_units.has(id):
				minimap.draw_arc(point, 2.6, 0.0, TAU, 10, Color.WHITE, 1.0, true)
	var corner: Vector2 = _minimap_point(_world_point(Vector2.ZERO), area)
	var end: Vector2 = _minimap_point(_world_point(map_canvas.size), area)
	var camera_rect := Rect2(corner, end - corner)
	# Preserve a visible indicator at extreme close-up zoom levels.
	var visible_extent: Vector2 = camera_rect.size.max(Vector2(3, 3))
	var visible_rect := Rect2(camera_rect.get_center() - visible_extent * 0.5, visible_extent)
	minimap.draw_rect(area, Color("#35536a"), false, 1.0)
	var clipped: Rect2 = visible_rect.intersection(area)
	if clipped.has_area():
		minimap.draw_rect(clipped, Color(HUD.ACCENT, 0.08))
		minimap.draw_rect(clipped, HUD.ACCENT, false, 1.2)


func _population_texture(pixels: int = 24) -> Texture2D:
	if not population_icons.has(pixels):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="#b9d9ed"><circle cx="12" cy="6" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4z"/></svg>' % [pixels, pixels])
		population_icons[pixels] = ImageTexture.create_from_image(image)
	return population_icons[pixels]

func _population_row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var icon := TextureRect.new()
	HUD.fixed_icon(icon, _population_texture(14), 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	return row

func _style_progress(bar: ProgressBar, p: Dictionary, job: Dictionary) -> void:
	var blocked: Array[String] = []
	if not job.is_empty():
		blocked = ECONOMY.construction_blockers(p, job)
	bar.set_meta("blocked", not blocked.is_empty())
	if blocked.is_empty():
		bar.remove_theme_stylebox_override("fill")
		bar.remove_theme_stylebox_override("background")
	else:
		bar.add_theme_stylebox_override("background", HUD.surface(Color("#33251a"), Color("#db9b54"), 0, 3))
		bar.add_theme_stylebox_override("fill", HUD.surface(Color("#b56b35"), Color("#f2b57e"), 0, 3))
		bar.tooltip_text = "Blocked: " + ", ".join(blocked)

func _set_cost_tooltip(button: Button, description: String, cost: Dictionary = {}, crew: float = 0.0, available: Dictionary = {}) -> void:
	var cost_button: CostButton = button as CostButton
	cost_button.recipe = cost.duplicate()
	cost_button.missing.clear()
	if crew > 0.0:
		cost_button.recipe["Population"] = crew
		cost_button.crew_icon = _population_texture()
	if not available.is_empty():
		for resource in cost_button.recipe:
			if float(available.get(resource, 0.0)) + ECONOMY.EPS < float(cost_button.recipe[resource]):
				cost_button.missing.append(resource)
	var shortcut: String = str(button.get_meta("hotkey", ""))
	_set_button_hint(button, description if shortcut.is_empty() else (description + "\n[" + shortcut + "]" if not description.is_empty() else "[" + shortcut + "]"))

func _available_cost_resources(p: Dictionary, yard: int = -1) -> Dictionary:
	var available: Dictionary = p["stock"].duplicate()
	var reserve: float = ECONOMY.SHIPYARD_POPULATION[yard] if yard >= 0 else 0.0
	available["Population"] = maxf(0.0, float(p["population"]) - reserve)
	return available

func _blaster_summary(kind: String) -> String:
	return "Blasters ×%d · %.0f damage/shot · %d shots/burst · %.1f s on / %.1f s off · Range %.0f" % [ECONOMY.blaster_count(kind), ECONOMY.BLASTER_DAMAGE, ECONOMY.BLASTER_SHOTS, ECONOMY.BLASTER_BURST, ECONOMY.BLASTER_PAUSE, ECONOMY.LASER_RANGE]

func _capital_weapon_summary(kind: String) -> String:
	return "Lasers ×%d · %.0f damage each · 1 s · Range %.0f\nMissiles ×%d · %.0f damage each · %.0f s · Range %.0f" % [ECONOMY.capital_lasers(kind), ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE, ECONOMY.missile_count(kind), ECONOMY.MISSILE_DAMAGE, ECONOMY.MISSILE_COOLDOWN, ECONOMY.MISSILE_RANGE] + "\n" + _blaster_summary(kind)

func _ship_stats(kind: String) -> String:
	var details: String = ""
	match kind:
		"ship": details = "Transports resources · Cargo %.0f t" % ECONOMY.CARGO_CAPACITY
		"colony_ship": details = "Settles a neutral system · %.0f settlers\nFarm %.0f t/s at 1× · Cargo %.0f t" % [ECONOMY.COLONY_POPULATION, ECONOMY.COLONY_FARM_RATE, ECONOMY.COLONY_CAPACITY]
		"scout": details = "Fast reconnaissance · " + _blaster_summary(kind)
		"cruiser", "destroyer": details = _capital_weapon_summary(kind)
		"fighter": details = _blaster_summary(kind)
		"miner": details = "Damage %.0f · Range %.0f · Mining %.0f t/s at 1× · Cargo %.0f t" % [ECONOMY.MINER_LASER_DAMAGE, ECONOMY.LASER_RANGE, ECONOMY.MINER_RATE, ECONOMY.MINER_CAPACITY]
		"science_ship": details = "Pulsar collector · 1 antimatter · %.0f s collection at 1×" % ECONOMY.SCIENCE_COLLECTION_YEARS
	return "%s\nHP %.0f · Speed %.0f/s (1×) · %s" % [details, ECONOMY.ship_max_hp(kind), ECONOMY.ship_speed(kind), ECONOMY.size_name(ECONOMY.ship_size(kind))]

func _build_production_summary() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	production_summary.add_child(header)
	var blank := Control.new()
	blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(blank)
	for column in [["Stock", 48], ["Lv", 18], ["/yr", 44], ["Bonus", 36]]:
		var title_label := _label(str(column[0]), 10)
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.custom_minimum_size.x = float(column[1])
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title_label.add_theme_color_override("font_color", HUD.MUTED)
		header.add_child(title_label)
	for resource in ECONOMY.RESOURCES:
		var row := HBoxContainer.new()
		production_summary.add_child(row)
		row.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		HUD.fixed_icon(icon, HUD.resource_icon(resource, 16), 16)
		row.add_child(icon)
		var name_label := _label(resource, 12)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var stock := _label("", 11)
		stock.autowrap_mode = TextServer.AUTOWRAP_OFF
		stock.custom_minimum_size.x = 48
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(stock)
		var level := _label("", 11)
		level.autowrap_mode = TextServer.AUTOWRAP_OFF
		level.custom_minimum_size.x = 18
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level)
		var rate_label := _label("", 11)
		rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		rate_label.custom_minimum_size.x = 44
		rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rate_label)
		var bonus := _label("", 11)
		bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
		bonus.custom_minimum_size.x = 36
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(bonus)
		production_values[resource] = {"row": row, "stock": stock, "level": level, "rate": rate_label, "bonus": bonus}

func _system_bonus_text(p: Dictionary) -> String:
	var lines: PackedStringArray = []
	var names: Dictionary = {"Metals": "Metal production", "Crystals": "Crystal production", "Organics": "Organics production"}
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var percent: int = roundi(ECONOMY.production_modifier(p, resource) * 100.0)
		if percent != 100:
			lines.append("%s %d%%" % [names[resource], percent])
	var advanced: int = roundi(float(p.get("advanced_bonus", 1.0)) * 100.0)
	if advanced != 100:
		lines.append("Advanced manufacturing %d%% (future)" % advanced)
	return "\n".join(lines)

func _economy_building_effect(p: Dictionary, resource: String) -> String:
	var preview: Dictionary = p.duplicate()
	var buildings: Dictionary = p.get("buildings", {}).duplicate()
	buildings[resource] = int(buildings.get(resource, 0)) + 1
	preview["buildings"] = buildings
	var before_multiplier: float = ECONOMY.building_multiplier(p, resource)
	var after_multiplier: float = ECONOMY.building_multiplier(preview, resource)
	var lines: PackedStringArray = ["Building output multiplier: %.2f× → %.2f× (+%.2f× baseline)" % [before_multiplier, after_multiplier, ECONOMY.BUILDING_BONUS]]
	if not ECONOMY.production_available(p, resource):
		lines.append("Unavailable: no local deposit")
		return "\n".join(lines)
	var before: float = ECONOMY.rate(p, resource)
	var after: float = ECONOMY.rate(preview, resource)
	var demand: float = ECONOMY.consumption(p, resource)
	var delta: float = after - before
	lines.append("Production: %.2f → %.2f t/yr (%+.2f)" % [before, after, delta])
	lines.append("Net after %.2f t/yr demand: %+.2f → %+.2f t/yr" % [demand, before - demand, after - demand])
	if ECONOMY.production_level(p, resource) == 0 and ECONOMY.production_level(preview, resource) > 0:
		lines.append("Unlocks local production (level 0 → 1)")
	if resource == "Organics":
		lines.append("Maximum farm output: %.2f → %.2f t/yr" % [ECONOMY.farm_potential(p), ECONOMY.farm_potential(preview)])
		lines.append("Food capacity: %s → %s people" % [_compact_amount(ECONOMY.population_capacity(p)), _compact_amount(ECONOMY.population_capacity(preview))])
	elif ECONOMY.MINED_RESOURCES.has(resource):
		lines.append("Local extraction limit: %.0f t/yr" % ECONOMY.PLANET_MINING_LIMIT)
		if after >= ECONOMY.PLANET_MINING_LIMIT - ECONOMY.EPS:
			lines.append("Output capped at the extraction limit")
	lines.append("At current population and modifiers; before storage limits.")
	return "\n".join(lines)

func _body_name(system_index: int, slot: int) -> String:
	var suffixes: Array[String] = ["I", "II", "III", "IV", "V", "VI"]
	return _system_name(system_index) + " " + suffixes[slot]

func _build_yard_overview(parent: Container) -> void:
	yard_overview = VBoxContainer.new()
	yard_overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	yard_overview.add_theme_constant_override("separation", 3)
	parent.add_child(yard_overview)
	yard_title = _label("", 16)
	yard_overview.add_child(yard_title)
	yard_context = _label("", 12)
	yard_context.add_theme_color_override("font_color", HUD.MUTED)
	yard_overview.add_child(yard_context)
	yard_status = _label("", 12)
	yard_overview.add_child(yard_status)
	yard_queue = _build_centered_queue(yard_overview)
	yard_overview.hide()

func _build_centered_queue(parent: Container) -> HFlowContainer:
	var queue := HFlowContainer.new()
	queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Center the flow's minimum-height block in the space below the header.
	# Filling the width lets each wrapped line stay centered independently.
	queue.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	queue.alignment = FlowContainer.ALIGNMENT_CENTER
	queue.add_theme_constant_override("h_separation", 6)
	queue.add_theme_constant_override("v_separation", 6)
	parent.add_child(queue)
	return queue

func _freighter_bay_center(index: int) -> Vector2:
	return Vector2(14.0 - float(floori(float(index) / 2.0)) * 7.0, -3.5 if index % 2 == 0 else 3.5)

func _freighter_bay_vertices(index: int) -> Array:
	var center: Vector2 = _freighter_bay_center(index)
	return [center + Vector2(3, 3), center + Vector2(-3, 3), center + Vector2(-3, -3), center + Vector2(3, -3)]

func _portrait_points(vertices: Array, factor: float = 1.0) -> String:
	var coordinates: PackedStringArray = []
	for vertex in vertices:
		var v: Vector2 = vertex
		coordinates.append("%.2f,%.2f" % [32.0 + v.y * 1.85 * factor, 32.0 - v.x * 1.85 * factor])
	return " ".join(coordinates)

func _hull_ui_radius(kind: String) -> float:
	return float({"ship": 24.0, "cruiser": 27.0, "destroyer": 46.0, "warp_gate": 44.0}.get(kind, 15.0))

func _portrait_scale(kind: String) -> float:
	return float({"ship": 0.6, "cruiser": 0.52, "destroyer": 0.30}.get(kind, 1.0))

func _hull_texture_half_size(kind: String) -> float:
	return 50.0 if kind == "destroyer" else 40.0

func _production_icon(kind: String, tint: Color, pixels: int = 64) -> Texture2D:
	var key: String = "%s:%s:%d" % [kind, tint.to_html(false), pixels]
	if not production_icons.has(key):
		var portrait_scale: float = _portrait_scale(kind)
		var outline: String = _portrait_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE), portrait_scale)
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g transform="translate(32 32) scale(1.13) translate(-32 -32)">'
		art += '<polygon points="%s" fill="#18283c" stroke="#%s" stroke-width="1.8" stroke-linejoin="round"/>' % [outline, tint.lightened(0.35).to_html(false)]
		for panel in HULL_PANELS.get(kind, []):
			var color: Color = _hull_panel_color(tint, panel[0])
			art += '<polygon points="%s" fill="#%s"/>' % [_portrait_points(panel[1], portrait_scale), color.lightened(0.12).to_html(false)]
		if kind == "ship":
			for bay in range(ECONOMY.FREIGHTER_BAY_COUNT):
				art += '<polygon points="%s" fill="#32465c" stroke="#9bb6cb" stroke-width="0.8"/>' % _portrait_points(_freighter_bay_vertices(bay), 0.6)
		art += '<polygon points="%s" fill="none" stroke="#%s" stroke-width="1.25" stroke-linejoin="round"/></g></svg>' % [outline, tint.lightened(0.50).to_html(false)]
		var image := Image.new()
		image.load_svg_from_string(art, float(pixels) / 64.0)
		production_icons[key] = ImageTexture.create_from_image(image)
	return production_icons[key]

func _register_command_hotkey(button: Button, key: int, scope: String, id: String, title_text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#e3f3ff"))
	label.add_theme_color_override("font_outline_color", Color("#101b29"))
	label.add_theme_constant_override("outline_size", 3)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -24.0
	label.offset_right = -2.0
	label.offset_top = 0.0
	label.offset_bottom = 12.0
	hotkey_entries[id] = {"scope": scope, "title": title_text, "default": key, "button": button, "badge": label}

func _hotkey_value(id: String, overrides: Dictionary) -> int:
	return int(overrides.get(id, hotkey_entries[id]["default"]))

func _hotkey_name(key: int) -> String:
	return "Esc" if key == KEY_ESCAPE else OS.get_keycode_string(key)

func _hotkey_conflict(id: String, key: int, overrides: Dictionary) -> String:
	var scope: String = hotkey_entries[id]["scope"]
	for other in hotkey_entries:
		if other == id:
			continue
		var other_scope: String = hotkey_entries[other]["scope"]
		if (scope == other_scope or scope == "General" or other_scope == "General") and _hotkey_value(other, overrides) == key:
			return str(hotkey_entries[other]["title"])
	return ""

func _load_hotkey_overrides() -> void:
	var candidate: Dictionary = {}
	for id in hotkey_entries:
		var default_key: int = int(hotkey_entries[id]["default"])
		var key: int = int(settings.get_value("hotkeys", id, default_key))
		if default_key != KEY_ESCAPE and ((key >= KEY_A and key <= KEY_Z) or (key >= KEY_F1 and key <= KEY_F12)) and key != default_key:
			candidate[id] = key
	for id in candidate.keys():
		if not _hotkey_conflict(id, int(candidate[id]), candidate).is_empty():
			candidate.clear()
			break
	hotkey_overrides = candidate
	_sync_hotkey_bindings()

func _sync_hotkey_bindings() -> void:
	command_hotkeys.clear()
	for id in hotkey_entries:
		var entry: Dictionary = hotkey_entries[id]
		if not entry.has("button"):
			continue
		var button: Button = entry["button"]
		var key: int = _hotkey_value(id, hotkey_overrides)
		var hint: String = _hotkey_name(key)
		var old: String = str(button.get_meta("hotkey", ""))
		if not old.is_empty():
			_set_button_hint(button, _button_hint(button).replace("\n[" + old + "]", "").replace(" [" + old + "]", ""))
			if _button_hint(button) == "[" + old + "]":
				_set_button_hint(button, "")
		button.set_meta("hotkey", hint)
		_set_button_hint(button, _button_hint(button) + ("\n" if not _button_hint(button).is_empty() else "") + "[" + hint + "]")
		var badge: Label = entry["badge"]
		badge.text = hint
		var shortcuts: Array = command_hotkeys.get(key, [])
		shortcuts.append(button)
		command_hotkeys[key] = shortcuts

func _trigger_command_hotkey(key: int) -> bool:
	for candidate in command_hotkeys.get(key, []):
		var button: Button = candidate
		if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	return false

func _button_hint(button: Button) -> String:
	return str(button.get_meta("command_hint", "")) if button.has_meta("command_hint") else button.tooltip_text

func _set_button_hint(button: Button, hint: String) -> void:
	if button.has_meta("command_hint"):
		button.set_meta("command_hint", hint)
		button.tooltip_text = ""
	else:
		button.tooltip_text = hint

func _make_tooltip_mouse_transparent(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_tooltip_mouse_transparent(child)

func _enable_fast_command_tooltip(button: Button) -> void:
	if not button is CostButton:
		return
	if button.has_meta("command_hint"):
		return
	button.set_meta("command_hint", button.tooltip_text)
	button.tooltip_text = ""
	(button as CostButton).fast_tooltip = true
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = float(ProjectSettings.get_setting("gui/timers/tooltip_delay", 0.5)) * 0.5
	button.add_child(timer)
	var popup := PanelContainer.new()
	popup.top_level = true
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	popup.theme = HUD.compact()
	popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	button.add_child(popup)
	popup.hide()
	button.mouse_entered.connect(func() -> void: timer.start())
	button.mouse_exited.connect(func() -> void:
		timer.stop()
		popup.hide())
	button.visibility_changed.connect(func() -> void:
		timer.stop()
		popup.hide())
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			timer.stop()
			popup.hide())
	timer.timeout.connect(func() -> void:
		if not button.is_visible_in_tree() or not button.get_global_rect().has_point(button.get_global_mouse_position()) or str(button.get_meta("command_hint", "")).is_empty():
			return
		for child in popup.get_children():
			popup.remove_child(child)
			child.queue_free()
		var content: Control = (button as CostButton)._make_custom_tooltip(str(button.get_meta("command_hint", ""))) as Control
		if content == null:
			var label := Label.new()
			label.text = str(button.get_meta("command_hint", ""))
			var panel := PanelContainer.new()
			panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101b29"), Color("#6385a4"), 8, 3))
			panel.add_child(label)
			content = panel
		popup.add_child(content)
		_make_tooltip_mouse_transparent(content)
		popup.reset_size()
		var bounds: Vector2 = button.get_viewport_rect().size
		var extent: Vector2 = popup.get_combined_minimum_size()
		var cursor: Vector2 = button.get_global_mouse_position()
		popup.global_position = Vector2(clampf(cursor.x + 14.0, 0.0, maxf(0.0, bounds.x - extent.x)), clampf(cursor.y - extent.y - 12.0, 0.0, maxf(0.0, bounds.y - extent.y)))
		popup.show())

func _roman_level(level: int) -> String:
	if level <= 0:
		return "0"
	var result: String = ""
	for pair in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while level >= int(pair[0]):
			result += str(pair[1])
			level -= int(pair[0])
	return result

func _upgrade_level_badge(button: Button, level: int) -> void:
	var label: Label = button.get_meta("level_badge") as Label if button.has_meta("level_badge") else null
	if not is_instance_valid(label):
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("#e3f3ff"))
		label.add_theme_color_override("font_outline_color", Color("#101b29"))
		label.add_theme_constant_override("outline_size", 3)
		button.add_child(label)
		label.position = Vector2(3, 1)
		button.set_meta("level_badge", label)
	label.text = _roman_level(level)

func _yard_ability_face(button: Button, caption: String, picture: Texture2D) -> TextureRect:
	_enable_fast_command_tooltip(button)
	button.custom_minimum_size = Vector2(60, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.icon = null
	button.text = ""
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 2.0
	content.offset_right = -2.0
	content.offset_top = 2.0
	content.offset_bottom = -2.0
	var art := TextureRect.new()
	art.texture = picture
	art.custom_minimum_size = Vector2(0, 16)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	var name_label := Label.new()
	name_label.text = caption
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	button.set_meta("caption", name_label)
	return art

func _build_yard_command_card(parent: VBoxContainer) -> void:
	yard_command_scroll = VBoxContainer.new()
	yard_command_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(yard_command_scroll)
	yard_command_card = VBoxContainer.new()
	yard_command_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yard_command_scroll.add_child(yard_command_card)
	var grid: GridContainer = _ability_grid(yard_command_card)
	yard_command_grid = grid
	for kind in ECONOMY.SHIP_KINDS:
		var button := CostButton.new()
		var caption: String = {"ship": "Freighter", "colony_ship": "Colony", "fighter": "Fighter", "miner": "Harvester", "science_ship": "Science\nvessel", "scout": "Scout", "cruiser": "Cruiser", "destroyer": "Destroyer"}[kind]
		var art: TextureRect = _yard_ability_face(button, caption, _production_icon(kind, HUD.ACCENT))
		button.set_meta("portrait", art)
		button.pressed.connect(_build_at_yard.bind(kind))
		button.gui_input.connect(_yard_build_input.bind(kind, button))
		var border := Control.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(border)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.draw.connect(_draw_autobuild_border.bind(border))
		border.hide()
		button.set_meta("auto_border", border)
		grid.add_child(button)
		yard_commands[kind] = button
		_register_command_hotkey(button, {"ship": KEY_D, "colony_ship": KEY_C, "fighter": KEY_A, "miner": KEY_S, "science_ship": KEY_V, "scout": KEY_Q, "cruiser": KEY_E, "destroyer": KEY_F}[kind], "Shipyard", "yard_" + kind, _ship_kind_name(kind))
	# Rows 1–3: Small, Medium and Large. A locked class shows only
	# its next eligible upgrade; unlocked ships begin in column one.
	for target_level in [2, 3]:
		var upgrade: Button = _button("", _upgrade_selected_yards.bind(target_level), grid, true)
		var class_name_text: String = ECONOMY.size_name(target_level)
		_yard_ability_face(upgrade, "Upgrade\n" + class_name_text, _station_command_icon("upgrade"))
		yard_upgrades[target_level] = upgrade
		_register_command_hotkey(upgrade, KEY_U if target_level == 2 else KEY_I, "Shipyard", "yard_upgrade" if target_level == 2 else "yard_upgrade_large", "Upgrade to " + class_name_text)
	yard_top_slots.assign([yard_commands["miner"], yard_commands["fighter"], yard_commands["scout"], _station_spacer(grid)])
	for i in range(8):
		yard_row_spacers.append(_station_spacer(grid))
	var station_button := _button("", _select_yard_station, grid)
	_yard_ability_face(station_button, "Select Space\nStation", _station_command_icon("select_station"))
	_set_button_hint(station_button, "Select parent Space Station")
	_register_command_hotkey(station_button, KEY_Z, "Shipyard", "yard_station", "Select Space Station")
	var navigation_spacer: Control = _station_spacer(grid)
	var clear := _button("", func() -> void:
		pending_command = ""
		_refresh_command_mode()
		for ref in _selected_yards(_state(), true):
			session.call("request_shipyard_rally", ref.x, ref.y, -1, Vector2.ZERO), grid)
	_yard_ability_face(clear, "Clear\nRally", _station_command_icon("clear_rally"))
	_set_button_hint(clear, "Clear rally point")
	yard_commands["clear"] = clear
	_register_command_hotkey(clear, KEY_X, "Shipyard", "yard_clear", "Clear Rally")
	var rally_button := CostButton.new()
	_yard_ability_face(rally_button, "Rally", _station_command_icon("rally"))
	rally_button.toggle_mode = true
	_set_button_hint(rally_button, "Set Rally Point")
	rally_button.pressed.connect(_arm_command.bind("rally"))
	grid.add_child(rally_button)
	yard_commands["rally"] = rally_button
	_register_command_hotkey(rally_button, KEY_Y, "Shipyard", "yard_rally", "Rally")
	yard_bottom_slots.assign([station_button, navigation_spacer, clear, rally_button])
	_layout_yard_classes(1, true, false)
	yard_command_scroll.hide()

func _layout_yard_classes(level: int, show_medium_upgrade: bool, show_large_upgrade: bool) -> void:
	var key := Vector3i(level, int(show_medium_upgrade), int(show_large_upgrade))
	if key == yard_layout_key:
		return
	yard_layout_key = key
	var ordered: Array[Control] = []
	ordered.append_array(yard_top_slots)
	var spacer_index: int = 0
	for target_level in [2, 3]:
		var kinds: Array = ["ship", "colony_ship", "cruiser"] if target_level == 2 else ["science_ship", "destroyer"]
		var row: Array[Control] = []
		for kind in kinds:
			var button: Button = yard_commands[kind]
			button.visible = level >= target_level
			if button.visible:
				row.append(button)
		var upgrade: Button = yard_upgrades[target_level]
		upgrade.visible = show_medium_upgrade if target_level == 2 else show_large_upgrade
		if upgrade.visible:
			row.append(upgrade)
		while row.size() < 4:
			yard_row_spacers[spacer_index].show()
			row.append(yard_row_spacers[spacer_index])
			spacer_index += 1
		ordered.append_array(row)
	for i in range(spacer_index, yard_row_spacers.size()):
		yard_row_spacers[i].hide()
	ordered.append_array(yard_bottom_slots)
	for i in range(ordered.size()):
		if ordered[i].get_index() != i:
			yard_command_grid.move_child(ordered[i], i)

func _select_yard_station() -> void:
	# For grouped yards, select the primary yard's parent station.
	_select_building_ref(Vector2i(selected, 0), "station")

# Shared command-card art. Keep silhouettes legible at compact native UI sizes.
func _station_command_icon(kind: String, pixels: int = 64) -> Texture2D:
	var key: String = "%s:%d" % [kind, pixels]
	if station_icons.has(key):
		return station_icons[key]
	var paths: Dictionary = {
		"auto_retreat": '<path fill="#f6aa79" d="M3 16L15 4V11H28V21H15V28Z"/><path stroke="#ffe5cc" stroke-width="2" d="M18 7L28 7M18 25L28 25"/>',
		"auto_wander": '<path stroke="#8bd5ed" stroke-width="2.5" fill="none" d="M3 25Q9 4 17 17T29 4"/><circle cx="4" cy="25" r="3" fill="#e1f8ff"/><path fill="#b4e9f9" d="M16 9L24 18L19 28L16 24L11 28L11 17Z"/>',
		"collect": '<circle cx="16" cy="16" r="10" fill="none" stroke="#ab92ff" stroke-width="3"/><circle cx="16" cy="16" r="5" fill="#e4c9ff"/><path stroke="#e4c9ff" stroke-width="2" d="M16 1V6M16 26V31M1 16H6M26 16H31"/>',
		"auto_farm": '<path fill="#9ee6a1" d="M15 28V17Q3 18 3 5Q14 5 16 15Q18 3 29 3Q29 18 18 19V28Z"/><path stroke="#e5ffd6" stroke-width="1.8" d="M7 9L16 18L25 8"/>',
		"auto_mine": '<path fill="#9fb8c9" d="M3 17L9 10L18 12L23 21L18 29L7 27Z"/><path fill="#dce8f3" d="M9 10L18 12L12 19L3 17Z"/><path stroke="#ffbd77" stroke-width="3" d="M28 3L17 14M30 10L21 19"/><path fill="#f1c892" d="M25 2L30 2L30 7Z"/>',
		"auto_salvage": '<path fill="#9ccfc5" d="M4 4H8V14Q8 21 16 21Q24 21 24 14V4H28V15Q28 27 16 27Q4 27 4 15Z"/><path fill="#d3e4eb" d="M13 4L21 6L18 13L10 11Z"/><path fill="#ffcd81" d="M12 14L16 18L12 22L8 18Z"/>',
		"move": '<path fill="#9ed9f6" d="M3 12H18V5L30 16L18 27V20H3Z"/><path fill="#edfaff" d="M5 13H19V9L26 15H5Z"/>',
		"stop": '<rect x="6" y="4" width="8" height="24" rx="1" fill="#d3e1eb"/><rect x="18" y="4" width="8" height="24" rx="1" fill="#d3e1eb"/>',
		"transform": '<circle cx="16" cy="16" r="12" stroke="#a3d6e9" stroke-width="3" fill="none"/><rect x="12" y="12" width="8" height="8" fill="#a3d6e9"/><path d="M16 2V10M16 22V30M2 16H10M22 16H30" stroke="#a3d6e9" stroke-width="3"/>',
		"guard": '<path fill="#a3d6e9" d="M16 2L29 7V17Q27 26 16 30Q5 26 3 17V7Z"/><path fill="#243d52" d="M16 7L24 10V17Q22 23 16 26Q10 23 8 17V10Z"/><path stroke="#a7e9c5" stroke-width="3" fill="none" d="M10 16L14 20L23 11"/>',
		"hold": '<rect x="5" y="5" width="22" height="22" rx="2" fill="#c1d4e2"/><rect x="10" y="10" width="12" height="12" rx="1" fill="#334c60"/>',
		"patrol": '<path fill="#bc9df1" d="M3 12A13 13 0 0 1 24 6L28 2V14H16L20 10A7 7 0 0 0 9 13ZM29 20A13 13 0 0 1 8 26L4 30V18H16L12 22A7 7 0 0 0 23 19Z"/>',
		"attack": '<path stroke="#ff776f" stroke-width="2.6" fill="none" d="M16 2V9M16 23V30M2 16H9M23 16H30"/><circle cx="16" cy="16" r="10" fill="none" stroke="#ff9c8d" stroke-width="3"/><path d="M16 11L21 20L16 18L11 20Z" fill="#ffe1ca"/>',
		"load": '<path fill="#8aa8c1" d="M3 19H29V29H3Z"/><path fill="#304c65" d="M6 22H26V26H6Z"/><path fill="#a7e9c5" d="M12 2H20V11H26L16 21L6 11H12Z"/>',
		"unload": '<path fill="#8aa8c1" d="M3 21H29V29H3Z"/><path fill="#304c65" d="M6 23H26V27H6Z"/><path fill="#ffd186" d="M16 2L26 13H20V20H12V13H6Z"/>',
		"repair": '<path fill="#a7e9c5" d="M12 3H20V12H29V20H20V29H12V20H3V12H12Z"/><path fill="#e0ffee" d="M13 4H19V13H27V15H13Z"/>',
		"rally": '<path fill="#b4e9f9" d="M5 3H8V25H12V29H2V25H5Z"/><path fill="#ff9b83" d="M9 4L29 7L23 12L29 17L9 14Z"/><path fill="#ffded0" d="M10 5L26 8L23 10L10 8Z"/>',
		"clear_rally": '<path fill="#8096a8" d="M5 3H8V25H12V29H2V25H5ZM9 4L28 7L23 12L28 17L9 14Z"/><path stroke="#162535" stroke-width="6" d="M16 16L29 29M29 16L16 29"/><path stroke="#ff8279" stroke-width="3.6" d="M16 16L29 29M29 16L16 29"/>',
		"upgrade": '<path fill="#a5d9f5" d="M3 14L16 3L29 14V20L16 9L3 20ZM3 23L16 12L29 23V29L16 18L3 29Z"/><path fill="#effaff" d="M16 3L29 14V16L16 6L3 16V14Z"/>',
		"select_station": '<circle cx="16" cy="16" r="12" fill="none" stroke="#a3c6e0" stroke-width="5"/><path fill="#8baec9" d="M14 1H18V11H14ZM14 21H18V31H14ZM1 14H11V18H1ZM21 14H31V18H21Z"/><circle cx="16" cy="16" r="6" fill="#d7f3ff"/><circle cx="16" cy="16" r="3" fill="#3c7798"/>',
		"build": '<path fill="#bcd5e6" d="M2 26L15 13L12 10L19 3L29 13L22 20L19 17L6 30Z"/><path fill="#7c9ab0" d="M19 3L29 13L25 14L18 7Z"/><path fill="#ffca80" d="M3 4H10V7H3ZM3 9H6V14H3Z"/>',
		"trade": '<path fill="#a2dfd0" d="M2 8H19V2L30 12L19 21V15H2Z"/><path fill="#efc98c" d="M30 24H13V30L2 20L13 11V17H30Z"/>',
		"return": '<path fill="#bfd8ed" d="M2 12L13 2V9H20Q30 9 30 19V29H23V19Q23 16 20 16H13V23Z"/>',
		"warehouse": '<path fill="#9ab5cb" d="M2 12L16 3L30 12V29H2Z"/><path fill="#d4e8f4" d="M2 12L16 3L30 12V15L16 7L2 15Z"/><path fill="#243a4d" d="M7 16H25V29H7Z"/><path fill="#d6b184" d="M9 19H15V24H9ZM17 19H23V24H17ZM9 25H23V28H9Z"/>',
		"habitation": '<path fill="#b3cee0" d="M3 12H12V29H3ZM13 3H23V29H13ZM24 15H30V29H24Z"/><path fill="#36536a" d="M5 15H9V19H5ZM5 22H9V26H5ZM16 7H20V11H16ZM16 14H20V18H16ZM16 21H20V25H16ZM26 19H28V23H26Z"/><path fill="#9ce1ed" d="M16 7H20V11H16ZM5 22H9V26H5Z"/>',
		"orbital_housing": '<circle cx="16" cy="16" r="13" fill="#41667b" stroke="#b3d6e8" stroke-width="2"/><path fill="#a0d5b7" d="M5 23Q16 11 27 23L23 27H9Z"/><path fill="#d4eef0" d="M9 21V13L16 7L23 13V21H19V16H13V21Z"/><path stroke="#b3d6e8" stroke-width="1.7" d="M1 16H5M27 16H31"/>',
		"yard": '<path fill="#9ebacf" d="M3 3H10V29H3ZM22 3H29V29H22ZM10 3H22V7H10ZM10 25H22V29H10Z"/><path fill="#d4e9f5" d="M3 3H7V29H3ZM22 3H26V29H22Z"/><path fill="#5c8fae" d="M16 8L21 22L16 20L11 22Z"/><path fill="#ffd088" d="M5 10H9V13H5ZM23 10H27V13H23ZM5 20H9V23H5ZM23 20H27V23H23Z"/>',
		"reinforced_plating": '<path fill="#a9c4d7" d="M16 2L29 7V17Q27 26 16 30Q5 26 3 17V7Z"/><path fill="#405a72" d="M16 7L24 10V17Q22 23 16 26Q10 23 8 17V10Z"/><path fill="#dbeaf4" d="M16 10L22 12V17Q20 21 16 23Q12 21 10 17V12Z"/>',
		"laser_matrix": '<path fill="#829caf" d="M2 24L9 17L15 23L8 30ZM10 16L17 9L23 15L16 22Z"/><path stroke="#ff776f" stroke-width="4" d="M11 21L26 6M19 13L29 3"/><path stroke="#ffe9d8" stroke-width="1.3" d="M11 21L26 6M19 13L29 3"/>',
		"pds": '<circle cx="15" cy="18" r="11" fill="#5c90ad"/><path fill="#97c3d8" d="M5 17Q15 10 25 17L24 22Q15 16 6 22Z"/><path fill="#b3ccdf" d="M12 4H25L29 8V13H19L15 19L10 16L15 10H12Z"/><path stroke="#ff8c75" stroke-width="2.5" d="M25 7L30 2"/><path fill="#eaf6fc" d="M18 6H24V9H18Z"/>',
		"Metals": '<path fill="#9fb8c9" d="M2 17H30V29H2ZM5 6H10V18H5ZM13 2H18V18H13Z"/><path fill="#cbd9e3" d="M2 17L12 11V17L21 11V17L30 11V20H2Z"/><path fill="#344b60" d="M6 23H12V27H6ZM16 23H26V27H16Z"/><path fill="#ffd194" d="M5 6H10V9H5ZM13 2H18V5H13Z"/>',
		"Organics": '<path fill="#658b72" d="M2 24Q2 9 16 5Q30 9 30 24V29H2Z"/><path fill="#a6e0b5" d="M3 24Q3 11 16 5Q29 11 29 24H26Q26 14 16 9Q6 14 6 24Z"/><path fill="#b8e28e" d="M16 25Q5 22 9 15Q16 16 16 21Q18 13 24 13Q27 21 17 25Z"/><path stroke="#d0eaca" stroke-width="1.5" d="M16 29V20"/>',
		"Crystals": '<path fill="#849ab6" d="M3 13H29V28H3Z"/><path fill="#4a607a" d="M6 15H26V25H6Z"/><path fill="#bb9bf5" d="M16 2L24 11L20 23H12L8 11Z"/><path fill="#e7d6ff" d="M16 2L16 23L8 11Z"/><path fill="#c6deed" d="M3 26H29V29H3Z"/>'
	}
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g stroke-linecap="round" stroke-linejoin="round">' + str(paths.get(kind, paths["build"])) + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg, float(pixels) / 32.0)
	station_icons[key] = ImageTexture.create_from_image(image)
	return station_icons[key]

func _ability_grid(parent: Container) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(grid)
	return grid

func _station_spacer(grid: GridContainer) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slot)
	return slot

func _fill_ability_grid(grid: GridContainer) -> void:
	while grid.get_child_count() < 16:
		_station_spacer(grid)

func _station_button(grid: GridContainer, caption: String, key: String, action: Callable) -> Button:
	var button: Button = _button("", action, grid, true)
	var art: TextureRect = _yard_ability_face(button, caption, _station_command_icon(key))
	button.set_meta("portrait", art)
	return button

func _build_station_command_card(parent: Container) -> void:
	station_commands = VBoxContainer.new()
	station_commands.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station_commands.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(station_commands)
	station_primary_grid = _ability_grid(station_commands)
	station_select_yards_button = _station_button(station_primary_grid, "Select\nShipyards", "yard", _station_select_yards)
	_register_command_hotkey(station_select_yards_button, KEY_Z, "Station", "station_port_1", "Select Shipyards")
	for i in range(3):
		_station_spacer(station_primary_grid)
	station_upgrade_buttons["reinforced_plating"] = _station_button(station_primary_grid, "Reinforced\nPlating", "reinforced_plating", _station_upgrade_pressed.bind("reinforced_plating"))
	station_upgrade_buttons["laser_matrix"] = _station_button(station_primary_grid, "Laser\nMatrix", "laser_matrix", _station_upgrade_pressed.bind("laser_matrix"))
	_register_command_hotkey(station_upgrade_buttons["reinforced_plating"], KEY_V, "Station", "station_plating", "Reinforced Plating")
	_register_command_hotkey(station_upgrade_buttons["laser_matrix"], KEY_L, "Station", "station_matrix", "Laser Matrix")
	_station_spacer(station_primary_grid)
	_station_spacer(station_primary_grid)
	for i in range(4):
		_station_spacer(station_primary_grid)
	_register_command_hotkey(_station_button(station_primary_grid, "Build", "build", _station_card_to.bind("build")), KEY_B, "Station", "station_build", "Build")
	_register_command_hotkey(_station_button(station_primary_grid, "Trade", "trade", _station_card_to.bind("trade")), KEY_T, "Station", "station_trade", "Trade")
	_station_spacer(station_primary_grid)
	_station_spacer(station_primary_grid)
	station_build_grid = _ability_grid(station_commands)
	var captions: Dictionary = {"warehouse": "Warehouse", "housing": "Habitation", "pds": "PDS", "yard": "Build\nShipyard"}
	for resource in ECONOMY.RESOURCES:
		captions[resource] = str(ECONOMY.ECONOMY_BUILDINGS[resource]["name"]).replace(" ", "\n")
	for key in ECONOMY.RESOURCES + ["warehouse", "housing", "pds", "yard"]:
		var button: Button = _station_button(station_build_grid, captions[key], "habitation" if key == "housing" else key, _station_build.bind(key))
		station_build_buttons[key] = button
		_register_command_hotkey(button, {"Metals": KEY_R, "Organics": KEY_G, "Crystals": KEY_C, "warehouse": KEY_W, "housing": KEY_H, "pds": KEY_T, "yard": KEY_X}[key], "Station Build", "build_" + key, captions[key].replace("\n", " "))
		if key in ECONOMY.RESOURCES or key in ["warehouse", "housing"]:
			button.gui_input.connect(_station_repeat_input.bind(key, button))
			var border := Control.new()
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(border)
			border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			border.draw.connect(_draw_autobuild_border.bind(border))
			border.hide()
			button.set_meta("auto_border", border)
	# Keep the fixed four-row grid and Return position with fewer resource cards.
	for i in range(8 - ECONOMY.RESOURCES.size()):
		_station_spacer(station_build_grid)
	# Return stays at the bottom right.
	for i in range(3):
		_station_spacer(station_build_grid)
	_register_command_hotkey(_station_button(station_build_grid, "Return", "return", _station_card_to.bind("primary")), KEY_ESCAPE, "Station Build", "build_return", "Return")
	station_trade = VBoxContainer.new()
	station_trade.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station_commands.add_child(station_trade)
	_sync_station_card()
	station_commands.hide()

func _station_card_to(card: String) -> void:
	station_card = card
	_sync_station_card()

func _sync_station_card() -> void:
	station_primary_grid.visible = station_card == "primary"
	station_build_grid.visible = station_card == "build"
	station_trade.visible = station_card == "trade"
	_layout_right_panel()

func _station_build(key: String) -> void:
	var p: Dictionary = _planet()
	if p.is_empty() or int(p["owner"]) != _me() or station_selected_index != selected:
		return
	if key == "housing" and building_selection_kind != "station":
		key = "habitation" if ECONOMY.has_planets(p) else "orbital_housing"
	if key in ["yard", "pds"]:
		_operation(key)
	else:
		_operation("economy", key)

func _station_select_yards() -> void:
	var state: Dictionary = _state()
	var p: Dictionary = _planet()
	if p.is_empty() or int(p["owner"]) != _me() or station_selected_index != selected or p["yards"].is_empty():
		return
	var system: int = selected
	_clear_building_selection()
	_set_building_primary(state, Vector2i(system, 0), "shipyard")
	building_selection_kind = "shipyard"
	for slot in range(p["yards"].size()):
		selected_buildings[Vector2i(system, slot)] = p["yards"].size()
	follow_units = false
	pending_command = ""
	_load_thresholds()
	_refresh()

func _station_upgrade_pressed(kind: String) -> void:
	if station_selected_index == selected:
		_operation(kind)

func _refresh_station_primary(p: Dictionary, owned: bool) -> void:
	station_select_yards_button.disabled = not owned or p["yards"].is_empty()
	_set_button_hint(station_select_yards_button, "Select all %d completed shipyards at this station" % p["yards"].size())
	(station_select_yards_button.get_meta("portrait") as TextureRect).modulate = Color(0.55, 0.55, 0.55) if station_select_yards_button.disabled else Color.WHITE
	for kind in station_upgrade_buttons:
		var button: Button = station_upgrade_buttons[kind]
		var installed: bool = bool(p["station"].get(kind, false))
		_upgrade_level_badge(button, 1 if installed else 0)
		var pending: bool = ECONOMY._has_job(p, kind, "")
		button.disabled = not owned or not _any_selected_station_buildable(kind, p)
		var hint: String = "Reinforced Plating I · %.0f s (1×)\nMaximum hull: 3,000 HP" if kind == "reinforced_plating" else "Laser Matrix I · %.0f s (1×)\n+2 defensive lasers (4 total) · 18 damage each · 1 shot/s (1×) · range 180"
		_set_cost_tooltip(button, hint % ECONOMY._work(kind, 1), ECONOMY._cost(kind, 1) if not installed and not pending else {}, 0.0, _available_cost_resources(p))
		if installed or pending:
			_set_button_hint(button, _button_hint(button) + "\n" + ("Installed" if installed else "Building"))
		(button.get_meta("portrait") as TextureRect).modulate = Color(0.55, 0.55, 0.55) if button.disabled and not installed else Color.WHITE

func _station_repeat_key(p: Dictionary, key: String) -> String:
	if key in ECONOMY.RESOURCES:
		return "economy_building:" + key
	if key == "warehouse":
		return key
	return "habitation" if key == "housing" and ECONOMY.has_planets(p) else ""

func _station_repeat_input(event: InputEvent, key: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed or button.disabled:
		return
	var p: Dictionary = _planet()
	if p.is_empty() or int(p["owner"]) != _me() or station_selected_index != selected:
		return
	var repeat_key: String = _station_repeat_key(p, key)
	if not repeat_key.is_empty():
		session.call("request_continuous", selected, repeat_key, not bool(p.get("continuous", {}).get(repeat_key, false)))
	button.accept_event()

func _refresh_station_build(p: Dictionary, owned: bool) -> void:
	for key in station_build_buttons:
		var button: Button = station_build_buttons[key]
		var kind: String = key
		var recipe: Dictionary = {}
		var name_text: String = ""
		var description: String = ""
		var work: float = 30.0
		var eligible: bool = true
		var available: bool = false
		var current_level: int = 0
		if key in ECONOMY.RESOURCES:
			current_level = int(p.get("buildings", {}).get(key, 0))
			name_text = str(ECONOMY.ECONOMY_BUILDINGS[key]["name"])
			recipe = ECONOMY.building_cost(p, key)
			eligible = ECONOMY.production_available(p, key)
			available = ECONOMY.building_available(p, key)
			description = "%s installed · Requires %s population\n%s" % [int(p.get("buildings", {}).get(key, 0)), _compact_amount(float(ECONOMY.ECONOMY_BUILDINGS[key]["population"])), _economy_building_effect(p, key)]
		elif key == "warehouse":
			var level: int = int(p.get("warehouse_level", 0))
			current_level = level
			name_text = "Warehouse"
			eligible = level < 3
			available = ECONOMY.warehouse_available(p)
			work = ECONOMY._work("warehouse", level + 1)
			description = "Storage: %s per resource" % _tons(ECONOMY.storage_capacity(p), 0)
			if eligible:
				recipe = ECONOMY.WAREHOUSE_COSTS[level]
				description += " → %s\nRequires %s population" % [_tons(ECONOMY.WAREHOUSE_CAPACITIES[level + 1], 0), _compact_amount(ECONOMY.WAREHOUSE_POPULATIONS[level])]
		elif key == "housing":
			kind = "habitation" if ECONOMY.has_planets(p) else "orbital_housing"
			var caption: Label = button.get_meta("caption")
			caption.text = "Habitation" if kind == "habitation" else "Orbital\nhousing"
			(button.get_meta("portrait") as TextureRect).texture = _station_command_icon(kind)
			if kind == "habitation":
				var level: int = int(p.get("habitation_level", 0))
				work = ECONOMY._work(kind, level + 1)
				current_level = level
				name_text = "Habitation"
				eligible = level < 3
				available = ECONOMY.habitation_available(p)
				recipe = ECONOMY.habitation_cost(p) if eligible else {}
				description = "Habitation capacity: %s → %s" % [_compact_amount(ECONOMY.habitation_capacity(p)), _compact_amount(ECONOMY.habitation_capacity(p) * (2.0 if eligible else 1.0))]
			else:
				work = ECONOMY._work(kind, 1)
				current_level = int(p.get("orbital_housing", 0))
				name_text = "Orbital Eco-Housing"
				recipe = ECONOMY.ORBITAL_HOUSING_COST
				available = ECONOMY.orbital_housing_available(p)
				description = "%d installed · +5,000 crew capacity · +%.1f t/yr Organics" % [int(p.get("orbital_housing", 0)), ECONOMY.ECO_HOUSING_ORGANICS]
		elif key == "yard":
			var slot: int = ECONOMY.next_shipyard_slot(p)
			name_text = "Build Shipyard"
			eligible = slot > 0
			if eligible:
				recipe = ECONOMY._cost("yard", slot)
				work = ECONOMY._work("yard", slot)
			available = eligible
			description = "%d / %d completed or queued" % [ECONOMY.shipyard_count(p), ECONOMY.MAX_SHIPYARDS]
		elif key == "pds":
			name_text = "PDS"
			current_level = p.get("pds", {}).size()
			eligible = ECONOMY.next_pds(p) >= 0
			available = eligible and ECONOMY.pds_job(p).is_empty()
			recipe = ECONOMY._cost("pds", 1)
			work = ECONOMY._work("pds", 1)
			description = "%d / %d defended · %.0f HP · %.0f damage · Range %.0f" % [p.get("pds", {}).size(), int(p["planet_count"]), ECONOMY.PDS_HP, ECONOMY.PDS_DAMAGE, ECONOMY.PDS_RANGE]
		_upgrade_level_badge(button, current_level)
		if key != "yard":
			name_text += " " + _roman_level(current_level + (1 if eligible else 0))
		var repeat_key: String = _station_repeat_key(p, key)
		var auto: bool = not repeat_key.is_empty() and bool(p.get("continuous", {}).get(repeat_key, false))
		available = owned and available and ECONOMY.affordable(p, recipe)
		button.disabled = not owned or (not _any_selected_station_buildable(key, p) if building_selection_kind == "station" and selected_buildings.size() > 1 else (not eligible or (repeat_key.is_empty() and not available)))
		(button.get_meta("portrait") as TextureRect).modulate = Color.WHITE if available else Color(0.55, 0.55, 0.55)
		if button.has_meta("auto_border"):
			(button.get_meta("auto_border") as Control).visible = auto
		_set_cost_tooltip(button, name_text + (" · %.1f s (1×)" % work if not recipe.is_empty() else "") + "\n" + description, recipe, 0.0, _available_cost_resources(p))
		if not eligible:
			_set_button_hint(button, _button_hint(button) + "\nUnavailable")
		elif not available and ECONOMY.affordable(p, recipe):
			_set_button_hint(button, _button_hint(button) + "\nRequirements not met or already queued")
		if not repeat_key.is_empty() and eligible:
			_set_button_hint(button, _button_hint(button) + "\nRight-click: %s repeat" % ("Disable" if auto else "Enable"))

func _draw_autobuild_border(border: Control) -> void:
	var bounds := Rect2(Vector2.ONE * 2.0, border.size - Vector2.ONE * 4.0)
	var pulse: float = 0.55 + 0.25 * sin(visual_clock * 4.0)
	border.draw_rect(bounds, Color(HUD.ACCENT, pulse), false, 2.0)
	var w: float = bounds.size.x
	var h: float = bounds.size.y
	var perimeter: float = 2.0 * (w + h)
	if perimeter <= 0.0:
		return
	var path := PackedVector2Array()
	for i in range(25):
		var along: float = fposmod(visual_clock * 100.0 + float(i) * perimeter / 100.0, perimeter)
		var point: Vector2
		if along < w:
			point = Vector2(along, 0)
		elif along < w + h:
			point = Vector2(w, along - w)
		elif along < 2.0 * w + h:
			point = Vector2(2.0 * w + h - along, h)
		else:
			point = Vector2(0, perimeter - along)
		path.append(bounds.position + point)
	border.draw_polyline(path, Color(HUD.ACCENT.lightened(0.65), 0.95), 3.0, true)

func _yard_build_input(event: InputEvent, kind: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	var state: Dictionary = _state()
	var refs: Array[Vector2i] = _selected_yards(state, true)
	var eligible: Array[Vector2i] = []
	var enable: bool = false
	for ref in refs:
		var system: Dictionary = state["planets"][ref.x]
		if not ECONOMY.yard_fits(system, ref.y, kind) or (kind == "ship" and not bool(system["home"])):
			continue
		eligible.append(ref)
		enable = enable or not system["yards"][ref.y].get("autobuild", []).has(kind)
	for ref in eligible:
		session.call("request_operation", ref.x, "shipyard_autobuild", "%d:%s:%d" % [ref.y, kind, int(enable)])
	button.accept_event()

func _yard_build_available(system: Dictionary, slot: int, kind: String) -> bool:
	return ECONOMY.yard_fits(system, slot, kind) and ECONOMY.shipyard_operational(system, slot) and ECONOMY.shipyard_queue_count(system, slot) < ECONOMY.SHIPYARD_QUEUE_LIMIT and ECONOMY.affordable(system, ECONOMY.construction_cost(system, kind, 1)) and (kind != "ship" or bool(system["home"]))

func _build_at_yard(kind: String) -> void:
	var state: Dictionary = _state()
	for ref in _selected_yards(state, true):
		var system: Dictionary = state["planets"][ref.x]
		if _yard_build_available(system, ref.y, kind):
			session.call("request_operation", ref.x, "shipyard_build", "%d:%s" % [ref.y, kind])

func _upgrade_selected_yards(target_level: int) -> void:
	var state: Dictionary = _state()
	for ref in _selected_yards(state, true):
		var system: Dictionary = state["planets"][ref.x]
		if int(system["yards"][ref.y]["level"]) == target_level - 1 and _yard_can_upgrade(system, ref.y):
			session.call("request_operation", ref.x, "yard_upgrade", str(ref.y))

func _yard_can_upgrade(system: Dictionary, slot: int) -> bool:
	if not ECONOMY.shipyard_operational(system, slot) or int(system["yards"][slot]["level"]) >= ECONOMY.MAX_SHIPYARD_LEVEL or ECONOMY.shipyard_queue_count(system, slot) >= ECONOMY.SHIPYARD_QUEUE_LIMIT:
		return false
	for job in system["queue"]:
		if job["kind"] == "yard_upgrade" and int(job["target"]) == slot:
			return false
	return ECONOMY.affordable(system, ECONOMY._cost("yard_upgrade", int(system["yards"][slot]["level"]) + 1))

func _refresh_yard_overview(system: Dictionary, owned: bool) -> void:
	var yard: Dictionary = system["yards"][selected_yard]
	var level: int = int(yard["level"])
	var operating: bool = ECONOMY.shipyard_operational(system, selected_yard)
	yard_title.text = "%s Shipyard %d · Lv %d" % [ECONOMY.size_name(level), ECONOMY.shipyard_port(system, selected_yard), level]
	yard_context.text = _system_name(selected)
	var jobs: Array = []
	var waiting: Array = []
	var active_id: int = int(yard["job"])
	for job in system["queue"]:
		var upgrade: bool = job["kind"] == "yard_upgrade" and int(job["target"]) == selected_yard
		if int(job["id"]) == active_id:
			jobs.push_front(job)
		elif upgrade or int(job.get("yard_slot", -1)) == selected_yard:
			if ECONOMY.construction_blockers(system, job, selected_yard).is_empty():
				jobs.append(job)
			else:
				waiting.append(job)
	jobs.append_array(waiting)
	yard_status.text = "Offline" if not operating else ("Idle" if jobs.is_empty() else "Waiting for population" if active_id < 0 and waiting.size() == jobs.size() else "%d queued" % jobs.size())
	_refresh_queue_tiles(yard_queue, yard_queue_rows, system, jobs, owned, active_id)
	for kind in ECONOMY.SHIP_KINDS:
		var button: Button = yard_commands[kind]
		var recipe: Dictionary = ECONOMY.construction_cost(system, kind, 1)
		button.disabled = not owned or not ECONOMY.yard_fits(system, selected_yard, kind) or (kind == "ship" and not bool(system["home"]))
		var available: bool = owned and _yard_build_available(system, selected_yard, kind)
		var auto: bool = yard.get("autobuild", []).has(kind)
		(button.get_meta("auto_border") as Control).visible = auto
		var portrait: TextureRect = button.get_meta("portrait")
		portrait.texture = _production_icon(kind, _empire_color(int(system["owner"])))
		portrait.modulate = Color.WHITE if available else Color(0.55, 0.55, 0.55)
		_set_cost_tooltip(button, "%s · %.1f s (1×)\n%s" % [_ship_kind_name(kind), ECONOMY._work(kind, 1) / ECONOMY.yard_speed(level), _ship_stats(kind)], recipe, float(ECONOMY.CREW_COSTS[kind]), _available_cost_resources(system, selected_yard))
		if not ECONOMY.yard_fits(system, selected_yard, kind):
			_set_button_hint(button, _button_hint(button) + "\nRequires %s shipyard (Lv %d)" % [ECONOMY.size_name(ECONOMY.ship_size(kind)), ECONOMY.ship_size(kind)])
		if not operating:
			_set_button_hint(button, _button_hint(button) + "\nShipyard offline")
		if kind == "ship" and not bool(system["home"]):
			_set_button_hint(button, _button_hint(button) + "\nRequires home system")
		elif ECONOMY.shipyard_queue_count(system, selected_yard) >= ECONOMY.SHIPYARD_QUEUE_LIMIT:
			_set_button_hint(button, _button_hint(button) + "\nQueue full (8/8)")
		_set_button_hint(button, _button_hint(button) + "\nRight-click: %s autobuild" % ("Disable" if auto else "Enable"))
	var rally: Dictionary = yard.get("rally", {})
	var rally_button: Button = yard_commands["rally"]
	rally_button.disabled = not owned
	rally_button.set_pressed_no_signal(pending_command == "rally")
	yard_commands["clear"].disabled = not owned or rally.is_empty()
	for target_level in [2, 3]:
		var upgrade: Button = yard_upgrades[target_level]
		var eligible: bool = level == target_level - 1
		upgrade.disabled = not owned or not eligible or not _yard_can_upgrade(system, selected_yard)
		if level >= target_level:
			_set_cost_tooltip(upgrade, ECONOMY.size_name(target_level) + " unlocked")
		else:
			var hint: String = "Upgrade to %s · %.0f s (1×)\nBuild speed: %.1f× → %.1f×\nMaximum hull: %.0f → %.0f HP\nRestores shipyard to full health" % [ECONOMY.size_name(target_level), ECONOMY._work("yard_upgrade", target_level), ECONOMY.yard_speed(target_level - 1) / ECONOMY.yard_speed(1), ECONOMY.yard_speed(target_level) / ECONOMY.yard_speed(1), ECONOMY.YARD_HP * (target_level - 1), ECONOMY.YARD_HP * target_level]
			if not eligible:
				hint += "\nRequires " + ECONOMY.size_name(target_level - 1) + " shipyard"
			_set_cost_tooltip(upgrade, hint, ECONOMY._cost("yard_upgrade", target_level), 0.0, _available_cost_resources(system, selected_yard))


func _job_icon(job: Dictionary, owner: int) -> Texture2D:
	if ECONOMY.SHIP_KINDS.has(job["kind"]):
		return _production_icon(str(job["kind"]), _empire_color(owner), 44)
	if job["kind"] == "yard_upgrade":
		return _station_command_icon("upgrade", 44)
	return _station_command_icon(str(job["target"]) if job["kind"] in ["economy_building", "production"] else str(job["kind"]), 44)

func _refresh_station_queue(system: Dictionary, owned: bool) -> void:
	var jobs: Array = []
	for job in system["queue"]:
		if int(job["size"]) == 0 and job["kind"] != "yard_upgrade":
			jobs.append(job)
	station_queue_panel.show()
	station_queue_heading.text = "Queue (%d)" % jobs.size()
	var active_id: int = int(jobs[0]["id"]) if not jobs.is_empty() else -1
	_refresh_queue_tiles(station_queue, station_queue_rows, system, jobs, owned, active_id)

func _refresh_queue_tiles(queue: HFlowContainer, rows: Dictionary, system: Dictionary, jobs: Array, owned: bool, active_id: int) -> void:
	for id in rows.keys():
		var keep: bool = false
		for job in jobs:
			if int(job["id"]) == id:
				keep = true
				break
		if not keep:
			var row: Control = rows[id]["row"]
			queue.remove_child(row)
			row.queue_free()
			rows.erase(id)

	for idx in range(jobs.size()):
		var job: Dictionary = jobs[idx]
		var id: int = int(job["id"])
		if not rows.has(id):
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			var cancel := _button("", _cancel_job.bind(id), row)
			cancel.focus_mode = Control.FOCUS_NONE
			cancel.custom_minimum_size = Vector2(57, 57)
			cancel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cancel.expand_icon = true
			cancel.add_theme_constant_override("icon_max_width", 44)
			cancel.icon = _job_icon(job, int(system["owner"]))
			var bar := ProgressBar.new()
			bar.custom_minimum_size.y = 6
			bar.show_percentage = false
			bar.step = 0.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(bar)
			queue.add_child(row)
			rows[id] = {"row": row, "bar": bar, "cancel": cancel}
		var widgets: Dictionary = rows[id]
		queue.move_child(widgets["row"], idx)
		var percent: float = 100.0 * float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"]))
		widgets["bar"].value = percent
		widgets["bar"].visible = id == active_id or percent > 0.0
		_style_progress(widgets["bar"], system, job)
		var tile: Button = widgets["cancel"]
		tile.disabled = not owned
		var blocked: bool = bool(widgets["bar"].get_meta("blocked"))
		if id == active_id:
			tile.add_theme_stylebox_override("normal", HUD.surface(Color("#172c3b"), Color("#db9b54") if blocked else HUD.ACCENT, 3, 3))
		else:
			tile.remove_theme_stylebox_override("normal")
		tile.tooltip_text = "%s · %s (%.0f%%)%s%s" % [_job_name(job), ("Delivering" if job.has("delivery_slot") else ("Building" if id == active_id else "Queued")), percent, "\n" + widgets["bar"].tooltip_text if blocked else "", ("\nClick to cancel; materials become salvage" if ECONOMY.construction_leaves_salvage(job) else "\nClick to cancel and refund") if owned else ""]

func _build_body_overview(parent: Container) -> void:
	body_overview = VBoxContainer.new()
	body_overview.add_theme_constant_override("separation", 8)
	parent.add_child(body_overview)
	var header := HBoxContainer.new()
	body_overview.add_child(header)
	body_title = _label("", 19)
	body_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	body_title.clip_text = true
	body_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(body_title)
	body_context = _label("", 12)
	body_context.autowrap_mode = TextServer.AUTOWRAP_OFF
	body_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body_context.clip_text = true
	body_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_context.add_theme_color_override("font_color", HUD.MUTED)
	header.add_child(body_context)
	body_status = _label("", 12)
	body_overview.add_child(body_status)
	body_overview.hide()

func _refresh_body_overview(system: Dictionary) -> void:
	var owner: int = int(system["owner"])
	var roster: Dictionary = session.get("players")
	var owner_name: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
	body_title.text = _body_name(selected, selected_body)
	body_context.text = "%s\n%s" % [_system_name(selected), owner_name]
	var has_battery: bool = system.get("pds", {}).has(selected_body)
	var bodies: Array = _system_visual(selected, _state())["bodies"]
	var lines: PackedStringArray = []
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var sources: Array = _planet_production_sources(bodies, resource)
		if not sources.has(selected_body):
			continue
		var output: float = _planet_production_rate(system, resource) / float(sources.size())
		lines.append("%s · %.2f t/yr" % [resource, output])
	if lines.is_empty():
		lines.append("No resource production")
	if bool(system.get("planet_blockaded", false)):
		lines.append("Planetary production blockaded")
	if has_battery:
		lines.append("PDS · Operational")
	body_status.text = "\n".join(lines)
	body_status.visible = true

func _build_fleet_cargo_row() -> void:
	for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
		var pair := HBoxContainer.new()
		pair.tooltip_text = resource
		fleet_cargo.add_child(pair)
		var icon := TextureRect.new()
		var texture: Texture2D = HUD.resource_icon(resource, 16)
		if resource == ECONOMY.ANTIMATTER:
			var image := Image.new()
			image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"><path fill="#f279d7" d="M12 1L22 12L12 23L2 12Z"/><path fill="#4e2356" d="M12 5L17 12L12 19L7 12Z"/></svg>')
			texture = ImageTexture.create_from_image(image)
		HUD.fixed_icon(icon, texture, 16)
		pair.add_child(icon)
		var amount := _label("", 12)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		amount.add_theme_color_override("font_color", HUD.COLORS[resource])
		pair.add_child(amount)
		fleet_cargo_labels[resource] = amount

func _ship_visible(state: Dictionary, ship: Dictionary) -> bool:
	return ECONOMY.ship_visible_to_team(state, ship, int(state.get("teams", {}).get(_me(), -1)))

func _selected_ship(state: Dictionary) -> Dictionary:
	if selected_ship_id < 0:
		return {}
	for ship in state.get("ships", []):
		if int(ship["id"]) == selected_ship_id and _ship_visible(state, ship):
			return ship
	return {}

func _ship_kind_name(kind: String) -> String:
	if kind == "warp_gate":
		return "Warp Gate"
	if kind == "science_ship":
		return "Science vessel"
	return {"ship": "Freighter", "miner": "Harvester", "colony_ship": "Colony"}.get(kind, kind.replace("_", " ").capitalize())

func _remaining_years(state: Dictionary, ship: Dictionary) -> float:
	var points: Array = ECONOMY.military_graph(state)["points"] if ship.get("kind", "") in ["fighter", "scout", "cruiser", "destroyer"] else state["map"]["points"]
	var pos: Vector2 = ECONOMY.combat_position(state, ECONOMY.military_graph(state), ship)
	var mode: String = ship.get("mining_mode", "idle")
	if mode == "outbound":
		return pos.distance_to(ship["mining_target"]) / ECONOMY.ship_speed(str(ship.get("kind", "ship")))
	if mode == "return":
		return pos.distance_to(points[int(ship["at"])]) / ECONOMY.ship_speed(str(ship.get("kind", "ship")))
	var remaining: float = 0.0
	for index in ship["route"]:
		var next: Vector2 = points[int(index)]
		remaining += pos.distance_to(next)
		pos = next
	return remaining / ECONOMY.ship_speed(str(ship.get("kind", "ship")))

func _build_field_command_card(parent: Container) -> void:
	field_command_grid = _ability_grid(parent)
	# Keep the bottom row for persistent modes, as on ship cards.
	while field_command_grid.get_child_count() < 12:
		_station_spacer(field_command_grid)
	for key in ["enabled", "Metals", "Crystals"]:
		var slot: Control = _station_spacer(field_command_grid)
		var button := Button.new()
		slot.add_child(button)
		var caption: String = "Mining" if key == "enabled" else key
		var art: Texture2D = _station_command_icon("auto_mine") if key == "enabled" else HUD.resource_icon(key, 32)
		_yard_ability_face(button, caption, art)
		button.custom_minimum_size = Vector2.ZERO
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.toggle_mode = true
		button.pressed.connect(_toggle_field_command.bind(key))
		button.gui_input.connect(_field_toggle_input.bind(key, button))
		var border := Control.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(border)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.draw.connect(_draw_field_enabled_border.bind(border))
		border.hide()
		button.set_meta("mode_border", border)
		field_commands[key] = button
		_register_command_hotkey(button, {"enabled": KEY_G, "Metals": KEY_M, "Crystals": KEY_C}[key], "Asteroid Field", "field_" + key, caption)
	_fill_ability_grid(field_command_grid)
	field_command_grid.hide()

func _draw_field_enabled_border(border: Control) -> void:
	if border.size.x > 4.0 and border.size.y > 4.0:
		border.draw_rect(Rect2(Vector2.ONE * 2.0, border.size - Vector2.ONE * 4.0), Color(HUD.ACCENT, 0.85), false, 2.0)

func _field_toggle_input(event: InputEvent, key: String, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not button.disabled:
		_toggle_field_command(key)
		button.accept_event()

func _toggle_field_command(key: String) -> void:
	var state: Dictionary = _state()
	if str(session.get("phase")) != "match" or state.is_empty() or selected_field < 0 or not ECONOMY.discovered(state, _me(), "fields", selected_field):
		return
	var policy: Dictionary = ECONOMY.mining_policy(state, _me(), selected_field).duplicate()
	var special: bool = bool(state["map"]["fields"][selected_field].get("antimatter", false))
	if key != "enabled" and (special or not bool(policy["enabled"])):
		return
	policy[key] = not bool(policy[key])
	session.call("request_mining_policy", selected_field, bool(policy["enabled"]), bool(policy["Metals"]), bool(policy["Crystals"]))

func _refresh_field_commands(state: Dictionary, special: bool) -> void:
	var policy: Dictionary = ECONOMY.mining_policy(state, _me(), selected_field)
	for key in field_commands:
		var button: Button = field_commands[key]
		var enabled: bool = bool(policy[key])
		button.visible = key == "enabled" or not special
		button.disabled = str(session.get("phase")) != "match" or (key != "enabled" and not bool(policy["enabled"]))
		button.set_pressed_no_signal(enabled)
		var border: Control = button.get_meta("mode_border")
		border.visible = enabled and not button.disabled
		border.queue_redraw()
		var caption: String = "Mining" if key == "enabled" else key
		var hint: String = str(button.get_meta("hotkey", ""))
		_set_button_hint(button, "%s · %s\nClick to toggle [%s]" % [caption, "On" if enabled else "Off", hint])

func _command_icon(path: String, pixels: int = 32) -> Texture2D:
	var image := Image.new()
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#c5e5f5" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">' + path + '</g></svg>'
	image.load_svg_from_string(svg, float(pixels) / 32.0)
	return ImageTexture.create_from_image(image)

func _command_slot(id: String, hint: String, action: Callable) -> Button:
	var button := CostButton.new()
	_enable_fast_command_tooltip(button)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _station_command_icon({"auto_repair": "repair", "auto_trade": "trade", "deliver_farm": "unload"}.get(id, id))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_button_hint(button, hint)
	button.toggle_mode = true
	button.pressed.connect(action)
	var slot: Control = _station_spacer(command_card)
	slot.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	command_buttons[id] = button
	var active_border := Control.new()
	active_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(active_border)
	active_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_border.draw.connect(_draw_active_command.bind(active_border))
	active_border.visible = false
	button.set_meta("active_border", active_border)
	_register_command_hotkey(button, {"move": KEY_M, "stop": KEY_S, "hold": KEY_H, "patrol": KEY_P, "attack": KEY_A, "load": KEY_L, "unload": KEY_D, "repair": KEY_R, "auto_wander": KEY_W, "auto_mine": KEY_G, "auto_salvage": KEY_V, "auto_repair": KEY_B, "auto_trade": KEY_T, "auto_farm": KEY_N, "deliver_farm": KEY_E, "collect": KEY_C, "guard": KEY_U, "transform": KEY_J, "auto_retreat": KEY_K}[id], "Fleet", "fleet_" + id, hint)
	return button

func _build_command_card(parent: VBoxContainer) -> void:
	command_card = _ability_grid(parent)
	_command_slot("move", "Move", _arm_command.bind("move"))
	_command_slot("stop", "Stop", _stop_selected)
	hold_button = _command_slot("hold", "Hold Position", _hold_selected)
	_command_slot("patrol", "Patrol", _arm_command.bind("patrol"))
	_command_slot("attack", "Attack Move", _arm_command.bind("attack"))
	_command_slot("load", "Load Cargo", _arm_command.bind("load"))
	unload_button = _command_slot("unload", "Drop Cargo", _arm_command.bind("unload"))
	_command_slot("repair", "Repair target", _arm_command.bind("repair"))
	_command_slot("deliver_farm", "Deliver Organics to nearest station", _deliver_farm_selected)
	for id in ["collect", "auto_farm", "auto_trade", "auto_wander", "auto_mine", "auto_salvage", "auto_repair", "auto_retreat"]:
		if id == "auto_retreat":
			_fill_ability_grid(command_card)
			_command_slot("guard", "Guard sector · return to the chosen point after combat", _arm_command.bind("guard"))
			_command_slot("transform", "Transform into Space Station", _transform_selected)
		var mode: String = AUTOCAST_SLOTS[id]
		var title_text: String = "Collect Antimatter" if mode == "collect" else ("Wander" if mode == "wander" else "Auto-" + mode.capitalize())
		var action: Callable = _arm_command.bind("collect") if mode == "collect" else _toggle_autocast.bind(mode)
		var button: Button = _command_slot(id, title_text, action)
		button.gui_input.connect(_autocast_input.bind(mode, button))
		var mask := Control.new()
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mask)
		mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mask.draw.connect(_draw_autocast_cooldown.bind(mask))
		button.set_meta("cooldown_mask", mask)
		var border := Control.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(border)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.draw.connect(_draw_autobuild_border.bind(border))
		button.set_meta("auto_border", border)

func _autocast_units(state: Dictionary, mode: String) -> Array:
	var units: Array = []
	for ship in state.get("ships", []):
		if _command_member(ship) and ECONOMY.supports_autocast(ship, mode):
			units.append(ship)
	return units

func _toggle_autocast(mode: String) -> void:
	var units: Array = _autocast_units(_state(), mode)
	if units.is_empty():
		return
	var all_on: bool = units.all(func(ship: Dictionary) -> bool: return ECONOMY.autocast_enabled(ship, mode))
	var ids: Array = units.map(func(ship: Dictionary) -> int: return int(ship["id"]))
	session.call("request_autocast", ids, mode, not all_on)

func _autocast_input(event: InputEvent, mode: String, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not button.disabled:
		_toggle_autocast(mode)
		button.accept_event()

func _draw_autocast_cooldown(mask: Control) -> void:
	var fraction: float = clampf(float(mask.get_meta("fraction", 0.0)), 0.0, 1.0)
	if fraction <= 0.0 or mask.size.x <= 0.0 or mask.size.y <= 0.0:
		return
	var center: Vector2 = mask.size * 0.5
	# Clockwise wipe from twelve o'clock; clip radial rays to the square.
	var polygon := PackedVector2Array([center])
	var segments: int = maxi(2, ceili(fraction * 96.0))
	for i in range(segments + 1):
		var angle: float = -PI * 0.5 + TAU * (1.0 - fraction + fraction * float(i) / float(segments))
		var ray := Vector2.from_angle(angle)
		var distance: float = minf(center.x / maxf(absf(ray.x), 0.00001), center.y / maxf(absf(ray.y), 0.00001))
		polygon.append(center + ray * distance)
	if fraction >= 0.9999:
		mask.draw_rect(Rect2(Vector2.ZERO, mask.size), Color(0.0, 0.0, 0.0, 0.65))
	else:
		mask.draw_colored_polygon(polygon, Color(0.0, 0.0, 0.0, 0.65))

func _refresh_autocast_cards() -> void:
	var state: Dictionary = _state()
	# Repair and Trade are exclusive on individual hulls. Keep Trade in
	# the bottom-right slot unless a mixed fleet needs both modes.
	if command_buttons.has("auto_trade") and command_buttons.has("auto_repair"):
		var trade: Button = command_buttons["auto_trade"]
		var desired_slot: Control = command_card.get_child(11 if not _autocast_units(state, "repair").is_empty() else 15)
		if trade.get_parent() != desired_slot:
			trade.reparent(desired_slot, false)
			trade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if command_buttons.has("auto_farm"):
		var farm: Button = command_buttons["auto_farm"]
		var farm_slot: Control = command_card.get_child(10 if not _autocast_units(state, "salvage").is_empty() else 14)
		if farm.get_parent() != farm_slot:
			farm.reparent(farm_slot, false)
			farm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if command_buttons.has("collect"):
		var collect_button: Button = command_buttons["collect"]
		var has_fighters: bool = state.get("ships", []).any(func(craft: Dictionary) -> bool: return _command_member(craft) and craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"])
		var has_harvesters: bool = not _autocast_units(state, "mine").is_empty()
		var extra: Control = command_card.get_child(16)
		var collect_slot: Control = command_card.get_child((16 if has_fighters else 9) if has_harvesters else 13)
		var guard_button: Button = command_buttons["guard"]
		var guard_slot: Control = command_card.get_child(9)
		if guard_button.get_parent() != guard_slot:
			guard_button.reparent(guard_slot, false)
			guard_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		guard_button.visible = has_fighters
		guard_button.disabled = not has_fighters
		extra.visible = has_fighters and has_harvesters and not _autocast_units(state, "collect").is_empty()
		if collect_button.get_parent() != collect_slot:
			collect_button.reparent(collect_slot, false)
			collect_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if command_buttons.has("auto_retreat"):
		var retreat: Button = command_buttons["auto_retreat"]
		var retreat_extra: Control = command_card.get_child(18)
		var retreat_slot: Control = command_card.get_child(13) if _autocast_units(state, "collect").is_empty() and _autocast_units(state, "mine").is_empty() else retreat_extra
		if retreat.get_parent() != retreat_slot:
			retreat.reparent(retreat_slot, false)
			retreat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		retreat_extra.visible = retreat_slot == retreat_extra and not _autocast_units(state, "retreat").is_empty()
	for id in AUTOCAST_SLOTS:
		if not command_buttons.has(id):
			continue
		var button: Button = command_buttons[id]
		var mode: String = AUTOCAST_SLOTS[id]
		var units: Array = _autocast_units(state, mode)
		var enabled_count: int = 0
		var remaining: float = 0.0
		for ship in units:
			if ECONOMY.autocast_enabled(ship, mode):
				enabled_count += 1
				remaining = maxf(remaining, ECONOMY.autocast_remaining(state, ship, mode))
		button.visible = not units.is_empty()
		button.disabled = units.is_empty()
		button.set_pressed_no_signal(enabled_count > 0 or (mode == "collect" and pending_command == "collect"))
		var border: Control = button.get_meta("auto_border")
		border.visible = enabled_count > 0
		border.queue_redraw()
		var mask: Control = button.get_meta("cooldown_mask")
		var duration: float = ECONOMY.autocast_duration(mode)
		mask.set_meta("fraction", remaining / duration if duration > 0.0 else 0.0)
		mask.queue_redraw()
		var title_text: String = "Collect Antimatter" if mode == "collect" else ("Wander" if mode == "wander" else "Auto-" + mode.capitalize())
		var status: String = "Off" if enabled_count == 0 else ("On" if enabled_count == units.size() else "%d/%d on" % [enabled_count, units.size()])
		var speed: float = maxf(1.0, float(state.get("time_speed", 1)))
		if remaining > ECONOMY.EPS:
			status += " · %.1f s remaining%s" % [remaining / speed, " (paused)" if int(state.get("time_speed", 1)) == 0 else ""]
		var shortcut: String = str(button.get_meta("hotkey", ""))
		_set_button_hint(button, "%s · %s\nLeft or right click to toggle [%s]" % [title_text, status, shortcut])
		_set_button_hint(button, _button_hint(button) + "\nCooldown: %.1f s at 1×" % duration)
		if mode == "wander":
			_set_button_hint(button, _button_hint(button) + "\nEnabling bypasses Wander cooldown; active orders and Hold still take priority.")
		elif mode == "collect":
			_set_button_hint(button, "%s · Auto: %s\nLeft click [%s], then choose a Pulsar. Right click toggles autocast.\nCollects 1 unit in %.0f s at 1×; auto cooldown %.0f s." % [title_text, status, shortcut, ECONOMY.SCIENCE_COLLECTION_YEARS, duration])
		elif mode == "retreat":
			_set_button_hint(button, _button_hint(button) + "\nWithdraw to safety at %.0f%% hull; resume orders after full repair." % (100.0 * ECONOMY.WITHDRAW_HP / ECONOMY.SHIP_HP))
		elif mode == "farm":
			_set_button_hint(button, _button_hint(button) + "\nProduces %.0f t/s at 1×; delivers a full hold when idle." % ECONOMY.COLONY_FARM_RATE)

func _arm_command(mode: String) -> void:
	pending_command = mode if pending_command != mode else ""
	_refresh_command_mode()

func _draw_active_command(border: Control) -> void:
	border.draw_rect(Rect2(Vector2.ONE * 2.0, border.size - Vector2.ONE * 4.0), Color("#7de4ff"), false, 2.0)

func _active_command(ship: Dictionary) -> String:
	if bool(ship.get("retreating", false)):
		return ""
	if bool(ship.get("holding", false)):
		return "hold"
	if not ECONOMY._unit_order_running(ship):
		return ""
	var order: Dictionary = ship.get("unit_order", {})
	match str(order.get("kind", "")):
		"guard": return "guard"
		"follow": return "guard" if bool(order.get("guard", false)) else "move"
		"position", "sector", "sector_entry": return "move" if bool(order.get("move_only", false)) else "attack"
		"attack": return "attack"
		"patrol": return "patrol"
		"repair": return "repair"
		"deposit", "drop", "unload": return "unload"
		"salvage": return "load"
		"collect": return "collect"
		"mine": return "auto_mine"
	return ""

func _refresh_command_mode() -> void:
	if not is_instance_valid(command_card):
		return
	var active: Dictionary = {}
	for ship in _state().get("ships", []):
		if _command_member(ship):
			var command: String = _active_command(ship)
			if not command.is_empty():
				active[command] = true
	for id in command_buttons:
		var button: Button = command_buttons[id]
		button.set_pressed_no_signal(id == pending_command or active.has(id))
		var border: Control = button.get_meta("active_border")
		border.visible = active.has(id)
		border.queue_redraw()
	_refresh_autocast_cards()
	if is_instance_valid(yard_command_card):
		yard_commands["rally"].set_pressed_no_signal(pending_command == "rally")
	map_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS if not pending_command.is_empty() else Control.CURSOR_ARROW

func _stop_selected() -> void:
	pending_command = ""
	var owned: Array[int] = _selected_owned_units(_state())
	if not owned.is_empty():
		_issue_order(owned, {"kind": "stop"}, Input.is_key_pressed(KEY_SHIFT))
	_refresh_command_mode()

func _issue_order(ids: Array, order: Dictionary, append: bool = false) -> void:
	if not ids.is_empty():
		sound_mixer.play_cue("order")
		session.call("request_unit_orders", [{"ids": ids, "order": order}], append)

func _execute_pending_command(point: Vector2, append: bool = false, minimap_hint: Dictionary = {}) -> void:
	var mode: String = pending_command
	pending_command = ""
	_refresh_command_mode()
	if mode == "rally":
		_set_rally_at(point)
	elif mode == "load":
		var state: Dictionary = _state()
		var wreck: int = _salvage_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["wreck"])
		if wreck >= 0:
			var eligible: Array[int] = []
			for craft in state["ships"]:
				if _command_member(craft) and ECONOMY.supports_autocast(craft, "salvage") and ECONOMY.cargo_free(craft) > ECONOMY.EPS:
					eligible.append(int(craft["id"]))
			_issue_order(eligible, {"kind": "salvage", "target": wreck}, append)
	elif mode == "guard":
		var state: Dictionary = _state()
		var graph: Dictionary = ECONOMY.military_graph(state)
		var world: Vector2 = minimap_hint.get("world", _world_point(point))
		var node: int = ECONOMY.patrol_node(state, graph, _me(), world)
		var ids: Array[int] = []
		for craft in state["ships"]:
			if _command_member(craft) and craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
				ids.append(int(craft["id"]))
		if node >= 0:
			_issue_order(ids, {"kind": "guard", "target": node, "point": world}, append)
	elif mode == "collect":
		var state: Dictionary = _state()
		var graph: Dictionary = ECONOMY.military_graph(state)
		var field: int = int(minimap_hint.get("field", -1))
		if minimap_hint.is_empty():
			var node: int = ECONOMY.sector_at(graph, _world_point(point), ECONOMY.military_pois(state, _me()))
			if node >= state["planets"].size():
				field = node - state["planets"].size()
		var eligible: Array[int] = []
		for craft in _autocast_units(state, "collect"):
			if ECONOMY._science_target_valid(state, graph, craft, field):
				eligible.append(int(craft["id"]))
		_issue_order(eligible, {"kind": "collect", "target": field}, append)
	elif mode == "repair":
		var target: int = _entity_hit(_state(), point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		if target != -1:
			var miners: Array[int] = _selected_miners()
			miners.erase(target)
			_issue_order(miners, {"kind": "repair", "target": target}, append)
	elif mode == "unload":
		var state: Dictionary = _state()
		var target: int = _entity_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		var ref: Dictionary = ECONOMY.service_targets(state).get(target, {})
		var owned: Array[int] = _selected_owned_units(state)
		var orders: Array = []
		for ship in state["ships"]:
			if not owned.has(int(ship["id"])) or ECONOMY._cargo_total(ship) <= ECONOMY.EPS:
				continue
			if ECONOMY._friendly_target(state, _me(), ref):
				if ECONOMY.can_deposit(state, ship, target):
					orders.append({"ids": [ship["id"]], "order": {"kind": "deposit", "target": target}})
			else:
				orders.append({"ids": [ship["id"]], "order": {"kind": "drop", "point": minimap_hint.get("world", _world_point(point))}})
		if not orders.is_empty():
			sound_mixer.play_cue("order")
			session.call("request_unit_orders", orders, append)
	if append and mode != "rally":
		pending_command = mode
		_refresh_command_mode()

func _set_rally_at(point: Vector2) -> void:
	var state: Dictionary = _state()
	var yards: Array[Vector2i] = _selected_yards(state, true)
	if yards.is_empty():
		return
	var graph: Dictionary = ECONOMY.military_graph(state)
	var candidates: Array[int] = []
	for index in range(state["planets"].size()):
		if ECONOMY.discovered(state, _me(), "planets", index):
			candidates.append(index)
	var world: Vector2 = _world_point(point)
	var node: int = ECONOMY.sector_at(graph, world, candidates, selected)
	if node >= 0:
		for ref in yards:
			session.call("request_shipyard_rally", ref.x, ref.y, node, world)

func _build_selection_portrait(parent: Container) -> void:
	selection_portrait = VBoxContainer.new()
	selection_portrait.custom_minimum_size.x = 90.0
	selection_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selection_portrait.add_theme_constant_override("separation", 1)
	parent.add_child(selection_portrait)
	selection_portrait_art = TextureRect.new()
	selection_portrait_art.custom_minimum_size.y = 90.0
	selection_portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selection_portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selection_portrait_art.mouse_filter = Control.MOUSE_FILTER_STOP
	selection_portrait_art.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			_focus_selection()
			selection_portrait_art.accept_event())
	selection_portrait.add_child(selection_portrait_art)
	selection_portrait_health = _label("", 12)
	selection_portrait_health.autowrap_mode = TextServer.AUTOWRAP_OFF
	selection_portrait_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_portrait.add_child(selection_portrait_health)
	selection_portrait_shield = _label("", 11)
	selection_portrait_shield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_portrait_shield.add_theme_color_override("font_color", Color("#80caff"))
	selection_portrait.add_child(selection_portrait_shield)
	selection_portrait_shield.hide()
	selection_portrait.hide()

func _queue_health_rect(rect: Rect2, tint: Color) -> void:
	if rect.size.x <= 0.0 or not rect.intersects(Rect2(Vector2.ZERO, map_canvas.size), true):
		return
	health_entries.append([Transform2D(0.0, rect.size, 0.0, rect.get_center()), tint])

func _draw_damage_bar(point: Vector2, radius: float, fraction: float, shield: float = -1.0) -> void:
	var show_health: bool = fraction < 1.0
	var show_shield: bool = shield >= 0.0 and shield < 1.0
	if not show_health and not show_shield:
		return
	var width: float = clampf(radius * 2.0, 18.0, 100.0)
	var base: Vector2 = point + Vector2(-width * 0.5, -maxf(8.0, radius) - 6.0)
	if show_health:
		_queue_health_rect(Rect2(base - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#0a111b"))
		_queue_health_rect(Rect2(base, Vector2(width, 3.0)), Color("#283748"))
		_queue_health_rect(Rect2(base, Vector2(width * clampf(fraction, 0.0, 1.0), 3.0)), _health_color(fraction))
	if show_shield:
		var shield_base: Vector2 = base + Vector2(0, 4) if show_health else base
		_queue_health_rect(Rect2(shield_base - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#0a111b"))
		_queue_health_rect(Rect2(shield_base, Vector2(width, 3.0)), Color("#203f5c"))
		_queue_health_rect(Rect2(shield_base, Vector2(width * clampf(shield, 0.0, 1.0), 3.0)), Color("#6fbaff"))

func _shield_fraction(entity: Dictionary) -> float:
	var maximum: float = float(entity.get("shield_max", 0.0))
	return float(entity.get("shield", 0.0)) / maximum if maximum > 0.0 else -1.0

func _health_color(fraction: float) -> Color:
	return Color("#e45b60") if fraction < 0.2 else (Color("#eac64a") if fraction < 0.5 else Color("#55c88b"))

func _selection_portrait_icon(kind: String) -> Texture2D:
	if not selection_portrait_icons.has(kind):
		# White wireframe art is tinted at runtime by current health, without
		# recreating textures as combat snapshots arrive.
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><g fill="none" stroke="#ffffff" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round">'
		if kind == "station":
			art += '<circle cx="32" cy="32" r="25"/><circle cx="32" cy="32" r="19"/><circle cx="32" cy="32" r="9"/>'
			for slot in range(3):
				art += '<g transform="rotate(%d 32 32)"><path d="M28 23V13H36V23M27 7V3H37V7"/></g>' % (120 * slot)
			for segment in range(12):
				art += '<path transform="rotate(%d 32 32)" d="M32 7V13" stroke-width="0.7"/>' % (30 * segment)
		elif kind == "warp_gate":
			art += '<circle cx="32" cy="32" r="27"/><circle cx="32" cy="32" r="20"/><circle cx="32" cy="32" r="14"/><path d="M32 5V12M32 52V59M5 32H12M52 32H59M13 13L18 18M46 46L51 51M13 51L18 46M46 18L51 13"/>'
		elif kind == "shipyard":
			# Open berth, paired gantries and cross braces match the map art.
			art += '<path d="M12 5L7 10V54L12 59H22L25 51V13L22 5ZM52 5L57 10V54L52 59H42L39 51V13L42 5ZM22 8H42M22 56H42M22 13H42M22 51H42"/>'
			for y in [19, 32, 45]:
				art += '<rect x="10" y="%d" width="11" height="7"/><rect x="43" y="%d" width="11" height="7"/>' % [y - 3, y - 3]
		elif kind in ["planet", "pds"]:
			art += '<circle cx="32" cy="32" r="25"/><ellipse cx="32" cy="32" rx="11" ry="25" stroke-width="0.8"/><path d="M12 17Q32 26 52 17M7 32H57M12 47Q32 38 52 47" stroke-width="0.8"/>'
			if kind == "pds":
				art += '<circle cx="32" cy="32" r="28"/><path d="M32 1V7M32 57V63M1 32H7M57 32H63"/>'
		else:
			art += '<polygon points="%s"/>' % _portrait_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE), _portrait_scale(kind))
			for panel in HULL_PANELS.get(kind, []):
				art += '<polygon points="%s" stroke-width="0.55" opacity="0.68"/>' % _portrait_points(panel[1], _portrait_scale(kind))
			if kind == "ship":
				for bay in range(ECONOMY.FREIGHTER_BAY_COUNT):
					art += '<polygon points="%s" stroke-width="0.7"/>' % _portrait_points(_freighter_bay_vertices(bay), 0.6)
		var image := Image.new()
		image.load_svg_from_string(art + '</g></svg>')
		selection_portrait_icons[kind] = ImageTexture.create_from_image(image)
	return selection_portrait_icons[kind]

func _refresh_selection_portrait(ship: Dictionary, system: Dictionary, body_selected: bool, yard_selected: bool, grouped: bool) -> void:
	var kind: String = ""
	var hp: float = 0.0
	var maximum: float = 0.0
	if not ship.is_empty() and selected_units.size() <= 1:
		kind = str(ship["kind"])
		maximum = ECONOMY.ship_max_hp(str(ship["kind"]))
		hp = float(ship.get("hp", maximum))
	elif not grouped and not system.is_empty():
		if yard_selected:
			var yard: Dictionary = system["yards"][selected_yard]
			kind = "shipyard"
			maximum = ECONOMY.YARD_HP * int(yard["level"])
			hp = float(yard.get("hp", maximum))
		elif body_selected:
			var battery: Dictionary = system.get("pds", {}).get(selected_body, {})
			kind = "planet" if battery.is_empty() else "pds"
			if not battery.is_empty():
				maximum = ECONOMY.PDS_HP
				hp = float(battery.get("hp", maximum))
		elif building_selection_kind == "station" and ECONOMY.has_station(system):
			kind = "station"
			maximum = ECONOMY.station_max_hp(system)
			hp = float(system["station"].get("hp", maximum))
	selection_portrait.visible = not kind.is_empty()
	if kind.is_empty():
		return
	var tint: Color = _health_color(clampf(hp / maximum, 0.0, 1.0)) if maximum > 0.0 else HUD.MUTED
	selection_portrait_art.texture = _selection_portrait_icon(kind)
	selection_portrait_art.modulate = tint
	selection_portrait_health.visible = maximum > 0.0
	selection_portrait_health.text = "%.0f / %.0f" % [hp, maximum] if maximum > 0.0 else ""
	selection_portrait_health.add_theme_color_override("font_color", tint)
	var entity: Dictionary = ship if not ship.is_empty() else (system.get("station", {}) if kind == "station" else {})
	var shield_max: float = float(entity.get("shield_max", 0.0))
	selection_portrait_shield.visible = shield_max > 0.0
	selection_portrait_shield.text = "Shield %.0f / %.0f" % [float(entity.get("shield", 0.0)), shield_max]

func _refresh_weapon_details(ship: Dictionary, system: Dictionary, body_selected: bool, yard_selected: bool, grouped: bool) -> void:
	var details: String = ""
	var parent: Control = weapon_details.get_parent()
	var at: int = -1
	if not grouped:
		if not ship.is_empty() and selected_units.size() == 1:
			parent = ship_overview
			at = ship_detail.get_index() + 1
			match str(ship["kind"]):
				"cruiser", "destroyer": details = _capital_weapon_summary(str(ship["kind"]))
				"scout", "fighter": details = _blaster_summary(str(ship["kind"]))
				"miner": details = "Mining laser ×2\n%.0f damage each · 1 shot/s (1×) · Range %.0f\n+200%% vs asteroids · %.0f t/yr nominal" % [ECONOMY.MINER_LASER_DAMAGE / 2.0, ECONOMY.LASER_RANGE, ECONOMY.MINER_RATE]
		elif not system.is_empty() and not yard_selected:
			if body_selected and system.get("pds", {}).has(selected_body):
				parent = body_status.get_parent()
				at = body_status.get_index() + 1
				details = "Planetary defense laser\n%.0f damage · 1 shot/s (1×) · Range %.0f" % [ECONOMY.PDS_DAMAGE, ECONOMY.PDS_RANGE]
			elif not body_selected and building_selection_kind == "station" and ECONOMY.has_station(system):
				parent = planet_overview
				at = 1
				details = "Station lasers ×%d\n%.0f damage each · 1 shot/s (1×) · Range %.0f" % [system["station"].get("weapons", []).size(), ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE]
	if weapon_details.get_parent() != parent:
		weapon_details.reparent(parent, false)
		parent.move_child(weapon_details, at)
	weapon_details.text = details
	weapon_details.visible = not details.is_empty()

func _selection_icon(kind: String, tint: Color) -> Texture2D:
	var key: String = kind + ":" + tint.to_html(false)
	if not selection_icons.has(key):
		var points: Array = HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE)
		var coords: PackedStringArray = []
		for vertex in points:
			var v: Vector2 = vertex
			var factor: float = float({"ship": 0.60, "cruiser": 0.54, "destroyer": 0.31}.get(kind, 1.0))
			coords.append("%.2f,%.2f" % [16.0 + v.y * factor, 16.0 - v.x * factor])
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><polygon points="%s" fill="none" stroke="#%s" stroke-width="1.8" stroke-linejoin="round"/></svg>' % [" ".join(coords), tint.to_html(false)])
		selection_icons[key] = ImageTexture.create_from_image(image)
	return selection_icons[key]

func _select_tile(id: int) -> void:
	_clear_building_selection()
	var shift: bool = Input.is_key_pressed(KEY_SHIFT)
	var control: bool = Input.is_key_pressed(KEY_CTRL)
	if control:
		var kind: String = ""
		var ships: Array = _state().get("ships", [])
		for craft in ships:
			if int(craft["id"]) == id:
				kind = craft["kind"]
				break
		for craft in ships:
			if selected_units.has(int(craft["id"])) and (craft["kind"] == kind) == shift:
				selected_units.erase(int(craft["id"]))
	elif shift:
		selected_units.erase(id)
	else:
		selected_units.assign([id])
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	follow_units = false
	pending_command = ""
	_refresh()

func _refresh_selection_tiles(state: Dictionary) -> void:
	var living: Dictionary = {}
	for craft in state.get("ships", []):
		var id: int = int(craft["id"])
		if not selected_units.has(id) and id != selected_ship_id:
			continue
		living[id] = true
		var tile: Button
		if selection_tiles.has(id):
			tile = selection_tiles[id]
		else:
			tile = Button.new()
			_style_selection_tile(tile)
			tile.pressed.connect(_select_tile.bind(id))
			selection_grid.add_child(tile)
			selection_tiles[id] = tile
		var hp: float = clampf(float(craft.get("hp", ECONOMY.ship_max_hp(str(craft["kind"])))) / ECONOMY.ship_max_hp(str(craft["kind"])), 0.0, 1.0)
		var tint: Color = _health_color(hp)
		if tile.get_meta("health_color", Color.TRANSPARENT) != tint or tile.get_meta("hull_kind", "") != craft["kind"]:
			tile.set_meta("health_color", tint)
			tile.set_meta("hull_kind", craft["kind"])
			tile.icon = _selection_icon(str(craft["kind"]), tint)
		var shield_bar: ProgressBar = tile.get_meta("shield_bar")
		var shield: float = _shield_fraction(craft)
		shield_bar.visible = shield >= 0.0 and shield < 1.0
		shield_bar.value = maxf(0.0, shield)
		tile.tooltip_text = "%s · HP %.0f / %.0f\nCrew: %s" % [_ship_kind_name(str(craft["kind"])), float(craft.get("hp", ECONOMY.ship_max_hp(str(craft["kind"])))), ECONOMY.ship_max_hp(str(craft["kind"])), _crew_text(float(craft.get("crew", 0.0)))]
	for id in selection_tiles.keys():
		if not living.has(id):
			var tile: Button = selection_tiles[id]
			selection_grid.remove_child(tile)
			tile.queue_free()
			selection_tiles.erase(id)
	selection_grid.visible = living.size() > 1

func _style_selection_tile(tile: Button) -> void:
	tile.custom_minimum_size = Vector2(38, 38)
	tile.focus_mode = Control.FOCUS_NONE
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.expand_icon = true
	tile.add_theme_constant_override("icon_max_width", 32)
	tile.add_theme_stylebox_override("normal", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#284661"), 2, 2))
	tile.add_theme_stylebox_override("hover", HUD.surface(HUD.CONSOLE_BACKGROUND.lightened(0.06), HUD.ACCENT, 2, 2))
	tile.add_theme_stylebox_override("pressed", HUD.surface(HUD.CONSOLE_BACKGROUND.lightened(0.10), Color.WHITE, 2, 2))
	var shield := ProgressBar.new()
	shield.show_percentage = false
	shield.max_value = 1.0
	shield.step = 0.0
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.add_theme_stylebox_override("background", HUD.surface(Color("#203f5c"), Color("#203f5c"), 0, 0))
	shield.add_theme_stylebox_override("fill", HUD.surface(Color("#6fbaff"), Color("#6fbaff"), 0, 0))
	tile.add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shield.offset_top = -4.0
	shield.offset_bottom = -1.0
	shield.hide()
	tile.set_meta("shield_bar", shield)

func _refresh_field_panels(state: Dictionary) -> void:
	var field: Dictionary = state["map"]["fields"][selected_field]
	var special: bool = bool(field.get("antimatter", false))
	ship_title.text = _poi_name(state["planets"].size() + selected_field)
	var stock: Dictionary = ECONOMY.field_inventory(field)
	var total: float = float(stock["Metals"]) + float(stock["Crystals"])
	if special:
		ship_detail.text = "Science vessels collect 1 unit / 30 yr" if float(stock[ECONOMY.ANTIMATTER]) >= 1.0 - ECONOMY.EPS else "Depleted"
	elif total <= ECONOMY.EPS:
		ship_detail.text = "Depleted"
	else:
		var metals: int = roundi(100.0 * float(stock["Metals"]) / total)
		ship_detail.text = "Metals ~%d%% · %s\nCrystals ~%d%% · %s" % [metals, _tons(float(stock["Metals"])), 100 - metals, _tons(float(stock["Crystals"]))]
	var access_names: PackedStringArray = []
	var graph: Dictionary = ECONOMY.military_graph(state)
	for anchor in graph["adjacent"][state["planets"].size() + selected_field]:
		access_names.append(_poi_name(anchor))
	ship_detail.tooltip_text = "%d chunks remaining · Access: %s" % [field["chunks"].size(), ", ".join(access_names)]
	fleet_title.text = "Mining"
	fleet_detail.hide()
	command_card.hide()
	pending_command = ""
	_refresh_command_mode()
	fleet_cargo_footer.hide()
	field_command_grid.visible = not special
	if not special:
		_refresh_field_commands(state, special)

func _crew_text(crew: float) -> String:
	return "%.0f" % crew

func _refresh_ship_panels(state: Dictionary, ship: Dictionary) -> void:
	field_command_grid.hide()
	var kind: String = ship.get("kind", "ship")
	var owner: int = int(ship["owner"])
	ship_title.text = _ship_kind_name(kind)
	var route: Array = ship["route"]
	var mode: String = ship.get("mining_mode", "idle")
	var status: String = "Orbiting %s" % _system_name(int(ship["at"]))
	if not route.is_empty():
		status = "%s → %s\nETA %.1f yr" % [_system_name(int(ship["at"])), _system_name(int(route.back())), _remaining_years(state, ship)]
	elif mode in ["outbound", "return"]:
		status = ("To field" if mode == "outbound" else "Returning") + "\nETA %.1f yr" % _remaining_years(state, ship)
	elif mode == "mining":
		status = "Mining %s\n%.1f / 5 yr" % [_poi_name(state["planets"].size() + int(ship["field"])), minf(5.0, float(ship.get("mining_years", 0.0)))]
	elif kind == "miner" and mode == "delivery":
		status = "Waiting for storage"
	elif kind == "miner" and mode == "idle":
		status = "Waiting for accessible ore / storage"
	if kind == "fighter":
		status = "Stationed at %s" % _poi_name(int(ship["at"])) if route.is_empty() else "%s\nETA %.1f yr" % [_poi_name(int(route.back())), _remaining_years(state, ship)]
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		status = "Repairing" if route.is_empty() and site >= 0 and (ship["position"] as Vector2).distance_to(ECONOMY.station_position(state, site, float(state["elapsed"]))) <= ECONOMY.STATION_REPAIR_RANGE + ECONOMY.EPS and ECONOMY._repair_site_safe(state, ECONOMY.military_graph(state), owner, site) else "Withdrawing"
	elif int(ship.get("pursuit_target", -1)) >= 0:
		status = "Pursuing"
	elif bool(ship.get("holding", false)):
		status = "Moving to hold position" if ship.has("hold_position") and (ship["position"] as Vector2).distance_to(ship["hold_position"]) > ECONOMY.EPS else "Holding position"
	elif int(ship.get("combat_target", -1)) >= 0:
		status = "Engaged"
	elif ship.has("local_move_target"):
		status = "Moving · ETA %.1f yr" % ((ship["position"] as Vector2).distance_to(ship["local_move_target"]) / ECONOMY.ship_speed(str(ship.get("kind", "ship"))))
	if not bool(ship.get("retreating", false)):
		if ship.has("attack_order"):
			status = "Attacking target"
		elif ship.has("repair_target") or ship.has("repair_order"):
			status = "Repairing" if ship.has("repair_target") else "Approaching repair target"
		elif ship.has("cargo_order"):
			status = "Dropping cargo" if ship["cargo_order"]["kind"] == "drop" else "Delivering cargo"
		elif ship.has("patrol_from"):
			status = "Patrolling → %s" % _poi_name(int(ship["operation_target"]))
	if int(ship.get("salvage_target", -1)) >= 0:
		status = "Collecting salvage" if bool(ship.get("tractor_active", false)) else "Approaching salvage"
	elif bool(ship.get("salvage_delivery", false)):
		status = "Delivering salvage" if int(ship.get("salvage_depot", -1)) >= 0 else "Waiting for salvage storage"
	elif int(ship.get("auto_salvage_target", -1)) >= 0:
		status += " · Salvaging" if bool(ship.get("tractor_active", false)) else " · Approaching debris"
	if ship.has("resource_stage"):
		var stage: Dictionary = ship["resource_stage"]
		status = "Approaching resource site" if (ship["position"] as Vector2).distance_to(stage["point"]) > ECONOMY.RESOURCE_HANDOFF_RANGE else "Awaiting resource cargo"
	elif bool(ship.get("resource_haul", false)):
		status = "Hauling resources" if int(ship.get("salvage_depot", -1)) >= 0 else "Waiting for resource storage"
	var follow_order: Dictionary = ship.get("unit_order", {})
	if follow_order.get("kind", "") == "guard" and not bool(ship.get("retreating", false)):
		status = "Guarding sector" if bool(ship.get("guard_arrived", false)) else "Moving to guard position"
	if follow_order.get("kind", "") == "follow" and not bool(ship.get("retreating", false)):
		var target_ship: Dictionary = ECONOMY.service_targets(state).get(int(follow_order["target"]), {}).get("entity", {})
		status = ("%s %s" % ["Guarding" if bool(follow_order.get("guard", false)) else "Following", _ship_kind_name(str(target_ship.get("kind", "ship")))])
	var wait_left: float = ECONOMY.autocast_remaining(state, ship, "wander")
	if wait_left > ECONOMY.EPS and ECONOMY.autocast_enabled(ship, "wander") and ECONOMY._is_idle_ship(ship):
		status = "Awaiting orders · %.0f yr" % ceilf(wait_left)
	if kind == "colony_ship":
		if bool(ship.get("salvage_delivery", false)):
			status = "Delivering Organics" if int(ship.get("salvage_depot", -1)) >= 0 else "Waiting for storage"
		status += "\nOrganics %.1f / %.0f t · %s" % [float(ship["cargo"].get("Organics", 0.0)), ECONOMY.COLONY_CAPACITY, "Farming" if ECONOMY.autocast_enabled(ship, "farm") and not bool(ship.get("salvage_delivery", false)) and ECONOMY.cargo_free(ship) > ECONOMY.EPS else "Farm idle"]
	if kind == "science_ship":
		if ECONOMY._cargo_total(ship) > ECONOMY.EPS:
			status += "\nAntimatter secured · 1 unit"
		elif ship.get("unit_order", {}).get("kind", "") == "collect":
			var years: float = float(ship.get("science_years", 0.0))
			status = "Collecting antimatter · %.1f / %.0f yr" % [years, ECONOMY.SCIENCE_COLLECTION_YEARS] if years > 0.0 else "Approaching Pulsar"
	if bool(ship.get("cloak_equipped", false)):
		status += "\nCloaked" if bool(ship.get("cloaked", false)) else "\nCloak recharging"
	if ECONOMY.armed(ship):
		status += "\nKills: %d" % int(ship.get("kills", 0))
	if ECONOMY.cargo_capacity(kind) > ECONOMY.EPS:
		var picked: float = float(ship.get("tons_picked", 0.0))
		var dropped: float = float(ship.get("tons_dropped", 0.0))
		status += "\nCargo handled: %.1f t (↑ %.1f / ↓ %.1f)" % [picked + dropped, picked, dropped]
	if kind == "colony_ship":
		status += "\nFood produced: %.1f t" % float(ship.get("food_produced", 0.0))
		if ECONOMY.can_transform_colony(state, ECONOMY.military_graph(state), ship):
			status += "\nReady to establish station"
	if kind == "warp_gate":
		var destination: Dictionary = ECONOMY.warp_gate(state, owner, int(ship.get("warp_destination", -1)))
		status = "Linked to %s" % _system_name(int(destination["at"])) if not destination.is_empty() else "Unlinked · deploy another gate"
	ship_detail.text = status
	ship_detail.tooltip_text = ""
	var multiple: bool = selected_units.size() > 1
	ship_title.visible = not multiple
	ship_detail.visible = not multiple
	fleet_title.text = "Fleet"
	fleet_detail.visible = true
	var owned_count: int = 0
	var selected_crew: float = 0.0
	var loaded_owned: bool = false
	var cargo: Dictionary = ECONOMY.empty_stock()
	for craft in state["ships"]:
		if not selected_units.has(int(craft["id"])):
			continue
		selected_crew += float(craft.get("crew", 0.0))
		owned_count += int(int(craft["owner"]) == _me())
		loaded_owned = loaded_owned or (int(craft["owner"]) == _me() and ECONOMY._cargo_total(craft) > ECONOMY.EPS)
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			cargo[resource] = float(cargo.get(resource, 0.0)) + float(craft.get("cargo", {}).get(resource, 0.0))
	if not multiple:
		selected_crew = float(ship.get("crew", 0.0))
	ship_population.text = ("Total crew: " if multiple else "Crew: ") + _crew_text(selected_crew)
	ship_population.get_parent().show()
	_sync_command_kind(state)
	command_card.show()
	loaded_owned = false
	var combat_owned: bool = false
	var can_load: bool = false
	var has_cargo_hold: bool = false
	var has_farm: bool = false
	var loaded_farm: bool = false
	var has_miners: bool = not _selected_miners().is_empty()
	for craft in state["ships"]:
		if _command_member(craft):
			loaded_owned = loaded_owned or ECONOMY._cargo_total(craft) > ECONOMY.EPS
			combat_owned = combat_owned or ECONOMY.armed(craft)
			can_load = can_load or (ECONOMY.supports_autocast(craft, "salvage") and ECONOMY.cargo_free(craft) > ECONOMY.EPS)
			has_cargo_hold = has_cargo_hold or ECONOMY.supports_autocast(craft, "salvage")
			has_farm = has_farm or craft["kind"] == "colony_ship"
			loaded_farm = loaded_farm or (craft["kind"] == "colony_ship" and ECONOMY._cargo_total(craft) > ECONOMY.EPS)
	for id in command_buttons:
		var button: Button = command_buttons[id]
		button.visible = (id != "repair" or has_miners) and (id not in ["load", "unload"] or has_cargo_hold)
		button.disabled = owned_count == 0 or (id == "attack" and not combat_owned) or (id == "patrol" and not state["ships"].any(func(craft: Dictionary) -> bool: return _command_member(craft) and craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"])) or (id == "repair" and not has_miners) or (id == "load" and not can_load) or (id == "unload" and not loaded_owned)
	var transform: Button = command_buttons["transform"]
	var transform_extra: Control = command_card.get_child(17)
	var transform_slot: Control = transform_extra if has_miners else command_card.get_child(7)
	if transform.get_parent() != transform_slot:
		transform.reparent(transform_slot, false)
		transform.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transform_extra.visible = has_farm and has_miners
	var graph: Dictionary = ECONOMY.military_graph(state)
	var science: bool = command_kind == "science_ship" and state.get("objectives", {}).get(_me(), {}).get("rewards", []).has("warp_gate")
	var gate: bool = command_kind == "warp_gate"
	transform.visible = has_farm or science or gate
	if gate:
		for button in command_buttons.values():
			button.visible = button == transform
			button.disabled = button != transform
		transform.disabled = ECONOMY.warp_gate_choices(state, _me(), int(ship.get("id", -1))).is_empty() or owned_count == 0
		_set_button_hint(transform, "Cycle link destination [J] · right-click an owned linked gate with ships to travel")
	elif science:
		transform.disabled = not state["ships"].any(func(craft: Dictionary) -> bool: return _command_member(craft) and ECONOMY.can_build_warp_gate(state, graph, craft))
		_set_button_hint(transform, "Deploy Warp Gate [J] · consumes 1 antimatter; one gate per owned system")
	else:
		transform.disabled = not state["ships"].any(func(craft: Dictionary) -> bool: return _command_member(craft) and ECONOMY._valid_unit_order(state, graph, craft, {"kind": "transform"}, true))
		_set_button_hint(transform, "Transform into Space Station [J]")
	command_buttons["deliver_farm"].visible = has_farm
	command_buttons["deliver_farm"].disabled = not loaded_farm
	if not command_buttons.has(pending_command) or (command_buttons[pending_command] as Button).disabled:
		pending_command = ""
	_refresh_command_mode()
	fleet_title.visible = _command_kinds(state).size() > 1
	fleet_title.text = "%s · Tab" % _ship_kind_name(command_kind)
	fleet_detail.visible = false
	fleet_cargo_footer.visible = ECONOMY._cargo_total({"cargo": cargo}) > ECONOMY.EPS
	if fleet_cargo_footer.visible:
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			var amount: float = float(cargo.get(resource, 0.0))
			fleet_cargo_labels[resource].text = _tons(amount, 1, true) if amount >= 1000.0 else (("%.1f" % amount).trim_suffix(".0") if amount >= 0.1 else "%.2f" % amount) + "t"
			fleet_cargo_labels[resource].tooltip_text = "%.1f t" % amount
			fleet_cargo_labels[resource].get_parent().visible = amount > ECONOMY.EPS

func _build_lens_buttons(parent: Container) -> void:
	logistics_lens = _button("", _toggle_lens.bind("logistics"), parent)
	# Linked cargo crates suggest the resource storage / logistics overlay.
	logistics_lens.icon = _command_icon('<rect x="3" y="3" width="10" height="10" rx="1"/><rect x="19" y="19" width="10" height="10" rx="1"/><path d="M13 8H24V19M20 15L24 19L28 15M8 3V7M24 24V29"/>')
	logistics_lens.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logistics_lens.expand_icon = true
	logistics_lens.add_theme_constant_override("icon_max_width", 24)
	logistics_lens.custom_minimum_size = Vector2.ONE * LENS_STRIP_WIDTH
	logistics_lens.toggle_mode = true
	logistics_lens.focus_mode = Control.FOCUS_NONE
	logistics_lens.tooltip_text = "Logistics lens · System resource storage"

var diagnostic_label: Label
var diagnostic_button: Button
var diagnostic_elapsed: float = 0.0
var diagnostic_last_bytes: int = -1
var diagnostic_last_full_count: int = 0
var diagnostic_last_motion_count: int = 0

func _build_time_controls(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	for speed in [0, 1, 2, 5]:
		var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
		var button: Button = _button(label, _set_time_speed.bind(int(speed)), row)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(26, 23)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_buttons[speed] = button
	diagnostic_button = _button("Perf", func() -> void: diagnostic_label.visible = not diagnostic_label.visible, row)
	diagnostic_button.custom_minimum_size.y = 23
	diagnostic_button.focus_mode = Control.FOCUS_NONE
	diagnostic_button.tooltip_text = "Toggle local performance diagnostics"
	diagnostic_label = _label("", 11)
	add_child(diagnostic_label)
	diagnostic_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	diagnostic_label.offset_left = -220
	diagnostic_label.offset_right = 220
	diagnostic_label.offset_top = -76
	diagnostic_label.offset_bottom = -52
	diagnostic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagnostic_label.hide()

func _set_time_speed(speed: int) -> void:
	session.call("request_time_speed", speed)
	_refresh_time_controls(_state())

func _refresh_time_controls(state: Dictionary) -> void:
	var current: int = int(state.get("time_speed", 1))
	var can_change: bool = str(session.get("phase")) == "match" and state.get("match_result", {}).is_empty()
	for speed in time_buttons:
		var button: Button = time_buttons[speed]
		var active: bool = int(speed) == current
		button.disabled = not can_change
		button.set_pressed_no_signal(active)
		# Keep the replicated speed visible even after the match ends.
		if active:
			button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
			button.add_theme_color_override("font_disabled_color", HUD.ACCENT)
		else:
			button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")

func _toggle_lens(kind: String) -> void:
	_refresh()
	active_lens = "" if active_lens == kind else kind
	logistics_lens.set_pressed_no_signal(active_lens == "logistics")
	map_canvas.queue_redraw()

func _draw_resource_fill(strip: Control, resource: String) -> void:
	var fraction: float = float(global_resource_fills.get(resource, 0.0))
	var segments: Array = global_resource_segments.get(resource, [])
	strip.draw_rect(Rect2(Vector2.ZERO, strip.size), Color("#081421"))
	if fraction <= 0.0 or segments.is_empty():
		return
	var width: float = strip.size.x * fraction
	strip.draw_rect(Rect2(Vector2.ZERO, Vector2(width, strip.size.y)), Color(HUD.COLORS.get(resource, Color("#b9d9ed")), 0.38))
	var font: Font = ThemeDB.fallback_font
	var x: float = 0.0
	for i in range(segments.size()):
		var segment: Dictionary = segments[i]
		var w: float = width * float(segment["share"])
		if segment.has("color"):
			strip.draw_rect(Rect2(Vector2(x, 0), Vector2(w, strip.size.y)), segment["color"])
		if i > 0:
			strip.draw_line(Vector2(x, 0), Vector2(x, strip.size.y), Color("#081421"), 1.0)
		var name_text: String = segment["name"]
		var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if text_width + 6.0 > w:
			name_text = name_text.left(2)
			text_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if text_width + 6.0 > w:
			name_text = name_text.left(1)
			text_width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if segments.size() > 1 and text_width + 6.0 <= w:
			strip.draw_string(font, Vector2(x + (w - text_width) * 0.5, (strip.size.y - font.get_height(10)) * 0.5 + font.get_ascent(10)), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e3edf7"))
		x += w

func _build_territory_layer() -> void:
	territory_layer = Control.new()
	add_child(territory_layer)
	territory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	territory_layer.offset_left = 8
	territory_layer.offset_top = 0
	territory_layer.offset_right = -8
	territory_layer.offset_bottom = -8
	territory_layer.clip_contents = true
	territory_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory_image = ColorRect.new()
	territory_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory_layer.add_child(territory_image)
	# The texture stores site coordinates, NOT a spatial raster. Every output
	# pixel evaluates continuous circle distances in world space.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D site_data : filter_nearest, repeat_disable;
uniform int site_count = 0;
uniform sampler2D sector_neighbors : filter_nearest, repeat_disable;
uniform sampler2D lane_data : filter_nearest, repeat_disable;
uniform sampler2D influence_data : filter_nearest, repeat_disable;
uniform int lane_count = 0;
uniform float lane_radius_fraction = 0.35;
uniform vec2 world_extent = vec2(1.0);
uniform float padding = 1.0;
uniform float corner_rounding = 0.32;

// Positive clearance is inside one region. Smooth the intersection of
// constraints inward; the same contour defines both fill and rim.
float rounded_intersection(float a, float b, float width) {
	float overlap = max(0.0, width - abs(a - b));
	return min(a, b) - overlap * overlap / (4.0 * max(width, 0.000001));
}

float sector_distance(vec2 p, vec4 site, int index) {
	vec2 offset = p - site.xy;
	float distance_to_center = length(offset);
	float limit = site.z;
	// Outside the disk this lower bound is sufficient for membership.
	// Near the disk calculate the clipped, rounded radial boundary too,
	// so the lane's region boundary meets the actual sector edge.
	if (distance_to_center > site.z * 1.2) {
		return distance_to_center - site.z;
	}
	vec2 ray = offset / max(distance_to_center, 0.0000001);
	float second = 1e20;
	for (int i = 0; i < int(site.w + 0.5); i++) {
		vec3 neighbor = texelFetch(sector_neighbors, ivec2(i, index), 0).xyz;
		vec2 delta = neighbor.xy;
		float length_sq = neighbor.z;
		float projection = dot(ray, delta);
		if (length_sq > 0.000000000001 && length_sq < 4.0 * site.z * site.z && projection > 0.000000001) {
			float bound = length_sq / (2.0 * projection);
			if (bound < limit) {
				second = limit;
				limit = bound;
			} else {
				second = min(second, bound);
			}
		}
	}
	float width = max(0.000000001, limit * corner_rounding);
	float overlap = max(0.0, width - (second - limit));
	limit -= overlap * overlap / (4.0 * width);
	return distance_to_center - limit;
}

// Lane samples contain axial fraction, centerline distance and radius.
vec3 lane_sample(vec2 p, int index) {
	vec4 edge = texelFetch(lane_data, ivec2(index, 0), 0);
	vec4 a = texelFetch(site_data, ivec2(int(edge.x + 0.5), 0), 0);
	vec4 b = texelFetch(site_data, ivec2(int(edge.y + 0.5), 0), 0);
	vec2 axis = b.xy - a.xy;
	float along = clamp(dot(p - a.xy, axis) / max(dot(axis, axis), 0.00000001), 0.0, 1.0);
	return vec3(along, length(p - (a.xy + axis * along)), min(a.z, b.z) * lane_radius_fraction);
}

vec4 region_color(int region, float clearance, float aa) {
	vec4 tint = texelFetch(influence_data, ivec2(region, 0), 0);
	vec3 neutral = vec3(0.60, 0.68, 0.76);
	float fill = smoothstep(-aa * 0.5, aa * 0.5, clearance);
	// A single centered AA stroke, rather than independent line
	// fragments with conflicting masks. Also visible at deep zoom.
	float rim = 1.0 - smoothstep(aa * 0.45, aa * 1.6, abs(clearance));
	float alpha = fill * 0.10 * tint.a + rim * mix(0.20, 0.45, tint.a);
	return vec4(mix(neutral, tint.rgb, tint.a), alpha);
}

void fragment() {
	vec2 p = UV * world_extent - vec2(padding);
	vec2 bounds = world_extent - vec2(2.0 * padding);
	float map_clearance = min(min(p.x, p.y), min(bounds.x - p.x, bounds.y - p.y));
	if (map_clearance < 0.0) { discard; }
	// Take derivatives before branching, to avoid undefined AA at seams.
	float aa = max(length(fwidth(p)), 0.000001);
	float core_d = 1e20;
	int core = -1;
	float nearest_inside = 1e20;
	int nearest_core = -1;
	for (int i = 0; i < site_count; i++) {
		vec4 site = texelFetch(site_data, ivec2(i, 0), 0);
		float distance_sq = dot(p - site.xy, p - site.xy);
		// Skip expensive radial clipping when the disk lower bound
		// cannot affect either the selected core or the nearby lane rim.
		float disk_d = sqrt(distance_sq) - site.z;
		if (disk_d > max(core_d, aa * 2.0)) { continue; }
		float d = sector_distance(p, site, i);
		if (d < core_d) {
			core_d = d;
			nearest_core = i;
		}
		if (d <= 0.0 && distance_sq < nearest_inside) {
			nearest_inside = distance_sq;
			core = i;
		}
	}
	if (core >= 0) {
		vec4 site = texelFetch(site_data, ivec2(core, 0), 0);
		float clearance = min(-sector_distance(p, site, core), map_clearance);
		COLOR = region_color(core, clearance, aa);
	} else {
		// Assign actual lane membership by nearest eligible centerline,
		// matching influence_region. Pick the nearest surface outside for AA.
		int lane = -1;
		int nearest_lane = -1;
		float nearest_distance = 1e20;
		float surface = 1e20;
		vec3 picked = vec3(0.0);
		vec3 outside = vec3(0.0);
		for (int i = 0; i < lane_count; i++) {
			vec3 lane_values = lane_sample(p, i);
			float d = lane_values.y - lane_values.z;
			if (d < surface) {
				surface = d;
				nearest_lane = i;
				outside = lane_values;
			}
			if (d <= 0.0 && lane_values.y < nearest_distance) {
				nearest_distance = lane_values.y;
				lane = i;
				picked = lane_values;
			}
		}
		bool in_lane = lane >= 0;
		if (!in_lane) {
			lane = nearest_lane;
			picked = outside;
		}
		vec4 lane_color = vec4(0.0);
		if (lane >= 0 && (in_lane || surface <= aa * 2.0)) {
			vec4 edge = texelFetch(lane_data, ivec2(lane, 0), 0);
			int sections = max(1, int(edge.w + 0.5));
			float scaled = picked.x * float(sections);
			int section = min(sections - 1, int(floor(scaled)));
			int region = int(edge.z + 0.5) + section;
			vec2 a = texelFetch(site_data, ivec2(int(edge.x + 0.5), 0), 0).xy;
			vec2 b = texelFetch(site_data, ivec2(int(edge.y + 0.5), 0), 0).xy;
			float span = length(b - a) / float(sections);
			float rounding = max(0.000001, picked.z * corner_rounding * 0.25);
			float clearance = min(picked.z - picked.y, map_clearance);
			// Closed lane mouths and section ends, not disconnected
			// lines from a smoothed union. Round only the local corners.
			clearance = rounded_intersection(clearance, core_d, rounding);
			if (section > 0) {
				clearance = rounded_intersection(clearance, (scaled - float(section)) * span, rounding);
			}
			if (section < sections - 1) {
				clearance = rounded_intersection(clearance, (float(section + 1) - scaled) * span, rounding);
			}
			// Clip against competing lanes' assigned areas. A point is
			// ours if outside the other capsule OR nearer our centerline.
			// This also closes contours at crossing or branching highways.
			for (int i = 0; i < lane_count; i++) {
				if (i == lane) { continue; }
				vec3 other = lane_sample(p, i);
				float separation = max(other.y - other.z, (other.y - picked.y) * 0.5);
				if (separation < clearance + rounding) {
					clearance = rounded_intersection(clearance, separation, rounding);
				}
			}
			lane_color = region_color(region, clearance, aa);
		}
		// Preserve the outer half of a core rim in empty space and at
		// highway mouths, blending rather than truncating at membership.
		vec4 core_color = vec4(0.0);
		if (nearest_core >= 0 && core_d < aa * 2.0) {
			core_color = region_color(nearest_core, -core_d, aa);
		}
		float alpha = core_color.a + lane_color.a * (1.0 - core_color.a);
		COLOR = vec4((core_color.rgb * core_color.a + lane_color.rgb * lane_color.a * (1.0 - core_color.a)) / max(alpha, 0.000001), alpha);
	}
}
"""
	territory_material = ShaderMaterial.new()
	territory_material.shader = shader
	territory_material.set_shader_parameter("corner_rounding", ECONOMY.SECTOR_CORNER_ROUNDING)
	territory_material.set_shader_parameter("lane_radius_fraction", ECONOMY.LANE_RADIUS_FRACTION)
	territory_image.material = territory_material
	territory_image.hide()

# One consistent radius per galaxy, based on median nearest-system spacing.
# Outlier systems cannot create enormous wedges; asteroid fields are smaller.
func _refresh_territory(state: Dictionary) -> void:
	if state.is_empty():
		territory_image.hide()
		territory_seed = -1
		territory_region_cache.clear()
		territory_region_graph = {}
		territory_last.clear()
		territory_influence_texture = null
		return
	var seed_value: int = int(state["map"]["seed"])
	var graph: Dictionary = ECONOMY.military_graph(state)
	var points: Array = graph["points"]
	var edges: Array = graph["edges"]
	if points.is_empty():
		territory_image.hide()
		return
	var layout: Dictionary = ECONOMY.highway_regions(graph)
	if territory_seed != seed_value or territory_site_count != points.size() or territory_last.size() != int(layout["size"]):
		territory_radius = ECONOMY.sector_base_radius(state["map"])
		territory_seed = seed_value
		territory_last.clear()
		territory_influence_texture = null
		territory_site_count = points.size()
		# Cache possible bisector constraints in original site order. Use a
		# conservative margin around the shader's strict disk cutoff.
		var neighbor_rows: Array = []
		var max_neighbors: int = 1
		for i in range(points.size()):
			var row: Array = []
			var radius: float = float(graph["sector_radii"][i]) / territory_radius
			for j in range(points.size()):
				if i == j:
					continue
				var delta: Vector2 = (points[j] as Vector2) / territory_radius - (points[i] as Vector2) / territory_radius
				var length_sq: float = delta.length_squared()
				if length_sq <= 4.0 * radius * radius + 0.00001:
					row.append(Color(delta.x, delta.y, length_sq, 0.0))
			neighbor_rows.append(row)
			max_neighbors = maxi(max_neighbors, row.size())
		var neighbors: Image = Image.create_empty(max_neighbors, points.size(), false, Image.FORMAT_RGBAF)
		var data: Image = Image.create_empty(points.size(), 1, false, Image.FORMAT_RGBAF)
		for i in range(points.size()):
			var point: Vector2 = points[i]
			var row: Array = neighbor_rows[i]
			for j in range(row.size()):
				neighbors.set_pixel(j, i, row[j])
			data.set_pixel(i, 0, Color(point.x / territory_radius, point.y / territory_radius, float(graph["sector_radii"][i]) / territory_radius, float(row.size())))
		territory_material.set_shader_parameter("sector_neighbors", ImageTexture.create_from_image(neighbors))
		territory_sites = ImageTexture.create_from_image(data)
		territory_material.set_shader_parameter("site_data", territory_sites)
		territory_material.set_shader_parameter("site_count", territory_site_count)
		var lanes: Image = Image.create_empty(maxi(1, edges.size()), 1, false, Image.FORMAT_RGBAF)
		for i in range(edges.size()):
			lanes.set_pixel(i, 0, Color(float(edges[i][0]), float(edges[i][1]), float(layout["starts"][i]), float(layout["counts"][i])))
		territory_material.set_shader_parameter("lane_data", ImageTexture.create_from_image(lanes))
		territory_material.set_shader_parameter("lane_count", edges.size())
		var extent: Vector2 = _map_size() / territory_radius + Vector2.ONE * 3.0
		territory_material.set_shader_parameter("world_extent", extent)
		territory_material.set_shader_parameter("padding", 1.5)
	var known: Array[int] = ECONOMY.military_pois(state, _me())
	if not is_same(territory_region_graph, graph):
		territory_region_cache.clear()
		territory_region_graph = graph
	var weights: Array[Dictionary] = ECONOMY.territory_influence(state, graph, known, territory_region_cache)
	# Only known sectors with a friendly majority are warning destinations.
	tactical_friendly.clear()
	var my_team: int = int(state["teams"].get(_me(), -1))
	for index in range(points.size()):
		if not known.has(index):
			continue
		var friendly: float = 0.0
		var hostile: float = 0.0
		for owner in weights[index]:
			if int(state["teams"].get(owner, 0)) == my_team:
				friendly += float(weights[index][owner])
			else:
				hostile += float(weights[index][owner])
		if friendly > hostile or (index < state["planets"].size() and ECONOMY.has_station(state["planets"][index]) and int(state["teams"].get(int(state["planets"][index]["owner"]), 0)) == my_team):
			tactical_friendly.append(index)
	var roster: Dictionary = session.get("players")
	var colors: Dictionary = {}
	for player in roster:
		colors[player] = _empire_color(int(player))
	var tints: Array[Color] = []
	for weights_by_player in weights:
		tints.append(ECONOMY.influence_color(weights_by_player, colors))
	if tints == territory_last:
		return
	territory_last = tints
	var influence: Image = Image.create_empty(tints.size(), 1, false, Image.FORMAT_RGBAF)
	for i in range(tints.size()):
		influence.set_pixel(i, 0, tints[i])
	if territory_influence_texture == null:
		territory_influence_texture = ImageTexture.create_from_image(influence)
		territory_material.set_shader_parameter("influence_data", territory_influence_texture)
	else:
		territory_influence_texture.update(influence)
	territory_image.show()
	_position_territory()

func _position_territory() -> void:
	var padding: Vector2 = Vector2.ONE * territory_radius * 1.5
	territory_image.position = _screen_point(-padding)
	territory_image.size = (_map_size() + padding * 2.0) * _fit() * zoom

func _show_system_rings(index: int) -> bool:
	if index != selected or selected_body >= 0 or selected_yard >= 0 or not building_selection_kind.is_empty():
		return false
	var p: Dictionary = _planet()
	return not p.is_empty() and int(p["owner"]) == 0 and not ECONOMY.has_station(p)

func _build_global_bar(stats: Container) -> void:
	for resource in ECONOMY.RESOURCES:
		var tile := PanelContainer.new()
		tile.custom_minimum_size.x = 148.0
		tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
		stats.add_child(tile)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		tile.add_child(stack)
		var line := HBoxContainer.new()
		stack.add_child(line)
		var icon := TextureRect.new()
		HUD.fixed_icon(icon, HUD.resource_icon(resource, 18), 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
		var value := _label("0", 13)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.clip_text = true
		value.add_theme_font_size_override("font_size", 12)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", HUD.COLORS[resource])
		line.add_child(value)
		global_resource_labels[resource] = value
		var delta := _label("0.0t", 12)
		delta.autowrap_mode = TextServer.AUTOWRAP_OFF
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(delta)
		global_resource_delta_labels[resource] = delta
		global_resource_tiles[resource] = tile
		global_resource_fills[resource] = 0.0
		var strip := Control.new()
		strip.custom_minimum_size.y = 14.0
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(strip)
		global_resource_strips[resource] = strip
		global_resource_segments[resource] = []
		strip.draw.connect(_draw_resource_fill.bind(strip, resource))

func _global_stat(parent: Container, value: String, tint: Color, population: bool = false) -> Label:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
	parent.add_child(tile)
	var label := _label(value, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if population:
		tile.custom_minimum_size.x = 180.0
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		tile.add_child(stack)
		_population_row(stack).add_child(label)
		var strip := Control.new()
		strip.custom_minimum_size = Vector2(0, 14)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(strip)
		global_resource_tiles["population"] = tile
		global_resource_strips["population"] = strip
		strip.draw.connect(_draw_resource_fill.bind(strip, "population"))
	else:
		tile.add_child(label)
	return label

func _tons(value: float, decimals: int = 1, compact: bool = false) -> String:
	# Stocks and prices share one unit; preserve fractional small values.
	var number: String = ("%.1f" % value).trim_suffix(".0") if decimals == 1 and absf(value) < 1000.0 else "%.0f" % value
	return number + ("" if compact else " ") + "t"

func _resource_delta(p: Dictionary, resource: String) -> float:
	return ECONOMY.rate(p, resource) - ECONOMY.consumption(p, resource)

func _empire_resource_delta(state: Dictionary, resource: String) -> float:
	var total: float = 0.0
	for p in state.get("planets", []):
		if int(p["owner"]) == _me():
			total += _resource_delta(p, resource)
	return total

func _set_resource_delta(label: Label, annual: float, parentheses: bool = false) -> void:
	var displayed: float = 0.0 if absf(annual) < 0.05 else annual
	var amount: String = ("+" if displayed > 0.0 else "") + _tons(displayed, 1, true)
	label.text = ("(%s/yr)" % amount if displayed != 0.0 else "") if parentheses else amount
	label.visible = not parentheses or displayed != 0.0
	label.add_theme_color_override("font_color", Color("#7cdb9b") if displayed > 0.0 else (Color("#eb8585") if displayed < 0.0 else Color.WHITE))

func _compact_amount(value: float) -> String:
	if value >= 1000000000.0:
		return "%.1fB" % (value / 1000000000.0)
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return "%.0f" % value

func _build_resource_hover() -> void:
	resource_hover_panel = PanelContainer.new()
	resource_hover_panel.z_index = 50
	resource_hover_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#42647e"), 9))
	add_child(resource_hover_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resource_hover_panel.add_child(scroll)
	resource_hover_label = _label("", 12)
	resource_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(resource_hover_label)
	resource_hover_panel.hide()

func _resource_breakdown(state: Dictionary, resource: String) -> String:
	if resource == "population":
		var population_totals: Dictionary = ECONOMY.empire_totals(state, _me())
		var lines: PackedStringArray = ["Population · %s people" % _compact_amount(float(population_totals["population"])), "Residents: %s · Ships: %s · Embarking: %s" % [_compact_amount(float(population_totals["resident_population"])), _compact_amount(float(population_totals["ship_population"])), _compact_amount(float(population_totals["embarking_population"]))], "Current local growth (people/yr)"]
		var ceiling: float = 0.0
		for system in state["planets"]:
			if int(system["owner"]) == _me():
				ceiling += ECONOMY.sustainable_population_capacity(system)
		lines.insert(1, "Resident sustainable capacity: %s people" % _compact_amount(ceiling))
		for i in range(state["planets"].size()):
			var p: Dictionary = state["planets"][i]
			if int(p["owner"]) != _me():
				continue
			var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
			var crew: float = float(p.get("crew_rate", 0.0))
			lines.append("%s · %.0f · %+.2f/yr\n  %+.2f demographic · %+.2f crews · %+.1f%% overpopulation · %+.1f%% food reserve" % [_system_name(i), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p), -100.0 * (1.0 - ECONOMY.food_growth_multiplier(p))])
		return "\n".join(lines)
	var totals: Dictionary = ECONOMY.empire_totals(state, _me())
	var lines: PackedStringArray = ["%s  ·  %.2f t stored" % [resource, float(totals["stock"][resource])],
		"%.2f t in transit  /  %.0f t storage" % [float(totals["cargo"][resource]), float(totals["storage_reference"][resource])],
		"Empire net: %+.2f t/yr" % _empire_resource_delta(state, resource)]
	for i in range((state.get("planets", []) as Array).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != _me():
			continue
		lines.append("%s  %+.2f t/yr · %.2f production / %.2f demand" % [_system_name(i), _resource_delta(p, resource), ECONOMY.rate(p, resource), ECONOMY.consumption(p, resource)])
	return "\n".join(lines)

func _local_breakdown(p: Dictionary, resource: String) -> String:
	if resource == "population":
		var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
		var crew: float = float(p.get("crew_rate", 0.0))
		return "%s · %.0f people\n%+.2f/yr net\n%+.2f demographic change\n%+.2f ship crews\nOverpopulation penalty: %+.1f%%\nFood reserve growth penalty: %+.1f%% (%.2f / %.0f t for full growth)\nOrganics: %.2f produced / %.2f consumed per year\nEco-Housing: %.0f / %.0f residents · +%.2f t/yr Organics" % [_system_name(selected), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p), -100.0 * (1.0 - ECONOMY.food_growth_multiplier(p)), float(p["stock"]["Organics"]), ECONOMY.POPULATION_FOOD_RESERVE, ECONOMY.rate(p, "Organics"), ECONOMY.consumption(p, "Organics"), ECONOMY.eco_population(p), ECONOMY.eco_capacity(p), ECONOMY.eco_organics(p)]
	var potential: float = ECONOMY.rate(p, resource)
	var demand: float = ECONOMY.consumption(p, resource)
	return "%s · %.2f t stored\nProduction: %.2f t/yr\nDemand: %.2f t/yr\nNet: %+.2f t/yr\nOutput: %.1f%% of baseline" % [resource, float(p["stock"][resource]), potential, demand, potential - demand, 100.0 * ECONOMY.production_modifier(p, resource)]

func _update_resource_hover() -> void:
	if not is_instance_valid(resource_hover_panel):
		return
	if is_instance_valid(codex) and codex.visible:
		resource_hover_panel.hide()
		return
	var mouse: Vector2 = get_global_mouse_position()
	var resource: String = ""
	for key in global_resource_tiles:
		if global_resource_tiles[key].get_global_rect().has_point(mouse):
			resource = key
			break
	var local_visible: bool = station_details.is_visible_in_tree() and overview_panel.get_global_rect().has_point(mouse) and not _planet().is_empty()
	if resource.is_empty() and local_visible:
		if population_label.is_visible_in_tree() and population_label.get_parent().get_global_rect().has_point(mouse):
			resource = "local:population"
		else:
			for key in production_values:
				if production_values[key]["row"].is_visible_in_tree() and production_values[key]["row"].get_global_rect().has_point(mouse):
					resource = "local:" + str(key)
					break
	if resource.is_empty() and resource_hover_panel.visible and resource_hover_panel.get_global_rect().has_point(mouse):
		resource = hovered_resource
	if resource.is_empty() or _state().is_empty():
		resource_hover_panel.hide()
		hovered_resource = ""
		return
	var state: Dictionary = _state()
	var local: bool = resource.begins_with("local:")
	if local and (_planet().is_empty() or not station_details.is_visible_in_tree()):
		resource_hover_panel.hide()
		hovered_resource = ""
		return
	var value: String = _local_breakdown(_planet(), resource.trim_prefix("local:")) if local else _resource_breakdown(state, resource)
	if resource_hover_label.text != value:
		resource_hover_label.text = value
	hovered_resource = resource
	var tile_rect: Rect2
	if local:
		tile_rect = population_label.get_parent().get_global_rect() if resource == "local:population" else production_values[resource.trim_prefix("local:")]["row"].get_global_rect()
	else:
		tile_rect = global_resource_tiles[resource].get_global_rect()
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(420.0, viewport.x - 16.0)
	var available: float = tile_rect.position.y - 8.0 if local else viewport.y - tile_rect.end.y - 8.0
	var height: float = minf(maxf(40.0, available), maxf(105.0, 20.0 * float(value.count("\n") + 2)))
	resource_hover_panel.size = Vector2(width, height).round()
	var popup_y: float = tile_rect.position.y - height if local else tile_rect.end.y
	resource_hover_panel.global_position = Vector2(clampf(tile_rect.position.x, 8.0, viewport.x - width - 8.0), clampf(popup_y, 8.0, maxf(8.0, viewport.y - height - 8.0))).round()
	resource_hover_panel.show()

func _refresh_global_bar(state: Dictionary) -> void:
	year_label.text = "%d A.D." % ECONOMY.current_year(state)
	var totals: Dictionary = ECONOMY.empire_totals(state, _me())
	for resource in ECONOMY.RESOURCES:
		var value: float = float(totals["resources"][resource])
		var annual: float = _empire_resource_delta(state, resource)
		global_resource_labels[resource].text = _tons(value, 0, true)
		_set_resource_delta(global_resource_delta_labels[resource], annual, true)
		var stored: float = float(totals["stock"][resource])
		var reference: float = float(totals["storage_reference"][resource])
		global_resource_fills[resource] = clampf(stored / reference, 0.0, 1.0) if reference > 0.0 else 0.0
		var tile: PanelContainer = global_resource_tiles[resource]
		var segments: Array = []
		if stored > ECONOMY.EPS:
			for i in range(state.get("planets", []).size()):
				var planet: Dictionary = state["planets"][i]
				if int(planet["owner"]) != _me():
					continue
				var quantity: float = float(planet["stock"][resource])
				if quantity > 0.0:
					segments.append({"name": _system_name(i), "share": quantity / stored, "index": i})
			segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
		global_resource_segments[resource] = segments
		global_resource_strips[resource].queue_redraw()
		tile.tooltip_text = ""
	global_population_label.text = "%s" % _compact_amount(float(totals["population"]))
	var population_total: float = float(totals["population"])
	var population_segments: Array = []
	var population_net: float = 0.0
	var population_ceiling: float = 0.0
	for i in range(state.get("planets", []).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != _me():
			continue
		population_ceiling += ECONOMY.sustainable_population_capacity(p)
		population_net += float(p.get("demographic_rate", ECONOMY.population_growth(p)))
		if population_total > 0.0 and float(p["population"]) > 0.0:
			population_segments.append({"name": _system_name(i), "share": float(p["population"]) / population_total, "index": i})
	var fleet_population: float = float(totals["ship_population"]) + float(totals["embarking_population"])
	if fleet_population > 0.0 and population_total > 0.0:
		population_segments.append({"name": "Fleet", "share": fleet_population / population_total, "index": -1, "color": Color("#5b90ba")})
	population_ceiling += fleet_population
	population_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
	global_population_label.text = "%s (%+.0f/yr)" % [_compact_amount(population_total), population_net]
	global_population_label.tooltip_text = ""
	global_resource_segments["population"] = population_segments
	global_resource_fills["population"] = clampf(population_total / maxf(ECONOMY.EPS, population_ceiling), 0.0, 1.0)
	global_resource_strips["population"].queue_redraw()

func _inspector_page(title_text: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title_text
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station_trade.add_child(scroll)
	var page_content := VBoxContainer.new()
	page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_theme_constant_override("separation", 5)
	scroll.add_child(page_content)
	var page := GridContainer.new()
	page.add_theme_constant_override("h_separation", 5)
	page.add_theme_constant_override("v_separation", 2)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_child(page)
	command_grids[title_text] = page
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	station_trade.add_child(footer)
	station_trade_back = _button("", _station_card_to.bind("primary"), footer)
	_yard_ability_face(station_trade_back, "Return", _station_command_icon("return"))
	_register_command_hotkey(station_trade_back, KEY_ESCAPE, "Station Trade", "trade_return", "Return")
	station_trade_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	return page

func _compact_trade_check(check: CheckBox) -> void:
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBox = check.get_theme_stylebox(style_name).duplicate()
		style.set_content_margin_all(0)
		check.add_theme_stylebox_override(style_name, style)
	# Native-size boxes with a high-contrast empty outline on the dark HUD.
	if trade_check_icons.is_empty():
		for state_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
			var checked: bool = state_name.begins_with("checked")
			var disabled: bool = state_name.ends_with("disabled")
			var fill: String = "#b9c8d6" if checked else "#122536"
			var edge: String = "#a3cce4" if not disabled else "#677f90"
			if disabled and checked:
				fill = "#677f90"
			var mark: String = '<path d="M3.5 7L6 9.5L10.5 4.5" fill="none" stroke="#102335" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' if checked else ""
			var image := Image.new()
			image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14"><rect x="1" y="1" width="12" height="12" rx="1.5" fill="%s" stroke="%s" stroke-width="1.5"/>%s</svg>' % [fill, edge, mark])
			trade_check_icons[state_name] = ImageTexture.create_from_image(image)
	for state_name in trade_check_icons:
		check.add_theme_icon_override(state_name, trade_check_icons[state_name])

func _state() -> Dictionary:
	return session.get("economy")

func _planet() -> Dictionary:
	var planets: Array = _state().get("planets", [])
	if selected < 0 or selected >= planets.size():
		return {}
	return planets[selected]

func _me() -> int:
	return 1 if bool(session.get("is_solo")) else multiplayer.get_unique_id()

func _load_thresholds() -> void:
	var p: Dictionary = _planet()
	if p.is_empty():
		return
	for resource in ECONOMY.RESOURCES:
		var t: Dictionary = p["thresholds"][resource]
		var slider: TradeRange = trade_sliders[resource]
		slider.set_range(float(t["min"]), float(t["max"]))
	_update_trade_stock(p)

func _update_trade_stock(p: Dictionary) -> void:
	for resource in ECONOMY.RESOURCES:
		var slider: TradeRange = trade_sliders[resource]
		var stock: float = float(p["stock"][resource])
		var capacity: float = ECONOMY.storage_capacity(p)
		slider.set_stock(stock, capacity, HUD.COLORS[resource])
		trade_stock_labels[resource].text = "%s / %s" % [_tons(stock, 1, true), _tons(capacity, 0, true)]
		trade_stock_labels[resource].tooltip_text = "%.1f / %.0f t" % [stock, capacity]
		slider.tooltip_text = "Import below the left handle; export above the right handle. 100%% = %.0f units." % capacity
		# Preserve this handle while dragging, even when a snapshot arrives.
		if slider.active_handle < 0:
			var t: Dictionary = p["thresholds"][resource]
			slider.import_enabled = bool(t.get("import", true))
			slider.export_enabled = bool(t.get("export", true))
			trade_checks[resource][0].set_pressed_no_signal(slider.import_enabled)
			trade_checks[resource][1].set_pressed_no_signal(slider.export_enabled)
			trade_checks[resource][0].text = "Import %d%%" % roundi(float(t["min"]))
			trade_checks[resource][1].text = "Export %d%%" % roundi(float(t["max"]))
			slider.queue_redraw()
			if not is_equal_approx(slider.lower, float(t["min"])) or not is_equal_approx(slider.upper, float(t["max"])):
				slider.set_range(float(t["min"]), float(t["max"]))

func _apply_thresholds(minimum: float, maximum: float, resource: String) -> void:
	var slider: TradeRange = trade_sliders[resource]
	session.call("request_thresholds", selected, resource, minimum, maximum, slider.import_enabled, slider.export_enabled)

func _trade_toggle(_pressed: bool, resource: String) -> void:
	var slider: TradeRange = trade_sliders[resource]
	slider.import_enabled = trade_checks[resource][0].button_pressed
	slider.export_enabled = trade_checks[resource][1].button_pressed
	if slider.import_enabled and slider.export_enabled and slider.lower > slider.upper:
		slider.upper = slider.lower
	slider.queue_redraw()
	_apply_thresholds(slider.lower, slider.upper, resource)

func _operation(kind: String, target: String = "") -> void:
	if building_selection_kind == "station" and selected_buildings.size() > 1:
		var state: Dictionary = _state()
		for ref in selected_buildings:
			if _building_valid(state, ref, "station") and int(state["planets"][ref.x]["owner"]) == _me():
				var local_target: String = target
				if kind == "economy" and target == "housing":
					local_target = "habitation" if ECONOMY.has_planets(state["planets"][ref.x]) else "orbital_housing"
				session.call("request_operation", ref.x, kind, local_target)
		return
	if kind == "economy" and target == "housing":
		target = "habitation" if ECONOMY.has_planets(_planet()) else "orbital_housing"
	session.call("request_operation", selected, kind, target)

func _cancel_job(id: int) -> void:
	session.call("request_cancel", selected, id)

func _refresh() -> void:
	# A disconnect notification can arrive while the match scene exits.
	if not is_inside_tree() or multiplayer == null:
		return
	if is_instance_valid(map_canvas):
		map_canvas.queue_redraw()
	if not is_instance_valid(year_label):
		return
	var state: Dictionary = _state()
	pose_frame = -1
	_sync_command_kind(state)
	var phase: String = str(session.get("phase"))
	if phase == "match" and not background_music.playing:
		background_music.play()
	elif phase != "match" and background_music.playing:
		background_music.stop()
	_refresh_global_bar(state)
	_refresh_conquest_button(state)
	if is_instance_valid(empire_dialog) and empire_dialog.visible:
		_refresh_empire(state)
	_refresh_match_result(state)
	_refresh_time_controls(state)
	menu_exit.text = "Main menu" if bool(session.get("is_solo")) else ("Return to lobby" if multiplayer.is_server() else "Leave match")
	if phase == "loading" and multiplayer.is_server():
		menu_exit.text = "Cancel start"
	var planets: Array = state.get("planets", [])
	if not initial_selection_done and not planets.is_empty():
		for i in range(planets.size()):
			if int(planets[i]["owner"]) == _me() and bool(planets[i].get("home", false)):
				initial_selection_done = true
				selected = i
				control_groups[1] = {"kind": "station", "refs": {Vector2i(i, 0): 0}}
				if not planets[i]["yards"].is_empty():
					control_groups[2] = {"kind": "shipyard", "refs": {Vector2i(i, 0): planets[i]["yards"].size()}}
				# Center the initial camera on the player's home system.
				_frame_starting_sector(i)
				# The first snapshot can arrive before the HUD containers have
				# settled; frame again using the final unobstructed viewport.
				call_deferred("_frame_starting_sector", i)
				_load_thresholds()
				break
	var ship: Dictionary = _selected_ship(state)
	var living: Array[int] = []
	for craft in state.get("ships", []):
		if selected_units.has(int(craft["id"])) and _ship_visible(state, craft):
			living.append(int(craft["id"]))
	selected_units = living
	_refresh_control_groups(state)
	if ship.is_empty():
		selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
		ship = _selected_ship(state)
	_prune_building_selection(state)
	var p: Dictionary = _planet()
	var field_selected: bool = selected_field >= 0 and ECONOMY.discovered(state, _me(), "fields", selected_field)
	var ship_selected: bool = not ship.is_empty()
	if not ship_selected and not field_selected and p.is_empty():
		follow_units = false
	var other_selected: bool = ship_selected or field_selected
	var body_selected: bool = not other_selected and not p.is_empty() and selected_body >= 0 and selected_body < int(p.get("planet_count", 0))
	if not body_selected:
		selected_body = -1
	# Slot indices compact after destruction. Return to the system rather
	# than silently retargeting an upgrade at a different shipyard.
	var yard_selected: bool = not other_selected and not body_selected and not p.is_empty() and selected_yard >= 0 and selected_yard < p.get("yards", []).size() and selected_yard_count == p.get("yards", []).size()
	if not yard_selected:
		if selected_yard >= 0:
			follow_units = false
		selected_yard = -1
	# A claimed sector is represented by its station, not a second selectable
	# sector entity. Keep explicit planet, yard and grouped selections intact.
	if not other_selected and not body_selected and not yard_selected and not p.is_empty() and building_selection_kind.is_empty():
		if ECONOMY.has_station(p):
			building_selection_kind = "station"
			selected_buildings[Vector2i(selected, 0)] = 0
		elif int(p["owner"]) != 0:
			selected = -1
			p = {}
	inspector_panel.visible = true
	overview_panel.visible = not p.is_empty() or other_selected
	empty_selection.visible = false
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_overview.visible = not p.is_empty() and not other_selected and not body_selected and not yard_selected and selected_buildings.size() <= 1
	var grouped_buildings: bool = selected_buildings.size() > 1
	_refresh_selection_portrait(ship, p, body_selected, yard_selected, grouped_buildings)
	_refresh_weapon_details(ship, p, body_selected, yard_selected, grouped_buildings)
	body_overview.visible = body_selected and not grouped_buildings
	yard_overview.visible = yard_selected and not grouped_buildings
	_refresh_building_group(state)
	var own_system: bool = not p.is_empty() and int(p.get("owner", -1)) == _me()
	var owned_station: bool = not other_selected and not body_selected and not yard_selected and own_system and ECONOMY.has_station(p)
	var right_needed: bool = field_selected or (ship_selected and state["ships"].any(func(craft: Dictionary) -> bool: return selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me())) or (yard_selected and not _selected_yards(state, true).is_empty()) or owned_station or (not other_selected and not yard_selected and not body_selected and not grouped_buildings and not p.is_empty() and int(p["owner"]) == 0)
	console_right_body.visible = right_needed
	inspector_panel.self_modulate.a = 1.0 if right_needed else 0.0
	inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP if right_needed else Control.MOUSE_FILTER_IGNORE
	console_profile.queue_redraw()
	station_commands.visible = owned_station
	var station_index: int = selected if owned_station else -1
	if station_index != station_selected_index:
		station_selected_index = station_index
		station_card = "primary"
	_sync_station_card()
	yard_command_scroll.visible = yard_selected
	interaction_scroll.visible = not other_selected and not body_selected and not yard_selected and not p.is_empty() and int(p["owner"]) == 0 and not grouped_buildings
	ship_overview.visible = other_selected
	ship_population.get_parent().hide()
	ship_title.visible = other_selected
	ship_detail.visible = other_selected
	_refresh_selection_tiles(state)
	if not ship_selected and not (yard_selected and not _selected_yards(state, true).is_empty() and pending_command == "rally"):
		pending_command = ""
		_refresh_command_mode()
	fleet_scroll.visible = other_selected
	fleet_overview.visible = other_selected
	field_command_grid.visible = field_selected
	fleet_title.visible = other_selected
	fleet_detail.visible = other_selected
	fleet_cargo_footer.hide()
	station_queue_panel.hide()
	if yard_selected:
		_refresh_yard_overview(p, own_system and phase == "match")
		if grouped_buildings:
			_refresh_group_yard_commands(state)
		else:
			var yard_level: int = int(p["yards"][selected_yard]["level"])
			_layout_yard_classes(yard_level, yard_level == 1, yard_level == 2)
		return
	if body_selected:
		if not grouped_buildings:
			_refresh_body_overview(p)
		return
	if field_selected:
		_refresh_field_panels(state)
		return
	if ship_selected:
		_refresh_ship_panels(state, ship)
		return
	var owned: bool = not p.is_empty() and int(p["owner"]) == _me() and phase == "match"
	_refresh_colony_choices(state, p, phase)
	for slider in trade_sliders.values():
		slider.enabled = owned
		for resource in trade_checks:
			for check in trade_checks[resource]:
				check.disabled = not owned
		if not owned:
			slider.active_handle = -1
		slider.queue_redraw()
	if p.is_empty():
		info.text = "Select a system."
		raw_antimatter_label.hide()
		system_owner_label.text = ""
		population_label.text = ""
		population_delta_label.text = ""
		return
	var owner: int = int(p["owner"])
	var roster: Dictionary = session.get("players")
	var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
	info.text = ("Space Station · " if building_selection_kind == "station" else "") + _system_name(selected)
	info.tooltip_text = info.text + (" · Home" if bool(p["home"]) else "")
	if ECONOMY.has_station(p):
		info.tooltip_text += "\nSpace Station · %.0f / %.0f HP" % [float(p["station"]["hp"]), ECONOMY.station_max_hp(p)]
	system_owner_label.text = name_text
	system_owner_label.tooltip_text = name_text
	system_owner_label.add_theme_color_override("font_color", _empire_color(owner).lerp(HUD.MUTED, 0.28))
	for resource in ECONOMY.RESOURCES:
		var amount: float = float(p["stock"][resource])
		production_values[resource]["stock"].text = _tons(amount)
		production_values[resource]["level"].text = str(int(p["levels"][resource]) + int(p.get("buildings", {}).get(resource, 0)))
		var percent: int = roundi(100.0 * ECONOMY.production_modifier(p, resource))
		var bonus: Label = production_values[resource]["bonus"]
		bonus.text = "—" if percent == 100 else "%d%%" % (percent - 100) if percent < 100 else "+%d%%" % (percent - 100)
		bonus.add_theme_color_override("font_color", HUD.ACCENT if percent > 100 else (Color("#e4a479") if percent < 100 else HUD.MUTED))
		var annual: float = _resource_delta(p, resource)
		var delta_label: Label = production_values[resource]["rate"]
		_set_resource_delta(delta_label, annual)
	var population: float = float(p["population"])
	var raw: float = float(p["stock"].get(ECONOMY.ANTIMATTER, 0.0))
	raw_antimatter_label.visible = raw > ECONOMY.EPS
	raw_antimatter_label.text = "Raw antimatter · %s" % _tons(raw)
	raw_antimatter_label.tooltip_text = "%.1f t stored locally" % raw
	population_label.text = "%s" % _compact_amount(population)
	var change: float = float(p.get("demographic_rate", ECONOMY.population_growth(p))) - float(p.get("crew_rate", 0.0))
	population_delta_label.text = "(%s%s/yr)" % ["+" if change >= 0.0 else "-", _compact_amount(absf(change))]
	population_delta_label.add_theme_color_override("font_color", Color("#7cdb9b") if change >= 0.0 else Color("#eb8585"))
	population_label.tooltip_text = ""
	_update_trade_stock(p)
	if building_selection_kind == "station" and not grouped_buildings:
		_refresh_station_queue(p, owned)
	if owned_station:
		_refresh_station_primary(p, owned)
		_refresh_station_build(p, owned)

func _job_name(item: Dictionary) -> String:
	match str(item["kind"]):
		"ship": return "Freighter"
		"economy_building": return str(ECONOMY.ECONOMY_BUILDINGS[item["target"]]["name"])
		"warehouse": return "Warehouse logistics → Lv %d" % int(item["level"])
		"habitation": return "Habitation technology → Lv %d" % int(item["level"])
		"orbital_housing": return "Orbital Eco-Housing"
		"pds": return "PDS"
		"yard": return "Build Shipyard %d" % int(item.get("station_slot", item["level"]))
		"yard_upgrade": return "Shipyard %d → Lv %d" % [ECONOMY.shipyard_port(_planet(), int(item["target"])), int(item["level"])]
		"reinforced_plating": return "Reinforced Plating"
		"laser_matrix": return "Laser Matrix"
		"production": return "%s → Lv %d" % [str(item["target"]), int(item["level"])]
		_: return str(item["kind"]).replace("_", " ").capitalize()

func _system_name(index: int) -> String:
	var names: Array = _state().get("map", {}).get("names", [])
	return str(names[index]) if index >= 0 and index < names.size() else "Unknown"

func _load_settings() -> void:
	settings.load("user://warbound_settings.cfg")
	# Ignore obsolete scaling preferences from earlier releases.
	if settings.has_section_key("interface", "scale"):
		settings.erase_section_key("interface", "scale")
	music_volume = clampf(float(settings.get_value("audio", "music", 100.0)), 0.0, 100.0)
	sfx_volume = clampf(float(settings.get_value("audio", "sfx", 100.0)), 0.0, 100.0)
	music_muted = bool(settings.get_value("audio", "music_muted", false))
	sfx_muted = bool(settings.get_value("audio", "sfx_muted", false))
	keyboard_pan_percent = clampf(float(settings.get_value("camera", "keyboard_pan", 100.0)), 0.0, 250.0)
	mouse_pan_percent = clampf(float(settings.get_value("camera", "edge_pan", 100.0)), 0.0, 250.0)
	wheel_zoom_percent = clampf(float(settings.get_value("camera", "wheel_zoom", 100.0)), 25.0, 250.0)

func _apply_settings() -> void:
	for bus_name in ["Music", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		var volume: float = music_volume if bus_name == "Music" else sfx_volume
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume / 100.0)))
		AudioServer.set_bus_mute(index, music_muted if bus_name == "Music" else sfx_muted)
	background_music.bus = "Music"

func _save_settings() -> void:
	settings.set_value("audio", "music", music_volume)
	settings.set_value("audio", "sfx", sfx_volume)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("audio", "sfx_muted", sfx_muted)
	settings.set_value("camera", "keyboard_pan", keyboard_pan_percent)
	settings.set_value("camera", "edge_pan", mouse_pan_percent)
	settings.set_value("camera", "wheel_zoom", wheel_zoom_percent)
	if settings.has_section("hotkeys"):
		settings.erase_section("hotkeys")
	for id in hotkey_overrides:
		settings.set_value("hotkeys", id, hotkey_overrides[id])
	settings.save("user://warbound_settings.cfg")
	_apply_settings()

func _build_settings_menu() -> void:
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	options.custom_minimum_size.x = 340
	match_menu.add_child(options)
	for channel in ["Music", "SFX"]:
		var row := HBoxContainer.new()
		options.add_child(row)
		row.add_theme_constant_override("separation", 10)
		var channel_label := _label(channel, 14)
		channel_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		channel_label.custom_minimum_size.x = 64
		channel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(channel_label)
		var volume := HSlider.new()
		volume.max_value = 100.0
		volume.step = 1.0
		volume.value = music_volume if channel == "Music" else sfx_volume
		volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		volume.custom_minimum_size = Vector2(120, 24)
		row.add_child(volume)
		var mute := Button.new()
		mute.toggle_mode = true
		mute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mute.custom_minimum_size = Vector2(36, 30)
		mute.button_pressed = music_muted if channel == "Music" else sfx_muted
		_set_mute_icon(mute, mute.button_pressed)
		row.add_child(mute)
		volume.value_changed.connect(_audio_volume_changed.bind(channel))
		mute.toggled.connect(func(value: bool) -> void:
			_set_mute_icon(mute, value)
			_audio_mute_changed(value, channel))
	options.add_child(HSeparator.new())
	_add_camera_setting(options, "Keyboard scroll speed", "keyboard", keyboard_pan_percent, 0.0)
	_add_camera_setting(options, "Mouse edge scroll speed", "edge", mouse_pan_percent, 0.0)
	_add_camera_setting(options, "Mouse wheel zoom speed", "wheel", wheel_zoom_percent, 25.0)
	_button("Hotkeys…", _open_hotkey_editor, options)

func _add_camera_setting(parent: Container, title_text: String, kind: String, initial: float, minimum: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := _label(title_text, 13)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.custom_minimum_size.x = 170
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = 250.0
	slider.step = 5.0
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100, 24)
	row.add_child(slider)
	var value_label := _label("%d%%" % roundi(initial), 12)
	value_label.custom_minimum_size.x = 45
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % roundi(value)
		match kind:
			"keyboard": keyboard_pan_percent = value
			"edge": mouse_pan_percent = value
			"wheel": wheel_zoom_percent = value
		_save_settings())

func _open_hotkey_editor() -> void:
	if not is_instance_valid(hotkey_dialog):
		hotkey_dialog = AcceptDialog.new()
		hotkey_dialog.title = "Hotkeys"
		hotkey_dialog.theme = theme
		hotkey_dialog.exclusive = true
		hotkey_dialog.transient = true
		hotkey_dialog.unresizable = true
		hotkey_dialog.ok_button_text = "Done"
		match_menu.add_child(hotkey_dialog)
		var body := VBoxContainer.new()
		hotkey_dialog.add_child(body)
		body.add_child(_label("Choose a key for each command. Keys may be reused on different cards.", 13))
		var viewport_size: Vector2 = get_viewport_rect().size
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(minf(510.0, viewport_size.x - 70.0), clampf(viewport_size.y - 230.0, 120.0, 380.0))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		for scope in ["General", "Fleet", "Shipyard", "Station", "Station Build", "Station Trade", "Asteroid Field"]:
			var heading := _label(scope.to_upper(), 13)
			heading.add_theme_color_override("font_color", HUD.ACCENT)
			rows.add_child(heading)
			for id in hotkey_entries:
				var entry: Dictionary = hotkey_entries[id]
				if entry["scope"] != scope:
					continue
				var row := HBoxContainer.new()
				rows.add_child(row)
				var caption := _label(str(entry["title"]), 13)
				caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(caption)
				var picker := OptionButton.new()
				picker.custom_minimum_size.x = 92
				var default_key: int = int(entry["default"])
				if default_key == KEY_ESCAPE:
					picker.add_item("Esc (fixed)", KEY_ESCAPE)
					picker.disabled = true
				else:
					for key in range(KEY_A, KEY_Z + 1):
						picker.add_item(_hotkey_name(key), key)
					for key in range(KEY_F1, KEY_F12 + 1):
						picker.add_item(_hotkey_name(key), key)
				row.add_child(picker)
				hotkey_pickers[id] = picker
				picker.item_selected.connect(_hotkey_changed.bind(str(id), picker))
		body.add_child(_label("Fixed: arrow keys, Esc, 0–9 control groups and mouse gestures.", 12))
		hotkey_status = _label("", 13)
		hotkey_status.custom_minimum_size.y = 26
		body.add_child(hotkey_status)
		_button("Reset all to defaults", _reset_hotkeys, body)
	_refresh_hotkey_pickers()
	hotkey_status.text = ""
	hotkey_dialog.popup_centered()

func _refresh_hotkey_pickers() -> void:
	for id in hotkey_pickers:
		var picker: OptionButton = hotkey_pickers[id]
		var index: int = picker.get_item_index(_hotkey_value(id, hotkey_overrides))
		if index >= 0:
			picker.select(index)

func _hotkey_changed(index: int, id: String, picker: OptionButton) -> void:
	var key: int = picker.get_item_id(index)
	var conflict: String = _hotkey_conflict(id, key, hotkey_overrides)
	if not conflict.is_empty():
		hotkey_status.text = "%s is already assigned to %s." % [_hotkey_name(key), conflict]
		_refresh_hotkey_pickers()
		return
	if key == int(hotkey_entries[id]["default"]):
		hotkey_overrides.erase(id)
	else:
		hotkey_overrides[id] = key
	_sync_hotkey_bindings()
	_save_settings()
	hotkey_status.text = "Saved."

func _reset_hotkeys() -> void:
	hotkey_overrides.clear()
	_sync_hotkey_bindings()
	_refresh_hotkey_pickers()
	_save_settings()
	hotkey_status.text = "Default hotkeys restored."

func _set_mute_icon(button: Button, muted: bool) -> void:
	var speaker: String = '<path d="M4 12H10L17 6V26L10 20H4Z"/>'
	button.icon = _command_icon(speaker + ('<path d="M4 29L29 4"/>' if muted else '<path d="M21 11Q27 16 21 21M25 7Q32 16 25 25"/>'))
	_set_button_hint(button, "Unmute" if muted else "Mute")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)

func _audio_volume_changed(value: float, channel: String) -> void:
	if channel == "Music":
		music_volume = value
	else:
		sfx_volume = value
	_save_settings()

func _audio_mute_changed(value: bool, channel: String) -> void:
	if channel == "Music":
		music_muted = value
	else:
		sfx_muted = value
	_save_settings()

func _refresh_match_result(state: Dictionary) -> void:
	if not is_instance_valid(match_result_dialog):
		return
	var result: Dictionary = state.get("match_result", {})
	if not result.is_empty() and not match_result_shown:
		match_result_shown = true
		if is_instance_valid(codex):
			codex.hide()
		var team: int = int(result["team"])
		var mine: int = int(state.get("teams", {}).get(_me(), 0))
		match_result_dialog.title = "Draw" if team == 0 else ("Victory" if mine == team else "Defeat")
		match_result_dialog.dialog_text = "No surviving teams." if team == 0 else "Team %d wins by conquest." % team
		match_result_dialog.ok_button_text = "Review map"
		match_result_dialog.popup_centered.call_deferred(Vector2i(320, 140))
	elif result.is_empty() and state.get("eliminated", []).has(_me()) and not defeated_shown:
		defeated_shown = true
		if is_instance_valid(codex):
			codex.hide()
		match_result_dialog.title = "Empire defeated"
		match_result_dialog.dialog_text = "Your empire has no remaining settlement or Colony."
		match_result_dialog.ok_button_text = "Observe match"
		match_result_dialog.popup_centered.call_deferred(Vector2i(320, 140))

func _open_codex() -> void:
	if match_menu.visible or codex.visible:
		return
	drag_button = 0
	formation_button = 0
	selecting_units = false
	pending_command = ""
	_refresh_command_mode()
	resource_hover_panel.hide()
	# Bound both axes by the actual match viewport, not desktop resolution.
	var available: Vector2 = get_viewport_rect().size
	var target := Vector2i(mini(1180, floori(available.x * 0.78)), mini(760, floori(available.y * 0.78)))
	codex.popup_centered(target)

func _open_menu() -> void:
	drag_button = 0
	match_menu.popup_centered(Vector2i(460, 350))

func _menu_action(action: StringName) -> void:
	if action == &"leave":
		match_menu.hide()
		_leave()

func _leave() -> void:
	if bool(session.get("is_solo")):
		session.call("leave_solo")
	elif multiplayer.is_server():
		if str(session.get("phase")) == "loading":
			session.call("cancel_loading")
		else:
			session.call("return_to_lobby")
	else:
		session.call("leave_session")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _refresh_colony_choices(state: Dictionary, p: Dictionary, phase: String) -> void:
	var neutral: bool = not p.is_empty() and int(p.get("owner", -1)) == 0 and phase == "match"
	send_colony_button.visible = neutral
	var id: int = ECONOMY.nearest_idle_colony(state, _me(), selected) if neutral else -1
	send_colony_button.disabled = id < 0
	_set_button_hint(send_colony_button, "Send nearest idle Colony to this sector" if id >= 0 else "No available idle Colonies")

func _send_colony() -> void:
	if not send_colony_button.disabled:
		# -1 requests authoritative nearest-idle selection.
		session.call("request_colonize", -1, selected)

func _reset_view() -> void:
	follow_units = false
	zoom = 1.0
	camera_world = Vector2.INF
	map_canvas.queue_redraw()

# The bottom console reserves a fixed viewport, independent of selection.
func _projection_size() -> Vector2:
	# Reserve the console footprint for camera framing, but let stars and
	# planets continue rendering underneath its opaque stepped panels.
	var hud_height: float = console_panel.size.y + 8.0 if is_instance_valid(console_panel) else 0.0
	return Vector2(map_canvas.size.x, maxf(1.0, map_canvas.size.y - hud_height))

func _map_resized() -> void:
	_layout_conquest_button()
	_layout_match_chat()
	# The world-space center is independent of screen dimensions.
	zoom = minf(zoom, _max_zoom())
	map_canvas.queue_redraw()

func _map_size() -> Vector2:
	return _state().get("map", {}).get("size", MAP.SIZE)

func _fit() -> float:
	var area: Vector2 = _projection_size() - Vector2(24, 52)
	var bounds: Vector2 = _map_size()
	return maxf(0.0001, minf(area.x / bounds.x, area.y / bounds.y))

func _screen_point(point: Vector2) -> Vector2:
	return _camera_center() + (point - _camera_world_center()) * _fit() * zoom

func _world_point(point: Vector2) -> Vector2:
	return _camera_world_center() + (point - _camera_center()) / (_fit() * zoom)

func _camera_world_center() -> Vector2:
	return camera_world if camera_world.is_finite() else _map_size() * 0.5

func _camera_center() -> Vector2:
	return _projection_size() * 0.5

func _max_zoom() -> float:
	# Scale the close-up ceiling to the actual viewport and map fit. At
	# maximum zoom a fighter is 60% of the full viewport width long.
	var base_scale: float = maxf(0.0001, minf(SHIP_WORLD_SCALE * _fit() * OVERVIEW_MAX_ZOOM, 1.25))
	var target_scale: float = size.x * CLOSEUP_SCREEN_FRACTION / FIGHTER_HULL_LENGTH
	return OVERVIEW_MAX_ZOOM * maxf(1.0, target_scale / base_scale)

func _zoom_at(point: Vector2, direction: float) -> void:
	var anchor: Vector2 = _camera_center() if follow_units else point
	var world: Vector2 = _world_point(anchor)
	var maximum: float = _max_zoom()
	# Step in log space, with progressively finer percentage changes as
	# the camera approaches its close-up limit (reversible in either direction).
	var log_span: float = log(maximum / MIN_ZOOM)
	var log_zoom: float = log(zoom / MIN_ZOOM)
	var rate: float = (0.25 - 0.06) / log_span
	var limit: float = 0.25 / rate
	var next_log: float = limit - (limit - log_zoom) * exp(-rate * direction)
	zoom = clampf(MIN_ZOOM * exp(next_log), MIN_ZOOM, maximum)
	camera_world = world - (anchor - _camera_center()) / (_fit() * zoom)
	map_canvas.queue_redraw()

func _system_visual(index: int, state: Dictionary) -> Dictionary:
	var seed_value: int = int(state["map"]["seed"])
	if system_visual_seed != seed_value:
		system_visual_seed = seed_value
		system_visuals.clear()
	if not system_visuals.has(index):
		var points: Array = state["map"]["points"]
		var closest: float = INF
		for i in range(points.size()):
			if i != index:
				closest = minf(closest, (points[index] as Vector2).distance_to(points[i]))
		system_visuals[index] = {"bodies": ECONOMY.system_bodies(state["planets"][index], seed_value, index), "spacing": closest}
	return system_visuals[index]

func _planet_radius(index: int, state: Dictionary) -> float:
	return _system_world_radius(index, state) * _fit() * zoom

func _system_world_radius(index: int, state: Dictionary) -> float:
	var ideal: float = SYSTEM_WORLD_RADIUS * float(state["planets"][index].get("size_factor", 1.0))
	return minf(ideal, float(_system_visual(index, state)["spacing"]) * 0.39)

func _planet_detail_target(radius: float) -> float:
	return smoothstep(PLANET_FADE_START, PLANET_FADE_FULL, radius)

func _planet_detail_opacity(index: int, radius: float) -> float:
	return float(planet_detail_alpha.get(index, _planet_detail_target(radius)))

func _update_planet_detail(state: Dictionary, delta: float) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if planet_detail_seed != seed_value:
		planet_detail_alpha.clear()
		planet_detail_seed = seed_value
	for index in range(state["planets"].size()):
		var target: float = _planet_detail_target(_planet_radius(index, state))
		var previous: float = float(planet_detail_alpha.get(index, 0.0))
		planet_detail_alpha[index] = move_toward(previous, target, delta / PLANET_FADE_SECONDS)

func _star_draw_radius(radius: float) -> float:
	# Constant world-space ratio; camera zoom is the only size multiplier.
	return radius * 0.13

func _update_orbit_clock(state: Dictionary, delta: float) -> void:
	var elapsed: float = float(state["elapsed"])
	var seed_value: int = int(state["map"]["seed"])
	var speed: float = float(state.get("time_speed", 1))
	if orbit_seed != seed_value or orbit_visual_time < 0.0 or elapsed < orbit_sample_time or speed <= 0.0 or not state.get("match_result", {}).is_empty():
		orbit_seed = seed_value
		orbit_visual_time = elapsed
		orbit_sample_time = elapsed
		orbit_sample_age = 0.0
		return
	if elapsed != orbit_sample_time:
		orbit_sample_time = elapsed
		orbit_sample_age = 0.0
	else:
		orbit_sample_age += delta
	# Predict only a bounded interval; gently converge on authoritative time.
	var target: float = elapsed + minf(orbit_sample_age, 0.6) * speed
	var correction: float = clampf((target - orbit_visual_time) * 4.0, -speed, speed * 2.0)
	orbit_visual_time = minf(maxf(orbit_visual_time, target), orbit_visual_time + delta * maxf(0.0, speed + correction))

func _orbit_time(state: Dictionary) -> float:
	return orbit_visual_time if orbit_visual_time >= 0.0 and orbit_seed == int(state["map"]["seed"]) else float(state["elapsed"])

func _body_position(body: Dictionary, radius: float, time: float) -> Vector2:
	return ECONOMY.body_position(body, radius, time)

func _draw_elliptical_orbit(center: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for step in range(65):
		var angle: float = TAU * float(step) / 64.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.65))
	map_canvas.draw_polyline(points, tint, 0.8, true)

# Resource palettes use strong surface hues, not UI icon tints.
func _body_base_color(body: Dictionary) -> Color:
	var palette: Dictionary = {"Organics": Color("#52a452"), "Metals": Color("#a3a7ad"), "Crystals": Color("#a16bda")}
	var material: String = str(body["resource"])
	var base: Color = palette.get(material, HUD.COLORS.get(material, Color("#7d8b9b")))
	return base.lerp(Color("#7b8790"), float(body["muted"]) * (0.22 if not material.is_empty() else 0.65))

# Generate a unique shaded surface once per visible body; no separate highlight dot.
func _body_texture(body: Dictionary) -> Texture2D:
	if body.has("texture"):
		return body["texture"]
	var noise := FastNoiseLite.new()
	noise.seed = int(body["surface_seed"])
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var base: Color = _body_base_color(body)
	var highlight: Color = base.lightened(0.48)
	var light := Vector3(-0.55, -0.45, 0.70).normalized()
	var angle: float = float(body["surface_angle"])
	var bands: bool = bool(body["bands"])
	for y in range(96):
		for x in range(96):
			var q := (Vector2(x + 0.5, y + 0.5) - Vector2(48, 48)) / 47.0
			var rr: float = q.length_squared()
			if rr >= 1.0:
				continue
			var z: float = sqrt(1.0 - rr)
			var uv: Vector2 = q.rotated(angle)
			var grain: float = noise.get_noise_2d(uv.x * 90.0 + 300.0 * z, uv.y * 90.0)
			var terrain: float = grain * 0.7
			if bands:
				terrain = sin(uv.y * 29.0 + grain * 2.0) * 0.24 + grain * 0.2
			var diffuse: float = maxf(0.0, Vector3(q.x, q.y, z).dot(light))
			var color: Color = base.lerp(highlight, maxf(0.0, terrain) * 0.7).darkened(clampf(0.74 - diffuse * 0.64 - terrain * 0.18, 0.0, 0.85))
			color.a = clampf((1.0 - sqrt(rr)) * 47.0, 0.0, 1.0)
			image.set_pixel(x, y, color)
	body["texture"] = ImageTexture.create_from_image(image)
	return body["texture"]

# Bake two photosphere/corona textures once per match. Every star shares
# its temperature-class texture with its own rotation and small color tint.
# No per-frame noise, particle nodes, network state or random simulation calls.
func _star_texture(cool: bool) -> Texture2D:
	if star_textures.has(cool):
		return star_textures[cool]
	var noise := FastNoiseLite.new()
	noise.seed = 91813 if cool else 41207
	noise.frequency = 0.047
	noise.fractal_octaves = 4
	var image := Image.create(STAR_TEXTURE_SIZE, STAR_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var dark := Color("#496c9b") if cool else Color("#c05a25")
	var middle := Color("#a4c7eb") if cool else Color("#ffbf64")
	var bright := Color("#eaf7ff") if cool else Color("#fff8dc")
	var halo := Color("#77a8df") if cool else Color("#f4a752")
	var half: float = float(STAR_TEXTURE_SIZE) * 0.5
	var extent: float = half / STAR_TEXTURE_CORE
	for y in range(STAR_TEXTURE_SIZE):
		for x in range(STAR_TEXTURE_SIZE):
			var q := (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * half) / STAR_TEXTURE_CORE
			var r: float = q.length()
			if r >= extent:
				continue
			# Directional noise breaks the corona into soft, radial filaments.
			var axis: Vector2 = q.normalized()
			var plume: float = clampf(0.5 + noise.get_noise_2d(axis.x * 87.0 + 133.0, axis.y * 87.0) * 1.25, 0.0, 1.0)
			var distance: float = maxf(0.0, r - 1.0)
			var falloff: float = 1.0 - smoothstep(1.0, extent, r)
			var glow: float = (0.15 * exp(-distance * 7.0) + 0.18 * plume * plume * exp(-distance * 4.5)) * falloff
			var coverage: float = 1.0 - smoothstep(1.0 - 1.0 / STAR_TEXTURE_CORE, 1.0 + 1.0 / STAR_TEXTURE_CORE, r)
			var color: Color = halo.lerp(middle, plume * 0.24)
			if coverage > 0.0:
				var z: float = sqrt(maxf(0.0, 1.0 - r * r))
				var surface: Vector2 = q * 105.0 + Vector2(z * 28.0, z * 15.0)
				# Warp the granulation into curved plasma cells and mottled lanes.
				var warp: float = noise.get_noise_2d(surface.x + 320.0, surface.y - 110.0)
				var cells: float = noise.get_noise_2d(surface.x + warp * 23.0, surface.y + warp * 18.0)
				var grain: float = noise.get_noise_2d(surface.x * 2.8 + 580.0, surface.y * 2.8)
				var heat: float = clampf(0.56 + cells * 0.83 + grain * 0.20 + z * 0.11, 0.0, 1.0)
				var core: Color = dark.lerp(middle, smoothstep(0.0, 0.56, heat)).lerp(bright, smoothstep(0.35, 0.98, heat))
				core = core.darkened((1.0 - z) * 0.18)
				color = color.lerp(core, coverage)
			color.a = coverage + glow * (1.0 - coverage)
			if color.a > 0.001:
				image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	star_textures[cool] = texture
	return texture

func _draw_star(index: int, pos: Vector2, radius: float, tint: Color, cool: bool, opacity: float) -> void:
	var viewport := Rect2(Vector2.ZERO, map_canvas.size)
	var extent: float = radius * float(STAR_TEXTURE_SIZE) / (2.0 * STAR_TEXTURE_CORE)
	if not viewport.grow(extent + 3.0).has_point(pos):
		return
	if radius < 2.0:
		# Keep the smallest overview stars clean and cheap.
		map_canvas.draw_circle(pos, maxf(0.75, radius), Color(tint.lightened(0.22), opacity), true, -1.0, true)
		return
	var texture: Texture2D = _star_texture(cool)
	var rotation: float = float(index) * 2.399963 + visual_clock * (0.012 + 0.003 * float(index % 5))
	var modulation: Color = Color.WHITE.lerp(tint.lightened(0.30), 0.20)
	modulation.a = opacity
	map_canvas.draw_set_transform(pos, rotation)
	map_canvas.draw_texture_rect(texture, Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0), false, modulation)
	map_canvas.draw_set_transform(Vector2.ZERO)
	# Analytic, short-lived plasma sparks drift away from the limb.
	# Fade in only at detail zoom; fixed count, no persistent emitters.
	var detail: float = smoothstep(10.0, 32.0, radius)
	if detail <= 0.001:
		return
	for i in range(STAR_SPARK_COUNT):
		var phase: float = float(i) * 0.618034 + float(index) * 0.137
		var age: float = fposmod(visual_clock * (0.16 + float(i % 3) * 0.025) + phase, 1.0)
		var angle: float = phase * TAU * 3.0 + rotation + age * 0.15
		var axis: Vector2 = Vector2.from_angle(angle)
		var point: Vector2 = pos + axis * radius * lerpf(0.98, 1.36, age)
		if not viewport.grow(4.0).has_point(point):
			continue
		var fade: float = sin(age * PI) * detail * opacity
		var spark_size: float = clampf(radius * 0.021, 0.65, 2.1)
		var spark_color: Color = tint.lightened(0.48)
		map_canvas.draw_line(point - axis * minf(5.0, radius * 0.045), point, Color(spark_color, fade * 0.26), maxf(0.7, spark_size * 0.65), true)
		map_canvas.draw_circle(point, spark_size, Color(spark_color, fade * 0.54), true, -1.0, true)

func _planet_production_sources(bodies: Array, resource: String) -> Array:
	var sources: Array = []
	for slot in range(bodies.size()):
		if bodies[slot]["resource"] == resource:
			sources.append(slot)
	if sources.is_empty() and not bodies.is_empty():
		sources.append(0)
	return sources

func _planet_production_rate(system: Dictionary, resource: String) -> float:
	if not ECONOMY.has_station(system) or bool(system.get("planet_blockaded", false)):
		return 0.0
	var output: float = ECONOMY.local_flow(system, "Production", resource)
	if resource == "Organics":
		output = maxf(0.0, output - ECONOMY.eco_organics(system))
	elif resource == "Crystals":
		output = maxf(0.0, output - ECONOMY.STATION_CRYSTALS_PER_YEAR)
	return output

func _draw_planet_production(state: Dictionary, index: int, center: Vector2, radius: float, detail: float) -> void:
	var system: Dictionary = state["planets"][index]
	if detail < 0.05 or not ECONOMY.has_station(system) or bool(system.get("planet_blockaded", false)):
		return
	var bodies: Array = _system_visual(index, state)["bodies"]
	if bodies.is_empty():
		return
	var elapsed: float = _orbit_time(state)
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var output: float = _planet_production_rate(system, resource)
		if output <= ECONOMY.EPS:
			continue
		var sources: Array = _planet_production_sources(bodies, resource)
		var color: Color = HUD.COLORS[resource]
		var bay: int = clampi(floori(float(system["stock"][resource]) / maxf(ECONOMY.EPS, ECONOMY.storage_capacity(system)) * ECONOMY.STATION_STORAGE_BAYS), 0, ECONOMY.STATION_STORAGE_BAYS - 1)
		var destination: Vector2 = _station_bay_point(_screen_point(ECONOMY.station_position(state, index, elapsed)), _station_radius(), elapsed, resource, bay)
		for slot in sources:
			var origin: Vector2 = center + _body_position(bodies[slot], radius, elapsed)
			var count: int = clampi(ceili(sqrt(output / float(sources.size()))), 1, 7)
			for k in range(count):
				var phase: float = fposmod(elapsed * 0.8 + float(k) / float(count) + float(slot) * 0.173, 1.0)
				var point: Vector2 = origin.lerp(destination, phase)
				var alpha: float = detail * smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
				_draw_planet_cargo_pod(point, origin.direction_to(destination), clampf(radius * 0.025, 2.0, 8.0) * 0.25, color, alpha)

func _draw_planet_cargo_pod(point: Vector2, axis: Vector2, size_factor: float, color: Color, alpha: float) -> void:
	var forward: Vector2 = axis * size_factor
	var side: Vector2 = axis.orthogonal() * size_factor
	var hull: PackedVector2Array = _hull_polygon(point, forward, side, [Vector2(0.72, 0.32), Vector2(0.40, 0.48), Vector2(-0.55, 0.82), Vector2(-0.82, 0.61), Vector2(-0.82, -0.61), Vector2(-0.55, -0.82), Vector2(0.40, -0.48), Vector2(0.72, -0.32)])
	map_canvas.draw_colored_polygon(hull, Color(Color("#a9bfd2"), alpha))
	var cargo: PackedVector2Array = _hull_polygon(point, forward, side, [Vector2(0.35, 0.30), Vector2(-0.58, 0.50), Vector2(-0.58, -0.50), Vector2(0.35, -0.30)])
	map_canvas.draw_colored_polygon(cargo, Color(color, alpha))
	for sign in [-1.0, 1.0]:
		var jet: Vector2 = point - forward * 0.38 + side * sign * 0.79
		map_canvas.draw_circle(jet, size_factor * 0.24, Color(Color("#526b80"), alpha), true)
		map_canvas.draw_line(jet - forward * 0.18, jet - forward * 0.67, Color(Color("#a1eaff"), alpha * 0.85), maxf(0.2, size_factor * 0.20), true)

func _draw_planet_upgrade_deliveries(state: Dictionary, index: int, center: Vector2, radius: float, detail: float) -> void:
	if detail < 0.05:
		return
	var system: Dictionary = state["planets"][index]
	var bodies: Array = _system_visual(index, state)["bodies"]
	var elapsed: float = _orbit_time(state)
	for item in system["queue"]:
		if not item.has("delivery_slot"):
			continue
		var slot: int = int(item["delivery_slot"])
		if slot < 0 or slot >= bodies.size():
			continue
		var fraction: float = 1.0 - clampf(float(item["delivery_remaining"]) / ECONOMY.PLANET_UPGRADE_DELIVERY_TIME, 0.0, 1.0)
		var origin: Vector2 = _screen_point(ECONOMY.station_position(state, index, elapsed))
		var destination: Vector2 = center + _body_position(bodies[slot], radius, elapsed)
		var point: Vector2 = origin.lerp(destination, fraction)
		var pod_size: float = clampf(radius * 0.025, 2.0, 8.0) * 0.75
		var color: Color = HUD.COLORS.get(str(item["target"]), Color("#d7b774")) if item["kind"] in ["economy_building", "production"] else Color("#d7b774")
		_draw_planet_cargo_pod(point, origin.direction_to(destination), pod_size, color, detail)
		var icon: Texture2D = _job_icon(item, int(system["owner"]))
		var icon_size: float = pod_size * 0.85
		if icon_size >= 4.0:
			map_canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, Color(1.0, 1.0, 1.0, detail))


func _draw_system(index: int, state: Dictionary, pos: Vector2, radius: float, tint: Color) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 32.0).has_point(pos):
		return
	var system: Dictionary = state["planets"][index]
	var color: Color = _planet_color(system)
	var star_radius: float = _star_draw_radius(radius)
	var star_color: Color = Color("#fff0c4").lerp(color.lightened(0.25), 0.30) if ECONOMY.has_planets(system) else Color("#8ea2bc")
	var detail: float = _planet_detail_opacity(index, radius)
	if detail > 0.001:
		var bodies: Array = _system_visual(index, state)["bodies"]
		for slot in range(bodies.size()):
			var body: Dictionary = bodies[slot]
			var orbit: float = radius * float(body["orbit"])
			if _show_system_rings(index):
				_draw_elliptical_orbit(pos, orbit, Color(tint, 0.20 * detail))
			var point: Vector2 = pos + _body_position(body, radius, _orbit_time(state))
			var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
			if Rect2(Vector2.ZERO, map_canvas.size).grow(body_radius).has_point(point):
				if body_radius >= 5.0:
					map_canvas.draw_texture_rect(_body_texture(body), Rect2(point - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2.0), false, Color(1.0, 1.0, 1.0, detail))
				else:
					map_canvas.draw_circle(point, body_radius, Color(_body_base_color(body).darkened(0.18), detail), true)
				if system.get("pds", {}).has(slot):
					_draw_pds_frame(point, body_radius, detail)
					if detail >= 0.5:
						_draw_damage_bar(point, body_radius + 4.0, float(system["pds"][slot].get("hp", ECONOMY.PDS_HP)) / ECONOMY.PDS_HP)
				if (index == selected and selected_body == slot) or (building_selection_kind == "pds" and selected_buildings.has(Vector2i(index, slot))):
					_draw_selection_ring(point, body_radius + 4.0, Color(HUD.ACCENT, detail))
					map_canvas.draw_string(get_theme_default_font(), point + Vector2(-90.0, -body_radius - 7.0), _body_name(index, slot), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color(HUD.TEXT, detail))
	_draw_planet_production(state, index, pos, radius, detail)
	_draw_planet_upgrade_deliveries(state, index, pos, radius, detail)
	var opacity: float = 1.0 - 0.4 * smoothstep(0.0, 1.0, log(maxf(zoom, 1.0)) / log(maxf(_max_zoom(), 1.01)))
	_draw_star(index, pos, star_radius, star_color, not ECONOMY.has_planets(system), opacity)
	if detail < 0.5:
		var defense_health: float = 1.0
		for battery in system.get("pds", {}).values():
			defense_health = minf(defense_health, float(battery.get("hp", ECONOMY.PDS_HP)) / ECONOMY.PDS_HP)
		_draw_damage_bar(pos, star_radius + 4.0, defense_health)
	if detail < 0.999 and not system.get("pds", {}).is_empty():
		map_canvas.draw_arc(pos, star_radius + 3.0, -PI * 0.8, PI * 0.8, 18, Color(Color("#bdcbd6"), 1.0 - detail), 1.5, true)
	if detail < 0.999:
		# A small battery marker stays on its actual planet even at overview zoom.
		var bodies: Array = _system_visual(index, state)["bodies"]
		for slot in system.get("pds", {}):
			if int(slot) >= 0 and int(slot) < bodies.size():
				var point: Vector2 = pos + _body_position(bodies[int(slot)], radius, _orbit_time(state))
				map_canvas.draw_circle(point, 2.0, Color(Color("#bdcbd6"), 1.0 - detail), true)
	if detail < 0.3 and building_selection_kind == "pds":
		# Retain a selection marker when F frames a distant battery group and
		# the individual planet surfaces fade out at overview zoom.
		var bodies: Array = _system_visual(index, state)["bodies"]
		for slot in system.get("pds", {}):
			if selected_buildings.has(Vector2i(index, int(slot))) and int(slot) < bodies.size():
				var point: Vector2 = pos + _body_position(bodies[int(slot)], radius, _orbit_time(state))
				_draw_selection_ring(point, 6.0)
	if _show_system_rings(index):
		map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)

# Thin metallic latitude/longitude ribs, clipped to the planet silhouette.
func _draw_pds_frame(center: Vector2, radius: float, opacity: float) -> void:
	var r: float = radius * 1.08
	var steel := Color(Color("#c4d1dc"), opacity)
	var shadow := Color(Color("#344655"), opacity)
	map_canvas.draw_arc(center, r, 0.0, TAU, 32, shadow, 2.0, true)
	map_canvas.draw_arc(center, r, 0.0, TAU, 32, steel, 1.0, true)
	if radius < 4.0:
		return
	for angle in [0.0, PI / 3.0, -PI / 3.0]:
		var axis := Vector2.from_angle(angle)
		for fraction in [-0.5, 0.0, 0.5]:
			var midpoint: Vector2 = center + axis.orthogonal() * r * fraction
			var extent: Vector2 = axis * r * sqrt(1.0 - fraction * fraction)
			map_canvas.draw_line(midpoint - extent, midpoint + extent, shadow, 2.0, true)
			map_canvas.draw_line(midpoint - extent, midpoint + extent, steel, 0.8, true)

func _empire_color_index(owner: int) -> int:
	if owner == 0:
		return 0
	var roster: Dictionary = session.get("players")
	return clampi(int(roster.get(owner, {}).get("color", 0)), 0, RULES.MAX_PLAYERS)

func _empire_color(owner: int) -> Color:
	return COLORS[_empire_color_index(owner)]

func _planet_color(planet: Dictionary) -> Color:
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for resource in ECONOMY.EXTRACTED:
		var amount: float = float(planet["abundance"].get(resource, 0.0))
		var tint: Color = HUD.COLORS[resource]
		sum += Vector3(tint.r, tint.g, tint.b) * amount
		weight += amount
	var organic: float = maxf(0.0, float(planet["bonuses"].get("Organics", 1.0)) - 1.0)
	var green: Color = HUD.COLORS["Organics"]
	sum += Vector3(green.r, green.g, green.b) * organic
	weight += organic
	if weight <= ECONOMY.EPS:
		return Color("#617587")
	var mix: Vector3 = sum / weight
	return Color(mix.x, mix.y, mix.z)

func _body_hit(point: Vector2, state: Dictionary) -> Vector2i:
	var hit := Vector2i(-1, -1)
	var nearest: float = INF
	for index in range(state["planets"].size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		var radius: float = _planet_radius(index, state)
		if _planet_detail_opacity(index, radius) < 0.3:
			continue
		var center: Vector2 = _screen_point(state["map"]["points"][index])
		if point.distance_to(center) > radius + 32.0:
			continue
		var bodies: Array = _system_visual(index, state)["bodies"]
		for slot in range(bodies.size()):
			var body: Dictionary = bodies[slot]
			var position: Vector2 = center + _body_position(body, radius, _orbit_time(state))
			var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
			var distance: float = point.distance_to(position)
			if distance <= body_radius + 3.0 and distance < nearest:
				hit = Vector2i(index, slot)
				nearest = distance
	return hit

func _yard_hit(point: Vector2, state: Dictionary) -> Vector2i:
	var hit := Vector2i(-1, -1)
	var nearest: float = INF
	if _ship_scale(true) < 0.14:
		return hit
	var elapsed: float = float(state["elapsed"])
	for index in range(state["planets"].size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		for slot in range(state["planets"][index]["yards"].size()):
			var scale: float = _ship_scale(true) * pow(1.2, int(state["planets"][index]["yards"][slot]["level"]) - 1)
			var center: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, slot, elapsed))
			var axis: Vector2 = Vector2.from_angle(float(ECONOMY.shipyard_port(state["planets"][index], slot) - 1) * TAU / 3.0 + elapsed * 0.008)
			var offset: Vector2 = point - center
			var distance: float = offset.length_squared()
			if absf(offset.dot(axis)) <= 14.0 * scale + 3.0 and absf(offset.dot(axis.orthogonal())) <= 17.0 * scale + 3.0 and distance < nearest:
				nearest = distance
				hit = Vector2i(index, slot)
	return hit

func _station_radius() -> float:
	# Scale the projected art, not its orbital position or simulation radius.
	return maxf(5.0, 58.0 * _fit() * zoom * _overview_art_multiplier())

func _station_hit(point: Vector2, state: Dictionary) -> int:
	var hit: int = -1
	var nearest: float = INF
	for index in range(state["planets"].size()):
		if not ECONOMY.has_station(state["planets"][index]) or not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		var center: Vector2 = _screen_point(ECONOMY.station_position(state, index, float(state["elapsed"])))
		var distance: float = point.distance_to(center)
		if distance <= _station_radius() + 3.0 and distance < nearest:
			hit = index
			nearest = distance
	return hit

func _clear_building_selection() -> void:
	parked_building_types.clear()
	selected_buildings = {}
	building_selection_kind = ""

func _build_control_group_strip() -> void:
	control_group_strip = HBoxContainer.new()
	control_group_strip.theme = HUD.compact()
	control_group_strip.add_theme_constant_override("separation", 2)
	add_child(control_group_strip)
	control_group_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control_group_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.resized.connect(_layout_control_group_strip)
	for number in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]:
		var button := _button(str(number), _recall_control_group.bind(number), control_group_strip)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(20, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 14)
		button.add_theme_font_size_override("font_size", 11)
		button.disabled = true
		control_group_buttons[number] = button
	control_group_strip.resized.connect(func() -> void: _refresh_control_groups(_state()))
	_layout_control_group_strip()

func _layout_control_group_strip() -> void:
	if not is_instance_valid(control_group_strip):
		return
	control_group_strip.position = Vector2(8.0, header_panel.position.y + header_panel.size.y + 3.0)
	control_group_strip.size = Vector2(minf(540.0, maxf(220.0, size.x - 16.0)), 26.0)

func _control_ref_valid(state: Dictionary, ref: Vector2i, kind: String, expected_count: int) -> bool:
	var planets: Array = state.get("planets", [])
	if ref.x < 0 or ref.x >= planets.size() or int(planets[ref.x]["owner"]) != _me():
		return false
	if kind == "system":
		return ECONOMY.has_station(planets[ref.x])
	if kind == "planet":
		return ref.y >= 0 and ref.y < int(planets[ref.x].get("planet_count", 0))
	return _building_valid(state, ref, kind, expected_count)

func _prune_control_group(state: Dictionary, group: Dictionary) -> Dictionary:
	var kind: String = group.get("kind", "")
	if kind == "units":
		var ids: Array[int] = []
		for craft in state.get("ships", []):
			if int(craft["owner"]) == _me() and group["ids"].has(int(craft["id"])):
				ids.append(int(craft["id"]))
		return {} if ids.is_empty() else {"kind": kind, "ids": ids}
	if kind.is_empty():
		return {}
	var refs: Dictionary = {}
	for ref in group["refs"]:
		if _control_ref_valid(state, ref, kind, int(group["refs"][ref])):
			refs[ref] = group["refs"][ref]
	return {} if refs.is_empty() else {"kind": kind, "refs": refs}

func _current_control_group(state: Dictionary) -> Dictionary:
	if not selected_units.is_empty():
		return _prune_control_group(state, {"kind": "units", "ids": selected_units})
	if not selected_buildings.is_empty():
		return _prune_control_group(state, {"kind": building_selection_kind, "refs": selected_buildings})
	if selected < 0 or selected >= state.get("planets", []).size():
		return {}
	var kind: String = "shipyard" if selected_yard >= 0 else "planet" if selected_body >= 0 else "system"
	var ref := Vector2i(selected, selected_yard if selected_yard >= 0 else selected_body if selected_body >= 0 else 0)
	return _prune_control_group(state, {"kind": kind, "refs": {ref: selected_yard_count if kind == "shipyard" else 0}})

func _assign_control_group(number: int, additive: bool = false) -> void:
	last_control_group_recall = -1
	var state: Dictionary = _state()
	var group: Dictionary = _current_control_group(state)
	if not group.is_empty():
		if additive:
			var previous: Dictionary = _prune_control_group(state, control_groups.get(number, {}))
			if not previous.is_empty() and previous["kind"] != group["kind"]:
				return
			if not previous.is_empty():
				if group["kind"] == "units":
					var ids: Array = previous["ids"].duplicate()
					for id in group["ids"]:
						if not ids.has(id):
							ids.append(id)
					group["ids"] = ids
				elif group["kind"] in ["shipyard", "station", "pds"]:
					var refs: Dictionary = previous["refs"].duplicate()
					refs.merge(group["refs"], true)
					group["refs"] = refs
				else:
					return
		control_groups[number] = group
	_refresh_control_groups(state)

func _refresh_control_groups(state: Dictionary) -> void:
	for number in control_group_buttons:
		var button: Button = control_group_buttons[number]
		var group: Dictionary = _prune_control_group(state, control_groups.get(number, {}))
		if group.is_empty():
			control_groups.erase(number)
			button.text = str(number)
			button.icon = null
			button.disabled = true
			_set_button_hint(button, "Ctrl+%d to assign a selection" % number)
			continue
		control_groups[number] = group
		var kind: String = group["kind"]
		var count: int = group["ids"].size() if kind == "units" else group["refs"].size()
		var icon_kind: String = "station" if kind == "system" else kind
		if kind == "units":
			for craft in state["ships"]:
				if group["ids"].has(int(craft["id"])):
					icon_kind = craft["kind"]
					break
		button.text = "%d·%d" % [number, count] if button.size.x >= 34.0 else str(number)
		button.icon = _selection_portrait_icon(icon_kind) if button.size.x >= 47.0 else null
		button.disabled = false
		_set_button_hint(button, "Group %d · %d %s\nPress %d to select · Twice to center · Ctrl+%d to replace · Shift+%d to add" % [number, count, "ships" if kind == "units" else "structures", number, number, number])

func _recall_control_group(number: int, additive: bool = false) -> void:
	var state: Dictionary = _state()
	var group: Dictionary = _prune_control_group(state, control_groups.get(number, {}))
	if group.is_empty():
		_refresh_control_groups(state)
		return
	var now: int = Time.get_ticks_msec()
	var center_group: bool = not additive and last_control_group_recall == number and now - last_control_group_recall_ms <= 400
	last_control_group_recall = number if not additive and not center_group else -1
	last_control_group_recall_ms = now
	var kind: String = group["kind"]
	var previous: Dictionary = _current_control_group(state) if additive else {}
	_clear_building_selection()
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	selected_ship_id = -1
	selected_units.clear()
	follow_units = false
	pending_command = ""
	formation_button = 0
	if kind == "units":
		if previous.get("kind", "") == kind:
			selected_units.assign(previous["ids"])
		for id in group["ids"]:
			if not selected_units.has(id):
				selected_units.append(id)
		selected_ship_id = selected_units[0]
	else:
		var refs: Dictionary = group["refs"].duplicate()
		if previous.get("kind", "") == kind and kind in ["shipyard", "station", "pds"]:
			refs.merge(previous["refs"])
		var first: Vector2i = refs.keys()[0]
		_set_building_primary(state, first, kind)
		if kind == "planet":
			selected_body = first.y
		elif kind in ["shipyard", "station", "pds"]:
			building_selection_kind = kind
			selected_buildings = refs
		_load_thresholds()
	_refresh_command_mode()
	_refresh()
	if center_group:
		# Center once at the existing zoom without enabling persistent follow.
		_follow_selection(state, _ship_poses(state), true)
		_position_territory()
		map_canvas.queue_redraw()

func _building_valid(state: Dictionary, ref: Vector2i, kind: String, expected_count: int = -1) -> bool:
	var planets: Array = state.get("planets", [])
	if ref.x < 0 or ref.x >= planets.size() or ref.y < 0 or not ECONOMY.discovered(state, _me(), "planets", ref.x):
		return false
	var system: Dictionary = planets[ref.x]
	if kind == "shipyard":
		return ref.y < system["yards"].size() and (expected_count < 0 or expected_count == system["yards"].size())
	if kind == "station":
		return ref.y == 0 and ECONOMY.has_station(system)
	return kind == "pds" and system.get("pds", {}).has(ref.y)

func _building_world(state: Dictionary, ref: Vector2i, kind: String) -> Vector2:
	if kind == "shipyard":
		return ECONOMY.shipyard_position(state, ref.x, ref.y, float(state["elapsed"]))
	if kind == "station":
		return ECONOMY.station_position(state, ref.x, float(state["elapsed"]))
	var body: Dictionary = _system_visual(ref.x, state)["bodies"][ref.y]
	return (state["map"]["points"][ref.x] as Vector2) + _body_position(body, _system_world_radius(ref.x, state), _orbit_time(state))

func _selected_yards(state: Dictionary, owned_only: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if building_selection_kind == "shipyard":
		for ref in selected_buildings:
			if _building_valid(state, ref, "shipyard", int(selected_buildings[ref])) and (not owned_only or int(state["planets"][ref.x]["owner"]) == _me()):
				result.append(ref)
	else:
		var ref := Vector2i(selected, selected_yard)
		if _building_valid(state, ref, "shipyard", selected_yard_count) and (not owned_only or int(state["planets"][ref.x]["owner"]) == _me()):
			result.append(ref)
	return result

func _set_building_primary(state: Dictionary, ref: Vector2i, kind: String) -> void:
	selected = ref.x
	selected_yard = ref.y if kind == "shipyard" else -1
	selected_body = ref.y if kind == "pds" else -1
	selected_yard_count = state["planets"][ref.x]["yards"].size()
	selected_units.clear()
	selected_ship_id = -1
	selected_field = -1

func _select_building_ref(ref: Vector2i, kind: String) -> void:
	var state: Dictionary = _state()
	if not _building_valid(state, ref, kind, int(selected_buildings.get(ref, -1))):
		return
	_clear_building_selection()
	_set_building_primary(state, ref, kind)
	if kind == "station":
		building_selection_kind = kind
		selected_buildings[ref] = 0
	follow_units = false
	pending_command = ""
	_load_thresholds()
	_refresh()

func _select_visible_buildings(state: Dictionary, first: Vector2i, kind: String) -> void:
	building_selection_kind = kind
	selected_buildings[first] = state["planets"][first.x]["yards"].size()
	for index in range(state["planets"].size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		var system: Dictionary = state["planets"][index]
		if kind == "pds" and _planet_detail_opacity(index, _planet_radius(index, state)) < 0.3:
			continue
		var slots: Array = range(system["yards"].size()) if kind == "shipyard" else ([0] if ECONOMY.has_station(system) else []) if kind == "station" else system.get("pds", {}).keys()
		for slot in slots:
			var ref := Vector2i(index, int(slot))
			if _in_visible_playfield(_screen_point(_building_world(state, ref, kind))):
				selected_buildings[ref] = system["yards"].size()

func _in_visible_playfield(point: Vector2) -> bool:
	# The center recess exposes a little more map than the reserved camera
	# viewport. Include that space but not objects obscured by the console.
	var global_point: Vector2 = map_canvas.get_global_transform() * point
	if is_instance_valid(time_panel) and time_panel.get_global_rect().has_point(global_point):
		return false
	if is_instance_valid(global_selection_strip) and global_selection_strip.get_global_rect().has_point(global_point):
		return false
	if is_instance_valid(control_group_strip) and control_group_strip.get_global_rect().has_point(global_point):
		return false
	for panel in [minimap, lens_column, overview_panel, inspector_panel]:
		if panel == inspector_panel and not console_right_body.visible:
			continue
		if panel.visible and panel.get_global_rect().has_point(global_point):
			return false
	return Rect2(Vector2.ZERO, map_canvas.size).has_point(point)

func _prune_building_selection(state: Dictionary) -> void:
	for kind in parked_building_types.keys():
		var refs: Dictionary = parked_building_types[kind]
		for ref in refs.keys():
			if not _building_valid(state, ref, kind, int(refs[ref])):
				refs.erase(ref)
		if refs.is_empty():
			parked_building_types.erase(kind)
	if building_selection_kind.is_empty():
		return
	for ref in selected_buildings.keys():
		if not _building_valid(state, ref, building_selection_kind, int(selected_buildings[ref])):
			selected_buildings.erase(ref)
	if selected_buildings.is_empty() and not parked_building_types.is_empty():
		building_selection_kind = parked_building_types.keys()[0]
		selected_buildings = parked_building_types[building_selection_kind]
		parked_building_types.erase(building_selection_kind)
		_set_building_primary(state, selected_buildings.keys()[0], building_selection_kind)
	if selected_buildings.is_empty():
		_clear_building_selection()
		selected_yard = -1
		selected_body = -1
		follow_units = false
		return
	var current := Vector2i(selected, selected_yard if building_selection_kind == "shipyard" else 0 if building_selection_kind == "station" else selected_body)
	if not selected_buildings.has(current):
		_set_building_primary(state, selected_buildings.keys()[0], building_selection_kind)

func _refresh_building_group(state: Dictionary) -> void:
	var group: bool = selected_buildings.size() > 1 or not parked_building_types.is_empty()
	building_group_panel.visible = group
	if not group:
		for button in building_group_rows.values():
			building_group_grid.remove_child(button)
			button.queue_free()
		building_group_rows.clear()
		return
	var kind: String = building_selection_kind
	building_group_title.text = "%d %s" % [selected_buildings.size(), "shipyards" if kind == "shipyard" else "space stations" if kind == "station" else "planetary defenses"]
	if not parked_building_types.is_empty():
		building_group_title.text += " · Tab"
	for ref in building_group_rows.keys():
		if not selected_buildings.has(ref) or building_group_rows[ref].get_meta("kind") != kind:
			var old: Button = building_group_rows[ref]
			building_group_grid.remove_child(old)
			old.queue_free()
			building_group_rows.erase(ref)
	for ref in selected_buildings:
		var system: Dictionary = state["planets"][ref.x]
		if not building_group_rows.has(ref):
			var row: Button = _button("", _select_building_tile.bind(ref, kind), building_group_grid)
			_style_selection_tile(row)
			row.set_meta("kind", kind)
			building_group_rows[ref] = row
		var button: Button = building_group_rows[ref]
		var name_text: String = "%s · Shipyard %d · Lv %d" % [_system_name(ref.x), ECONOMY.shipyard_port(system, ref.y), int(system["yards"][ref.y]["level"])] if kind == "shipyard" else _system_name(ref.x) + " · Space Station" if kind == "station" else _body_name(ref.x, ref.y)
		var maximum: float = ECONOMY.station_max_hp(system) if kind == "station" else ECONOMY.PDS_HP if kind == "pds" else ECONOMY.YARD_HP * int(system["yards"][ref.y]["level"])
		var entity: Dictionary = system["station"] if kind == "station" else system["pds"][ref.y] if kind == "pds" else system["yards"][ref.y]
		var hp: float = float(entity.get("hp", maximum))
		var tint: Color = _health_color(clampf(hp / maximum, 0.0, 1.0))
		button.icon = _selection_portrait_icon(kind)
		button.add_theme_color_override("icon_normal_color", tint)
		button.add_theme_color_override("icon_hover_color", tint)
		button.add_theme_color_override("icon_pressed_color", tint)
		_set_button_hint(button, "%s · %.0f / %.0f HP%s" % [name_text, hp, maximum, "" if int(system["owner"]) == _me() else " · Foreign"])

func _select_building_tile(ref: Vector2i, kind: String) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		selected_buildings.erase(ref)
		_refresh()
	else:
		_select_building_ref(ref, kind)

func _refresh_group_yard_commands(state: Dictionary) -> void:
	var refs: Array[Vector2i] = _selected_yards(state, true)
	# Mixed owned selections expose unlocked ships plus any remaining
	# upgrades; ship buttons always precede the upgrade in their row.
	var display_refs: Array[Vector2i] = refs if not refs.is_empty() else _selected_yards(state)
	var max_level: int = 1
	var show_medium: bool = false
	var show_large: bool = false
	for ref in display_refs:
		var level: int = int(state["planets"][ref.x]["yards"][ref.y]["level"])
		max_level = maxi(max_level, level)
		show_medium = show_medium or level == 1
		show_large = show_large or level == 2
	_layout_yard_classes(max_level, show_medium, show_large)
	var available: Dictionary = {}
	for ref in refs:
		var local: Dictionary = _available_cost_resources(state["planets"][ref.x], ref.y)
		for resource in local:
			available[resource] = maxf(float(available.get(resource, 0.0)), float(local[resource]))
	for kind in ECONOMY.SHIP_KINDS:
		var eligible: bool = false
		var can_toggle: bool = false
		var auto: bool = false
		for ref in refs:
			var system: Dictionary = state["planets"][ref.x]
			eligible = eligible or _yard_build_available(system, ref.y, kind)
			can_toggle = can_toggle or (ECONOMY.yard_fits(system, ref.y, kind) and (kind != "ship" or bool(system["home"])))
			auto = auto or system["yards"][ref.y].get("autobuild", []).has(kind)
		var button: Button = yard_commands[kind]
		button.disabled = not can_toggle
		(button.get_meta("auto_border") as Control).visible = auto
		var portrait: TextureRect = button.get_meta("portrait")
		portrait.texture = _production_icon(kind, _empire_color(_me()))
		portrait.modulate = Color.WHITE if eligible else Color(0.55, 0.55, 0.55)
		_set_cost_tooltip(button, "%s · Cost per ship\nQueue one at every eligible owned shipyard\n%s\nRight-click: toggle autobuild" % [_ship_kind_name(kind), _ship_stats(kind)], ECONOMY.construction_cost(state["planets"][refs[0].x] if not refs.is_empty() else {}, kind, 1), float(ECONOMY.CREW_COSTS[kind]), available)
	var can_clear: bool = false
	var can_upgrade: Dictionary = {2: false, 3: false}
	for ref in refs:
		var system: Dictionary = state["planets"][ref.x]
		var next_level: int = int(system["yards"][ref.y]["level"]) + 1
		if can_upgrade.has(next_level) and _yard_can_upgrade(system, ref.y):
			can_upgrade[next_level] = true
		can_clear = can_clear or not system["yards"][ref.y].get("rally", {}).is_empty()
	for target_level in [2, 3]:
		var upgrade: Button = yard_upgrades[target_level]
		upgrade.disabled = not can_upgrade[target_level]
		_set_cost_tooltip(upgrade, "Upgrade every eligible %s shipyard to %s\nUnlocks the next ship class and restores full health." % [ECONOMY.size_name(target_level - 1), ECONOMY.size_name(target_level)], ECONOMY._cost("yard_upgrade", target_level), 0.0, available)
	yard_commands["rally"].disabled = refs.is_empty()
	yard_commands["clear"].disabled = not can_clear

func _select_at(point: Vector2, additive: bool = false, double_click: bool = false) -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	sound_mixer.play_cue("select")
	last_control_group_recall = -1
	if additive and not double_click and selected_units.is_empty():
		var yard: Vector2i = _yard_hit(point, state)
		var station: int = _station_hit(point, state)
		var body: Vector2i = _body_hit(point, state)
		var kind: String = "shipyard" if yard.x >= 0 else "station" if station >= 0 else "pds" if body.x >= 0 and state["planets"][body.x].get("pds", {}).has(body.y) else ""
		if not kind.is_empty():
			var ref: Vector2i = yard if kind == "shipyard" else Vector2i(station, 0) if kind == "station" else body
			if int(state["planets"][ref.x]["owner"]) == _me():
				if kind != building_selection_kind:
					if not selected_buildings.is_empty():
						parked_building_types[building_selection_kind] = selected_buildings
					selected_buildings = parked_building_types.get(kind, {})
					parked_building_types.erase(kind)
					building_selection_kind = kind
				selected_buildings[ref] = state["planets"][ref.x]["yards"].size()
				_set_building_primary(state, ref, kind)
				pending_command = ""
				_load_thresholds()
				_refresh()
				return
	_clear_building_selection()
	if double_click:
		additive = false
	var graph: Dictionary = ECONOMY.military_graph(state)
	var hit: int = ECONOMY.sector_at(graph, _world_point(point), ECONOMY.military_pois(state, _me()))
	# Objects have priority over the sector's background geometry.
	# Use the same interpolated physical pose for selection and rendering.
	var poses: Dictionary = _ship_poses(state)
	var ship_hit: int = -1
	var ship_distance: float = INF
	for id in poses:
		var distance: float = point.distance_to(poses[id]["point"])
		if distance <= maxf(5.0, _hull_ui_radius(str(poses[id]["kind"])) * _ship_scale()) and distance < ship_distance:
			ship_distance = distance
			ship_hit = int(id)
	var next_ship: int = ship_hit
	var body_hit: Vector2i = _body_hit(point, state) if not additive else Vector2i(-1, -1)
	var yard_hit: Vector2i = _yard_hit(point, state) if not additive else Vector2i(-1, -1)
	if yard_hit.x >= 0:
		var yard_distance: float = point.distance_to(_screen_point(ECONOMY.shipyard_position(state, yard_hit.x, yard_hit.y, float(state["elapsed"]))))
		if yard_distance <= ship_distance or next_ship < 0:
			selected = yard_hit.x
			selected_yard = yard_hit.y
			selected_yard_count = state["planets"][selected]["yards"].size()
			selected_body = -1
			selected_ship_id = -1
			selected_units.clear()
			selected_field = -1
			follow_units = false
			if double_click:
				_select_visible_buildings(state, yard_hit, "shipyard")
			var focus: Control = get_viewport().gui_get_focus_owner()
			if is_instance_valid(focus):
				focus.release_focus()
			_load_thresholds()
			_refresh()
			return
	if not additive:
		var station_hit: int = _station_hit(point, state)
		if station_hit >= 0 and (next_ship < 0 or point.distance_to(_screen_point(ECONOMY.station_position(state, station_hit, float(state["elapsed"])))) < ship_distance):
			var ref := Vector2i(station_hit, 0)
			_set_building_primary(state, ref, "station")
			building_selection_kind = "station"
			selected_buildings[ref] = 0
			follow_units = false
			if double_click:
				_select_visible_buildings(state, ref, "station")
			_load_thresholds()
			_refresh()
			return
	if body_hit.x >= 0:
		selected = body_hit.x
		selected_yard = -1
		selected_body = body_hit.y
		follow_units = false
		selected_ship_id = -1
		selected_units.clear()
		selected_field = -1
		if double_click and state["planets"][selected].get("pds", {}).has(selected_body):
			_select_visible_buildings(state, body_hit, "pds")
		var focus: Control = get_viewport().gui_get_focus_owner()
		if is_instance_valid(focus):
			focus.release_focus()
		_load_thresholds()
		_refresh()
		return
	if additive and not selected_units.is_empty() and next_ship < 0:
		return
	selected_body = -1
	selected_yard = -1
	selected_ship_id = next_ship
	if not additive:
		selected_units.clear()
	for craft in state["ships"]:
		if int(craft["id"]) == selected_ship_id:
			if additive and selected_units.has(selected_ship_id):
				selected_units.erase(selected_ship_id)
				selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
			elif not selected_units.has(selected_ship_id):
				selected_units.append(selected_ship_id)
			if double_click:
				var kind: String = str(craft["kind"])
				var team: int = int(state["teams"].get(_me(), -1))
				if int(state["teams"].get(int(craft["owner"]), -2)) != team:
					selected_units.clear()
					selected_ship_id = -1
				for other in state["ships"]:
					var id: int = int(other["id"])
					if int(state["teams"].get(int(other["owner"]), -2)) == team and other["kind"] == kind and poses.has(id) and _in_visible_playfield(poses[id]["point"]) and not selected_units.has(id):
						selected_units.append(id)
				if not selected_units.is_empty():
					selected_ship_id = selected_units[0]
			break
	selected_field = -1
	if selected_ship_id < 0:
		var fields: Array = state["map"].get("fields", [])
		for i in range(fields.size()):
			if not ECONOMY.discovered(state, _me(), "fields", i):
				continue
			var distance: float = point.distance_to(_screen_point(fields[i]["position"]))
			if distance <= maxf(9.0, float(fields[i]["radius"]) * _fit() * zoom):
				selected_field = i
				break
	if selected_ship_id < 0 and selected_field < 0 and hit >= state["planets"].size():
		selected_field = hit - state["planets"].size()
		hit = -1
	selected = -1 if selected_ship_id >= 0 or selected_field >= 0 else hit
	follow_units = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focused.release_focus()
	if selected >= 0:
		var system: Dictionary = state["planets"][selected]
		var owner: int = int(system["owner"])
		if owner > 0 and ECONOMY.has_station(system) and int(state["teams"].get(owner, -1)) == int(state["teams"].get(_me(), -2)):
			var ref := Vector2i(selected, 0)
			_set_building_primary(state, ref, "station")
			building_selection_kind = "station"
			selected_buildings[ref] = 0
		_load_thresholds()
	_refresh()

func _select_box(rect: Rect2, additive: bool) -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	sound_mixer.play_cue("select")
	last_control_group_recall = -1
	_clear_building_selection()
	if not additive:
		selected_units.clear()
	var poses: Dictionary = _ship_poses(state)
	var team: int = int(state["teams"].get(_me(), -1))
	var friendly_ids: Dictionary = {}
	for craft in state.get("ships", []):
		if int(state["teams"].get(int(craft["owner"]), -2)) != team or craft.get("kind", "") == "warp_gate":
			continue
		friendly_ids[int(craft["id"])] = true
		var id: int = int(craft["id"])
		if poses.has(id) and rect.has_point(poses[id]["point"]) and not selected_units.has(id):
			selected_units.append(id)
	# Shift-box must not retain a previously inspected enemy.
	for id in selected_units.duplicate():
		if not friendly_ids.has(id):
			selected_units.erase(id)
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	follow_units = false
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	_refresh()

func _entity_hit(state: Dictionary, point: Vector2) -> int:
	# Docked ships can overlap the station; its central face must remain a
	# usable deposit/attack/repair target even when a hull is docked there.
	var station: int = _station_hit(point, state)
	if station >= 0:
		var center: Vector2 = _screen_point(ECONOMY.station_position(state, station, float(state["elapsed"])))
		if point.distance_to(center) <= maxf(5.0, _station_radius() * 0.55):
			return ECONOMY.station_target_id(state, station)
	var nearest: float = INF
	var target: int = -1
	var poses: Dictionary = _ship_poses(state)
	for id in poses:
		var distance: float = point.distance_to(poses[id]["point"])
		if distance <= maxf(5.0, _hull_ui_radius(str(poses[id]["kind"])) * _ship_scale()) and distance < nearest:
			nearest = distance
			target = int(id)
	if target != -1:
		return target
	var yard: Vector2i = _yard_hit(point, state)
	if yard.x >= 0:
		return -2 - yard.x * 3 - yard.y
	if station >= 0:
		return ECONOMY.station_target_id(state, station)
	var body: Vector2i = _body_hit(point, state)
	if body.x >= 0 and state["planets"][body.x].get("pds", {}).has(body.y):
		return -2 - state["planets"].size() * 3 - body.y * state["planets"].size() - body.x
	return -1

func _command_at(point: Vector2, force_position: bool = false, patrol: bool = false, move_only: bool = true, explicit_attack: bool = false, append: bool = false, contextual: bool = false, minimap_hint: Dictionary = {}) -> void:
	var state: Dictionary = _state()
	var owned: Array[int] = _selected_owned_units(state, not patrol and not explicit_attack)
	if state.is_empty() or owned.is_empty():
		return
	var graph: Dictionary = ECONOMY.military_graph(state)
	var world: Vector2 = minimap_hint.get("world", _world_point(point))
	var node: int = ECONOMY.sector_at(graph, world, ECONOMY.military_pois(state, _me()))
	if patrol:
		var anchor: int = ECONOMY.patrol_node(state, graph, _me(), world)
		var fighters: Array[int] = []
		for craft in state["ships"]:
			if owned.has(int(craft["id"])) and craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"]:
				fighters.append(int(craft["id"]))
		if anchor >= 0:
			_issue_order(fighters, {"kind": "patrol", "target": anchor, "point": world}, append)
		return
	var target: int = -1
	if not force_position and (contextual or explicit_attack):
		target = _entity_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
	var ref: Dictionary = ECONOMY.service_targets(state).get(target, {})
	var wreck: int = -1
	if contextual and not force_position:
		wreck = _salvage_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["wreck"])
	var field: int = -1
	var rock_id: int = -1
	if contextual and not force_position and not minimap_hint.is_empty():
		field = int(minimap_hint["field"])
	elif contextual and not force_position and node >= state["planets"].size():
		var candidate: int = node - state["planets"].size()
		var data: Dictionary = state["map"]["fields"][candidate]
		var distance: float = point.distance_to(_screen_point(data["position"]))
		if distance <= maxf(9.0, float(data["radius"]) * _fit() * zoom):
			field = candidate
			var best: float = INF
			for rock in data.get("chunks", []):
				var d: float = point.distance_to(_screen_point(rock["position"]))
				if d < best and d <= maxf(5.0, float(rock.get("radius", 0.0)) * _fit() * zoom):
					best = d
					rock_id = int(rock["id"])
	var entries: Array = []
	var salvage_ids: Array[int] = []
	for craft in state["ships"]:
		var id: int = int(craft["id"])
		if not owned.has(id):
			continue
		var order: Dictionary = {}
		var armed: bool = ECONOMY.armed(craft)
		if explicit_attack and not armed:
			continue
		if not ref.is_empty() and armed and ECONOMY._hostile_hull(state, _me(), ref):
			order = {"kind": "attack", "target": target}
		elif contextual and ref.get("entity", {}).get("kind", "") == "warp_gate" and int(ref.get("owner", -1)) == _me() and ECONOMY._warp_order_valid(state, craft, target):
			order = {"kind": "warp_travel", "target": target}
		elif contextual and ref.get("kind") == "ship" and ECONOMY._friendly_target(state, _me(), ref):
			if id == target:
				continue
			order = {"kind": "follow", "target": target, "guard": craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"]}
		elif contextual and ref.get("kind") == "station" and ECONOMY.can_deposit(state, craft, target):
			order = {"kind": "deposit", "target": target}
		elif field >= 0 and bool(state["map"]["fields"][field].get("antimatter", false)) and craft["kind"] == "science_ship" and ECONOMY._cargo_total(craft) <= ECONOMY.EPS:
			order = {"kind": "collect", "target": field}
		elif wreck >= 0 and ECONOMY.supports_autocast(craft, "salvage") and ECONOMY.cargo_free(craft) > ECONOMY.EPS:
			salvage_ids.append(id)
			continue
		elif field >= 0 and craft["kind"] == "miner" and not bool(state["map"]["fields"][field].get("antimatter", false)):
			order = {"kind": "mine", "target": field, "chunk": rock_id}
		else:
			var endpoint: Vector2 = ref.get("position", world)
			# PDS combat references are attached to the sector star. A
			# non-attack move must instead reach the clicked orbital body.
			if ref.get("kind") == "pds":
				var count: int = state["planets"].size()
				var pds_node: int = int(ref["node"])
				var slot: int = floori(float(-2 - count * 3 - target - pds_node) / float(count))
				endpoint = _building_world(state, Vector2i(pds_node, slot), "pds")
			var destination: int = ECONOMY.patrol_node(state, graph, _me(), endpoint)
			if destination < 0:
				continue
			order = {"kind": "position", "target": destination, "point": endpoint, "move_only": move_only}
		entries.append({"ids": [id], "order": order})
	if not salvage_ids.is_empty():
		entries.append({"ids": salvage_ids, "order": {"kind": "salvage", "target": wreck}})
	if not entries.is_empty():
		sound_mixer.play_cue("order")
		session.call("request_unit_orders", entries, append)

func _command_kinds(state: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for craft in state.get("ships", []):
		var kind: String = str(craft["kind"])
		if selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me() and not kinds.has(kind):
			kinds.append(kind)
	kinds.sort()
	return kinds

func _sync_command_kind(state: Dictionary) -> void:
	var kinds: Array[String] = _command_kinds(state)
	if command_selection != selected_units or not kinds.has(command_kind):
		command_selection.assign(selected_units)
		command_kind = kinds[0] if not kinds.is_empty() else ""

func _command_member(craft: Dictionary) -> bool:
	return selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me() and str(craft["kind"]) == command_kind

func _cycle_command_kind(reverse: bool) -> bool:
	var state: Dictionary = _state()
	if not building_selection_kind.is_empty() and not parked_building_types.is_empty():
		var kinds: Array = parked_building_types.keys()
		kinds.append(building_selection_kind)
		kinds.sort()
		var next: String = kinds[posmod(kinds.find(building_selection_kind) + (-1 if reverse else 1), kinds.size())]
		parked_building_types[building_selection_kind] = selected_buildings
		selected_buildings = parked_building_types[next]
		parked_building_types.erase(next)
		building_selection_kind = next
		_set_building_primary(state, selected_buildings.keys()[0], next)
		pending_command = ""
		_load_thresholds()
		_refresh()
		return true
	_sync_command_kind(state)
	var kinds: Array[String] = _command_kinds(state)
	if kinds.size() < 2:
		return false
	command_kind = kinds[posmod(kinds.find(command_kind) + (-1 if reverse else 1), kinds.size())]
	pending_command = ""
	formation_button = 0
	_refresh()
	return true

func _selected_miners() -> Array[int]:
	var miners: Array[int] = []
	for craft in _state().get("ships", []):
		if _command_member(craft) and craft["kind"] == "miner":
			miners.append(int(craft["id"]))
	return miners

func _selected_owned_units(state: Dictionary, all_types: bool = false) -> Array[int]:
	var owned: Array[int] = []
	for craft in state.get("ships", []):
		if craft.get("kind", "") != "warp_gate" and (_command_member(craft) or (all_types and selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me())):
			owned.append(int(craft["id"]))
	return owned

func _any_selected_holding() -> bool:
	for craft in _state().get("ships", []):
		if _command_member(craft) and bool(craft.get("holding", false)):
			return true
	return false

func _hold_selected() -> void:
	pending_command = ""
	var owned: Array[int] = _selected_owned_units(_state())
	if not owned.is_empty():
		if Input.is_key_pressed(KEY_SHIFT):
			_issue_order(owned, {"kind": "hold"}, true)
		else:
			session.call("request_unit_hold", owned, _any_selected_holding())
	_refresh_command_mode()

func _transform_selected() -> void:
	var state: Dictionary = _state()
	var graph: Dictionary = ECONOMY.military_graph(state)
	var ids: Array[int] = []
	if command_kind == "warp_gate":
		var gate: Dictionary = _selected_ship(state)
		var choices: Array[int] = ECONOMY.warp_gate_choices(state, _me(), int(gate.get("id", -1)))
		if not gate.is_empty() and not choices.is_empty():
			var next: int = (choices.find(int(gate.get("warp_destination", -1))) + 1) % choices.size()
			_issue_order([int(gate["id"])], {"kind": "warp_link", "target": choices[next]})
		return
	if command_kind == "science_ship":
		for ship in state["ships"]:
			if _command_member(ship) and ECONOMY.can_build_warp_gate(state, graph, ship):
				ids.append(int(ship["id"]))
		_issue_order(ids, {"kind": "warp_build"})
		return
	for ship in state["ships"]:
		if _command_member(ship) and ECONOMY._valid_unit_order(state, graph, ship, {"kind": "transform"}, Input.is_key_pressed(KEY_SHIFT)):
			ids.append(int(ship["id"]))
	if not ids.is_empty():
		_issue_order(ids, {"kind": "transform"}, Input.is_key_pressed(KEY_SHIFT))

func _deliver_farm_selected() -> void:
	var ids: Array[int] = []
	for ship in _state().get("ships", []):
		if ship["kind"] == "colony_ship" and _command_member(ship) and ECONOMY._cargo_total(ship) > ECONOMY.EPS:
			ids.append(int(ship["id"]))
	pending_command = ""
	_issue_order(ids, {"kind": "unload"}, Input.is_key_pressed(KEY_SHIFT))
	_refresh_command_mode()

func _unload_selected() -> void:
	_arm_command("unload")

func _formation_orders(state: Dictionary) -> Array:
	var entries: Array = []
	var owned: Array[int] = _selected_owned_units(state, formation_mode not in ["attack", "patrol"])
	if owned.is_empty() or formation_length <= 5.0:
		return entries
	var graph: Dictionary = ECONOMY.military_graph(state)
	var stroke := PackedVector2Array()
	for point in formation_path:
		stroke.append(_world_point(point))
	var ships: Dictionary = {}
	var origins: Dictionary = {}
	for ship in state["ships"]:
		if owned.has(int(ship["id"])) and not bool(ship.get("retreating", false)) and (formation_mode != "attack" or ECONOMY.armed(ship)) and (formation_mode != "patrol" or ship["kind"] in ["fighter", "scout", "cruiser", "destroyer"]):
			var origin: Vector2 = ECONOMY.unit_order_origin(state, graph, ship) if formation_append else ship["position"]
			ships[ship["id"]] = ship
			origins[ship["id"]] = origin
	if owned.size() == 1:
		if ships.is_empty():
			return entries
		var ship: Dictionary = ships[owned[0]]
		# The press anchors the destination. The cursor rotates the ghost
		# around that point, instead of moving it along a formation stroke.
		var point: Vector2 = stroke[0]
		var heading: Vector2 = (stroke[-1] - point).normalized()
		if heading.is_zero_approx():
			heading = ship.get("heading", Vector2.UP)
		var node: int = ECONOMY.patrol_node(state, graph, _me(), point)
		var order: Dictionary = {"kind": "patrol" if formation_mode == "patrol" else "position", "target": node, "point": point, "move_only": formation_mode != "attack", "heading": heading}
		entries.append({"ids": owned, "order": order, "hull": ship["kind"], "valid": ECONOMY._valid_unit_order(state, graph, ship, order, formation_append)})
		return entries
	for slot in ECONOMY.polyline_formation_slots(origins, stroke):
		var ship: Dictionary = ships[slot["id"]]
		var point: Vector2 = slot["point"]
		var node: int = ECONOMY.patrol_node(state, graph, _me(), point)
		var order: Dictionary = {"kind": "patrol" if formation_mode == "patrol" else "position", "target": node, "point": point, "move_only": formation_mode != "attack", "heading": slot["heading"]}
		entries.append({"ids": [ship["id"]], "order": order, "hull": ship["kind"], "valid": ECONOMY._valid_unit_order(state, graph, ship, order, formation_append)})
	return entries

func _append_formation_point(point: Vector2, force: bool = false) -> void:
	var distance: float = formation_path[-1].distance_to(point)
	if distance <= 0.0 or (distance < 2.0 and not force):
		return
	formation_length += distance
	if formation_path.size() >= 2048:
		formation_path.remove_at(1)
	formation_path.append(point)

func _draw_destination_ghost(kind: String, point: Vector2, heading: Vector2, tint: Color) -> void:
	var axis: Vector2 = heading.normalized() if not heading.is_zero_approx() else Vector2.UP
	var scale: float = maxf(0.42, _ship_scale())
	var shape: PackedVector2Array = _hull_polygon(point, axis * scale, axis.orthogonal() * scale, HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE))
	if not Geometry2D.triangulate_polygon(shape).is_empty():
		map_canvas.draw_colored_polygon(shape, Color(tint, 0.24))
	shape.append(shape[0])
	map_canvas.draw_polyline(shape, Color(tint, 0.85), 1.0, true)

func _draw_sector_target(graph: Dictionary, node: int, tint: Color, drawn: Dictionary) -> void:
	if node < 0 or node >= graph["points"].size() or drawn.has(node):
		return
	drawn[node] = true
	var center: Vector2 = graph["points"][node]
	var outline := PackedVector2Array()
	for i in range(97):
		var direction := Vector2.from_angle(TAU * float(i) / 96.0)
		outline.append(_screen_point(center + direction * ECONOMY.sector_limit(graph, node, direction)))
	map_canvas.draw_polyline(outline, Color(tint, 0.9), 2.0, true)

func _draw_formation_preview(state: Dictionary) -> void:
	if formation_button == 0 or formation_length <= 5.0:
		return
	var entries: Array = _formation_orders(state)
	if entries.is_empty():
		return
	var color: Color = Color("#b880fa") if formation_mode == "patrol" else Color("#ff605c") if formation_mode == "attack" else HUD.ACCENT
	if _selected_owned_units(state, formation_mode not in ["attack", "patrol"]).size() == 1:
		map_canvas.draw_line(formation_path[0], formation_path[-1], color, 1.5, true)
	else:
		map_canvas.draw_polyline(formation_path, color, 1.5, true)
	for entry in entries:
		var order: Dictionary = entry["order"]
		var point: Vector2 = _screen_point(order["point"])
		var heading: Vector2 = order["heading"]
		_draw_destination_ghost(entry["hull"], point, heading, color if entry["valid"] else Color("#a88b83"))

func _begin_formation(mouse: InputEventMouseButton) -> void:
	formation_button = mouse.button_index
	formation_path = PackedVector2Array([mouse.position])
	formation_length = 0.0
	formation_mode = pending_command
	formation_append = mouse.shift_pressed
	formation_force_position = mouse.alt_pressed
	selecting_units = false
	follow_units = false

func _finish_formation(point: Vector2) -> void:
	_append_formation_point(point, true)
	var entries: Array = _formation_orders(_state())
	formation_button = 0
	if entries.is_empty():
		_command_at(point, formation_force_position, formation_mode == "patrol", formation_mode not in ["attack", "patrol"], formation_mode == "attack", formation_append, formation_mode.is_empty())
	else:
		var valid: Array = []
		for entry in entries:
			if entry["valid"]:
				valid.append({"ids": entry["ids"], "order": entry["order"]})
		if not valid.is_empty():
			sound_mixer.play_cue("order")
			session.call("request_unit_orders", valid, formation_append)
	if not formation_append:
		pending_command = ""
		_refresh_command_mode()

func _map_input(event: InputEvent) -> void:
	if match_menu.visible or (is_instance_valid(codex) and codex.visible):
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and _jump_tactical_alert(mouse.position):
			map_canvas.accept_event()
			return
		if mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			# Either button can confirm an armed order; ordinary right drag
			# still forms a move line and ordinary left drag selects.
			if formation_button != 0:
				if mouse.button_index != formation_button and mouse.pressed:
					formation_button = 0
					pending_command = ""
					_refresh_command_mode()
				else:
					if mouse.button_index == formation_button and not mouse.pressed:
						_finish_formation(mouse.position)
					map_canvas.queue_redraw()
					map_canvas.accept_event()
					return
			if mouse.pressed and (pending_command in ["move", "attack", "patrol"] or (mouse.button_index == MOUSE_BUTTON_RIGHT and pending_command.is_empty() and selected_yard < 0)):
				_begin_formation(mouse)
				map_canvas.queue_redraw()
				map_canvas.accept_event()
				return
		match mouse.button_index:
			MOUSE_BUTTON_MIDDLE:
				if mouse.pressed:
					follow_units = false
				drag_button = MOUSE_BUTTON_MIDDLE if mouse.pressed else 0
			MOUSE_BUTTON_RIGHT:
				if mouse.pressed:
					if pending_command in ["repair", "unload", "load", "rally", "collect", "guard"]:
						_execute_pending_command(mouse.position, mouse.shift_pressed)
					elif not pending_command.is_empty() and pending_command not in ["move", "attack", "patrol"]:
						pending_command = ""
						_refresh_command_mode()
					elif selected_yard >= 0:
						_set_rally_at(mouse.position)
			MOUSE_BUTTON_LEFT:
				if not pending_command.is_empty():
					if mouse.pressed:
						selecting_units = false
						_execute_pending_command(mouse.position, mouse.shift_pressed)
					map_canvas.accept_event()
					return
				if mouse.pressed:
					selecting_units = true
					selection_double_click = mouse.double_click
					selection_start = mouse.position
					selection_end = mouse.position
				elif selecting_units:
					selecting_units = false
					if selection_start.distance_to(mouse.position) > 5.0:
						_select_box(Rect2(selection_start, mouse.position - selection_start).abs(), mouse.shift_pressed)
					else:
						_select_at(mouse.position, mouse.shift_pressed, selection_double_click)
					selection_double_click = false
			MOUSE_BUTTON_WHEEL_UP:
				if mouse.pressed:
					_zoom_at(mouse.position, wheel_zoom_percent / 100.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse.pressed:
					_zoom_at(mouse.position, -wheel_zoom_percent / 100.0)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if formation_button != 0:
			_append_formation_point(motion.position)
		elif selecting_units:
			selection_end = motion.position
		elif drag_button != 0:
			if motion.button_mask == 0:
				drag_button = 0
			else:
				camera_world = _camera_world_center() - motion.relative / (_fit() * zoom)
	map_canvas.queue_redraw()
	map_canvas.accept_event()

func _fighter_path(ship: Dictionary) -> Array[int]:
	var path: Array[int] = [int(ship["at"])]
	for node in ship["route"]:
		path.append(int(node))
	return path

func _poi_name(node: int) -> String:
	var count: int = (_state().get("planets", []) as Array).size()
	if node < count:
		return _system_name(node)
	var index: int = node - count
	var fields: Array = _state().get("map", {}).get("fields", [])
	return "Pulsar" if index < fields.size() and bool(fields[index].get("antimatter", false)) else "Asteroid Field"

func _ship_position(ship: Dictionary, _points: Array) -> Vector2:
	if ship.has("position"):
		return ship["position"]
	return ECONOMY.combat_position(_state(), ECONOMY.military_graph(_state()), ship)

func _visual_position(visual: Dictionary) -> Vector2:
	var duration: float = float(visual.get("duration", SNAPSHOT_SECONDS))
	return (visual["from"] as Vector2).lerp(visual["to"], clampf(float(visual["age"]) / duration, 0.0, 1.0))

# UI cues are local, while world cues use the same authority snapshots as
# combat visuals. No audio events or additional network traffic are required.
func _sound_button_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		var button: BaseButton = node
		button.pressed.connect(_sound_click)

func _sound_click() -> void:
	sound_mixer.play_cue("click")

func _sound_chat() -> void:
	if str(session.get("phase")) == "match" and not session.get("match_chat").is_empty():
		sound_mixer.play_cue("notice")

func _sound_gain(point: Vector2, center: Vector2, radius: float) -> float:
	return SFX.spatial_gain(point.distance_to(center), radius, zoom)

func _sync_upgrade_audio(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	var active: Dictionary = {}
	var structures: Dictionary = {}
	var added: bool = false
	var complete: bool = false
	for system_index in range(state["planets"].size()):
		var system: Dictionary = state["planets"][system_index]
		if int(system["owner"]) != _me():
			continue
		for job in system["queue"]:
			var id: int = int(job["id"])
			active[id] = true
			if not known_upgrade_jobs.has(id):
				added = true
		var level: int = int(system.get("warehouse_level", 0)) + int(system.get("habitation_level", 0)) + int(system.get("orbital_housing", 0)) + system.get("pds", {}).size()
		for yard in system.get("yards", []):
			level += int(yard["level"])
		for resource in ECONOMY.RESOURCES:
			level += int(system.get("levels", {}).get(resource, 0)) + int(system.get("buildings", {}).get(resource, 0))
		level += int(bool(system.get("station", {}).get("reinforced_plating", false))) + int(bool(system.get("station", {}).get("laser_matrix", false)))
		structures[system_index] = level
		if level > int(sound_structures.get(system_index, -1)):
			complete = true
	var hulls: Dictionary = {}
	var ship_ready: bool = false
	for ship in state["ships"]:
		if int(ship["owner"]) == _me():
			var id: int = int(ship["id"])
			hulls[id] = true
			if not sound_hulls.has(id):
				ship_ready = true
	if upgrade_audio_initialized:
		if added:
			sound_mixer.play_cue("queue")
		if complete:
			sound_mixer.play_cue("complete")
		if ship_ready:
			sound_mixer.play_cue("ship_ready")
	known_upgrade_jobs = active
	sound_hulls = hulls
	sound_structures = structures
	upgrade_audio_initialized = true

func _sync_world_audio(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	var now: float = float(state["elapsed"])
	var initial: bool = sound_elapsed < 0.0
	var advanced: bool = not initial and now > sound_elapsed
	var center: Vector2 = _camera_world_center()
	var radius: float = clampf(_projection_size().length() / maxf(0.0001, _fit() * zoom) * 0.55, 650.0, 9000.0)
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= sound_destruction_sequence:
			continue
		sound_destruction_sequence = sequence
		if not initial:
			var gain: float = _sound_gain(event["position"], center, radius)
			var heavy: bool = event["kind"] in ["station", "shipyard", "cruiser", "destroyer"]
			sound_mixer.offer("heavy_explosion" if heavy else "explosion", gain)
	var notices: Dictionary = {}
	var announced: bool = false
	for event in state.get("objective_events", []):
		var key: String = "%s:%s:%s" % [event["player"], event.get("objective", event.get("reward", "")), event["elapsed"]]
		notices[key] = true
		if not sound_objectives.has(key):
			announced = true
	if announced and not initial:
		sound_mixer.play_cue("notice")
	sound_objectives = notices
	if advanced:
		# Timestamp edges, not visual-frame repeats. A sampled volley can
		# represent several actual shots between network snapshots.
		for ship in state["ships"]:
			var laser: bool = maxf(float(ship.get("laser_until", -1.0)), float(ship.get("yard_laser_until", -1.0))) > sound_elapsed + 0.2 + ECONOMY.EPS
			var blaster: bool = float(ship.get("blaster_fired", -1.0)) > sound_elapsed + ECONOMY.EPS
			var missile: bool = float(ship.get("missile_until", -1.0)) > sound_elapsed + 0.65 + ECONOMY.EPS
			var mining: bool = bool(ship.get("mining_active", false))
			var repair: bool = ship.has("repair_target")
			var tractor: bool = bool(ship.get("tractor_active", false))
			if not (laser or blaster or missile or mining or repair or tractor) or not _ship_visible(state, ship):
				continue
			var gain: float = _sound_gain(ship["position"], center, radius)
			if gain < 0.035:
				continue
			if laser:
				sound_mixer.offer("laser", gain)
			if blaster:
				sound_mixer.offer("blaster", gain)
			if missile:
				sound_mixer.offer("missile", gain)
			if mining:
				sound_mixer.offer("mining", gain)
			if repair:
				sound_mixer.offer("repair", gain)
			if tractor:
				sound_mixer.offer("tractor", gain)
		for index in range(state["planets"].size()):
			if not ECONOMY.discovered(state, _me(), "planets", index):
				continue
			var system: Dictionary = state["planets"][index]
			var firing: bool = false
			for weapon in system.get("station", {}).get("weapons", []):
				if float(weapon.get("laser_until", -1.0)) > sound_elapsed + 0.2 + ECONOMY.EPS:
					firing = true
					break
			if not firing:
				for battery in system.get("pds", {}).values():
					if float(battery.get("laser_until", -1.0)) > sound_elapsed + 0.2 + ECONOMY.EPS:
						firing = true
						break
			if firing:
				sound_mixer.offer("laser", _sound_gain(state["map"]["points"][index], center, radius))
	sound_elapsed = now
	sound_mixer.flush()

func _alert_off_camera(point: Vector2) -> bool:
	return not Rect2(Vector2(0, HEADER_HEIGHT), (_projection_size() - Vector2(0, HEADER_HEIGHT)).max(Vector2.ONE)).has_point(_screen_point(point))

func _post_tactical_alert(key: String, message: String, point: Vector2, now: int, target_id: int = -1) -> void:
	var previous: Dictionary = tactical_alerts.get(key, {})
	if not previous.is_empty() and now - int(previous["born"]) < ALERT_REPEAT_MS:
		if now - int(previous["born"]) < ALERT_LIFETIME_MS:
			previous["text"] = message
			previous["point"] = point
			previous["target"] = target_id
		return
	tactical_alerts[key] = {"text": message, "point": point, "born": now, "target": target_id}
	sound_mixer.play_cue("warning")

func _jump_tactical_alert(point: Vector2) -> bool:
	for hit in tactical_hit_rects:
		if not (hit["rect"] as Rect2).has_point(point):
			continue
		var key: String = hit["key"]
		var alert: Dictionary = tactical_alerts.get(key, {})
		if alert.is_empty() or Time.get_ticks_msec() - int(alert["born"]) >= ALERT_LIFETIME_MS:
			continue
		var destination: Vector2 = alert["point"]
		var target: int = int(alert["target"])
		if target >= 0:
			for ship in _state().get("ships", []):
				if int(ship["id"]) == target:
					destination = ship["position"]
					break
		follow_units = false
		formation_button = 0
		selecting_units = false
		_center_world(destination)
		_position_territory()
		map_canvas.queue_redraw()
		sound_mixer.play_cue("click")
		return true
	return false

func _sync_tactical_alerts(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		tactical_alerts.clear()
		tactical_hit_rects.clear()
		tactical_durability.clear()
		tactical_positions.clear()
		tactical_initialized = false
		tactical_next_scan = 0
		tactical_last_damage_sequence = 0
		return
	var now: int = Time.get_ticks_msec()
	for key in tactical_alerts.keys():
		if now - int(tactical_alerts[key]["born"]) >= ALERT_REPEAT_MS:
			tactical_alerts.erase(key)
	var current: Dictionary = {}
	var team: int = int(state["teams"].get(_me(), -1))
	for ship in state["ships"]:
		if int(state["teams"].get(int(ship["owner"]), 0)) != team:
			continue
		var id: int = int(ship["id"])
		var point: Vector2 = ship["position"]
		var health: Vector2 = Vector2(float(ship.get("hp", 0.0)), float(ship.get("shield", 0.0)))
		var previous: Vector2 = tactical_durability.get(id, health)
		current[id] = health
		if tactical_initialized and (health.x < previous.x - ECONOMY.EPS or health.y < previous.y - ECONOMY.EPS) and _alert_off_camera(point):
			var cell := Vector2i(floori(point.x / 1500.0), floori(point.y / 1500.0))
			_post_tactical_alert("attack:%s" % str(cell), "Unit under attack!  ›", point, now, id)
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= tactical_last_damage_sequence:
			continue
		tactical_last_damage_sequence = sequence
		var point: Vector2 = event["position"]
		if tactical_initialized and int(state["teams"].get(int(event["owner"]), 0)) == team and _alert_off_camera(point):
			var cell := Vector2i(floori(point.x / 1500.0), floori(point.y / 1500.0))
			_post_tactical_alert("attack:%s" % str(cell), "Unit under attack!  ›", point, now)
	tactical_durability = current
	tactical_initialized = true
	if now < tactical_next_scan:
		return
	tactical_next_scan = now + 500
	var graph: Dictionary = territory_region_graph
	if graph.is_empty():
		return
	var points: Array = graph["points"]
	# Build a temporary grid of friendly sector centers. Each visible hostile
	# is counted once, at its nearest approaching friendly sector.
	var cell_size: float = ALERT_APPROACH_RANGE
	for index in tactical_friendly:
		cell_size = maxf(cell_size, float(graph["sector_radii"][index]) + ALERT_APPROACH_RANGE)
	var cells: Dictionary = {}
	for index in tactical_friendly:
		var center: Vector2 = points[index]
		var cell := Vector2i(floori(center.x / cell_size), floori(center.y / cell_size))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(index)
	var positions: Dictionary = {}
	var groups: Dictionary = {}
	for ship in state["ships"]:
		if not ECONOMY.military_hull(str(ship["kind"])) or int(state["teams"].get(int(ship["owner"]), 0)) == team or not _ship_visible(state, ship):
			continue
		var id: int = int(ship["id"])
		var point: Vector2 = ship["position"]
		var previous: Vector2 = tactical_positions.get(id, point)
		positions[id] = point
		var movement: Vector2 = point - previous
		if movement.length_squared() <= ECONOMY.EPS:
			continue
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		var best: int = -1
		var best_distance: float = INF
		for x in range(-1, 2):
			for y in range(-1, 2):
				for index in cells.get(cell + Vector2i(x, y), []):
					var center: Vector2 = points[index]
					var distance: float = point.distance_to(center)
					if distance > float(graph["sector_radii"][index]) + ALERT_APPROACH_RANGE or distance >= best_distance:
						continue
					if sector_contains_for_alert(graph, index, point) or movement.normalized().dot(point.direction_to(center)) < 0.35:
						continue
					best = index
					best_distance = distance
		if best >= 0:
			var group: Dictionary = groups.get(best, {"count": 0, "sum": Vector2.ZERO})
			group["count"] = int(group["count"]) + 1
			group["sum"] = (group["sum"] as Vector2) + point
			groups[best] = group
	tactical_positions = positions
	for index in groups:
		var group: Dictionary = groups[index]
		var count: int = int(group["count"])
		var label_text: String = "%d enemy combat unit%s approaching %s!  ›" % [count, "" if count == 1 else "s", _poi_name(index)]
		_post_tactical_alert("approach:%d" % index, label_text, (group["sum"] as Vector2) / float(count), now)

func sector_contains_for_alert(graph: Dictionary, index: int, point: Vector2) -> bool:
	return ECONOMY.sector_contains(graph, index, point)

func _on_economy_changed() -> void:
	var state: Dictionary = _state()
	_sync_upgrade_audio(state)
	_sync_world_audio(state)
	_refresh_territory(state)
	_sync_tactical_alerts(state)
	_sync_ship_visuals(state)
	_refresh()

func _sync_ship_visuals(state: Dictionary) -> void:
	var updated: Dictionary = {}
	if not state.is_empty():
		var points: Array = state["map"]["points"]
		var samples: Dictionary = session.get("motion_samples")
		var guest: bool = not bool(session.get("is_solo")) and not multiplayer.is_server()
		var duration: float = clampf(float(session.get("diagnostic_motion_gap_ms")) / 1000.0 * 1.2, 0.1, 0.3) if guest else SNAPSHOT_SECONDS
		for ship in state["ships"]:
			var id: int = int(ship["id"])
			var sample: Dictionary = samples.get(id, {})
			var target: Vector2 = sample.get("position", _ship_position(ship, points))
			var heading: Vector2 = sample.get("heading", ship.get("heading", Vector2.UP))
			var previous: Dictionary = ship_visuals.get(id, {})
			var interval: float = duration if not sample.is_empty() else SNAPSHOT_SECONDS
			# Authority revisions, not frame/packet-arrival timing, keep the
			# acceleration estimate stable across rendering rates and peers.
			var revision: int = int(sample.get("revision", session.get("motion_base_revision") if guest else session.get("motion_revision")))
			var speed: int = int(state.get("time_speed", 1))
			if previous.is_empty():
				updated[id] = {"from": target, "to": target, "age": interval, "duration": interval, "heading": heading, "motion_revision": revision, "motion_point": target, "motion_speed": speed, "velocity": Vector2.ZERO, "thrust": 0.0}
				continue
			var prior_revision: int = int(previous.get("motion_revision", revision))
			if speed <= 0 or int(previous.get("motion_speed", speed)) != speed or revision < prior_revision:
				previous["velocity"] = Vector2.ZERO
				previous["thrust"] = 0.0
				previous["motion_revision"] = revision
				previous["motion_point"] = target
			elif revision > prior_revision:
				var sample_dt: float = float(revision - prior_revision) * 0.1 * float(speed)
				var velocity: Vector2 = (target - (previous.get("motion_point", target) as Vector2)) / maxf(0.1, sample_dt)
				var old_velocity: Vector2 = previous.get("velocity", Vector2.ZERO)
				var nominal: float = maxf(1.0, ECONOMY.ship_speed(str(ship["kind"])))
				var delta_velocity: Vector2 = velocity - old_velocity
				# Forward acceleration drives the main plume. Turning gets
				# a smaller burst; braking and tiny position corrections do not.
				var axis: Vector2 = velocity.normalized()
				var forward_accel: float = maxf(0.0, delta_velocity.dot(axis))
				var turning: float = absf(delta_velocity.cross(axis)) * 0.30
				var impulse: float = (forward_accel + turning) * SNAPSHOT_SECONDS / (nominal * maxf(0.1, sample_dt))
				var thrust: float = smoothstep(THRUST_DEAD_ZONE, 0.75, clampf(impulse, 0.0, 1.0))
				thrust *= smoothstep(0.04, 0.25, velocity.length() / nominal)
				previous["thrust"] = maxf(float(previous.get("thrust", 0.0)), thrust) if velocity.length() > nominal * 0.04 else 0.0
				previous["velocity"] = velocity
				previous["motion_revision"] = revision
				previous["motion_point"] = target
			previous["motion_speed"] = speed
			if previous["to"] != target:
				previous["from"] = _visual_position(previous)
				previous["to"] = target
				previous["age"] = 0.0
				previous["duration"] = interval
			previous["heading"] = heading
			updated[id] = previous
	ship_visuals = updated
	for id in ship_offsets.keys():
		if not updated.has(id):
			ship_offsets.erase(id)

func _layout_match_chat() -> void:
	if not is_instance_valid(match_chat_edit):
		return
	var width: float = _notification_width()
	match_chat_edit.position = Vector2((map_canvas.size.x - width) * 0.5, HEADER_HEIGHT + 2.0)
	match_chat_edit.size = Vector2(width, 28.0)

func _close_match_chat() -> void:
	if is_instance_valid(match_chat_edit):
		match_chat_edit.hide()
		match_chat_edit.clear()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not is_instance_valid(match_chat_edit) or str(session.get("phase")) != "match":
		return
	var key: int = event.keycode
	var enter: bool = key in [KEY_ENTER, KEY_KP_ENTER]
	if match_chat_edit.visible:
		if enter or key == KEY_ESCAPE:
			if enter:
				session.call("send_chat", match_chat_edit.text)
			_close_match_chat()
			get_viewport().set_input_as_handled()
		return
	if not enter or event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
		return
	if match_menu.visible or (is_instance_valid(codex) and codex.visible) or (is_instance_valid(match_result_dialog) and match_result_dialog.visible) or (is_instance_valid(hotkey_dialog) and hotkey_dialog.visible) or (is_instance_valid(conquest_dialog) and conquest_dialog.visible) or (is_instance_valid(empire_dialog) and empire_dialog.visible):
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	_layout_match_chat()
	match_chat_edit.show()
	match_chat_edit.grab_focus()
	get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not is_instance_valid(match_menu) or str(session.get("phase")) != "match":
		return
	var key: int = event.physical_keycode
	if is_instance_valid(codex) and codex.visible:
		if key == KEY_ESCAPE:
			codex.hide()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(match_result_dialog) and match_result_dialog.visible:
		return
	if is_instance_valid(hotkey_dialog) and hotkey_dialog.visible:
		return
	if key == KEY_ESCAPE:
		if match_menu.visible:
			match_menu.hide()
		elif not pending_command.is_empty() or formation_button != 0 or selecting_units:
			formation_button = 0
			selecting_units = false
			pending_command = ""
			_refresh_command_mode()
		elif not _trigger_command_hotkey(KEY_ESCAPE):
			_open_menu()
		get_viewport().set_input_as_handled()
		return
	if match_menu.visible or (is_instance_valid(codex) and codex.visible) or (is_instance_valid(match_result_dialog) and match_result_dialog.visible):
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.alt_pressed or event.meta_pressed:
		return
	if key >= KEY_0 and key <= KEY_9:
		var number: int = key - KEY_0
		if event.ctrl_pressed:
			_assign_control_group(number)
		elif event.shift_pressed:
			_assign_control_group(number, true)
		else:
			_recall_control_group(number)
	elif event.ctrl_pressed:
		return
	elif key == KEY_TAB and _cycle_command_kind(event.shift_pressed):
		pass
	elif key == _hotkey_value("focus", hotkey_overrides):
		_focus_selection()
	elif key == _hotkey_value("army", hotkey_overrides):
		_select_all_military()
	elif not _trigger_command_hotkey(key):
		return
	get_viewport().set_input_as_handled()

func _build_global_selection_strip() -> void:
	global_selection_strip = VBoxContainer.new()
	global_selection_strip.theme = HUD.compact()
	global_selection_strip.z_index = 5
	global_selection_strip.add_theme_constant_override("separation", 3)
	add_child(global_selection_strip)
	for entry in [["stations", "Stations", "station", KEY_F1], ["army", "Army", "fighter", KEY_F2], ["shipyards", "Shipyards", "shipyard", KEY_F3]]:
		var action: Callable = _select_all_military if entry[0] == "army" else _select_all_buildings.bind(entry[2])
		var button: Button = _button("", action, global_selection_strip)
		_yard_ability_face(button, entry[1], _selection_portrait_icon(entry[2]))
		_set_button_hint(button, "Select all owned " + str(entry[1]).to_lower())
		_register_command_hotkey(button, int(entry[3]), "General", entry[0], "Select all " + str(entry[1]).to_lower())
	var empire_button: Button = _button("", _open_empire, global_selection_strip)
	_yard_ability_face(empire_button, "Empire", _command_icon('<circle cx="16" cy="16" r="6"/><circle cx="5" cy="6" r="3"/><circle cx="27" cy="6" r="3"/><circle cx="16" cy="28" r="2"/><path d="M8 9L12 12M24 9L20 12M16 22V26"/>'))
	_set_button_hint(empire_button, "Empire fleet planning")
	_register_command_hotkey(empire_button, KEY_F4, "General", "empire", "Empire")
	_build_empire_dialog()
	global_selection_strip.resized.connect(_layout_console)

func _select_all_buildings(kind: String) -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	_clear_building_selection()
	selected_units.clear()
	selected_ship_id = -1
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	for node in range(state["planets"].size()):
		var system: Dictionary = state["planets"][node]
		if int(system["owner"]) != _me():
			continue
		if kind == "station" and ECONOMY.has_station(system):
			selected_buildings[Vector2i(node, 0)] = 0
		elif kind == "shipyard":
			for slot in range(system["yards"].size()):
				selected_buildings[Vector2i(node, slot)] = system["yards"].size()
	if not selected_buildings.is_empty():
		building_selection_kind = kind
		_set_building_primary(state, selected_buildings.keys()[0], kind)
		_load_thresholds()
	last_control_group_recall = -1
	follow_units = false
	pending_command = ""
	formation_button = 0
	selecting_units = false
	_refresh()

func _select_all_military() -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	_clear_building_selection()
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	selected_units.clear()
	for craft in state["ships"]:
		if craft["kind"] in ["fighter", "scout", "cruiser", "destroyer"] and int(craft["owner"]) == _me():
			selected_units.append(int(craft["id"]))
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	var now: int = Time.get_ticks_msec()
	var center_army: bool = last_control_group_recall == -2 and now - last_control_group_recall_ms <= 400
	last_control_group_recall = -1 if center_army else -2
	last_control_group_recall_ms = now
	follow_units = false
	pending_command = ""
	formation_button = 0
	selecting_units = false
	_refresh_command_mode()
	_refresh()
	if center_army and not selected_units.is_empty():
		_follow_selection(state, _ship_poses(state), true)
		_position_territory()
		map_canvas.queue_redraw()

func _keyboard_pan(delta: float) -> void:
	if str(session.get("phase")) != "match" or match_menu.visible or (is_instance_valid(codex) and codex.visible) or (is_instance_valid(match_result_dialog) and match_result_dialog.visible):
		return
	if not get_window().has_focus():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	var edge_direction := Vector2.ZERO
	# Do not edge-scroll while dragging a selection, order or UI control.
	if Input.mouse_mode == Input.MOUSE_MODE_CONFINED and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var bounds: Rect2 = get_viewport_rect()
		var cursor: Vector2 = get_viewport().get_mouse_position() - bounds.position
		if Rect2(Vector2.ZERO, bounds.size).has_point(cursor):
			const EDGE_MARGIN: float = 12.0
			var edge := Vector2(
				float(cursor.x >= bounds.size.x - EDGE_MARGIN) - float(cursor.x < EDGE_MARGIN),
				float(cursor.y >= bounds.size.y - EDGE_MARGIN) - float(cursor.y < EDGE_MARGIN))
			edge_direction = edge
	var velocity: Vector2 = direction.normalized() * keyboard_pan_percent / 100.0 + edge_direction.normalized() * mouse_pan_percent / 100.0
	velocity = velocity.limit_length(maxf(keyboard_pan_percent, mouse_pan_percent) / 100.0)
	_pan_camera(velocity, delta)

func _sync_match_mouse_mode() -> void:
	var active: bool = str(session.get("phase")) == "match" and get_window().has_focus()
	var modal: bool = match_menu.visible or (is_instance_valid(codex) and codex.visible) or (is_instance_valid(match_result_dialog) and match_result_dialog.visible)
	var target: Input.MouseMode = Input.MOUSE_MODE_CONFINED if active and not modal else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target:
		Input.mouse_mode = target

func _pan_camera(direction: Vector2, delta: float) -> void:
	if not direction.is_zero_approx():
		follow_units = false
		camera_world = _camera_world_center() + direction * KEYBOARD_PAN_SPEED * delta / (_fit() * zoom)
		map_canvas.queue_redraw()

func _process(delta: float) -> void:
	conquest_pulse_time += delta
	var glow: float = 0.5 + 0.5 * sin(conquest_pulse_time * TAU / 1.4)
	for button in conquest_buttons.values():
		button.modulate = Color(0.78 + glow * 0.65, 0.68 + glow * 0.57, 0.45 + glow * 0.47) if button.visible and not button.disabled else Color.WHITE
	if formation_button != 0 and not Input.is_mouse_button_pressed(formation_button):
		formation_button = 0
		map_canvas.queue_redraw()
	if selecting_units and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		selecting_units = false
		map_canvas.queue_redraw()
	_sync_match_mouse_mode()
	_keyboard_pan(delta)
	_update_resource_hover()
	if is_instance_valid(diagnostic_label):
		diagnostic_elapsed += delta
		if diagnostic_elapsed >= 1.0:
			var authority: bool = bool(session.get("is_solo")) or multiplayer.is_server()
			var bytes: int = int(session.get("diagnostic_sent_bytes" if authority else "diagnostic_received_bytes"))
			var throughput: float = float(maxi(0, bytes - diagnostic_last_bytes)) / diagnostic_elapsed / 1024.0 if diagnostic_last_bytes >= 0 else 0.0
			diagnostic_last_bytes = bytes
			if diagnostic_label.visible:
				var timing: String = " · sim %.2f ms · encode %.2f ms" % [float(session.get("diagnostic_sim_ms")), float(session.get("diagnostic_encode_ms"))] if authority else ""
				var net: Dictionary = session.call("network_diagnostics")
				if not net.is_empty():
					timing += " · %.0f ms RTT · %.1f%% reliable loss" % [float(net["ping"]), float(net["loss"])]
				if not authority:
					var now: int = Time.get_ticks_msec()
					var last_full: int = int(session.get("diagnostic_last_full_ms"))
					var last_motion: int = int(session.get("diagnostic_last_motion_ms"))
					var full_count: int = int(session.get("diagnostic_full_received"))
					var motion_count: int = int(session.get("diagnostic_motion_received"))
					timing += " · decode %.2f ms · state %.1f Hz / %s · motion %.1f Hz / %s" % [float(session.get("diagnostic_decode_ms")), float(maxi(0, full_count - diagnostic_last_full_count)) / diagnostic_elapsed, "%d ms" % (now - last_full) if last_full >= 0 else "—", float(maxi(0, motion_count - diagnostic_last_motion_count)) / diagnostic_elapsed, "%d ms" % (now - last_motion) if last_motion >= 0 else "—"]
					diagnostic_last_full_count = full_count
					diagnostic_last_motion_count = motion_count
				var phases: Dictionary = session.get("diagnostic_sim_phases") if authority else {}
				var ranked: Array = phases.keys()
				ranked.sort_custom(func(a: String, b: String) -> bool: return int(phases[a]) > int(phases[b]))
				var summary: PackedStringArray = []
				for stage in ranked:
					summary.append("%s %.1fms" % [stage, float(phases[stage]) / 1000.0])
				var hotspot: String = (" · " + summary[0]) if not summary.is_empty() else ""
				diagnostic_label.text = "%d FPS%s%s · %.1f KiB snapshot · %.1f KiB/s payload" % [Engine.get_frames_per_second(), timing, hotspot, float(session.get("diagnostic_snapshot_bytes")) / 1024.0, throughput]
				diagnostic_button.tooltip_text = "Toggle local performance diagnostics\n" + "\n".join(summary)
			diagnostic_elapsed = 0.0
	visual_clock += delta
	for kind in ECONOMY.SHIP_KINDS:
		if yard_commands.has(kind):
			var border: Control = yard_commands[kind].get_meta("auto_border")
			if border.is_visible_in_tree():
				border.queue_redraw()
	for button in station_build_buttons.values():
		if button.has_meta("auto_border"):
			var border: Control = button.get_meta("auto_border")
			if border.is_visible_in_tree():
				border.queue_redraw()
	for id in AUTOCAST_SLOTS:
		if command_buttons.has(id):
			var border: Control = command_buttons[id].get_meta("auto_border")
			if is_instance_valid(border) and border.is_visible_in_tree():
				border.queue_redraw()
	game_visual_clock += delta * float(_state().get("time_speed", 1))
	for visual in ship_visuals.values():
		var duration: float = float(visual.get("duration", SNAPSHOT_SECONDS))
		if float(visual["age"]) < duration:
			visual["age"] = minf(duration, float(visual["age"]) + delta)
		# Exhaust decays even after interpolation reaches its destination.
		visual["thrust"] = float(visual.get("thrust", 0.0)) * exp(-delta * THRUST_FADE_RATE)
	var state: Dictionary = _state()
	if not state.is_empty():
		_update_orbit_clock(state, delta)
		_update_planet_detail(state, delta)
		var poses: Dictionary = _ship_poses(state, delta)
		_follow_selection(state, poses)
		_sync_destruction_effects(state)
	else:
		orbit_visual_time = -1.0
		orbit_sample_time = -1.0
		orbit_seed = -1
		planet_detail_alpha.clear()
		planet_detail_seed = -1
		follow_units = false
		ship_destructions.clear()
		last_destruction_sequence = 0
	if is_instance_valid(map_canvas):
		_position_territory()
		map_canvas.queue_redraw()
	if is_instance_valid(minimap):
		minimap.queue_redraw()

func _orbit_offset(slot: int, radius: float, time: float) -> Vector2:
	var ring: int = floori(float(slot) / 8.0)
	var angle: float = TAU * float(slot % 8) / 8.0 + time * (0.48 / (1.0 + float(ring) * 0.2)) + float(ring) * 0.35
	return Vector2.from_angle(angle) * (radius + 12.0 + float(ring) * 13.0)

func _orbit_direction(offset: Vector2) -> Vector2:
	return Vector2(-offset.y, offset.x).normalized()

func _cached_hull_texture(kind: String, empire: Color, detailed: bool) -> Texture2D:
	var key: String = "%s:%s:%s" % [kind, empire.to_html(false), str(detailed)]
	if not hull_textures.has(key):
		var vertices: Array = HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE if kind == "ship" else [Vector2(9, 0), Vector2(-6, 5), Vector2(-3, 0), Vector2(-6, -5)])
		var outline: String = _hull_svg_points(vertices)
		var half: float = _hull_texture_half_size(kind)
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="%s %s %s %s">' % [-half, -half, half * 2.0, half * 2.0]
		art += '<polygon points="%s" fill="#%s"/>' % [outline, empire.lightened(0.35).to_html(false)]
		if detailed and kind not in ["ship", "science_ship"]:
			for panel in HULL_PANELS.get(kind, []):
				art += '<polygon points="%s" fill="#%s"/>' % [_hull_svg_points(panel[1]), _hull_panel_color(empire, panel[0]).to_html(false)]
		art += '<polygon points="%s" fill="none" stroke="#08111b" stroke-width="2.5" stroke-linejoin="round"/>' % outline
		art += '<polygon points="%s" fill="none" stroke="#%s" stroke-width="1" stroke-linejoin="round"/></svg>' % [outline, empire.lightened(0.2).to_html(false)]
		var image := Image.new()
		image.load_svg_from_string(art)
		hull_textures[key] = ImageTexture.create_from_image(image)
	return hull_textures[key]

func _shield_texture(kind: String) -> Texture2D:
	if not shield_textures.has(kind):
		var outline: String = _hull_svg_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE))
		var half: float = _hull_texture_half_size(kind) + 8.0
		# Three soft bands and a bright rim, baked once per hull type.
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="%s %s %s %s"><g fill="none" stroke-linejoin="round">' % [-half, -half, half * 2.0, half * 2.0]
		for band in [[8.0, 0.10], [5.5, 0.18], [3.5, 0.36], [1.4, 0.95]]:
			art += '<polygon points="%s" stroke="#77ccff" stroke-width="%s" opacity="%s"/>' % [outline, band[0], band[1]]
		art += '</g></svg>'
		var image := Image.new()
		image.load_svg_from_string(art)
		shield_textures[kind] = ImageTexture.create_from_image(image)
	return shield_textures[kind]

func _hull_svg_points(vertices: Array) -> String:
	var coordinates: PackedStringArray = []
	for vertex in vertices:
		coordinates.append("%.2f,%.2f" % [vertex.x, vertex.y])
	return " ".join(coordinates)

func _hull_panel_color(empire: Color, original: Color) -> Color:
	# Use the original value contrast as a shading template, not its class
	# hue; keep the dark cockpit and bright lights readable on every color.
	var value: float = original.get_luminance()
	return empire.darkened(0.72).lerp(empire.lightened(0.75), clampf(value, 0.0, 1.0))

func _sync_destruction_effects(state: Dictionary) -> void:
	while not ship_destructions.is_empty() and visual_clock - float(ship_destructions[0]["started"]) >= DESTRUCTION_LIFETIME:
		ship_destructions.pop_front()
	for event in state.get("ship_destructions", []):
		var sequence: int = int(event["sequence"])
		if sequence <= last_destruction_sequence:
			continue
		last_destruction_sequence = sequence
		var kind: String = event["kind"]
		var heading: Vector2 = event["heading"]
		var angle: float = heading.angle() if not heading.is_zero_approx() else -PI * 0.5
		var empire: Color = _empire_color(int(event["owner"]))
		var hull: Color = empire.lightened(0.35)
		var rng := RandomNumberGenerator.new()
		rng.seed = sequence * 7919 + int(event["ship"])
		var vertices: Array = HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE)
		if kind == "station":
			vertices = []
			for segment in range(16):
				vertices.append(Vector2.from_angle(TAU * float(segment) / 16.0) * 12.0)
		elif kind == "shipyard":
			vertices = [Vector2(-12, -8), Vector2(12, -8), Vector2(12, 8), Vector2(-12, 8)]
		var panels: Array = HULL_PANELS.get(kind, [])
		var edge_color: Color = _empire_color(int(event["owner"])).lightened(0.2)
		var fragments: Array = []
		for index in range(vertices.size()):
			var a: Vector2 = vertices[index]
			var b: Vector2 = vertices[(index + 1) % vertices.size()]
			var center: Vector2 = (a + b) * 0.5
			var velocity: Vector2 = center.normalized().rotated(rng.randf_range(-0.45, 0.45)) * rng.randf_range(12.0, 30.0)
			fragments.append({"offset": center, "half": (b - a) * 0.5, "velocity": velocity, "spin": rng.randf_range(-5.0, 5.0), "color": edge_color, "hull": hull})
		var sparks: Array = []
		# Emit from the actual interior panels rather than a generic fire palette.
		for panel in panels:
			var center: Vector2 = Vector2.ZERO
			var polygon: Array = panel[1]
			for vertex in polygon:
				center += vertex
			center /= float(polygon.size())
			for index in range(2):
				sparks.append(_destruction_spark(center, _hull_panel_color(empire, panel[0]), rng))
		if panels.is_empty():
			# The freighter has dark cargo wells and resource-colored bays.
			for index in range(8):
				sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), Color("#182333"), rng))
			for resource in event.get("materials", []):
				for index in range(3):
					sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), HUD.COLORS.get(resource, hull), rng))
		for index in range(5):
			sparks.append(_destruction_spark(Vector2.ZERO, hull, rng))
		ship_destructions.append({"position": event["position"], "angle": angle, "started": visual_clock, "fragments": fragments, "sparks": sparks, "scale": 3.2 if kind == "station" else 1.0, "structure": not ECONOMY.SHIP_KINDS.has(kind)})
		if ship_destructions.size() > MAX_VISIBLE_DESTRUCTIONS:
			ship_destructions.pop_front()

func _destruction_spark(offset: Vector2, color: Color, rng: RandomNumberGenerator) -> Dictionary:
	var direction: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
	return {"offset": offset, "velocity": direction * rng.randf_range(18.0, 42.0), "size": rng.randf_range(0.65, 1.65), "color": color}

func _draw_ship_destructions(viewport_bounds: Rect2) -> void:
	for effect in ship_destructions:
		var scale: float = maxf(0.2, _ship_scale(bool(effect.get("structure", false)))) * float(effect.get("scale", 1.0))
		var point: Vector2 = _screen_point(effect["position"])
		if not viewport_bounds.grow(maxf(80.0, 60.0 * scale)).has_point(point):
			continue
		var age: float = visual_clock - float(effect["started"])
		var fade: float = clampf(1.0 - age / DESTRUCTION_LIFETIME, 0.0, 1.0)
		if fade <= 0.0:
			continue
		# Local forward and lateral match the original hull transform.
		var forward: Vector2 = Vector2.from_angle(float(effect["angle"])) * scale
		var lateral: Vector2 = forward.orthogonal()
		var travel: float = (1.0 - exp(-2.2 * age)) / 2.2
		for particle in effect["sparks"]:
			var offset: Vector2 = particle["offset"] + particle["velocity"] * travel
			var position: Vector2 = point + forward * offset.x + lateral * offset.y
			_queue_projectile(position, maxf(0.65, float(particle["size"]) * scale * (0.55 + fade * 0.45)), Color(particle["color"], fade))
		# Each original outline segment detaches, drifts and tumbles.
		for fragment in effect["fragments"]:
			var offset: Vector2 = fragment["offset"] + fragment["velocity"] * travel
			var half: Vector2 = (fragment["half"] as Vector2).rotated(float(fragment["spin"]) * age)
			var center: Vector2 = point + forward * offset.x + lateral * offset.y
			var edge: Vector2 = forward * half.x + lateral * half.y
			_queue_beam(center - edge, center + edge, Color(fragment["hull"], fade), maxf(1.0, 2.0 * scale))
			_queue_beam(center - edge, center + edge, Color(fragment["color"], fade), maxf(0.6, scale))

# Same source-player hue for every beam. The wider translucent halo
# and brighter core retain readability without changing the allegiance.
# GPU instanced, color-modulated quads. The circle shader softens edges
# without per-projectile tessellation; beams retain their exact endpoints.
func _build_effect_batch(round_sprite: bool) -> MultiMeshInstance2D:
	var batch := MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad
	batch.multimesh = mesh
	if round_sprite:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float edge = 1.0 - smoothstep(0.85, 1.0, length(UV * 2.0 - 1.0));
	COLOR.a *= edge;
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		batch.material = material
	map_canvas.add_child(batch)
	batch.hide()
	return batch

func _queue_beam(origin: Vector2, target: Vector2, tint: Color, width: float) -> void:
	var axis: Vector2 = target - origin
	var length: float = axis.length()
	if length <= 0.001:
		return
	var bounds := Rect2(origin, axis).abs().grow(width)
	if not bounds.intersects(Rect2(Vector2.ZERO, map_canvas.size), true):
		return
	beam_instances.append([Transform2D(axis.angle(), Vector2(length, width), 0.0, (origin + target) * 0.5), tint])

func _queue_projectile(point: Vector2, radius: float, tint: Color) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(point):
		return
	projectile_instances.append([Transform2D(0.0, Vector2.ONE * radius * 2.0, 0.0, point), tint])

func _flush_effect_batch(batch: MultiMeshInstance2D, entries: Array) -> void:
	if entries.is_empty():
		return
	var mesh: MultiMesh = batch.multimesh
	if mesh.instance_count < entries.size():
		mesh.instance_count = maxi(entries.size(), maxi(64, mesh.instance_count * 2))
	var buffer := PackedFloat32Array()
	buffer.resize(mesh.instance_count * 12)
	for i in range(entries.size()):
		var t: Transform2D = entries[i][0]
		var tint: Color = entries[i][1]
		var offset: int = i * 12
		buffer[offset] = t.x.x
		buffer[offset + 1] = t.y.x
		buffer[offset + 3] = t.origin.x
		buffer[offset + 4] = t.x.y
		buffer[offset + 5] = t.y.y
		buffer[offset + 7] = t.origin.y
		buffer[offset + 8] = tint.r
		buffer[offset + 9] = tint.g
		buffer[offset + 10] = tint.b
		buffer[offset + 11] = tint.a
	mesh.buffer = buffer
	mesh.visible_instance_count = entries.size()
	batch.show()

func _draw_owned_laser(origin: Vector2, target: Vector2, owner: int, width: float) -> void:
	var tint: Color = _empire_color(owner)
	_queue_beam(origin, target, Color(tint, 0.28), width * 3.0)
	_queue_beam(origin, target, tint.lightened(0.28), width)

func _fighter_beam_origin(pose: Dictionary) -> Vector2:
	return (pose["point"] as Vector2) + (pose["direction"] as Vector2) * FIGHTER_MUZZLE * _ship_scale()

func _draw_blaster_tracers(state: Dictionary, ship: Dictionary, poses: Dictionary) -> void:
	if not ship.has("blaster_fired"):
		return
	var age: float = maxf(0.0, _orbit_time(state) - float(ship["blaster_fired"]))
	if age >= ECONOMY.BLASTER_TRAVEL:
		return
	var mounts: Array = {"scout": [Vector2(11, 0)], "fighter": [Vector2(1, -5), Vector2(1, 5)], "cruiser": [Vector2(17, 0), Vector2(5, -10), Vector2(5, 10)], "destroyer": [Vector2(34, -5), Vector2(34, 5), Vector2(14, -15), Vector2(14, 15)]}.get(ship["kind"], [])
	var start: Vector2 = _screen_point(ship["blaster_origin"])
	var endpoint: Vector2 = _screen_point(ship["blaster_endpoint"])
	var direction: Vector2 = poses.get(int(ship["id"]), {}).get("direction", start.direction_to(endpoint))
	var tint: Color = _empire_color(int(ship["owner"])).lightened(0.45)
	var scale: float = _ship_scale()
	for prior in range(int(ship.get("blaster_visual_shot", 0)) + 1):
		var travel: float = (age + float(prior) * ECONOMY.BLASTER_SHOT_INTERVAL) / ECONOMY.BLASTER_TRAVEL
		if travel >= 1.0:
			break
		for mount in mounts:
			var muzzle: Vector2 = start + (direction * mount.x + direction.orthogonal() * mount.y) * scale
			var point: Vector2 = muzzle.lerp(endpoint, travel)
			var radius: float = clampf(scale * 0.9, 1.0, 3.5)
			_queue_projectile(point, radius * 1.8, Color(tint, 0.24))
			_queue_projectile(point, radius, tint)

func _draw_ship_laser(ship: Dictionary, pose: Dictionary, endpoint: Vector2, width: float) -> void:
	if ship["kind"] in ["scout", "fighter"]:
		return
	if ship["kind"] != "miner":
		var mounts: Array = {"cruiser": [Vector2(20, 3), Vector2(20, -3)], "destroyer": [Vector2(30, 12), Vector2(30, -12), Vector2(21, 16), Vector2(21, -16)]}.get(ship["kind"], [Vector2(FIGHTER_MUZZLE, 0)])
		var axis: Vector2 = pose["direction"]
		for mount in mounts:
			_draw_owned_laser((pose["point"] as Vector2) + (axis * mount.x + axis.orthogonal() * mount.y) * _ship_scale(), endpoint, int(ship["owner"]), width)
		return
	var point: Vector2 = pose["point"]
	var direction: Vector2 = pose["direction"] if bool(ship.get("holding", false)) else point.direction_to(endpoint)
	if direction.is_zero_approx():
		direction = pose["direction"]
	pose["direction"] = direction
	var scale: float = _ship_scale()
	for sign in [-1.0, 1.0]:
		var origin: Vector2 = point + (direction * MINER_MUZZLE.x + direction.orthogonal() * sign * MINER_MUZZLE.y) * scale
		_draw_owned_laser(origin, endpoint, int(ship["owner"]), maxf(0.65, width * 0.65))

func _build_ring_batch() -> MultiMeshInstance2D:
	var batch: MultiMeshInstance2D = _build_effect_batch(false)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
varying float radius;
void vertex() {
	radius = max(1.0, length(MODEL_MATRIX[0].xy) * 0.5 - 2.0);
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * (radius + 2.0);
	float angle = atan(p.y, p.x);
	float count = clamp(floor(6.2831853 * radius / 9.0 + 0.5), 6.0, 128.0);
	float phase = fract(angle / 6.2831853 * count);
	float rim = 1.0 - smoothstep(0.25, 1.25, abs(length(p) - radius));
	float dash = 1.0 - smoothstep(0.67, 0.75, phase);
	COLOR.a *= rim * dash;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	batch.material = material
	batch.z_index = 2
	return batch

func _draw_selection_ring(point: Vector2, radius: float, tint: Color = HUD.ACCENT) -> void:
	var extent: float = radius + 2.0
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(extent).has_point(point):
		return
	ring_entries.append([Transform2D(0.0, Vector2.ONE * extent * 2.0, 0.0, point), tint])

# Target indicators use authoritative entity IDs, not the ship's navigation
# waypoint. They follow the interpolated pose and rendered structure geometry.
func _target_ring_entity(state: Dictionary, poses: Dictionary, refs: Dictionary, id: int) -> Dictionary:
	var ref: Dictionary = refs.get(id, {})
	if ref.is_empty():
		return {}
	var center: Vector2 = poses[id]["point"] if poses.has(id) else _screen_point(ref["position"])
	var radius: float = maxf(8.0, _hull_ui_radius(str(ref.get("entity", {}).get("kind", ""))) * _ship_scale())
	match str(ref["kind"]):
		"station": radius = _station_radius() + 4.0
		"yard": radius = maxf(8.0, 23.0 * _ship_scale(true) * pow(1.2, int(ref["entity"]["level"]) - 1))
		"pds":
			var node: int = int(ref["node"])
			var slot: int = floori(float(-2 - id - state["planets"].size() * 3) / float(state["planets"].size()))
			var system_radius: float = _planet_radius(node, state)
			var body: Dictionary = _system_visual(node, state)["bodies"][slot]
			center = _screen_point(ref["repair_position"])
			radius = maxf(6.0, system_radius * float(body["size"]) * 0.55 + 5.0)
	return {"point": center, "radius": radius, "owner": ref["owner"]}

func _ship_target_ring(state: Dictionary, poses: Dictionary, refs: Dictionary, ship: Dictionary) -> Dictionary:
	var destination: int = -1
	if bool(ship.get("retreating", false)):
		destination = int(ship.get("repair_site", -1))
		if destination >= 0:
			return _target_ring_entity(state, poses, refs, ECONOMY.station_target_id(state, destination))
		return {}
	for key in ["attack_order", "combat_target", "pursuit_target", "yard_target", "repair_order", "repair_target"]:
		var target: int = int(ship.get(key, -1))
		if target != -1 and refs.has(target):
			return _target_ring_entity(state, poses, refs, target)
	var cargo: Dictionary = ship.get("cargo_order", {})
	if cargo.get("kind", "") == "deposit":
		return _target_ring_entity(state, poses, refs, int(cargo.get("target", -1)))
	for key in ["salvage_target", "auto_salvage_target"]:
		var pile: Dictionary = state.get("salvage", {}).get(int(ship.get(key, -1)), {})
		if not pile.is_empty():
			return {"point": _screen_point(pile["position"]), "radius": _salvage_radius(pile) + 5.0, "owner": 0}
	if ship.has("local_move_target") or ship.has("launch_rally") or bool(ship.get("holding", false)):
		return {}
	if ship["kind"] == "miner" and ship.get("mining_mode", "") in ["approach", "outbound", "mining"]:
		var field: int = int(ship.get("field", -1))
		if field >= 0 and field < state["map"]["fields"].size():
			var chunk: Dictionary = ECONOMY._find_chunk(state["map"]["fields"][field], int(ship.get("chunk", -1)))
			if not chunk.is_empty():
				var radius: float = float(chunk["radius"]) * _fit() * zoom * sqrt(float(chunk["remaining"]) / float(chunk["initial"]))
				return {"point": _screen_point(chunk["position"]), "radius": maxf(6.0, radius + 4.0), "owner": 0}
	if bool(ship.get("salvage_delivery", false)):
		destination = int(ship.get("salvage_depot", -1))
	elif ship["kind"] == "miner" and ship.get("mining_mode", "") in ["return", "delivery"]:
		destination = int(ship.get("mining_anchor", -1)) if ship.get("mining_mode", "") == "return" else int(ship.get("dest", -1))
	elif ship["kind"] == "ship":
		destination = int(ship.get("source", -1)) if int(ship.get("source", -1)) >= 0 else int(ship.get("dest", -1))
	elif ship["kind"] == "colony_ship":
		destination = int(ship.get("dest", -1))
	if destination >= 0 and destination < state["planets"].size():
		if refs.has(ECONOMY.station_target_id(state, destination)):
			return _target_ring_entity(state, poses, refs, ECONOMY.station_target_id(state, destination))
		return {"point": _screen_point(state["map"]["points"][destination]), "radius": maxf(8.0, _star_draw_radius(_planet_radius(destination, state)) + 5.0), "owner": state["planets"][destination]["owner"]}
	return {}

func _draw_ship_target_rings(state: Dictionary, poses: Dictionary, refs: Dictionary) -> void:
	var drawn: Dictionary = {}
	for ship in state["ships"]:
		if not selected_units.has(int(ship["id"])) and int(ship["id"]) != selected_ship_id:
			continue
		var target: Dictionary = _ship_target_ring(state, poses, refs, ship)
		if target.is_empty() or drawn.has(target["point"]):
			continue
		drawn[target["point"]] = true
		var owner: int = int(target["owner"])
		var tint: Color = Color.WHITE if owner <= 0 else Color("#50a8ff") if ECONOMY._friendly_target(state, _me(), target) else Color("#ff5058")
		var radius: float = float(target["radius"]) + 4.0
		if Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 4.0).has_point(target["point"]):
			map_canvas.draw_arc(target["point"], radius, 0.0, TAU, clampi(ceili(radius * 0.7), 24, 96), tint, 1.8, true)

func _hull_polygon(origin: Vector2, forward: Vector2, lateral: Vector2, vertices: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for vertex in vertices:
		polygon.append(origin + forward * vertex.x + lateral * vertex.y)
	return polygon

func _overview_art_multiplier(maximum: float = OVERVIEW_ART_MAX_MULTIPLIER) -> float:
	# Wheel zoom is logarithmic; blend in the same space for a smooth
	# overview-to-tactical transition, with exact maximum/1x endpoints.
	var progress: float = clampf(log(maxf(zoom, MIN_ZOOM) / MIN_ZOOM) / log(OVERVIEW_ART_NORMAL_ZOOM / MIN_ZOOM), 0.0, 1.0)
	return lerpf(maximum, 1.0, smoothstep(0.0, 1.0, progress))

func _ship_scale(structure: bool = false) -> float:
	# Preserve the authored close-up ceiling and camera framing.
	var base: float = minf(SHIP_WORLD_SCALE * _fit() * minf(zoom, OVERVIEW_MAX_ZOOM), 1.25) * maxf(1.0, zoom / OVERVIEW_MAX_ZOOM)
	return base * _overview_art_multiplier(OVERVIEW_ART_MAX_MULTIPLIER if structure else OVERVIEW_SHIP_MAX_MULTIPLIER)

func _focus_selection() -> void:
	var state: Dictionary = _state()
	if state.is_empty():
		return
	follow_units = true
	_follow_selection(state, _ship_poses(state))
	_position_territory()
	map_canvas.queue_redraw()

func _bounds_zoom(bounds: Rect2) -> float:
	# Fit the selection into the unobstructed play area with breathing room
	# around silhouettes and selection indicators.
	var available: Vector2 = _projection_size() * 0.78
	var extent: Vector2 = bounds.size.max(Vector2.ONE)
	return clampf(minf(available.x / extent.x, available.y / extent.y) / _fit(), MIN_ZOOM, _max_zoom())

func _center_world(point: Vector2) -> void:
	camera_world = point

func _frame_starting_sector(index: int) -> void:
	var state: Dictionary = _state()
	if selected != index or index < 0 or index >= state.get("planets", []).size() or selected_ship_id >= 0 or selected_yard >= 0 or selected_body >= 0 or selected_buildings.size() > 1:
		return
	# The same clipped command-sector boundary used for local navigation.
	var graph: Dictionary = ECONOMY.military_graph(state)
	var extent := Vector2.ZERO
	for i in range(64):
		var direction: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0)
		extent = extent.max((direction * ECONOMY.sector_limit(graph, index, direction)).abs())
	zoom = _bounds_zoom(Rect2(-extent, extent * 2.0))
	_center_world(state["map"]["points"][index])
	_position_territory()
	map_canvas.queue_redraw()

func _follow_selection(state: Dictionary, poses: Dictionary, center_only: bool = false) -> void:
	if (not follow_units and not center_only) or selecting_units or drag_button != 0 or str(session.get("phase")) != "match":
		return
	var ids: Array = selected_units if not selected_units.is_empty() else [selected_ship_id]
	var positions: Array[Vector2] = []
	for id in ids:
		if poses.has(id):
			positions.append(poses[id]["world"])
	var tracking_ships: bool = not positions.is_empty()
	if positions.is_empty():
		for ref in selected_buildings:
			if _building_valid(state, ref, building_selection_kind, int(selected_buildings[ref])):
				positions.append(_building_world(state, ref, building_selection_kind))
	if not positions.is_empty():
		# Equal weight per hull, not per extreme of its bounding box.
		# Preserve the original bounds center for building-only selections.
		if tracking_ships:
			var sum: Vector2 = Vector2.ZERO
			for point in positions:
				sum += point
			_center_world(sum / float(positions.size()))
		else:
			var bounds := Rect2(positions[0], Vector2.ZERO)
			for point in positions:
				bounds = bounds.expand(point)
			_center_world(bounds.get_center())
		return
	var fields: Array = state["map"].get("fields", [])
	if selected_field >= 0 and selected_field < fields.size() and ECONOMY.discovered(state, _me(), "fields", selected_field):
		_center_world(fields[selected_field]["position"])
		return
	if selected >= 0 and selected < state["planets"].size() and ECONOMY.discovered(state, _me(), "planets", selected):
		var system: Dictionary = state["planets"][selected]
		var center: Vector2 = state["map"]["points"][selected]
		if selected_yard >= 0 and selected_yard < system["yards"].size():
			_center_world(ECONOMY.shipyard_position(state, selected, selected_yard, float(state["elapsed"])))
		elif selected_body >= 0 and selected_body < int(system.get("planet_count", 0)):
			_center_world(_building_world(state, Vector2i(selected, selected_body), "pds"))
		elif ECONOMY.has_station(system):
			_center_world(ECONOMY.station_position(state, selected, float(state["elapsed"])))
		else:
			_center_world(center)
		return
	follow_units = false

func _ship_poses(state: Dictionary, delta: float = 0.0) -> Dictionary:
	var frame: int = Engine.get_process_frames()
	var revision: Array = [session.get("motion_revision"), session.get("motion_base_revision"), state.get("elapsed"), state["ships"].size(), state.get("time_speed")]
	if delta <= 0.0 and pose_frame == frame and pose_revision == revision:
		var projected: Dictionary = {}
		for id in pose_world_cache:
			var pose: Dictionary = pose_world_cache[id].duplicate()
			pose["point"] = _screen_point(pose["world"])
			projected[id] = pose
		return projected
	_sync_ship_visuals(state)
	var points: Array = state["map"]["points"]
	var poses: Dictionary = {}
	for ship in state["ships"]:
		if not _ship_visible(state, ship):
			continue
		var id: int = int(ship["id"])
		var visual: Dictionary = ship_visuals.get(id, {})
		var pos: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
		var direction: Vector2 = visual.get("heading", ship.get("heading", Vector2.UP))
		var prior: Dictionary = ship_offsets.get(id, {"angle": direction.angle()})
		var weight: float = 1.0 - exp(-delta / SNAPSHOT_SECONDS * 3.0)
		var angle: float = lerp_angle(float(prior["angle"]), direction.angle(), weight)
		if delta > 0.0 or not ship_offsets.has(id):
			ship_offsets[id] = {"angle": angle}
		var mining: bool = ship.get("kind", "") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]
		poses[id] = {"point": _screen_point(pos), "world": pos, "direction": Vector2.from_angle(angle), "mining": mining, "kind": ship.get("kind", "")}
	pose_frame = frame
	pose_revision = revision
	pose_world_cache = poses.duplicate(true)
	return poses

func _draw_logistics_lens(state: Dictionary, font: Font) -> void:
	if active_lens != "logistics":
		return
	var points: Array = state["map"]["points"]
	for i in range(points.size()):
		var system: Dictionary = state["planets"][i]
		if int(system["owner"]) == 0 or not ECONOMY.discovered(state, _me(), "planets", i):
			continue
		if not ECONOMY.has_station(system):
			continue
		var pos: Vector2 = _screen_point(ECONOMY.station_position(state, i, float(state["elapsed"])))
		var radius: float = _station_radius()
		if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 80.0).has_point(pos):
			continue
		var spacing: float = float(_system_visual(i, state)["spacing"]) * _fit() * zoom
		var scale: float = clampf(spacing / 150.0, 0.22, 1.0)
		var origin: Vector2 = pos + Vector2(-94.0 * scale, radius + 5.0 * scale)
		logistics_overlay.draw_rect(Rect2(origin - Vector2.ONE * 3.0 * scale, Vector2(194, 34.0 + 32.0 * float(maxi(0, ceili(float(ECONOMY.RESOURCES.size()) / 3.0) - 1))) * scale), Color("#0c1928ec"))
		for r in range(ECONOMY.RESOURCES.size()):
			var resource: String = ECONOMY.RESOURCES[r]
			var cell: Vector2 = origin + Vector2(float(r % 3) * 47.0, floorf(float(r) / 3.0) * 32.0) * scale
			var fraction: float = clampf(float(system["stock"][resource]) / ECONOMY.storage_capacity(system), 0.0, 1.0)
			logistics_overlay.draw_rect(Rect2(cell, Vector2(44, 14) * scale), Color("#263b50"))
			logistics_overlay.draw_rect(Rect2(cell, Vector2(44.0 * fraction, 14) * scale), HUD.COLORS[resource].darkened(0.4))
			logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(cell, Vector2(13, 13) * scale), false)
			if scale >= 0.8:
				logistics_overlay.draw_string(font, cell + Vector2(15, 11) * scale, _tons(float(system["stock"][resource]), 0, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			var grade: int = ECONOMY.specialization_grade(system, resource)
			if grade != 0 and scale >= 0.55:
				var badge_pos: Vector2 = cell + Vector2(8, 16) * scale
				logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(badge_pos, Vector2(11, 11) * scale), false)
				var marks: String = ("+" if grade > 0 else "-").repeat(absi(grade))
				logistics_overlay.draw_string(font, badge_pos + Vector2(13, 10) * scale, marks, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, roundi(13 * scale)), Color("#79e59a") if grade > 0 else Color("#ff7777"))
		var pop_cell: Vector2 = origin + Vector2(141, 0) * scale
		var population: float = float(system["population"])
		var capacity: float = maxf(1.0, ECONOMY.sustainable_population_capacity(system))
		logistics_overlay.draw_rect(Rect2(pop_cell, Vector2(50, 14) * scale), Color("#263b50"))
		logistics_overlay.draw_rect(Rect2(pop_cell, Vector2(50 * clampf(population / capacity, 0.0, 1.0), 14) * scale), Color("#44647e"))
		logistics_overlay.draw_texture_rect(_population_texture(24), Rect2(pop_cell, Vector2(13, 13) * scale), false)
		if scale >= 0.8:
			logistics_overlay.draw_string(font, pop_cell + Vector2(15, 11) * scale, "%.1fk" % (population / 1000.0) if population >= 1000 else str(int(population)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	# Aggregate loaded shipments at their origin and final destination.
	var traffic: Dictionary = {}
	for ship in state["ships"]:
		if ship["kind"] != "ship" or ECONOMY._cargo_total(ship) <= ECONOMY.EPS:
			continue
		for endpoint in ["source", "dest"]:
			var node: int = int(ship.get(endpoint, -1))
			if node < 0 or node >= points.size():
				continue
			var lane: Array[int] = ECONOMY._path(state, ECONOMY.planet_teams(state), int(state["planets"][node]["team"]) if state["planets"][node].has("team") else int(ECONOMY.planet_teams(state)[node]), int(ship["source"]), int(ship["dest"]), {})
			if lane.size() < 2:
				continue
			var neighbor: int = lane[1] if endpoint == "source" else lane[lane.size() - 2]
			if not traffic.has(node):
				traffic[node] = {}
			var key: Vector2i = Vector2i(neighbor, 0 if endpoint == "source" else 1)
			if not traffic[node].has(key):
				traffic[node][key] = ECONOMY.empty_stock()
			for resource in ECONOMY.RESOURCES:
				traffic[node][key][resource] += float(ship["cargo"][resource])
	for node in traffic:
		if not ECONOMY.has_station(state["planets"][node]) or not ECONOMY.discovered(state, _me(), "planets", node):
			continue
		var center: Vector2 = _screen_point(ECONOMY.station_position(state, node, float(state["elapsed"])))
		var radius: float = _station_radius()
		for key in traffic[node]:
			var endpoint: String = "source" if key.y == 0 else "dest"
			for k in range(ECONOMY.RESOURCES.size()):
				var resource: String = ECONOMY.RESOURCES[k]
				var cargo: float = traffic[node][key][resource]
				if cargo <= ECONOMY.EPS:
					continue
				var radial: Vector2 = (_screen_point(points[key.x]) - center).normalized()
				var axis: Vector2 = radial if endpoint == "source" else -radial
				var normal: Vector2 = axis.orthogonal()
				var base: Vector2 = center + radial * minf(radius + 24.0 + float(k) * 13.0, center.distance_to(_screen_point(points[key.x])) * 0.48)
				var count: int = clampi(ceili(3.0 * cargo / ECONOMY.CARGO_CAPACITY), 1, 3)
				logistics_overlay.draw_texture_rect(HUD.ICONS[resource], Rect2(base + radial * 14.0 - Vector2(5, 5), Vector2(10, 10)), false)
				for j in range(count):
					var tip: Vector2 = base + axis * float(j * 5)
					logistics_overlay.draw_polyline(PackedVector2Array([tip - axis * 4.0 + normal * 3.0, tip, tip - axis * 4.0 - normal * 3.0]), HUD.COLORS[resource], 1.5, true)

func _station_bay_point(center: Vector2, radius: float, elapsed: float, resource: String, bay: int) -> Vector2:
	var resources: Array = ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]
	var slot: int = resources.find(resource) * ECONOMY.STATION_STORAGE_BAYS + bay
	return center + Vector2.from_angle((float(slot) + 0.5) * TAU / float(resources.size() * ECONOMY.STATION_STORAGE_BAYS) + elapsed * 0.008) * radius * 0.71

func _draw_station_storage(system: Dictionary, center: Vector2, radius: float, elapsed: float) -> void:
	if radius < 8.0:
		return
	var half: float = radius * 0.115
	for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
		var color: Color = HUD.COLORS[resource]
		var fill: float = clampf(float(system["stock"].get(resource, 0.0)) / maxf(ECONOMY.EPS, ECONOMY.storage_capacity(system)), 0.0, 1.0) * ECONOMY.STATION_STORAGE_BAYS
		for bay in range(ECONOMY.STATION_STORAGE_BAYS):
			var point: Vector2 = _station_bay_point(center, radius, elapsed, resource, bay)
			var bounds := Rect2(point - Vector2.ONE * half, Vector2.ONE * half * 2.0)
			map_canvas.draw_rect(bounds, Color("#111d2b"))
			var fraction: float = clampf(fill - float(bay), 0.0, 1.0)
			if fraction > 0.0:
				map_canvas.draw_rect(Rect2(bounds.position + Vector2(0.0, bounds.size.y * (1.0 - fraction)), Vector2(bounds.size.x, bounds.size.y * fraction)), color.darkened(0.25))
			map_canvas.draw_rect(bounds, color, false, maxf(0.8, radius * 0.018))

# Show current production lanes, not queued future yard work.
func _draw_station_jobs(system: Dictionary, center: Vector2, radius: float, tint: Color) -> void:
	if radius < 22.0 or not Rect2(Vector2.ZERO, map_canvas.size).grow(radius).has_point(center):
		return
	var jobs: Array = []
	var infrastructure: Dictionary = ECONOMY.station_construction_job(system)
	if not infrastructure.is_empty():
		jobs.append(infrastructure)
	if jobs.is_empty():
		return
	var columns: int = mini(2, jobs.size())
	var rows: int = ceili(float(jobs.size()) / float(columns))
	var cell: float = radius * (0.46 if jobs.size() == 1 else (0.30 if rows == 1 else 0.20))
	var gap: float = maxf(1.0, cell * 0.1)
	var step: float = cell + gap
	for i in range(jobs.size()):
		var job: Dictionary = jobs[i]
		var row: int = floori(float(i) / float(columns))
		var in_row: int = mini(columns, jobs.size() - row * columns)
		var point: Vector2 = center + Vector2((float(i % columns) - float(in_row - 1) * 0.5) * step, (float(row) - float(rows - 1) * 0.5) * step)
		var icon: Texture2D = _job_icon(job, int(system["owner"]))
		var icon_size: float = cell * 0.82
		map_canvas.draw_texture_rect(icon, Rect2(point - Vector2(icon_size * 0.5, cell * 0.5), Vector2.ONE * icon_size), false)
		var width: float = cell * 0.92
		var height: float = maxf(1.0, cell * 0.09)
		var bar := Rect2(point + Vector2(-width * 0.5, cell * 0.39), Vector2(width, height))
		var fraction: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
		map_canvas.draw_rect(bar, Color("#101a26"))
		map_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), tint.lightened(0.35))

func _draw_station(state: Dictionary, index: int, tint: Color, elapsed: float) -> void:
	var system: Dictionary = state["planets"][index]
	if not ECONOMY.has_station(system):
		return
	var center: Vector2 = _screen_point(ECONOMY.station_position(state, index, elapsed))
	var radius: float = _station_radius()
	var frame: Color = Color("#71869b")
	var selected_station: bool = building_selection_kind == "station" and selected_buildings.has(Vector2i(index, 0))
	# Orbital hub with circular habitat/industrial ring, central docking
	# berth, and three fixed module attachment arms on its rotating frame.
	map_canvas.draw_circle(center, radius, Color("#131e2b"), true, -1.0, true)
	map_canvas.draw_arc(center, radius * 0.85, 0.0, TAU, 48, frame, maxf(2.0, radius * 0.22), true)
	map_canvas.draw_arc(center, radius, 0.0, TAU, 48, tint.lightened(0.30), maxf(1.0, radius * 0.055), true)
	map_canvas.draw_circle(center, radius * 0.32, Color("#293c51"), true, -1.0, true)
	map_canvas.draw_arc(center, radius * 0.35, 0.0, TAU, 24, tint, maxf(1.0, radius * 0.07), true)
	for slot in range(3):
		var axis: Vector2 = Vector2.from_angle(float(slot) * TAU / 3.0 + elapsed * 0.008)
		var side: Vector2 = axis.orthogonal()
		map_canvas.draw_line(center + axis * radius * 0.35, center + axis * radius * 0.87, frame.darkened(0.3), maxf(1.0, radius * 0.13), true)
		var port: Vector2 = center + axis * radius
		map_canvas.draw_line(port - side * radius * 0.18, port + side * radius * 0.18, tint.lightened(0.4), maxf(1.0, radius * 0.07), true)
		var yard_index: int = ECONOMY.shipyard_at_port(system, slot + 1)
		if yard_index >= 0:
			var dock: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, yard_index, elapsed))
			map_canvas.draw_line(port, dock, frame, maxf(1.0, radius * 0.12), true)
	if radius >= 12.0:
		for segment in range(12):
			var a: float = float(segment) * TAU / 12.0 + elapsed * 0.008
			var direction: Vector2 = Vector2.from_angle(a)
			map_canvas.draw_line(center + direction * radius * 0.74, center + direction * radius * 0.95, Color("#1a293a"), maxf(1.0, radius * 0.05), true)
			map_canvas.draw_circle(center + direction * radius * 0.88, maxf(0.8, radius * 0.035), tint.lightened(0.4))
	_draw_station_storage(system, center, radius, elapsed)
	_draw_station_jobs(system, center, radius, tint)
	if selected_station:
		_draw_selection_ring(center, radius + 4.0)
	var hp: float = float(system["station"]["hp"]) / ECONOMY.station_max_hp(system)
	_draw_damage_bar(center, radius, hp, _shield_fraction(system["station"]))
	if _shield_fraction(system["station"]) > 0.0:
		# Stations themselves have a circular hull; use a continuous glow.
		for band in [[6.0, 0.10], [3.5, 0.23], [1.3, 0.85]]:
			map_canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.47, 0.8, 1.0, float(band[1])), float(band[0]), true)

func _draw_shipyard_construction(state: Dictionary, index: int, job: Dictionary, tint: Color, elapsed: float) -> void:
	var port: int = int(job.get("station_slot", job["level"]))
	var point: Vector2 = _screen_point(ECONOMY.shipyard_port_position(state, index, port, elapsed))
	var scale: float = _ship_scale(true)
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(maxf(16.0, 32.0 * scale)).has_point(point):
		return
	var u: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
	var angle: float = float(port - 1) * TAU / 3.0 + elapsed * 0.008
	var lateral: Vector2 = Vector2.from_angle(angle) * scale
	var forward: Vector2 = lateral.orthogonal()
	if scale < 0.15 * _overview_art_multiplier():
		map_canvas.draw_rect(Rect2(point - Vector2.ONE, Vector2.ONE * 2.0), Color(tint, 0.25 + u * 0.75))
		return
	for sign in [-1.0, 1.0]:
		var rail: Array = [Vector2(-17, sign * 8), Vector2(-15, sign * 13), Vector2(-10, sign * 14), Vector2(10, sign * 14), Vector2(15, sign * 13), Vector2(17, sign * 8), Vector2(12, sign * 7), Vector2(-12, sign * 7)]
		var hull: PackedVector2Array = _hull_polygon(point, forward, lateral, rail)
		for k in range(hull.size()):
			var a: Vector2 = hull[k]
			var b: Vector2 = hull[(k + 1) % hull.size()]
			map_canvas.draw_line(a, b, Color(tint, 0.18), maxf(0.65, scale), true)
			var part: float = clampf(u * 2.0 * float(hull.size()) - float(k), 0.0, 1.0)
			if part > 0.0:
				map_canvas.draw_line(a, a.lerp(b, part), tint.lightened(0.4), maxf(0.65, scale), true)
		if u > 0.5:
			map_canvas.draw_colored_polygon(hull, Color(Color("#607387"), (u - 0.5) * 2.0))
	for end in [-1.0, 1.0]:
		var bridge: Vector2 = point + forward * end * 16.0
		map_canvas.draw_line(bridge - lateral * 8.5, bridge + lateral * 8.5, Color(tint, clampf(u * 2.0, 0.18, 1.0)), maxf(0.65, scale), true)

func _draw_shipyards(state: Dictionary, index: int, tint: Color, elapsed: float) -> void:
	var planet: Dictionary = state["planets"][index]
	var pending: Dictionary = ECONOMY.station_construction_job(planet)
	if pending.get("kind", "") == "yard":
		_draw_shipyard_construction(state, index, pending, tint, elapsed)
	for slot in range(planet["yards"].size()):
		var yard: Dictionary = planet["yards"][slot]
		var scale: float = _ship_scale(true) * pow(1.2, int(yard["level"]) - 1)
		var angle: float = float(ECONOMY.shipyard_port(planet, slot) - 1) * TAU / 3.0 + elapsed * 0.008
		var axis: Vector2 = Vector2.from_angle(angle)
		var side: Vector2 = axis.orthogonal()
		var point: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, slot, elapsed))
		if not Rect2(Vector2.ZERO, map_canvas.size).grow(maxf(16.0, 32.0 * scale)).has_point(point):
			continue
		if scale < 0.15 * _overview_art_multiplier():
			var half_size: float = _overview_art_multiplier()
			map_canvas.draw_rect(Rect2(point - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0), tint.lightened(0.25))
			if (selected == index and selected_yard == slot) or (building_selection_kind == "shipyard" and selected_buildings.has(Vector2i(index, slot))):
				_draw_selection_ring(point, 9.0)
			continue
		var conversion: float = clampf((elapsed - float(yard.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
		var frame: PackedVector2Array = PackedVector2Array([point - axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale + side * 17.0 * scale, point - axis * 11.0 * scale + side * 17.0 * scale])
		if conversion < 1.0:
			var heading: Vector2 = yard.get("colony_heading", Vector2.UP)
			var cross: Vector2 = heading.orthogonal()
			var original := PackedVector2Array([point + heading * 6.0 * scale, point + cross * 3.5 * scale, point - heading * 4.5 * scale, point - cross * 3.5 * scale])
			for k in range(4):
				frame[k] = original[k].lerp(frame[k], smoothstep(0.0, 1.0, conversion))
			if not Geometry2D.triangulate_polygon(frame).is_empty():
				map_canvas.draw_colored_polygon(frame, Color(tint.lightened(0.35), 1.0 - conversion))
		if conversion < 1.0:
			for k in range(4):
				map_canvas.draw_line(frame[k], frame[(k + 1) % 4], tint, maxf(0.8, 2.0 * scale), true)
		else:
			# Industrial drydock: open central berth, two reinforced gantries,
			# habitat pods, end clamps and work lights. Draw the large
			# silhouette at every zoom, the finer hardware only up close.
			var forward: Vector2 = side * scale
			var lateral: Vector2 = axis * scale
			for sign in [-1.0, 1.0]:
				var rail: Array = [Vector2(-17, sign * 8), Vector2(-15, sign * 13), Vector2(-10, sign * 14), Vector2(10, sign * 14), Vector2(15, sign * 13), Vector2(17, sign * 8), Vector2(12, sign * 7), Vector2(-12, sign * 7)]
				var hull: PackedVector2Array = _hull_polygon(point, forward, lateral, rail)
				map_canvas.draw_colored_polygon(hull, Color("#607387"))
				hull.append(hull[0])
				map_canvas.draw_polyline(hull, tint, maxf(0.65, scale), true)
				if scale >= 0.42:
					for longitudinal in [-8.0, 1.0, 9.0]:
						var module: Vector2 = point + forward * longitudinal + lateral * sign * 10.5
						var panel: PackedVector2Array = _hull_polygon(module, forward, lateral, [Vector2(-3.5, -2), Vector2(3.5, -2), Vector2(3.5, 2), Vector2(-3.5, 2)])
						map_canvas.draw_colored_polygon(panel, Color("#23384b"))
						map_canvas.draw_line(module - forward * 2.4, module + forward * 2.4, Color("#b0d5e6"), maxf(0.65, scale), true)
					for end in [-1.0, 1.0]:
						var clamp_origin: Vector2 = point + forward * end * 14.0 + lateral * sign * 8.0
						map_canvas.draw_line(clamp_origin, clamp_origin - lateral * sign * 3.0, Color("#d6a965"), maxf(1.0, 2.0 * scale), true)
						map_canvas.draw_circle(clamp_origin, maxf(0.75, scale), tint.lightened(0.45))
			for end in [-1.0, 1.0]:
				var bridge: Vector2 = point + forward * end * 16.0
				map_canvas.draw_line(bridge - lateral * 8.5, bridge + lateral * 8.5, Color("#829aad"), maxf(0.8, 2.0 * scale), true)
			if scale >= 0.42:
				for end in [-1.0, 1.0]:
					var light: Vector2 = point + forward * end * 16.0
					map_canvas.draw_line(light - lateral * 3.0, light + lateral * 3.0, tint.lightened(0.4), maxf(0.7, scale), true)
		if (selected == index and selected_yard == slot) or (building_selection_kind == "shipyard" and selected_buildings.has(Vector2i(index, slot))):
			_draw_selection_ring(point, maxf(9.0, 23.0 * scale))
		var health: float = float(yard.get("hp", ECONOMY.YARD_HP * int(yard["level"]))) / (ECONOMY.YARD_HP * int(yard["level"]))
		_draw_damage_bar(point, maxf(8.0, 22.0 * scale), health)
		for job in planet["queue"]:
			if int(job["id"]) != int(yard["job"]):
				continue
			if job["kind"] == "yard_upgrade":
				var icon: Texture2D = _station_command_icon("upgrade")
				var icon_size: float = 14.0 * scale
				map_canvas.draw_texture_rect(icon, Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)
				var fraction: float = clampf(float(job["progress"]) / maxf(ECONOMY.EPS, float(job["work"])), 0.0, 1.0)
				var bar := Rect2(point + Vector2(-7.0, 8.0) * scale, Vector2(14.0 * scale, maxf(1.0, 1.5 * scale)))
				map_canvas.draw_rect(bar, Color("#101a26"))
				map_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), tint.lightened(0.35))
				break
			if not ECONOMY.SHIP_KINDS.has(job["kind"]):
				continue
			var u: float = clampf(float(job["progress"]) / float(job["work"]), 0.0, 1.0)
			var shape: Array = HULL_OUTLINES.get(str(job["kind"]), FREIGHTER_OUTLINE)
			var hull := PackedVector2Array()
			for vertex in shape:
				hull.append(point + side * vertex.x * scale * 0.5 + axis * vertex.y * scale * 0.5)
			var edges: int = mini(hull.size(), floori(u * 2.0 * hull.size()))
			for k in range(edges):
				map_canvas.draw_line(hull[k], hull[(k + 1) % hull.size()], tint.lightened(0.4), 0.75 * scale, true)
			if u > 0.5 and not Geometry2D.triangulate_polygon(hull).is_empty():
				map_canvas.draw_colored_polygon(hull, Color(tint.lightened(0.4), (u - 0.5) * 2.0))
			break

func _salvage_radius(pile: Dictionary) -> float:
	return maxf(3.0, sqrt(float(pile["amount"])) * 1.6 * _fit() * zoom)

func _salvage_hit(state: Dictionary, point: Vector2) -> int:
	var hit: int = -1
	var nearest: float = INF
	for pile in state.get("salvage", {}).values():
		var distance: float = point.distance_to(_screen_point(pile["position"]))
		if distance <= maxf(7.0, _salvage_radius(pile) + 3.0) and distance < nearest:
			nearest = distance
			hit = int(pile["id"])
	return hit

# A shared white alpha falloff supplies soft local halos without HDR/bloom
# or a particle emitter per resource. Tint at draw time to preserve identity.
func _resource_glow() -> Texture2D:
	if is_instance_valid(resource_glow_texture):
		return resource_glow_texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius: float = ((Vector2(x + 0.5, y + 0.5) - Vector2(32.0, 32.0)) / 32.0).length()
			var alpha: float = pow(maxf(0.0, 1.0 - radius * radius), 3.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	resource_glow_texture = ImageTexture.create_from_image(image)
	return resource_glow_texture

func _draw_resource_glow(point: Vector2, radius: float, tint: Color, strength: float) -> void:
	var extent: float = maxf(1.5, radius)
	map_canvas.draw_texture_rect(_resource_glow(), Rect2(point - Vector2.ONE * extent, Vector2.ONE * extent * 2.0), false, Color(tint.lightened(0.12), strength))

func _queue_cargo_rect(shape: PackedVector2Array, tint: Color) -> void:
	var axis: Vector2 = shape[0] - shape[1]
	var width: float = shape[1].distance_to(shape[2])
	cargo_entries.append([Transform2D(axis.angle(), Vector2(axis.length(), width), 0.0, (shape[0] + shape[2]) * 0.5), tint])

func _draw_cargo_segment(shape: PackedVector2Array, tint: Color) -> void:
	_queue_cargo_rect(shape, tint.lightened(0.14))
	var length: float = shape[0].distance_to(shape[1])
	var width: float = shape[1].distance_to(shape[2])
	if minf(length, width) < 0.8:
		return
	var center: Vector2 = (shape[0] + shape[2]) * 0.5
	var extent: float = clampf(maxf(length, width) * 0.9, 2.0, 48.0)
	var strength: float = 0.32 * clampf(length / maxf(width, 0.1), 0.25, 1.0)
	cargo_glow_entries.append([Transform2D(0.0, Vector2.ONE * extent * 2.0, 0.0, center), Color(tint.lightened(0.12), strength)])

func _draw_salvage(state: Dictionary, poses: Dictionary, viewport_bounds: Rect2, font: Font) -> void:
	if state.get("salvage", {}).is_empty():
		return
	var hovered: int = _salvage_hit(state, map_canvas.get_local_mouse_position())
	var ships_by_id: Dictionary = {}
	for ship in state["ships"]:
		ships_by_id[int(ship["id"])] = ship
	for pile in state.get("salvage", {}).values():
		var point: Vector2 = _screen_point(pile["position"])
		var radius: float = _salvage_radius(pile)
		if not viewport_bounds.grow(radius * 2.6 + 24.0).has_point(point):
			continue
		var tint: Color = HUD.COLORS[pile["resource"]]
		_draw_resource_glow(point, radius * 2.6, tint, 0.58)
		var rotation: float = float(pile["id"]) * 2.4 + game_visual_clock * 0.08
		var axis: Vector2 = Vector2.from_angle(rotation) * radius
		var side: Vector2 = axis.orthogonal() * 0.68
		var shape := PackedVector2Array([point + axis, point + side, point - axis, point - side])
		map_canvas.draw_colored_polygon(shape, tint.lerp(Color.WHITE, 0.12))
		shape.append(shape[0])
		map_canvas.draw_polyline(shape, tint.lightened(0.45), 1.0, true)
		var claimant: int = int(pile["claim"])
		if ships_by_id.has(claimant) and poses.has(claimant):
			var craft: Dictionary = ships_by_id[claimant]
			var color: Color = _empire_color(int(craft["owner"]))
			map_canvas.draw_arc(point, radius + 3.0, 0.0, TAU, 20, Color(color, 0.8), 1.0, true)
			if bool(craft.get("tractor_active", false)):
				var start: Vector2 = poses[claimant]["point"]
				map_canvas.draw_line(start, point, Color(color, 0.22), 5.0, true)
				map_canvas.draw_line(start, point, color.lightened(0.45), 1.5, true)
				var pulse: float = fposmod(visual_clock * 1.8, 1.0)
				map_canvas.draw_circle(point.lerp(start, pulse), 2.0, tint.lightened(0.5))
			elif selected_units.size() == 1 and selected_units.has(claimant):
				map_canvas.draw_line(poses[claimant]["point"], point, Color(color, 0.45), 1.0, true)
		if int(pile["id"]) == hovered:
			var remaining: float = maxf(0.0, float(pile.get("expires_at", float(pile["born"]) + ECONOMY.SALVAGE_MAX_LIFETIME)) - float(state["elapsed"]))
			map_canvas.draw_string(font, point + Vector2(9, -9), "%s · %.1f t · %ds%s" % [pile["resource"], float(pile["amount"]), ceili(remaining), " · Claimed" if claimant >= 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.35))

# Bays represent equal shares of each hull’s capacity, with partial resource-colored fills.
# Preserve the authored bay geometry independently of cargo balance.
func _draw_other_cargo(ship: Dictionary, point: Vector2, forward: Vector2, lateral: Vector2) -> void:
	var kind: String = str(ship["kind"])
	var capacity: float = ECONOMY.cargo_capacity(kind)
	if capacity <= ECONOMY.EPS:
		return
	var count: int = 2 if kind == "miner" else 5 if kind == "colony_ship" else 1
	var bays: Array = ECONOMY.cargo_bays(ship.get("cargo", {}), capacity, count)
	var per_bay: float = capacity / float(count)
	for k in range(count):
		var center: Vector2
		var half_length: float = 1.05
		var half_width: float = 1.35
		if kind == "miner":
			center = Vector2(5.7, -4.8 if k == 0 else 4.8)
			half_length = 0.85
		elif kind == "colony_ship":
			center = Vector2(4.0 - float(k) * 2.65, 0.0)
			half_length = 1.15
		else:
			center = [Vector2(-4.4, 4.7), Vector2(-4.4, -4.7), Vector2(-7.0, 0.0)][k]
		var module: Vector2 = point + forward * center.x + lateral * center.y
		var corners := PackedVector2Array([module + forward * half_length + lateral * half_width, module - forward * half_length + lateral * half_width, module - forward * half_length - lateral * half_width, module + forward * half_length - lateral * half_width])
		_queue_cargo_rect(corners, Color("#182333"))
		var start: float = -half_length
		for segment in bays[k]:
			var end: float = minf(half_length, start + 2.0 * half_length * float(segment["amount"]) / per_bay)
			# Fractional tonnes can project to a degenerate polygon.
			if (end - start) * forward.length() >= 0.1:
				var fill := PackedVector2Array([module + forward * end + lateral * half_width, module + forward * start + lateral * half_width, module + forward * start - lateral * half_width, module + forward * end - lateral * half_width])
				_draw_cargo_segment(fill, HUD.COLORS[segment["resource"]])
			start = end

func _order_color(ship: Dictionary, order: Dictionary) -> Color:
	var kind: String = str(order.get("kind", ""))
	if kind == "patrol":
		return Color("#b880fa")
	if ECONOMY.armed(ship) and (kind == "attack" or (kind in ["sector", "sector_entry", "position"] and not bool(order.get("move_only", false)))):
		return Color("#ff605c")
	if kind == "repair":
		return Color("#55c88b")
	return HUD.ACCENT

# Use the authoritative remaining route, never reconstruct a straight-line path.
func _draw_command_route(graph: Dictionary, ship: Dictionary, start: Vector2, finish: Vector2, tint: Color, dashed: bool = false) -> void:
	var cursor: Vector2 = start
	var points: Array = graph["points"]
	var route: Array = ship.get("route", [])
	for node in route:
		if int(node) < 0 or int(node) >= points.size():
			continue
		var waypoint: Vector2 = _screen_point(points[int(node)])
		if cursor.distance_to(waypoint) > 1.0:
			if dashed:
				map_canvas.draw_dashed_line(cursor, waypoint, Color(tint, 0.8), 1.5, 6.0, true, true)
			else:
				map_canvas.draw_line(cursor, waypoint, Color(tint, 0.8), 1.5, true)
		cursor = waypoint
	if cursor.distance_to(finish) > 1.0:
		if dashed:
			map_canvas.draw_dashed_line(cursor, finish, Color(tint, 0.8), 1.5, 6.0, true, true)
		else:
			map_canvas.draw_line(cursor, finish, Color(tint, 0.8), 1.5, true)

func _draw_single_command_line(state: Dictionary, graph: Dictionary, ship: Dictionary, start: Vector2, poses: Dictionary, refs: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	var endpoint: Vector2 = Vector2.INF
	var tint: Color = _order_color(ship, order)
	var target: int = int(order.get("target", -1))
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		if site >= 0 and site < state["planets"].size():
			endpoint = ECONOMY.station_position(state, site, float(state["elapsed"]))
			tint = Color("#55c88b")
	elif ship.has("patrol_from"):
		endpoint = ship["patrol_start_point"] if bool(ship.get("patrol_returning", false)) else ship["patrol_end_point"]
	elif order.get("kind", "") == "follow" and poses.has(target):
		# The existing follow branch draws its own live line.
		return
	elif ship.has("launch_rally"):
		# The existing rally branch draws its own line.
		return
	elif ship.has("local_move_target"):
		endpoint = ship["local_move_target"]
	elif ECONOMY._unit_order_running(ship):
		endpoint = ECONOMY.unit_order_point(state, graph, ship, order)
		if order.get("kind", "") in ["attack", "repair", "deposit"] and poses.has(target):
			endpoint = Vector2.INF
			_draw_command_route(graph, ship, start, poses[target]["point"], tint)
			return
	if not endpoint.is_finite():
		var depot: int = int(ship.get("salvage_depot", ship.get("dest", -1)))
		var repair: int = int(ship.get("repair_target", -1))
		var salvage: int = int(ship.get("salvage_target", ship.get("auto_salvage_target", -1)))
		var combat: int = int(ship.get("combat_target", -1))
		if refs.has(repair):
			endpoint = refs[repair].get("repair_position", refs[repair]["position"])
			tint = Color("#55c88b")
		elif poses.has(combat):
			_draw_command_route(graph, ship, start, poses[combat]["point"], Color("#ff605c"))
			return
		elif state.get("salvage", {}).has(salvage):
			endpoint = state["salvage"][salvage]["position"]
		elif ship.has("resource_stage"):
			endpoint = ship["resource_stage"]["point"]
		elif ship.get("mining_mode", "") in ["outbound", "mining"] and ship.has("mining_target"):
			endpoint = ship["mining_target"]
		elif depot >= 0 and depot < state["planets"].size() and ECONOMY.has_station(state["planets"][depot]) and ship.get("kind", "") not in ["fighter", "scout", "cruiser", "destroyer"]:
			endpoint = ECONOMY.station_position(state, depot, float(state["elapsed"]))
		elif not ship["route"].is_empty():
			var node: int = int(ship["route"].back())
			if node >= 0 and node < graph["points"].size():
				endpoint = graph["points"][node]
		elif ship.has("hold_position") and bool(ship.get("holding", false)):
			endpoint = ship["hold_position"]
		else:
			endpoint = ship.get("navigation_target", Vector2.INF)
	if endpoint.is_finite():
		var finish: Vector2 = _screen_point(endpoint)
		_draw_command_route(graph, ship, start, finish, tint)

# Shared orders use semantic targets, not individual route legs or formation
# offsets. A sector-entry order has one sector despite differing approach points.
func _group_command_target(state: Dictionary, graph: Dictionary, ship: Dictionary, poses: Dictionary, refs: Dictionary) -> Dictionary:
	if bool(ship.get("holding", false)):
		return {}
	var order: Dictionary = ship.get("unit_order", {})
	var kind: String = str(order.get("kind", ""))
	var target: int = int(order.get("target", -1))
	var endpoint: Vector2 = Vector2.INF
	var tint: Color = _order_color(ship, order)
	var signature: Array = [kind, target, bool(order.get("move_only", false)), bool(order.get("guard", false)), int(order.get("chunk", -1))]
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		if site < 0 or site >= state["planets"].size():
			return {}
		signature = ["withdraw", site]
		endpoint = _screen_point(ECONOMY.station_position(state, site, float(state["elapsed"])))
		tint = Color("#55c88b")
	elif ship.has("launch_rally"):
		signature = ["rally", ship["launch_rally"]["point"]]
		endpoint = _screen_point(ship["launch_rally"]["point"])
		tint = Color("#ff605c")
	elif kind.is_empty() or not ECONOMY._unit_order_running(ship):
		return {}
	elif kind in ["sector", "sector_entry"]:
		if target < 0 or target >= graph["points"].size():
			return {}
		endpoint = _screen_point(graph["points"][target])
	elif kind == "patrol" and ship.has("patrol_from"):
		var leg_end: Vector2 = ship["patrol_start_point"] if bool(ship.get("patrol_returning", false)) else ship["patrol_end_point"]
		signature.append(leg_end)
		endpoint = _screen_point(leg_end)
	elif kind in ["follow", "attack", "repair", "deposit"]:
		if poses.has(target):
			endpoint = poses[target]["point"]
		elif refs.has(target):
			var ref: Dictionary = refs[target]
			var world: Vector2 = ref.get("repair_position", ref["position"]) if kind == "repair" else ref["position"]
			endpoint = _screen_point(world)
		if kind == "follow":
			tint = HUD.ACCENT
	else:
		var world: Vector2 = ECONOMY.unit_order_point(state, graph, ship, order)
		if world.is_finite():
			endpoint = _screen_point(world)
		# Point orders and automatically chosen unload destinations must
		# actually agree; a shared sector alone is not enough.
		signature.append(world)
	if not endpoint.is_finite():
		return {}
	return {"signature": signature, "point": endpoint, "tint": tint}

func _draw_group_command_line(state: Dictionary, poses: Dictionary, refs: Dictionary) -> void:
	var graph: Dictionary = ECONOMY.military_graph(state)
	var shared: Dictionary = {}
	var center := Vector2.ZERO
	var count: int = 0
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		if not selected_units.has(id):
			continue
		if not poses.has(id):
			return
		var command: Dictionary = _group_command_target(state, graph, ship, poses, refs)
		if command.is_empty():
			return
		if shared.is_empty():
			shared = command
		elif command["signature"] != shared["signature"]:
			return
		# Use attack-move color if a mixed fleet has armed members.
		elif command["tint"] == Color("#ff605c"):
			shared["tint"] = command["tint"]
		center += poses[id]["point"] as Vector2
		count += 1
	if count < 2 or count != selected_units.size():
		return
	center /= float(count)
	var finish: Vector2 = shared["point"]
	if center.distance_to(finish) > 1.0:
		# One direct intent indicator; individual ships may take different lanes.
		map_canvas.draw_line(center, finish, Color(shared["tint"], 0.8), 1.5, true)

# Drag placement orders already carry authoritative points and headings.
# Draw their original hull slots independently of shared command-line targets.
func _draw_formation_order_ghost(ship: Dictionary, order: Dictionary, bounds: Rect2) -> void:
	if order.get("kind", "") not in ["position", "patrol"] or not order.get("heading") is Vector2 or not order.get("point") is Vector2:
		return
	var world: Vector2 = order["point"]
	if not world.is_finite():
		return
	var point: Vector2 = _screen_point(world)
	if not bounds.has_point(point):
		return
	_draw_destination_ghost(str(ship["kind"]), point, order["heading"], _order_color(ship, order))

func _draw_group_formation_ghosts(state: Dictionary, viewport_bounds: Rect2) -> void:
	var bounds: Rect2 = viewport_bounds.grow(60.0 * maxf(0.42, _ship_scale()))
	for ship in state["ships"]:
		if not selected_units.has(int(ship["id"])) or int(ship["owner"]) != _me():
			continue
		var order: Dictionary = ship.get("unit_order", {})
		# Preserve the planned patrol endpoint on either leg and the move
		# destination through combat or repair. Completed orders disappear.
		if (order.get("kind", "") == "position" and ship.has("local_move_target")) or (order.get("kind", "") == "patrol" and ship.has("patrol_from")):
			_draw_formation_order_ghost(ship, order, bounds)
		for queued in ship.get("order_queue", []):
			_draw_formation_order_ghost(ship, queued, bounds)

func _draw_queued_orders(state: Dictionary, graph: Dictionary, ship: Dictionary, start: Vector2, drawn_sectors: Dictionary) -> void:
	var order: Dictionary = ship.get("unit_order", {})
	var endpoint: Vector2 = ECONOMY.unit_order_point(state, graph, ship, order)
	if ship.has("patrol_from") and ship.get("patrol_returning", false):
		endpoint = ship["patrol_start_point"]
	if endpoint.is_finite() and ECONOMY._unit_order_running(ship):
		start = _screen_point(endpoint)
	elif ship.has("launch_rally"):
		start = _screen_point(ship["launch_rally"]["point"])
	for pending in ship.get("order_queue", []):
		endpoint = ECONOMY.unit_order_point(state, graph, ship, pending)
		if not endpoint.is_finite():
			continue
		var finish: Vector2 = _screen_point(endpoint)
		var tint: Color = _order_color(ship, pending)
		if pending["kind"] in ["sector", "sector_entry"]:
			_draw_sector_target(graph, int(pending["target"]), tint, drawn_sectors)
		elif pending["kind"] == "position" or (pending["kind"] == "patrol" and pending.has("heading")):
			_draw_destination_ghost(ship["kind"], finish, pending.get("heading", finish - start), tint)
		map_canvas.draw_dashed_line(start, finish, Color(tint, 0.45), 1.0, 5.0, true, true)
		start = finish

func _transfer_anchor(state: Dictionary, poses: Dictionary, refs: Dictionary, id: int, resource: String, bay: int) -> Vector2:
	var ref: Dictionary = refs.get(id, {})
	if ref.get("kind", "") == "station":
		var node: int = int(ref["node"])
		if not ECONOMY.discovered(state, _me(), "planets", node):
			return Vector2.INF
		return _station_bay_point(_screen_point(ECONOMY.station_position(state, node, float(state["elapsed"]))), _station_radius(), float(state["elapsed"]), resource, bay)
	if not poses.has(id):
		return Vector2.INF
	var pose: Dictionary = poses[id]
	var kind: String = str(pose["kind"])
	var offset: Vector2 = Vector2.ZERO
	if kind == "ship":
		offset = _freighter_bay_center(bay)
	elif kind == "miner":
		offset = Vector2(5.7, -4.8 if bay == 0 else 4.8)
	elif kind == "colony_ship":
		offset = Vector2(4.0 - float(bay) * 2.65, 0.0)
	var axis: Vector2 = pose["direction"]
	return (pose["point"] as Vector2) + (axis * offset.x + axis.orthogonal() * offset.y) * _ship_scale()

func _draw_cargo_transfers(state: Dictionary, poses: Dictionary, refs: Dictionary, bounds: Rect2) -> void:
	var seed_value: int = int(state["map"]["seed"])
	if transfer_visual_seed != seed_value:
		transfer_visual_seed = seed_value
		transfer_visuals.clear()
	var events: Dictionary = state.get("cargo_transfers", {})
	for key in transfer_visuals.keys():
		if not events.has(key):
			transfer_visuals.erase(key)
	for key in events:
		var event: Dictionary = events[key]
		var old: Dictionary = transfer_visuals.get(key, {})
		if int(old.get("seq", -1)) != int(event["seq"]):
			var start: float = float(old.get("start", visual_clock)) if visual_clock - float(old.get("last", -100.0)) < 0.65 else visual_clock
			old = {"seq": event["seq"], "start": start, "last": visual_clock}
			transfer_visuals[key] = old
		var age: float = visual_clock - float(old["last"])
		if age > 0.65:
			continue
		var resource: String = event["resource"]
		var a: Vector2 = _transfer_anchor(state, poses, refs, int(event["source"]), resource, int(event["from_bay"]))
		var b: Vector2 = _transfer_anchor(state, poses, refs, int(event["target"]), resource, int(event["to_bay"]))
		if not a.is_finite() or not b.is_finite() or (not bounds.grow(30.0).has_point(a) and not bounds.grow(30.0).has_point(b)):
			continue
		var color: Color = HUD.COLORS[resource]
		var count: int = clampi(ceili(sqrt(float(event["amount"])) * 2.0), 2, 8)
		var radius: float = clampf(_ship_scale() * 1.2, 0.9, 3.5)
		for i in range(count):
			var phase: float = fposmod((visual_clock - float(old["start"])) * 2.8 + float(i) / float(count), 1.0)
			var point: Vector2 = a.lerp(b, phase)
			var alpha: float = (1.0 - age / 0.65) * smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
			map_canvas.draw_circle(point, radius * 2.0, Color(color, alpha * 0.18), true, -1.0, true)
			map_canvas.draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color(color.lightened(0.2), alpha))

# One GPU-instanced quad batch per cached overview texture. Keep detailed
# hulls and gameplay/picking on their existing paths.
func _build_exhaust_batch() -> void:
	exhaust_batch = MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad
	exhaust_batch.multimesh = mesh
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float visual_time;
varying vec4 plume;
void vertex() {
	plume = INSTANCE_CUSTOM;
}
void fragment() {
	float t = 1.0 - UV.x;
	float y = abs(UV.y * 2.0 - 1.0);
	float taper = max(0.0, 1.0 - t);
	float sheath = (1.0 - smoothstep(taper * 0.75, taper + 0.04, y)) * (1.0 - smoothstep(0.8, 1.0, t));
	float core_width = max(0.0, 0.45 * (1.0 - t / 0.4));
	float core = (1.0 - smoothstep(core_width * 0.7, core_width + 0.025, y)) * (1.0 - smoothstep(0.32, 0.4, t));
	float phase = fract(t * 5.0 - visual_time * 4.5 + plume.y);
	float sparks = (1.0 - smoothstep(0.06, 0.22, abs(phase - 0.5))) * (1.0 - smoothstep(0.12, 0.35, y)) * taper;
	float alpha = clamp(plume.x * (0.34 * sheath + 0.9 * core + 0.45 * sparks), 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.15, 0.62, 1.0), vec3(0.8, 0.96, 1.0), core), alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	exhaust_batch.material = material
	map_canvas.add_child(exhaust_batch)
	exhaust_batch.hide()

func _queue_exhaust(kind: String, point: Vector2, direction: Vector2, scale: float, thrust: float, id: int, bounds: Rect2) -> void:
	if not exhaust_extents.has(kind):
		var rear: float = 0.0
		var nose: float = 0.0
		for vertex in HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE):
			rear = minf(rear, vertex.x)
			nose = maxf(nose, vertex.x)
		exhaust_extents[kind] = Vector2(rear, maxf(0.5, (nose - rear) / 18.0))
	var extent: Vector2 = exhaust_extents[kind]
	var engine: Vector2 = point + direction * extent.x
	var plume_length: float = extent.y * lerpf(4.0, 20.0, thrust) * scale
	var plume_width: float = extent.y * lerpf(0.8, 2.1, thrust) * scale
	if not bounds.grow(maxf(24.0, plume_length + 8.0)).has_point(engine):
		return
	var center: Vector2 = engine - direction.normalized() * plume_length * 0.5
	exhaust_instances.append([Transform2D(direction.angle(), Vector2(plume_length, plume_width * 2.0), 0.0, center), thrust, fposmod(float(id) * 0.173, 1.0)])

func _flush_exhaust() -> void:
	if exhaust_instances.is_empty():
		return
	var mesh: MultiMesh = exhaust_batch.multimesh
	if mesh.instance_count < exhaust_instances.size():
		mesh.instance_count = maxi(exhaust_instances.size(), maxi(64, mesh.instance_count * 2))
	var buffer := PackedFloat32Array()
	buffer.resize(mesh.instance_count * 12)
	for i in range(exhaust_instances.size()):
		var entry: Array = exhaust_instances[i]
		var t: Transform2D = entry[0]
		var offset: int = i * 12
		buffer[offset] = t.x.x
		buffer[offset + 1] = t.y.x
		buffer[offset + 3] = t.origin.x
		buffer[offset + 4] = t.x.y
		buffer[offset + 5] = t.y.y
		buffer[offset + 7] = t.origin.y
		buffer[offset + 8] = entry[1]
		buffer[offset + 9] = entry[2]
	mesh.buffer = buffer
	mesh.visible_instance_count = exhaust_instances.size()
	(exhaust_batch.material as ShaderMaterial).set_shader_parameter("visual_time", visual_clock)
	exhaust_batch.show()

func _overview_dot_texture(tint: Color) -> Texture2D:
	var key: String = tint.to_html(false)
	if not overview_dot_textures.has(key):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="31" fill="#%s"/></svg>' % key)
		overview_dot_textures[key] = ImageTexture.create_from_image(image)
	return overview_dot_textures[key]

func _queue_overview_hull(texture: Texture2D, point: Vector2, angle: float, extent: float) -> void:
	if not overview_instances.has(texture):
		overview_instances[texture] = []
	overview_instances[texture].append(Transform2D(angle, Vector2.ONE * extent * 2.0, 0.0, point))

func _flush_overview_hulls() -> void:
	for texture in overview_instances:
		var transforms: Array = overview_instances[texture]
		if not overview_batches.has(texture):
			var instance := MultiMeshInstance2D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.mesh = quad
			instance.multimesh = mm
			instance.texture = texture
			if shield_textures.values().has(texture):
				instance.z_index = 1
			map_canvas.add_child(instance)
			overview_batches[texture] = instance
		var batch: MultiMeshInstance2D = overview_batches[texture]
		var mesh: MultiMesh = batch.multimesh
		if mesh.instance_count < transforms.size():
			mesh.instance_count = maxi(transforms.size(), maxi(64, mesh.instance_count * 2))
		var buffer := PackedFloat32Array()
		buffer.resize(mesh.instance_count * 8)
		for i in range(transforms.size()):
			var t: Transform2D = transforms[i]
			var offset: int = i * 8
			buffer[offset] = t.x.x
			buffer[offset + 1] = t.y.x
			buffer[offset + 3] = t.origin.x
			buffer[offset + 4] = t.x.y
			buffer[offset + 5] = t.y.y
			buffer[offset + 7] = t.origin.y
		mesh.buffer = buffer
		mesh.visible_instance_count = transforms.size()
		batch.show()

func _draw_map() -> void:
	logistics_overlay.queue_redraw()
	objectives_overlay.queue_redraw()
	asteroid_frame_meshes.clear()
	health_entries.clear()
	ring_entries.clear()
	health_batch.hide()
	ring_batch.hide()
	cargo_entries.clear()
	cargo_glow_entries.clear()
	cargo_batch.hide()
	cargo_glow_batch.hide()
	beam_instances.clear()
	projectile_instances.clear()
	beam_batch.hide()
	projectile_batch.hide()
	exhaust_instances.clear()
	exhaust_batch.hide()
	overview_instances.clear()
	for batch in overview_batches.values():
		batch.hide()
	if session == null:
		return
	var state: Dictionary = _state()
	if state.is_empty():
		return
	var seed_value: int = int(state["map"]["seed"])
	if asteroid_cache_seed != seed_value:
		asteroid_shape_cache.clear()
		asteroid_cache_seed = seed_value
	var viewport_bounds := Rect2(Vector2.ZERO, map_canvas.size)
	var render_scale: float = _fit() * zoom
	var points: Array = state["map"]["points"]
	var font: Font = ThemeDB.fallback_font
	var fields: Array = state["map"].get("fields", [])
	for field_index in range(fields.size()):
		var field: Dictionary = fields[field_index]
		var center: Vector2 = _screen_point(field["position"])
		if not viewport_bounds.grow(float(field["radius"]) * render_scale * 2.0 + 40.0).has_point(center):
			continue
		if not ECONOMY.discovered(state, _me(), "fields", field_index):
			map_canvas.draw_string(font, center + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
			continue
		var boundary := PackedVector2Array()
		for vertex in field["outline"]:
			boundary.append(_screen_point(vertex))
		if not boundary.is_empty():
			var special: bool = bool(field.get("antimatter", false))
			var edge_tint: Color = HUD.COLORS[ECONOMY.ANTIMATTER] if special else Color("#b9ac77")
			map_canvas.draw_colored_polygon(boundary, Color(edge_tint, 0.09))
			boundary.append(boundary[0])
			map_canvas.draw_polyline(boundary, HUD.ACCENT if selected_field == field_index else Color(edge_tint, 0.8 if special else 0.25), 1.5, true)
			if special:
				map_canvas.draw_string(font, center + Vector2(-60, float(field["radius"]) * render_scale + 14.0), "Pulsar", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, edge_tint)
		if bool(field.get("antimatter", false)):
			var pulse: float = 0.5 + 0.5 * sin(visual_clock * 3.0)
			var star_radius: float = maxf(4.0, float(field["radius"]) * render_scale * 0.16)
			var glow: Color = HUD.COLORS[ECONOMY.ANTIMATTER]
			_draw_resource_glow(center, star_radius * 2.0, glow, 0.6 + pulse * 0.4)
			map_canvas.draw_circle(center, star_radius, glow.lightened(0.7), true, -1.0, true)
			var axis: Vector2 = Vector2.from_angle(visual_clock * 0.8)
			map_canvas.draw_line(center - axis * star_radius * 4.0, center + axis * star_radius * 4.0, Color(glow, 0.45 + pulse * 0.4), maxf(1.0, star_radius * 0.45), true)
			continue
		var rock_vertices := PackedVector3Array()
		var rock_colors := PackedColorArray()
		for chunk in field["chunks"]:
			var rock_pos: Vector2 = _screen_point(chunk["position"])
			if not viewport_bounds.grow(maxf(4.0, float(chunk["radius"]) * render_scale * 2.0)).has_point(rock_pos):
				continue
			var fraction: float = float(chunk["remaining"]) / float(chunk["initial"])
			var rock_radius: float = maxf(1.3, float(chunk["radius"]) * render_scale * sqrt(fraction))
			var shape_key: Vector2 = chunk["position"]
			if not asteroid_shape_cache.has(shape_key):
				var unit_shape := PackedVector2Array()
				for k in range(chunk["shape"].size()):
					var angle: float = TAU * float(k) / float(chunk["shape"].size()) + float(chunk["rotation"])
					unit_shape.append(Vector2.from_angle(angle) * float(chunk["shape"][k]))
				asteroid_shape_cache[shape_key] = {"vertices": unit_shape, "triangles": Geometry2D.triangulate_polygon(unit_shape)}
			var rock := PackedVector2Array()
			var cached: Dictionary = asteroid_shape_cache[shape_key]
			for vertex in cached["vertices"]:
				rock.append(rock_pos + vertex * rock_radius)
			var tint: Color = HUD.COLORS[chunk["resource"]]
			for index in cached["triangles"]:
				var p: Vector2 = rock[index]
				rock_vertices.append(Vector3(p.x, p.y, 0.0))
				rock_colors.append(tint.darkened(0.25))
			# Batch thin edge quads, retaining the existing screen-space width.
			for k in range(rock.size()):
				var p: Vector2 = rock[k]
				var q: Vector2 = rock[(k + 1) % rock.size()]
				var normal: Vector2 = (q - p).normalized().orthogonal() * 0.4
				for v in [p - normal, q - normal, q + normal, p - normal, q + normal, p + normal]:
					rock_vertices.append(Vector3(v.x, v.y, 0.0))
					rock_colors.append(tint)
		if not rock_vertices.is_empty():
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = rock_vertices
			arrays[Mesh.ARRAY_COLOR] = rock_colors
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			asteroid_frame_meshes.append(mesh)
			map_canvas.draw_mesh(mesh, null)
	for i in range(points.size()):
		var pos: Vector2 = _screen_point(points[i])
		if not ECONOMY.discovered(state, _me(), "planets", i):
			map_canvas.draw_string(font, pos + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
			continue
		var radius: float = _planet_radius(i, state)
		var tint: Color = _empire_color(int(state["planets"][i]["owner"]))
		_draw_system(i, state, pos, radius, tint)
		_draw_station(state, i, tint, float(state["elapsed"]))
		_draw_shipyards(state, i, tint, float(state["elapsed"]))
		if _show_system_rings(i):
			var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
			for angle in range(4):
				var start: float = float(angle) * TAU / 4.0 + 0.1
				map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
		var name_star_radius: float = _star_draw_radius(radius)
		map_canvas.draw_string(font, pos + Vector2(-80, -name_star_radius - 7), _system_name(i), HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#f4faff") if i == selected else Color(0.83, 0.89, 0.95, 0.65))
	for ref in _selected_yards(state):
		var rally: Dictionary = state["planets"][ref.x]["yards"][ref.y].get("rally", {})
		if not rally.is_empty():
			var start: Vector2 = _screen_point(ECONOMY.shipyard_position(state, ref.x, ref.y, float(state["elapsed"])))
			var target: Vector2 = _screen_point(rally["point"])
			var rally_tint := Color("#ff605c")
			map_canvas.draw_line(start, target, Color(rally_tint, 0.65), 1.5, true)
			var pole_top: Vector2 = target + Vector2(0, -23)
			var flag := PackedVector2Array([pole_top, pole_top + Vector2(15, 0), pole_top + Vector2(10, 5), pole_top + Vector2(15, 10), pole_top + Vector2(0, 10)])
			map_canvas.draw_line(target, pole_top, Color("#111b26"), 4.0, true)
			map_canvas.draw_line(target, pole_top, rally_tint, 2.0, true)
			map_canvas.draw_colored_polygon(flag, rally_tint)
			flag.append(flag[0])
			map_canvas.draw_polyline(flag, Color("#111b26"), 1.0, true)
	var poses: Dictionary = _ship_poses(state)
	_draw_salvage(state, poses, viewport_bounds, font)
	var service_refs: Dictionary = ECONOMY.service_targets(state)
	for gate in state["ships"]:
		if gate.get("kind", "") != "warp_gate" or int(gate["owner"]) != _me():
			continue
		var target: Dictionary = service_refs.get(int(gate.get("warp_destination", -1)), {}).get("entity", {})
		if target.get("kind", "") == "warp_gate" and int(target["owner"]) == _me():
			map_canvas.draw_line(_screen_point(gate["position"]), _screen_point(target["position"]), Color("#855bbf80"), 2.0, true)
	_draw_ship_target_rings(state, poses, service_refs)
	if selected_units.size() > 1:
		_draw_group_command_line(state, poses, service_refs)
		_draw_group_formation_ghosts(state, viewport_bounds)
	if selected_units.size() == 1:
		var order_graph: Dictionary = ECONOMY.military_graph(state)
		var drawn_sectors: Dictionary = {}
		for craft in state["ships"]:
			var id: int = int(craft["id"])
			if not selected_units.has(id) or not poses.has(id):
				continue
			var start: Vector2 = poses[id]["point"]
			if selected_units.size() == 1:
				_draw_single_command_line(state, order_graph, craft, start, poses, service_refs)
			_draw_queued_orders(state, order_graph, craft, start, drawn_sectors)
			var active_order: Dictionary = craft.get("unit_order", {})
			var order_tint: Color = _order_color(craft, active_order)
			if craft.has("patrol_from"):
				var from: Vector2 = _screen_point(craft["patrol_start_point"])
				var to: Vector2 = _screen_point(craft["patrol_end_point"])
				map_canvas.draw_dashed_line(from, to, Color("#b880fa"), 1.5, 4.0, true, true)
				_draw_formation_order_ghost(craft, active_order, viewport_bounds.grow(60.0 * maxf(0.42, _ship_scale())))
			elif craft.has("launch_rally") and not bool(craft.get("retreating", false)):
				var destination: Vector2 = _screen_point(craft["launch_rally"]["point"])
				var rally_tint := Color("#ff605c")
				_draw_command_route(order_graph, craft, start, destination, rally_tint)
				_draw_destination_ghost(craft["kind"], destination, destination - start, rally_tint)
			elif active_order.get("kind", "") == "follow" and poses.has(int(active_order["target"])):
				var destination: Vector2 = poses[int(active_order["target"])]["point"]
				_draw_command_route(order_graph, craft, start, destination, HUD.ACCENT, true)
			elif active_order.get("kind", "") in ["sector", "sector_entry"] and ECONOMY._unit_order_running(craft):
				_draw_sector_target(order_graph, int(active_order["target"]), order_tint, drawn_sectors)
			elif active_order.get("kind", "") == "position" and ECONOMY._unit_order_running(craft):
				var endpoint: Vector2 = ECONOMY.unit_order_point(state, order_graph, craft, active_order)
				if endpoint.is_finite():
					var destination: Vector2 = _screen_point(endpoint)
					_draw_destination_ghost(craft["kind"], destination, active_order.get("heading", destination - start), order_tint)
			elif craft.has("local_move_target") and not bool(craft.get("retreating", false)):
				var destination: Vector2 = _screen_point(craft["local_move_target"])
				_draw_destination_ghost(craft["kind"], destination, active_order.get("heading", destination - start), order_tint)
	for index in range(points.size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		var system: Dictionary = state["planets"][index]
		var weapons: Array = system.get("station", {}).get("weapons", [])
		for emitter in range(weapons.size()):
			var weapon: Dictionary = weapons[emitter]
			var target: int = int(weapon["target"])
			if not poses.has(target) or float(weapon["laser_until"]) < float(state["elapsed"]):
				continue
			var center: Vector2 = _screen_point(ECONOMY.station_position(state, index, float(state["elapsed"])))
			var endpoint: Vector2 = poses[target]["point"]
			var offset: Vector2 = center.direction_to(endpoint).orthogonal() * (float(emitter) * 2.0 - float(weapons.size() - 1)) * 4.0 * _ship_scale(true)
			_draw_owned_laser(center + offset, endpoint, int(system["owner"]), 1.5)
		var defenses: Dictionary = state["planets"][index].get("pds", {})
		if defenses.is_empty():
			continue
		var radius: float = _planet_radius(index, state)
		for slot in defenses:
			var battery: Dictionary = defenses[slot]
			var target: int = int(battery["target"])
			if not poses.has(target) or float(battery["laser_until"]) < float(state["elapsed"]):
				continue
			var origin: Vector2 = _screen_point(points[index])
			if _planet_detail_opacity(index, radius) >= 0.5:
				origin += _body_position(_system_visual(index, state)["bodies"][slot], radius, _orbit_time(state))
			_draw_owned_laser(origin, poses[target]["point"], int(state["planets"][index]["owner"]), 2.0)
	for ship in state["ships"]:
		if not _ship_visible(state, ship):
			continue
		var shooter: int = int(ship["id"])
		_draw_blaster_tracers(state, ship, poses)
		if float(ship.get("missile_until", -1.0)) >= float(state["elapsed"]) and ship.has("missile_endpoint"):
			var a: Vector2 = _screen_point(ship["missile_origin"])
			var b: Vector2 = _screen_point(ship["missile_endpoint"])
			var phase: float = clampf(1.0 - (float(ship["missile_until"]) - _orbit_time(state)) / 0.65, 0.0, 1.0)
			var axis: Vector2 = a.direction_to(b)
			for launcher in range(ECONOMY.missile_count(str(ship["kind"]))):
				var offset: Vector2 = axis.orthogonal() * (float(launcher) - float(ECONOMY.missile_count(str(ship["kind"])) - 1) * 0.5) * 6.0 * sin(phase * PI)
				var launch: Vector2 = a
				if poses.has(shooter):
					var facing: Vector2 = poses[shooter]["direction"]
					var mount: Vector2 = Vector2(4, 0) if ship["kind"] == "cruiser" else Vector2(8, -8 if launcher == 0 else 8)
					launch += (facing * mount.x + facing.orthogonal() * mount.y) * _ship_scale()
				var tip: Vector2 = launch.lerp(b, phase) + offset
				_queue_beam(tip - axis * 12.0, tip, Color("#ffb36b"), 2.0)
				_queue_projectile(tip, 2.0, Color("#fff2d2"))
		var target: int = int(ship.get("combat_target", -1))
		var yard_target: int = int(ship.get("yard_target", -1))
		if poses.has(shooter) and yard_target < -1 and float(ship.get("yard_laser_until", -1.0)) >= float(state["elapsed"]):
			var encoded: int = -2 - yard_target
			var count: int = (state["planets"] as Array).size()
			if encoded < count * 3:
				var index: int = floori(float(encoded) / 3.0)
				var slot: int = posmod(encoded, 3)
				if slot < state["planets"][index]["yards"].size():
					_draw_ship_laser(ship, poses[shooter], _screen_point(ECONOMY.shipyard_position(state, index, slot, float(state["elapsed"]))), 1.5)
			elif encoded >= count * 9:
				var station_index: int = encoded - count * 9
				if station_index < count and ECONOMY.has_station(state["planets"][station_index]):
					_draw_ship_laser(ship, poses[shooter], _screen_point(ECONOMY.station_position(state, station_index, float(state["elapsed"]))), 1.5)
			else:
				var pds_index: int = posmod(encoded - count * 3, count)
				var pds_slot: int = floori(float(encoded - count * 3) / float(count))
				if state["planets"][pds_index].get("pds", {}).has(pds_slot):
					var endpoint: Vector2 = _screen_point(points[pds_index])
					var pds_radius: float = _planet_radius(pds_index, state)
					if _planet_detail_opacity(pds_index, pds_radius) >= 0.5:
						endpoint += _body_position(_system_visual(pds_index, state)["bodies"][pds_slot], pds_radius, _orbit_time(state))
					_draw_ship_laser(ship, poses[shooter], endpoint, 1.5)
		if poses.has(shooter) and poses.has(target) and float(ship.get("laser_until", 0.0)) >= float(state["elapsed"]):
			_draw_ship_laser(ship, poses[shooter], poses[target]["point"], 1.0)
		if bool(ship.get("retreating", false)) and poses.has(shooter) and (ship["route"] as Array).is_empty():
			var site: int = int(ship.get("repair_site", -1))
			if site >= 0 and site < state["planets"].size():
				var world: Vector2 = ECONOMY.station_position(state, site, float(state["elapsed"]))
				if int(ship["at"]) == site and (ship["position"] as Vector2).distance_to(world) <= ECONOMY.STATION_REPAIR_RANGE + ECONOMY.EPS and ECONOMY._repair_site_safe(state, ECONOMY.military_graph(state), int(ship["owner"]), site):
					var hub: Vector2 = _screen_point(ECONOMY.station_position(state, site, _orbit_time(state)))
					var end: Vector2 = poses[shooter]["point"]
					var aim: Vector2 = hub.direction_to(end)
					if not aim.is_zero_approx():
						for side in [-1.0, 1.0]:
							var muzzle: Vector2 = hub + (aim * 0.8 + aim.orthogonal() * side * 0.35) * _station_radius()
							_queue_beam(muzzle, end, Color("#59e8a4"), 1.4)
		var repair: int = int(ship.get("repair_target", -1))
		if poses.has(shooter) and service_refs.has(repair):
			var origin: Vector2 = poses[shooter]["point"]
			var endpoint: Vector2 = poses[repair]["point"] if poses.has(repair) else _screen_point(service_refs[repair].get("repair_position", service_refs[repair]["position"]))
			if str(service_refs[repair].get("kind", "")) == "pds":
				var count: int = state["planets"].size()
				var encoded: int = -2 - repair - count * 3
				endpoint = _screen_point(_building_world(state, Vector2i(posmod(encoded, count), floori(float(encoded) / float(count))), "pds"))
			var axis: Vector2 = origin.direction_to(endpoint)
			if not axis.is_zero_approx():
				if bool(ship.get("holding", false)):
					axis = poses[shooter]["direction"]
				poses[shooter]["direction"] = axis
				for side in [-1.0, 1.0]:
					var muzzle: Vector2 = origin + (axis * MINER_MUZZLE.x + axis.orthogonal() * side * MINER_MUZZLE.y) * _ship_scale()
					_queue_beam(muzzle, endpoint, Color("#59e8a4"), 1.4)
	for ship in state["ships"]:
		if not poses.has(int(ship["id"])):
			continue
		var pose: Dictionary = poses[int(ship["id"])]
		var point: Vector2 = pose["point"]
		var scale: float = _ship_scale()
		if not viewport_bounds.grow(maxf(32.0, 80.0 * scale)).has_point(point):
			continue
		var direction: Vector2 = pose["direction"]
		if not bool(ship.get("holding", false)) and ship.get("mining_mode", "") == "mining" and ship.has("mining_rock") and not ECONOMY._engaged(ship) and int(ship.get("yard_target", -1)) >= -1:
			var aim: Vector2 = _screen_point(ship["mining_rock"]) - point
			if not aim.is_zero_approx():
				direction = aim.normalized()
		var route: Array = ship["route"]
		var empire: Color = _empire_color(int(ship["owner"]))
		var hull: Color = empire.lightened(0.35)
		var side: Vector2 = direction.orthogonal() * scale
		direction *= scale
		var visual: Dictionary = ship_visuals.get(int(ship["id"]), {})
		var thrust: float = float(visual.get("thrust", 0.0))
		if int(state.get("time_speed", 1)) > 0 and scale >= 0.65 and thrust > 0.035:
			_queue_exhaust(str(ship["kind"]), point, direction, scale, thrust, int(ship["id"]), viewport_bounds)
		if bool(ship.get("mining_active", false)) and ship.get("mining_mode", "") == "mining" and not ECONOMY._salvage_active(ship) and not bool(ship.get("holding", false)) and ship.has("mining_rock") and viewport_bounds.grow(maxf(32.0, 14.0 * scale)).has_point(point) and scale >= 0.65:
			var rock: Vector2 = _screen_point(ship["mining_rock"])
			for sign in [-1.0, 1.0]:
				var emitter: Vector2 = point + direction * MINER_MUZZLE.x + side * sign * MINER_MUZZLE.y
				var impact: Vector2 = rock + side * sign * 2.0
				_draw_owned_laser(emitter, impact, int(ship["owner"]), maxf(0.8, scale))
				for k in range(3 if scale >= 1.0 else 1):
					var age: float = fposmod(visual_clock * 4.0 + float(k) * 0.33 + sign * 0.12, 1.0)
					var spark: Vector2 = impact - direction * age * 6.0 + side * sign * age * float(k + 1) * 2.0
					map_canvas.draw_circle(spark, maxf(0.7, scale * (1.0 - age)), Color(1.0, 0.85, 0.45, 1.0 - age), false)
		if int(ship["id"]) == selected_ship_id or selected_units.has(int(ship["id"])):
			var radius: float = maxf(5.0, _hull_ui_radius(str(ship["kind"])) * scale)
			_draw_selection_ring(point, radius)
		# At a distant galaxy overview, the smallest authored edges can
		# collapse into an invalid polygon after projection. Keep the hull
		# visible and owner-colored rather than drawing degenerate geometry.
		var overview: float = _overview_art_multiplier(OVERVIEW_SHIP_MAX_MULTIPLIER)
		_draw_damage_bar(point, _hull_ui_radius(str(ship["kind"])) * scale, float(ship.get("hp", ECONOMY.ship_max_hp(str(ship["kind"])))) / ECONOMY.ship_max_hp(str(ship["kind"])), _shield_fraction(ship))
		if bool(ship.get("cloaked", false)):
			_draw_selection_ring(point, maxf(5.0, _hull_ui_radius(str(ship["kind"])) * scale + 2.0), Color("#b698ff80"))
		if ship["kind"] == "warp_gate":
			var gate_radius: float = maxf(5.0, 44.0 * scale)
			map_canvas.draw_circle(point, gate_radius, Color("#382b58"), true, -1.0, true)
			map_canvas.draw_arc(point, gate_radius, 0.0, TAU, 32, empire, maxf(1.0, scale * 2.0), true)
			map_canvas.draw_arc(point, gate_radius * 0.72, 0.0, TAU, 32, Color("#b998ff"), maxf(1.0, scale * 2.0), true)
			map_canvas.draw_circle(point, gate_radius * 0.48, Color("#151225"), true, -1.0, true)
			continue
		if scale < 0.15 * overview:
			_queue_overview_hull(_overview_dot_texture(hull), point, 0.0, maxf(0.8, 6.0 * scale / overview) * overview)
			continue
		var texture: Texture2D = _cached_hull_texture(str(ship["kind"]), empire, scale >= 0.42)
		if _shield_fraction(ship) > 0.0:
			_queue_overview_hull(_shield_texture(str(ship["kind"])), point, direction.angle(), (_hull_texture_half_size(str(ship["kind"])) + 8.0) * scale)
		if ship["kind"] != "science_ship":
			_queue_overview_hull(texture, point, direction.angle(), _hull_texture_half_size(str(ship["kind"])) * scale)
		else:
			map_canvas.draw_set_transform(point, direction.angle(), Vector2.ONE * scale)
			var half: float = _hull_texture_half_size(str(ship["kind"]))
			map_canvas.draw_texture_rect(texture, Rect2(-half, -half, half * 2.0, half * 2.0), false)
			map_canvas.draw_set_transform(Vector2.ZERO)
		if ship["kind"] == "ship" and scale >= 0.42:
			var bays: Array = ECONOMY.freighter_cargo_bays(ship["cargo"])
			for k in range(bays.size()):
				var bay_center: Vector2 = _freighter_bay_center(k)
				var module: Vector2 = point + direction * bay_center.x + side * bay_center.y
				var half_length: float = 3.0
				var corners := PackedVector2Array([module + direction * half_length + side * 3, module - direction * half_length + side * 3, module - direction * half_length - side * 3, module + direction * half_length - side * 3])
				_queue_cargo_rect(corners, Color("#182333"))
				var start: float = -half_length
				for segment in bays[k]:
					var end: float = minf(half_length, start + 2.0 * half_length * float(segment["amount"]) / ECONOMY.FREIGHTER_BAY_CAPACITY)
					if (end - start) * scale >= 0.1:
						var filled := PackedVector2Array([module + direction * end + side * 3, module + direction * start + side * 3, module + direction * start - side * 3, module + direction * end - side * 3])
						_draw_cargo_segment(filled, HUD.COLORS[segment["resource"]])
					start = end
		elif ship["kind"] == "science_ship":
			map_canvas.draw_circle(point, maxf(1.0, 11.5 * scale), empire.darkened(0.4), true, -1.0, true)
			map_canvas.draw_arc(point, 10.5 * scale, 0.0, TAU, 32, empire.lightened(0.5), maxf(0.8, scale), true)
			map_canvas.draw_circle(point, maxf(0.9, 6.0 * scale), Color("#101d30"), true, -1.0, true)
			if float(ship.get("cargo", {}).get(ECONOMY.ANTIMATTER, 0.0)) >= 1.0 - ECONOMY.EPS:
				var tint: Color = HUD.COLORS[ECONOMY.ANTIMATTER]
				var pulse: float = 0.5 + 0.5 * sin(visual_clock * 4.0)
				_draw_resource_glow(point, maxf(2.0, 8.0 * scale), tint, 0.7 + 0.3 * pulse)
				map_canvas.draw_circle(point, maxf(1.0, (2.5 + pulse) * scale), tint.lightened(0.5), true, -1.0, true)
				for k in range(3):
					var angle: float = visual_clock * 2.0 + TAU * float(k) / 3.0
					map_canvas.draw_circle(point + Vector2.from_angle(angle) * 5.0 * scale, maxf(0.7, scale), tint, true, -1.0, true)
		elif scale >= 0.42:
			_draw_other_cargo(ship, point, direction, side)
	_draw_ship_destructions(viewport_bounds)
	_flush_exhaust()
	_flush_effect_batch(beam_batch, beam_instances)
	_flush_effect_batch(projectile_batch, projectile_instances)
	_flush_overview_hulls()
	_flush_effect_batch(cargo_batch, cargo_entries)
	_flush_effect_batch(cargo_glow_batch, cargo_glow_entries)
	_draw_cargo_transfers(state, poses, service_refs, viewport_bounds)
	_draw_formation_preview(state)
	_flush_effect_batch(health_batch, health_entries)
	_flush_effect_batch(ring_batch, ring_entries)
	if selecting_units and selection_start.distance_to(selection_end) > 5.0:
		var rect: Rect2 = Rect2(selection_start, selection_end - selection_start).abs()
		map_canvas.draw_rect(rect, Color(HUD.ACCENT, 0.12))
		map_canvas.draw_rect(rect, HUD.ACCENT, false, 1.0)

func _draw_logistics_overlay() -> void:
	if session == null:
		return
	var state: Dictionary = _state()
	if not state.is_empty():
		_draw_logistics_lens(state, ThemeDB.fallback_font)

func _draw_objectives_overlay() -> void:
	if session == null:
		return
	var state: Dictionary = _state()
	if state.is_empty():
		return
	var progress: Dictionary = state.get("objectives", {}).get(_me(), {})
	var completed: Dictionary = progress.get("completed", {})
	var font: Font = ThemeDB.fallback_font
	var x: float = maxf(8.0, map_canvas.size.x - OBJECTIVES_WIDTH)
	var y: float = HEADER_HEIGHT + 24.0
	var clock: float = float(state.get("objective_clock", 0.0))
	objectives_overlay.draw_string(font, Vector2(x, y), "OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b8d9ef"))
	y += 26.0
	for objective in ECONOMY.active_objectives(progress, clock):
		var category: String = objective["track"]
		var key: String = objective["id"]
		var done: bool = completed.has(key)
		var tint: Color = Color("#8ee2a9") if done else Color.WHITE
		objectives_overlay.draw_string(font, Vector2(x, y), "%s · %d CP" % [category.capitalize(), ECONOMY.reward_points(progress, category)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b8d9ef"))
		y += 23.0
		var pos := Vector2(x, y)
		if not key.is_empty():
			objectives_overlay.draw_rect(Rect2(pos + Vector2(0, -10), Vector2(10, 10)), tint, false, 1.0)
			if done:
				objectives_overlay.draw_polyline(PackedVector2Array([pos + Vector2(1, -6), pos + Vector2(4, -2), pos + Vector2(9, -9)]), tint, 2.0, true)
			pos.x += 16.0
		var counter: String = objective["counter"]
		var counter_width: float = font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var label_width: float = maxf(40.0, map_canvas.size.x - 12.0 - counter_width - pos.x - 8.0)
		objectives_overlay.draw_string_outline(font, pos, objective["label"], HORIZONTAL_ALIGNMENT_LEFT, label_width, 12, 4, Color("#101824"))
		objectives_overlay.draw_string(font, pos, objective["label"], HORIZONTAL_ALIGNMENT_LEFT, label_width, 12, tint)
		objectives_overlay.draw_string(font, Vector2(map_canvas.size.x - 12.0 - counter_width, y), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		y += 29.0
	_draw_conquest_notifications(state, font, clock)

func _notification_width() -> float:
	return clampf(map_canvas.size.x * 0.56, 80.0, 560.0)

# Keep every message on one invisible, centered column. Text shadows
# preserve legibility without a background panel or individually centered cards.
func _draw_notice_text(font: Font, point: Vector2, message: String, width: float, tint: Color) -> float:
	var height: float = font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, width, 13).y
	objectives_overlay.draw_multiline_string_outline(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, 4, Color(0.04, 0.08, 0.13, tint.a))
	objectives_overlay.draw_multiline_string(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, tint)
	return height

func _draw_conquest_notifications(state: Dictionary, font: Font, clock: float) -> void:
	var events: Array = state.get("objective_events", [])
	var roster: Dictionary = session.get("players")
	var y: float = HEADER_HEIGHT + 49.0 if match_chat_edit.visible else HEADER_HEIGHT + 34.0
	var width: float = _notification_width() - 16.0
	var left: float = (map_canvas.size.x - _notification_width()) * 0.5 + 8.0
	var visible_count: int = 0
	tactical_hit_rects.clear()
	var now: int = Time.get_ticks_msec()
	var keys: Array = tactical_alerts.keys()
	keys.sort_custom(func(a, b) -> bool: return int(tactical_alerts[a]["born"]) > int(tactical_alerts[b]["born"]))
	for key in keys:
		var alert: Dictionary = tactical_alerts[key]
		var age: int = now - int(alert["born"])
		if age >= ALERT_LIFETIME_MS:
			continue
		var tint := Color("#ffb16b") if str(key).begins_with("approach:") else Color("#ff7777")
		tint.a = clampf(float(ALERT_LIFETIME_MS - age) / 2000.0, 0.0, 1.0)
		var height: float = _draw_notice_text(font, Vector2(left, y), alert["text"], width, tint)
		tactical_hit_rects.append({"key": key, "rect": Rect2(left - 5.0, y - font.get_ascent(13) - 2.0, width + 10.0, maxf(24.0, height + 6.0))})
		y += maxf(24.0, height + 8.0)
		visible_count += 1
		if visible_count >= 3:
			break
	var chat_count: int = 0
	var chat: Array = session.get("match_chat")
	for j in range(chat.size() - 1, -1, -1):
		var item: Dictionary = chat[j]
		var age: float = float(Time.get_ticks_msec() - int(item["received_ms"])) / 1000.0
		if age >= 10.0:
			break
		var sender: int = int(item["sender"])
		var name_text: String = str(item.get("sender_name", roster.get(sender, {}).get("name", "Player"))) + ": "
		var message: String = str(item.get("message", str(item["text"]).trim_prefix(name_text)))
		var alpha: float = clampf((10.0 - age) / 2.0, 0.0, 1.0)
		var color_index: int = clampi(int(item.get("sender_color", _empire_color_index(sender))), 0, RULES.MAX_PLAYERS)
		var sender_tint: Color = COLORS[color_index]
		sender_tint.a = alpha
		var body_tint := Color(0.85, 0.94, 1.0, alpha)
		var name_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var height: float
		if name_width > width * 0.45:
			# Long names on narrow windows get their own wrapped line.
			height = _draw_notice_text(font, Vector2(left, y), name_text, width, sender_tint)
			height += _draw_notice_text(font, Vector2(left, y + height), message, width, body_tint)
		else:
			objectives_overlay.draw_string_outline(font, Vector2(left, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, name_width, 13, 4, Color(0.04, 0.08, 0.13, alpha))
			objectives_overlay.draw_string(font, Vector2(left, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, name_width, 13, sender_tint)
			height = _draw_notice_text(font, Vector2(left + name_width, y), message, width - name_width, body_tint)
		y += maxf(24.0, height + 8.0)
		visible_count += 1
		chat_count += 1
		if chat_count >= 3 or visible_count >= 5:
			break
	for j in range(events.size() - 1, -1, -1):
		if visible_count >= 5:
			break
		var event: Dictionary = events[j]
		var age: float = maxf(0.0, clock - float(event["elapsed"]))
		if age >= 10.0:
			continue
		var name_text: String = str(roster.get(event["player"], {}).get("name", "Player")).left(20)
		var message: String
		var tint := Color("#e9cb7c")
		if event.has("reward"):
			message = "%s acquired %s (Unique)" % [name_text, ECONOMY.CONQUEST_REWARDS[event["reward"]][0]]
			tint = Color("#c7aaff")
		else:
			message = "%s completed %s · +%d CP" % [name_text, ECONOMY.objective_label(str(event["objective"])), int(event["award"])]
			if not bool(event["first"]):
				tint = Color("#b8d9ef")
		tint.a = clampf((10.0 - age) / 2.0, 0.0, 1.0)
		var height: float = _draw_notice_text(font, Vector2(left, y), message, width, tint)
		y += maxf(24.0, height + 8.0)
		visible_count += 1
		if visible_count >= 5:
			break

func _style_objective_header_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", HUD.surface(Color("#193448"), accent.darkened(0.35), 1, 2))
	button.add_theme_stylebox_override("hover", HUD.surface(Color("#285268"), accent, 1, 2))
	button.add_theme_stylebox_override("pressed", HUD.surface(Color("#24526a"), accent, 1, 2))
	button.add_theme_stylebox_override("disabled", HUD.surface(Color("#101c29"), Color("#263748"), 1, 2))
	button.add_theme_color_override("font_color", accent.lightened(0.25))

func _layout_conquest_button() -> void:
	if conquest_buttons.is_empty():
		return
	var state: Dictionary = _state()
	var progress: Dictionary = state.get("objectives", {}).get(_me(), {})
	var font: Font = ThemeDB.fallback_font
	var height: float = ceilf(font.get_height(13))
	var upgrade_width: float = 52.0
	var y: float = HEADER_HEIGHT + 24.0 + 26.0
	var visible_categories: Array = []
	for objective in ECONOMY.active_objectives(progress, float(state.get("objective_clock", 0.0))):
		visible_categories.append(objective["track"])
	for category in ECONOMY.REWARD_CATEGORIES:
		var button: Button = conquest_buttons[category]
		var refresh: Button = objective_refresh_buttons[category]
		button.visible = not state.is_empty() and visible_categories.has(category)
		refresh.visible = button.visible
		if not button.visible:
			continue
		var right: float = map_canvas.size.x - 12.0
		var header_y: float = roundf(y - font.get_ascent(13))
		button.position = Vector2(right - upgrade_width, header_y)
		button.size = Vector2(upgrade_width, height)
		refresh.position = Vector2(right - upgrade_width - height - 4.0, header_y)
		refresh.size = Vector2(height, height)
		y += 52.0

func _request_objective_refresh(category: String) -> void:
	var progress: Dictionary = _state().get("objectives", {}).get(_me(), {})
	var key: String = str(progress.get("active_goals", {}).get(category, ""))
	if not key.is_empty():
		session.call("request_objective_refresh", category, key)

func _refresh_conquest_button(state: Dictionary) -> void:
	if conquest_buttons.is_empty():
		return
	var progress: Dictionary = state.get("objectives", {}).get(_me(), {})
	var clock: float = float(state.get("objective_clock", 0.0))
	for category in ECONOMY.REWARD_CATEGORIES:
		var button: Button = conquest_buttons[category]
		var points: int = ECONOMY.reward_points(progress, category)
		button.disabled = points <= 0 or ECONOMY.reward_offer(progress, category).is_empty()
		button.tooltip_text = "%d CP · Choose a %s or general upgrade" % [points, category]
		var refresh: Button = objective_refresh_buttons[category]
		var remaining: float = ECONOMY.objective_refresh_remaining(progress, category, clock)
		var key: String = str(progress.get("active_goals", {}).get(category, ""))
		refresh.text = str(ceili(remaining)) if remaining > 0.0 else "↻"
		refresh.disabled = remaining > ECONOMY.EPS or key.is_empty() or progress.get("completed", {}).has(key) or ECONOMY.objective_candidates(progress, category, key).is_empty()
		refresh.tooltip_text = "Refresh available in %d s" % ceili(remaining) if remaining > 0.0 else "Randomize this objective · 60 s cooldown"
	_layout_conquest_button()
	if is_instance_valid(conquest_dialog) and conquest_dialog.visible:
		if ECONOMY.reward_points(progress, conquest_category) <= 0:
			conquest_dialog.hide()
			conquest_card_signature = ""
		else:
			_refresh_reward_cards()

func _refresh_reward_cards() -> void:
	var progress: Dictionary = _state().get("objectives", {}).get(_me(), {})
	var signature: String = conquest_category + str(ECONOMY.reward_offer(progress, conquest_category)) + str(ECONOMY.reward_generation(progress)) + str(ECONOMY.reward_points(progress, conquest_category))
	if signature == conquest_card_signature:
		return
	conquest_card_signature = signature
	for child in conquest_cards.get_children():
		conquest_cards.remove_child(child)
		child.queue_free()
	var points: int = ECONOMY.reward_points(progress, conquest_category)
	var generation: int = ECONOMY.reward_generation(progress)
	var heading := Label.new()
	heading.text = "Choose one %s upgrade · %d CP" % [conquest_category.capitalize(), points]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	conquest_cards.add_child(heading)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 10)
	conquest_cards.add_child(cards)
	for key in ECONOMY.reward_offer(progress, conquest_category):
		var reward: Array = ECONOMY.CONQUEST_REWARDS[key]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(192, 300)
		var unique: bool = ECONOMY.reward_is_unique(str(key))
		var frame: StyleBoxFlat = HUD.surface(Color("#24203d") if unique else Color("#102b40"), Color("#b697ff") if unique else Color("#d6b46a"), 12, 8)
		frame.set_border_width_all(2)
		frame.shadow_color = Color("#0a0f19")
		frame.shadow_size = 4
		card.add_theme_stylebox_override("panel", frame)
		cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		var art := TextureRect.new()
		HUD.fixed_icon(art, _station_command_icon(str(reward[4]), 72), 72)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(art)
		var rarity := Label.new()
		rarity.text = "UNIQUE · ONE PLAYER" if unique else ""
		rarity.add_theme_color_override("font_color", Color("#d2baff"))
		rarity.add_theme_font_size_override("font_size", 11)
		rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(rarity)
		var title_label := Label.new()
		title_label.text = reward[0]
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.add_theme_color_override("font_color", Color("#f4dca3"))
		title_label.custom_minimum_size.y = 42
		content.add_child(title_label)
		content.add_child(HSeparator.new())
		var benefit := Label.new()
		benefit.text = reward[1]
		benefit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		benefit.modulate = Color("#c8f3db")
		content.add_child(benefit)
		if not str(reward[2]).is_empty():
			var drawback := Label.new()
			drawback.text = reward[2]
			drawback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			drawback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			drawback.modulate = Color("#ffb4a4")
			content.add_child(drawback)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(spacer)
		var buy := Button.new()
		buy.text = "SELECT · 1 CP"
		buy.tooltip_text = "Only the first player to select this upgrade can acquire it." if unique else "Spend 1 conquest point"
		buy.custom_minimum_size.y = 38
		buy.disabled = points < 1
		HUD.action(buy, Color("#e9cb7c"))
		buy.add_theme_stylebox_override("normal", HUD.surface(Color("#5a4824"), Color("#edc76f"), 5, 4))
		buy.add_theme_stylebox_override("hover", HUD.surface(Color("#80642c"), Color("#fff0b2"), 5, 4))
		content.add_child(buy)
		buy.pressed.connect(_buy_conquest_reward.bind(str(key), generation, cards))
	if ECONOMY.reward_offer(progress, conquest_category).is_empty():
		var empty := Label.new()
		empty.text = "No eligible rewards remain in this category."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cards.add_child(empty)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	conquest_cards.add_child(footer)
	var close := Button.new()
	close.text = "Close"
	HUD.action(close)
	footer.add_child(close)
	close.pressed.connect(conquest_dialog.hide)

func _buy_conquest_reward(key: String, generation: int, cards: HBoxContainer) -> void:
	for card in cards.get_children():
		for child in card.get_child(0).get_children():
			if child is Button:
				child.disabled = true
	# Wait for the authoritative result: a losing unique-reward race must
	# keep the remaining point and show its replacement draft.
	session.call("request_conquest_reward", key, generation, conquest_category)

func _open_conquest_upgrades(category: String) -> void:
	var progress: Dictionary = _state().get("objectives", {}).get(_me(), {})
	if ECONOMY.reward_points(progress, category) <= 0 or ECONOMY.reward_offer(progress, category).is_empty():
		return
	conquest_category = category
	conquest_card_signature = ""
	_refresh_reward_cards()
	var viewport_size: Vector2 = get_viewport_rect().size
	conquest_dialog.popup_centered(Vector2i(mini(660, int(viewport_size.x) - 32), mini(420, int(viewport_size.y) - 56)))

func _build_empire_dialog() -> void:
	empire_dialog = AcceptDialog.new()
	empire_dialog.title = "Empire · Fleet management"
	empire_dialog.theme = theme
	empire_dialog.exclusive = true
	empire_dialog.ok_button_text = "Close"
	add_child(empire_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	empire_dialog.add_child(content)
	var heading := Label.new()
	heading.text = "Desired fleet composition"
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var note := Label.new()
	note.text = "Automatically build missing ships. Existing orders count toward targets."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.name = "FleetScroll"
	scroll.custom_minimum_size = Vector2(320, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	empire_rows = VBoxContainer.new()
	empire_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empire_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(empire_rows)
	HUD.action(empire_dialog.get_ok_button())

func _refresh_empire(state: Dictionary) -> void:
	if state.is_empty():
		return
	var counts: Dictionary = ECONOMY.empire_fleet_counts(state, _me())
	var targets: Dictionary = state.get("empire_targets", {}).get(_me(), {})
	var visible_kinds: Array = []
	for kind in ["scout", "fighter", "miner", "ship", "colony_ship", "science_ship", "cruiser", "destroyer"]:
		if ECONOMY.empire_ship_available(state, _me(), kind, counts) or targets.has(kind):
			visible_kinds.append(kind)
	var signature: String = str(visible_kinds)
	if signature != empire_signature:
		empire_signature = signature
		empire_controls.clear()
		for child in empire_rows.get_children():
			empire_rows.remove_child(child)
			child.queue_free()
		for kind in visible_kinds:
			var panel := PanelContainer.new()
			empire_rows.add_child(panel)
			var row := HBoxContainer.new()
			panel.add_child(row)
			var portrait := TextureRect.new()
			portrait.texture = _selection_portrait_icon(kind)
			portrait.custom_minimum_size = Vector2(40, 40)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(portrait)
			var body := VBoxContainer.new()
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(body)
			var top := HBoxContainer.new()
			body.add_child(top)
			var name_label := Label.new()
			name_label.text = _ship_kind_name(kind)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(name_label)
			var counter := Label.new()
			top.add_child(counter)
			var slider := HSlider.new()
			slider.max_value = ECONOMY.EMPIRE_TARGET_STEPS.size() - 1
			slider.step = 1
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(slider)
			slider.drag_ended.connect(_empire_slider_released.bind(kind, slider))
			slider.value_changed.connect(_empire_preview.bind(kind, slider, counter))
			empire_controls[kind] = {"slider": slider, "counter": counter}
	for kind in empire_controls:
		var entry: Dictionary = empire_controls[kind]
		var slider: HSlider = entry["slider"]
		var desired: int = int(targets.get(kind, 0))
		if not slider.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			slider.set_value_no_signal(maxi(0, ECONOMY.EMPIRE_TARGET_STEPS.find(desired)))
		var counter: Label = entry["counter"]
		_empire_preview(slider.value, kind, slider, counter)

func _empire_preview(value: float, kind: String, _slider: HSlider, counter: Label) -> void:
	var counts: Dictionary = ECONOMY.empire_fleet_counts(_state(), _me())
	var live: int = int(counts["live"].get(kind, 0))
	var queued: int = int(counts["queued"].get(kind, 0))
	var desired: int = ECONOMY.EMPIRE_TARGET_STEPS[int(value)]
	counter.text = "%d / %d  (+%d queued)" % [live, desired, queued]
	counter.modulate = Color("#8ee2a9") if live + queued >= desired else Color("#e9cb7c")

func _empire_slider_released(changed: bool, kind: String, slider: HSlider) -> void:
	if changed:
		session.call("request_empire_target", kind, ECONOMY.EMPIRE_TARGET_STEPS[int(slider.value)])
	slider.release_focus()

func _open_empire() -> void:
	if str(session.get("phase")) != "match":
		return
	_refresh_empire(_state())
	var viewport: Vector2 = get_viewport_rect().size
	empire_dialog.popup_centered(Vector2i(int(minf(600, viewport.x - 40)), int(minf(570, viewport.y - 80))))

func _any_selected_station_buildable(key: String, primary: Dictionary) -> bool:
	if building_selection_kind != "station" or selected_buildings.size() <= 1:
		return _station_buildable(key, primary)
	var state: Dictionary = _state()
	for ref in selected_buildings:
		if _building_valid(state, ref, "station"):
			var p: Dictionary = state["planets"][ref.x]
			if int(p["owner"]) == _me() and _station_buildable(key, p):
				return true
	return false

func _station_buildable(key: String, p: Dictionary) -> bool:
	if key in ECONOMY.RESOURCES:
		return ECONOMY.building_available(p, key) and ECONOMY.affordable(p, ECONOMY.building_cost(p, key))
	match key:
		"warehouse":
			return ECONOMY.warehouse_available(p)
		"housing":
			return ECONOMY.habitation_available(p) if ECONOMY.has_planets(p) else ECONOMY.orbital_housing_available(p)
		"yard":
			var level: int = ECONOMY.next_shipyard_slot(p)
			return level > 0 and ECONOMY.affordable(p, ECONOMY._cost("yard", level))
		"pds":
			return ECONOMY.next_pds(p) >= 0 and ECONOMY.pds_job(p).is_empty() and ECONOMY.affordable(p, ECONOMY._cost("pds", 1))
	return ECONOMY.station_upgrade_available(p, key)
