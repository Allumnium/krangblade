extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const UPGRADE_SOUND = preload("res://assets/sfx/detail.wav")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RULES = preload("res://scripts/lobby_rules.gd")
const COLORS = RULES.EMPIRE_COLORS
const CONSOLE_WIDE_WIDTH: float = 1240.0
const OVERVIEW_WIDTH: float = 286.0
const YARD_WIDTH: float = 252.0
const HEADER_HEIGHT: float = 54.0
const KEYBOARD_PAN_SPEED: float = 420.0
const RADIUS: float = 12.0
const MIN_ZOOM: float = 0.5
const OVERVIEW_MAX_ZOOM: float = 64.0
const FIGHTER_HULL_LENGTH: float = 22.0
const CLOSEUP_SCREEN_FRACTION: float = 0.6
const SNAPSHOT_SECONDS: float = 0.2

var session: Node
var settings := ConfigFile.new()
var ui_percent: int = 90
var music_volume: float = 100.0
var sfx_volume: float = 100.0
var music_muted: bool = false
var sfx_muted: bool = false
var upgrade_audio: AudioStreamPlayer
var known_upgrade_jobs: Dictionary = {}
var upgrade_audio_initialized: bool = false
var map_canvas: Control
var territory_layer: Control
var territory_image: ColorRect
var territory_material: ShaderMaterial
var territory_sites: ImageTexture
var territory_site_count: int = 0
var territory_radius: float = 1.0
var territory_last: Array[int] = []
var territory_cycle_elapsed: float = 0.0
var territory_seed: int = -1
var header_panel: PanelContainer
var inspector_panel: PanelContainer
var overview_panel: PanelContainer
var console_panel: PanelContainer
var minimap: Control
var console_columns: HBoxContainer
var console_center: VBoxContainer
var console_center_spacer: Control
var console_right_body: VBoxContainer
var console_profile: Control
var yard_column: VBoxContainer
var empty_selection: Label
var command_grids: Dictionary = {}
var cargo_grids: Array[GridContainer] = []
var yard_activity: VBoxContainer
var yard_activity_rows: Dictionary = {}
var inspector_tabs: TabContainer
var asteroid_shape_cache: Dictionary = {}
var asteroid_cache_seed: int = -1
var habitation_card: Dictionary = {}
var orbital_card: Dictionary = {}
var population_label: Label
var raw_antimatter_label: Label
var population_delta_label: Label
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var previous_map_fit: float = 0.0
var follow_units: bool = false
var drag_button: int = 0
var ship_visuals: Dictionary = {}
var ship_offsets: Dictionary = {}
const SHIP_WORLD_SCALE: float = 1.5
const FIGHTER_MUZZLE: float = 12.0
const MINER_MUZZLE: Vector2 = Vector2(10.0, 3.75)
const FREIGHTER_OUTLINE: Array[Vector2] = [Vector2(14, 4), Vector2(10, 8), Vector2(-13, 8), Vector2(-13, -8), Vector2(10, -8), Vector2(14, -4)]
const DESTRUCTION_LIFETIME: float = 1.35
const MAX_VISIBLE_DESTRUCTIONS: int = 32
var last_destruction_sequence: int = 0
var ship_destructions: Array = []
# Authored top-down silhouette and interior panel geometry in hull-local
# coordinates (forward, lateral). Logistics keeps its original cargo bays.
const HULL_OUTLINES: Dictionary = {
	"fighter": [Vector2(12, 0), Vector2(6, 2.5), Vector2(2.5, 3), Vector2(-3, 8), Vector2(-7, 7.5), Vector2(-6, 3), Vector2(-10, 2.5), Vector2(-10, -2.5), Vector2(-6, -3), Vector2(-7, -7.5), Vector2(-3, -8), Vector2(2.5, -3), Vector2(6, -2.5)],
	"miner": [Vector2(10, 5), Vector2(6, 5), Vector2(3, 7), Vector2(-5, 7), Vector2(-8, 4), Vector2(-8, -4), Vector2(-5, -7), Vector2(3, -7), Vector2(6, -5), Vector2(10, -5), Vector2(10, -2.5), Vector2(5, -2.5), Vector2(4, 0), Vector2(5, 2.5), Vector2(10, 2.5)],
	"colony_ship": [Vector2(13, 0), Vector2(8, 3), Vector2(5, 3.5), Vector2(3, 6.5), Vector2(-5, 7), Vector2(-9, 4), Vector2(-11, 3), Vector2(-11, -3), Vector2(-9, -4), Vector2(-5, -7), Vector2(3, -6.5), Vector2(5, -3.5), Vector2(8, -3)]
}
const HULL_PANELS: Dictionary = {
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
var interaction_panel: VBoxContainer
var logistics_lens: Button
var active_lens: String = ""
var global_resource_fills: Dictionary = {}
var global_resource_segments: Dictionary = {}
var global_resource_strips: Dictionary = {}
var colony_picker: OptionButton
var send_colony_button: Button
var colony_button: Button
var colony_choices: Array[int] = []
var selected: int = -1
var selected_body: int = -1
var selected_yard: int = -1
var selected_yard_count: int = 0
var yard_overview: VBoxContainer
var yard_title: Label
var yard_context: Label
var yard_status: Label
var yard_detail: Label
var yard_costs: GridContainer
var yard_progress: ProgressBar
var yard_upgrade: Button
var yard_cancel: Button
var last_system_tab_selection: int = -1
var selected_ship_id: int = -1
var selected_units: Array[int] = []
var control_groups: Dictionary = {}
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selecting_units: bool = false
var selected_field: int = -1
var mining_controls: VBoxContainer
var mining_enabled: CheckBox
var mining_metals: CheckBox
var mining_crystals: CheckBox
var planet_overview: VBoxContainer
var body_overview: VBoxContainer
var body_title: Label
var body_context: Label
var body_defense: Label
var body_status: Label
var body_costs: GridContainer
var body_upgrade: Button
var body_cancel: Button
var body_progress: ProgressBar
var ship_overview: VBoxContainer
var ship_title: Label
var ship_detail: Label
var ship_cargo: VBoxContainer
var ship_cargo_labels: Dictionary = {}
var fleet_scroll: ScrollContainer
var fleet_overview: VBoxContainer
var fleet_title: Label
var fleet_detail: Label
var hold_button: Button
var unload_button: Button
var command_card: GridContainer
var command_hint: Label
var command_buttons: Dictionary = {}
var pending_command: String = ""
var selection_grid: GridContainer
var selection_tiles: Dictionary = {}
var selection_icons: Dictionary = {}
var fleet_cargo: VBoxContainer
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
var info: Label
var visual_clock: float = 0.0
var system_visuals: Dictionary = {}
var system_visual_seed: int = -1
var trade_sliders: Dictionary = {}
var trade_checks: Dictionary = {}
var trade_stock_labels: Dictionary = {}
var pds_card: Dictionary = {}
var economy_cards: Dictionary = {}
var warehouse_card: Dictionary = {}
var continuous_checks: Dictionary = {}
var repeat_icon: Texture2D
var population_icon: Texture2D
var build_clock_icon: Texture2D
var production_summary: VBoxContainer
var production_values: Dictionary = {}
var fighter_button: Button
var miner_button: Button
var system_owner_label: Label
var ship_button: Button
var leave: Button
var match_menu: AcceptDialog
var match_result_dialog: AcceptDialog
var match_result_shown: bool = false
var defeated_shown: bool = false
var menu_exit: Button
var build_cards: Dictionary = {}

class TradeRange extends Control:
	signal committed(minimum: float, maximum: float)
	var lower: float = 10.0
	var upper: float = 20.0
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
	upgrade_audio = AudioStreamPlayer.new()
	upgrade_audio.stream = UPGRADE_SOUND
	add_child(upgrade_audio)
	_load_settings()
	_build_ui()
	_build_resource_hover()
	_apply_settings()
	_on_economy_changed()
	session.call("match_scene_loaded")

func _label(value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable, parent: Container) -> Button:
	var b := Button.new()
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
	map_canvas.offset_top = HEADER_HEIGHT + 16
	map_canvas.offset_right = -8
	map_canvas.offset_bottom = -8
	map_canvas.clip_contents = false
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.gui_input.connect(_map_input)
	map_canvas.draw.connect(_draw_map)
	map_canvas.resized.connect(_map_resized)
	header_panel = PanelContainer.new()
	add_child(header_panel)
	header_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928ed"), Color("#284661"), 6))
	header_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_panel.offset_left = 8
	header_panel.offset_right = -8
	header_panel.offset_top = 8
	header_panel.offset_bottom = 8 + HEADER_HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	header_panel.add_child(row)
	year_label = _global_stat(row, "%d A.D." % ECONOMY.START_YEAR, HUD.ACCENT)
	_build_global_bar(row)
	global_population_label = _global_stat(row, "0", Color("#b9d9ed"), true)
	leave = _button("MENU", _open_menu, row)
	match_menu = AcceptDialog.new()
	match_menu.title = "Menu"
	match_menu.theme = theme
	match_menu.exclusive = true
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
	deck.add_theme_constant_override("separation", 4)
	console_panel.add_child(deck)
	minimap = Control.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.focus_mode = Control.FOCUS_NONE
	minimap.tooltip_text = "Click or drag to move the camera"
	minimap.clip_contents = true
	deck.add_child(minimap)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	minimap.resized.connect(minimap.queue_redraw)
	# Three actual columns; controls are owned by their corresponding wing.
	console_columns = deck
	console_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_selection = _label("Select a system, ship or asteroid field", 14)
	empty_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_selection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_selection.add_theme_color_override("font_color", HUD.MUTED)
	console_center = VBoxContainer.new()
	console_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_center.size_flags_stretch_ratio = 1.2
	console_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_columns.add_child(console_center)
	console_center_spacer = Control.new()
	console_center.add_child(console_center_spacer)
	var center_toolbar := HBoxContainer.new()
	center_toolbar.add_theme_constant_override("separation", 3)
	console_center.add_child(center_toolbar)
	_build_lens_buttons(center_toolbar)
	console_center.add_child(empty_selection)
	inspector_panel = PanelContainer.new()
	console_columns.add_child(inspector_panel)
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_stretch_ratio = 1.3
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101f30"), Color("#284661"), 3, 3))
	# Simulation controls are global, not contextual commands.
	var time_panel := PanelContainer.new()
	add_child(time_panel)
	time_panel.theme = HUD.compact()
	time_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#0b1624"), Color("#345570"), 4, 3))
	time_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	time_panel.offset_left = -280
	time_panel.offset_right = -8
	time_panel.offset_top = HEADER_HEIGHT + 14
	time_panel.offset_bottom = HEADER_HEIGHT + 48
	var time_toolbar := HBoxContainer.new()
	time_toolbar.alignment = BoxContainer.ALIGNMENT_END
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
	overview_panel.add_theme_stylebox_override("panel", HUD.surface(Color("#101f30"), Color("#284661"), 3, 3))
	var overview_scroll := ScrollContainer.new()
	overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overview_panel.add_child(overview_scroll)
	var overview := VBoxContainer.new()
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_theme_constant_override("separation", 3)
	overview_scroll.add_child(overview)
	planet_overview = VBoxContainer.new()
	planet_overview.add_theme_constant_override("separation", 3)
	overview.add_child(planet_overview)
	_build_body_overview(overview)
	_build_yard_overview(overview)
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
	ship_cargo = HUD.section(ship_overview, "Cargo", true)
	_build_cargo_rows(ship_cargo, ship_cargo_labels)
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
	fleet_cargo = HUD.section(ship_overview, "Fleet cargo", true)
	_build_cargo_rows(fleet_cargo, fleet_cargo_labels)
	mining_controls = HUD.section(fleet_overview, "Mine", true)
	mining_enabled = CheckBox.new()
	mining_enabled.text = "Enabled"
	mining_controls.add_child(mining_enabled)
	mining_metals = CheckBox.new()
	mining_metals.text = "Metals"
	mining_controls.add_child(mining_metals)
	mining_crystals = CheckBox.new()
	mining_crystals.text = "Crystals"
	mining_controls.add_child(mining_crystals)
	for check in [mining_enabled, mining_metals, mining_crystals]:
		check.toggled.connect(func(_value: bool) -> void: _apply_mining_policy())
	mining_controls.get_parent().hide()
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
	population_label = _label("", 13)
	population_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	population_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	population_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var population_row: HBoxContainer = _population_row(planet_overview)
	population_row.add_child(population_label)
	population_delta_label = _label("", 11)
	population_delta_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	population_row.add_child(population_delta_label)
	production_summary = HUD.section(planet_overview, "Resources", true)
	production_summary.get_child(0).hide()
	production_summary.add_theme_constant_override("separation", 1)
	_build_production_summary()
	raw_antimatter_label = _label("", 12)
	raw_antimatter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	raw_antimatter_label.add_theme_color_override("font_color", HUD.COLORS[ECONOMY.ANTIMATTER])
	production_summary.add_child(raw_antimatter_label)
	raw_antimatter_label.hide()
	interaction_panel = VBoxContainer.new()
	interaction_panel.add_theme_constant_override("separation", 8)
	body.add_child(interaction_panel)
	colony_picker = OptionButton.new()
	interaction_panel.add_child(colony_picker)
	send_colony_button = _button("SEND COLONY SHIP", _send_colony, interaction_panel)
	HUD.action(send_colony_button, Color("#c7a4ff"), true)
	inspector_tabs = TabContainer.new()
	inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_tabs.clip_contents = true
	inspector_tabs.tab_changed.connect(func(_tab: int) -> void: _collapse_details())
	body.add_child(inspector_tabs)
	inspector_tabs.visibility_changed.connect(func() -> void:
		if not inspector_tabs.is_visible_in_tree():
			_collapse_details())
	var shipyard_page: GridContainer = _inspector_page("Shipyards")
	# Keep building cards first and yard activity below them in one scroll.
	yard_column = VBoxContainer.new()
	yard_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shipyard_page.get_parent().add_child(yard_column)
	yard_activity = HUD.section(yard_column, "Shipyards", true)
	var economy_page: GridContainer = _inspector_page("Economy")
	_build_economy_cards(economy_page)
	var trade_page: GridContainer = _inspector_page("Trade")
	_build_pds_card(economy_page)
	for resource in ECONOMY.RESOURCES:
		var logistics: VBoxContainer = HUD.section(trade_page, "", true)
		logistics.get_child(0).hide()
		var trade_row := HBoxContainer.new()
		logistics.add_child(trade_row)
		var resource_icon := TextureRect.new()
		resource_icon.texture = HUD.ICONS[resource]
		resource_icon.custom_minimum_size = Vector2(14, 14)
		resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
		var switches := HBoxContainer.new()
		logistics.add_child(switches)
		logistics.move_child(switches, slider.get_index())
		var incoming := CheckBox.new()
		incoming.text = "In"
		incoming.tooltip_text = "Enable imports below the left threshold"
		incoming.add_theme_font_size_override("font_size", 10)
		incoming.button_pressed = true
		switches.add_child(incoming)
		var outgoing := CheckBox.new()
		outgoing.text = "Out"
		outgoing.tooltip_text = "Enable exports above the right threshold"
		outgoing.add_theme_font_size_override("font_size", 10)
		outgoing.button_pressed = true
		incoming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outgoing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		switches.add_child(outgoing)
		trade_checks[resource] = [incoming, outgoing]
		incoming.toggled.connect(_trade_toggle.bind(resource))
		outgoing.toggled.connect(_trade_toggle.bind(resource))
	ship_button = _ship_build_row(shipyard_page, "BUILD LOGISTICS SHIP", "ship")
	HUD.action(ship_button, HUD.ACCENT, true)
	colony_button = _ship_build_row(shipyard_page, "BUILD COLONY SHIP", "colony_ship")
	HUD.action(colony_button, Color("#c7a4ff"), true)
	fighter_button = _ship_build_row(shipyard_page, "BUILD FIGHTER", "fighter")
	HUD.action(fighter_button, Color("#f2b57e"), true)
	fighter_button.tooltip_text = "Select fighters and right-click a destination or hostile ship."
	miner_button = _ship_build_row(shipyard_page, "BUILD MINING SHIP", "miner")
	HUD.action(miner_button, Color("#d8e58b"), true)
	miner_button.tooltip_text = "Automatically mines accessible fields from owned service systems."
	for grid in command_grids.values():
		for card in grid.get_children():
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resized.connect(_layout_console)
	inspector_panel.resized.connect(_layout_command_grids)
	inspector_panel.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(_layout_command_grids)
	console_columns.resized.connect(console_profile.queue_redraw)
	_layout_console()

func _layout_console() -> void:
	if not is_instance_valid(console_panel) or not is_instance_valid(yard_activity):
		return
	# Keep a stable, useful map at both normal and small window sizes.
	var height: float = minf(clampf(size.y * 0.36, 220.0, 320.0), maxf(135.0, size.y - HEADER_HEIGHT - 180.0))
	console_panel.offset_top = -8.0 - height
	# Draw the space scene behind the HUD rather than clipping it at a
	# horizontal line. Camera framing still uses the unobstructed play area.
	map_canvas.offset_bottom = -8.0
	territory_layer.offset_bottom = map_canvas.offset_bottom
	diagnostic_label.offset_bottom = -20.0 - height
	diagnostic_label.offset_top = -44.0 - height
	minimap.custom_minimum_size.x = minf(220.0, minf(height * 0.87, size.x * 0.19))
	# SC2-style raised wings: minimap and commands use the full deck height;
	# selection details begin 20% lower, leaving more map visible centrally.
	console_center_spacer.custom_minimum_size.y = height * 0.20
	console_profile.queue_redraw()
	# Do not force the center wider than its allotted column.
	overview_panel.custom_minimum_size.x = 0.0
	_layout_command_grids()

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
	var fill := Color("#0b1624")
	var edge := Color("#345570")
	var left_rect := Rect2(Vector2.ZERO, Vector2(maxf(0.0, center_left), bounds.size.y))
	var center_rect := Rect2(Vector2(center_left, center_top), Vector2(maxf(0.0, right_left - center_left), maxf(0.0, bounds.size.y - center_top)))
	var right_rect := Rect2(Vector2(right_left, 0.0), Vector2(maxf(0.0, bounds.size.x - right_left), bounds.size.y))
	for rect in [left_rect, center_rect, right_rect]:
		if rect.has_area():
			console_profile.draw_rect(rect, fill)
			console_profile.draw_rect(rect.grow(-0.5), edge, false, 1.0)

func _layout_command_grids() -> void:
	var width: float = inspector_panel.size.x - 34.0
	if is_instance_valid(selection_grid):
		selection_grid.columns = maxi(1, floori(maxf(38.0, console_center.size.x - 20.0) / 41.0))
	for title in command_grids:
		var grid: GridContainer = command_grids[title]
		var cell_width: float = 160.0 if title == "Trade" else 222.0
		grid.columns = clampi(floori(width / cell_width), 1, 3)
	for grid in cargo_grids:
		grid.columns = 2 if grid.get_parent() == ship_cargo else clampi(floori(width / 180.0), 1, 4)

func _minimap_area() -> Rect2:
	var bounds: Vector2 = _map_size().max(Vector2.ONE)
	var available: Vector2 = (minimap.size - Vector2(12, 12)).max(Vector2.ONE)
	var scale: float = minf(available.x / bounds.x, available.y / bounds.y)
	var extent: Vector2 = bounds * scale
	return Rect2((minimap.size - extent) * 0.5, extent)

func _minimap_point(point: Vector2, area: Rect2) -> Vector2:
	return area.position + point / _map_size().max(Vector2.ONE) * area.size

func _minimap_input(event: InputEvent) -> void:
	var move_camera: bool = false
	if event is InputEventMouseButton:
		move_camera = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventMouseMotion:
		move_camera = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if move_camera and not _state().is_empty():
		var area: Rect2 = _minimap_area()
		var fraction: Vector2 = ((event.position - area.position) / area.size).clamp(Vector2.ZERO, Vector2.ONE)
		var world: Vector2 = fraction * _map_size()
		follow_units = false
		pan = (_map_size() * 0.5 - world) * _fit() * zoom
		_position_territory()
		map_canvas.queue_redraw()
		minimap.queue_redraw()
	minimap.accept_event()

func _draw_minimap() -> void:
	var surface := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(surface, Color("#070e19"))
	minimap.draw_rect(surface.grow(-0.5), Color("#345570"), false, 1.0)
	var state: Dictionary = _state()
	if state.is_empty() or minimap.size.x < 12.0 or minimap.size.y < 12.0:
		return
	var area: Rect2 = _minimap_area()
	minimap.draw_rect(area, Color("#0b1928"))
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
		if known[i] and i < territory_last.size() and territory_last[i] > 0:
			var radius: float = clampf(territory_radius * area.size.x / _map_size().x, 3.0, 12.0) * (1.0 if i < count else 0.68)
			minimap.draw_circle(locations[i], radius, Color(COLORS[territory_last[i]], 0.20))
	for edge in graph["edges"]:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		minimap.draw_line(locations[a], locations[b], Color("#39546c") if known[a] and known[b] else Color("#182b3b"), 1.0, true)
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
	# Mirror the main map's live hull visibility and interpolation; do not
	# reveal undiscovered system ownership or apply any simulation commands.
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		var visual: Dictionary = ship_visuals.get(id, {})
		var world: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
		var point: Vector2 = _minimap_point(world, area)
		if area.has_point(point):
			minimap.draw_circle(point, 1.5, _empire_color(int(ship["owner"])))
			if selected_units.has(id):
				minimap.draw_arc(point, 2.6, 0.0, TAU, 10, Color.WHITE, 1.0, true)
	var corner: Vector2 = _minimap_point(_world_point(Vector2.ZERO), area)
	var end: Vector2 = _minimap_point(_world_point(_projection_size()), area)
	var camera_rect := Rect2(corner, end - corner)
	# Preserve a visible indicator at extreme close-up zoom levels.
	var visible_extent: Vector2 = camera_rect.size.max(Vector2(3, 3))
	var visible_rect := Rect2(camera_rect.get_center() - visible_extent * 0.5, visible_extent)
	minimap.draw_rect(area, Color("#35536a"), false, 1.0)
	var clipped: Rect2 = visible_rect.intersection(area)
	if clipped.has_area():
		minimap.draw_rect(clipped, Color(HUD.ACCENT, 0.08))
		minimap.draw_rect(clipped, HUD.ACCENT, false, 1.2)


func _make_disclosure(parent: Container, title_text: String) -> Dictionary:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	parent.add_child(line)
	var header := Button.new()
	header.flat = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.clip_text = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 21
	header.add_theme_font_size_override("font_size", 12)
	line.add_child(header)
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 2)
	parent.add_child(summary)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	parent.add_child(body)
	body.hide()
	header.set_meta("caption", title_text)
	header.text = title_text
	var card: Dictionary = {"header": header, "summary": summary, "body": body, "actions": line}
	header.pressed.connect(_toggle_disclosure.bind(card))
	return card

func _detail_cards() -> Array:
	return build_cards.values() + economy_cards.values() + yard_activity_rows.values() + [warehouse_card, habitation_card, orbital_card, pds_card]

func _card_tab(card: Dictionary) -> Node:
	var node: Node = card["header"]
	while node.get_parent() != null:
		if node.get_parent() == inspector_tabs:
			return node
		node = node.get_parent()
	return null

func _toggle_disclosure(card: Dictionary) -> void:
	var expanded: bool = not card["body"].visible
	if expanded:
		var tab: Node = _card_tab(card)
		for other in _detail_cards():
			if other.has("body") and other["body"] != card["body"] and _card_tab(other) == tab:
				_collapse_card(other)
	card["body"].visible = expanded
	_disclosure_title(card, str(card["header"].get_meta("caption")))

func _collapse_details() -> void:
	for card in _detail_cards():
		_collapse_card(card)

func _card_action(card: Dictionary, caption: String, callback: Callable) -> Button:
	var button: Button = _button(caption, callback, card["actions"])
	button.custom_minimum_size = Vector2(0, 20)
	button.add_theme_font_size_override("font_size", 10)
	return button

func _card_cancel(card: Dictionary, callback: Callable, progress: ProgressBar = null) -> Button:
	var button: Button = _card_action(card, "×", callback)
	var line: HBoxContainer = card["actions"]
	line.move_child(button, 1)
	if progress != null:
		progress.reparent(line, false)
		line.move_child(progress, 0)
		progress.custom_minimum_size = Vector2(5, 0)
		progress.show_percentage = false
		progress.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		progress.step = 0.0
		progress.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		progress.size_flags_vertical = Control.SIZE_FILL
		progress.add_theme_stylebox_override("background", HUD.surface(Color("#14283a"), Color("#14283a"), 0, 0))
		progress.add_theme_stylebox_override("fill", HUD.surface(HUD.ACCENT, HUD.ACCENT, 0, 0))
	button.hide()
	button.custom_minimum_size.x = 23
	button.tooltip_text = "Cancel / refund"
	button.disabled = true
	return button

func _population_texture() -> Texture2D:
	if population_icon == null:
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="#b9d9ed"><circle cx="12" cy="6" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4z"/></svg>')
		population_icon = ImageTexture.create_from_image(image)
	return population_icon

func _population_row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _population_texture()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = "Population"
	row.add_child(icon)
	return row

func _disclosure_title(card: Dictionary, caption: String) -> void:
	var header: Button = card["header"]
	header.set_meta("caption", caption)
	header.text = caption

func _collapse_card(card: Dictionary) -> void:
	if card.has("body"):
		card["body"].hide()
		_disclosure_title(card, str(card["header"].get_meta("caption")))

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

func _clock_texture() -> Texture2D:
	if build_clock_icon == null:
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#dbeaff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/></svg>')
		build_clock_icon = ImageTexture.create_from_image(image)
	return build_clock_icon

func _duration_text(years: float) -> String:
	if is_zero_approx(years):
		return "Instant"
	return "%.0fyr" % years if is_equal_approx(years, roundf(years)) else "%.1fyr" % years

func _set_timed_action(button: Button, caption: String, years: float = -1.0) -> void:
	button.text = caption if years < 0.0 else "%s · %s" % [caption, _duration_text(years)]
	button.icon = _clock_texture() if years > 0.0 else null
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 12)

func _cost_grid(parent: Container) -> GridContainer:
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 3)
	parent.add_child(grid)
	return grid

func _show_cost(grid: GridContainer, cost: Dictionary, crew: float = 0.0) -> void:
	var signature: Array = [cost, crew]
	if grid.get_meta("recipe", []) == signature:
		return
	grid.set_meta("recipe", signature.duplicate(true))
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var entries: Dictionary = cost.duplicate()
	if crew > 0.0:
		entries["Population"] = crew
	grid.columns = maxi(1, entries.size())
	for resource in entries:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		grid.add_child(pair)
		var symbol := TextureRect.new()
		if resource == "Population":
			symbol.texture = _population_texture()
		else:
			symbol.texture = HUD.ICONS[resource]
		symbol.custom_minimum_size = Vector2(12, 12)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pair.add_child(symbol)
		var value: float = float(entries[resource])
		var amount := _label(_compact_amount(value), 11)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		pair.add_child(amount)
		pair.tooltip_text = ("%.0f people" % value) if resource == "Population" else "%.0f t %s" % [value, resource]

func _ship_build_years(p: Dictionary, kind: String) -> float:
	var speed: float = ECONOMY.yard_speed(1)
	for index in range(p.get("yards", []).size()):
		var level: int = int(p["yards"][index]["level"])
		if ECONOMY.shipyard_operational(p, index) and ECONOMY.max_size(level) >= ECONOMY.SHIP_SIZE:
			speed = maxf(speed, ECONOMY.yard_speed(level))
	return ECONOMY._work(kind, 1) / speed

func _ship_stats(kind: String) -> String:
	var details: String = ""
	match kind:
		"ship": details = "Transports resources · Cargo %.0f t" % ECONOMY.CARGO_CAPACITY
		"colony_ship": details = "Settles a neutral system · %.0f settlers · Cargo %.0f t" % [ECONOMY.COLONY_POPULATION, ECONOMY.COLONY_CAPACITY]
		"fighter": details = "Engages hostile ships · Damage %.0f · Range %.0f · Cargo %.0f t" % [ECONOMY.LASER_DAMAGE, ECONOMY.LASER_RANGE, ECONOMY.FIGHTER_CAPACITY]
		"miner": details = "Extracts asteroids · Cargo %.0f t · Mining %.0f t/yr" % [ECONOMY.MINER_CAPACITY, ECONOMY.MINER_RATE]
	return "%s\nHP %.0f · Speed %.0f/yr · Size %d" % [details, ECONOMY.SHIP_HP, ECONOMY.SHIP_SPEED, ECONOMY.SHIP_SIZE]

func _ship_build_row(parent: Container, title_text: String, kind: String) -> Button:
	var section: VBoxContainer = HUD.section(parent, "", true)
	section.get_child(0).hide()
	var disclosure: Dictionary = _make_disclosure(section, title_text.trim_prefix("BUILD ").capitalize() + " (0)")
	var body: VBoxContainer = disclosure["body"]
	var build_progress := ProgressBar.new()
	build_progress.custom_minimum_size.y = 12
	section.add_child(build_progress)
	section.move_child(build_progress, body.get_index())
	build_progress.hide()
	body.add_child(_label(_ship_stats(kind), 12))
	var requirements := _label("", 12)
	body.add_child(requirements)
	var costs: GridContainer = _cost_grid(disclosure["summary"])
	_show_cost(costs, ECONOMY._cost(kind, 1), float(ECONOMY.CREW_COSTS[kind]))
	var row: HBoxContainer = disclosure["actions"]
	var maintain_row := HBoxContainer.new()
	body.add_child(maintain_row)
	var maintain_caption := _label("Maintain", 12)
	maintain_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	maintain_row.add_child(maintain_caption)
	var amount := SpinBox.new()
	amount.min_value = 0
	amount.max_value = 9999
	amount.step = 1
	amount.custom_minimum_size = Vector2(72, 28)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount.get_line_edit().add_theme_font_size_override("font_size", 12)
	amount.get_line_edit().text_changed.connect(_filter_ship_limit.bind(amount.get_line_edit()))
	maintain_row.add_child(amount)
	var ships_caption := _label("ships", 12)
	ships_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	maintain_row.add_child(ships_caption)
	amount.value_changed.connect(func(value: float) -> void:
		session.call("request_maintain", selected, kind, int(value)))
	var infinity := _label("∞", 14)
	maintain_row.add_child(infinity)
	infinity.hide()
	infinity.mouse_filter = Control.MOUSE_FILTER_STOP
	infinity.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.relative.y > 0.0:
			session.call("request_maintain", selected, kind, maxi(0, int(amount.value) - maxi(1, roundi(event.relative.y / 4.0)))))
	var button: Button = _card_action(disclosure, "Build", _operation.bind(kind))
	_set_timed_action(button, "Build", _ship_build_years({}, kind))
	if kind != "yard":
		var check: Button = _repeat_button(row, kind)
		continuous_checks[kind] = check
	var cancel: Button = _card_cancel(disclosure, _cancel_kind.bind(kind, ""), build_progress)
	cancel.tooltip_text = "Cancel one order and stop repeat"
	disclosure.merge({"maintain_amount": amount, "infinity": infinity, "button": button, "cancel": cancel, "title": title_text, "requirements": requirements, "costs": costs, "build_progress": build_progress})
	build_cards[kind] = disclosure
	return button

func _filter_ship_limit(value: String, field: LineEdit) -> void:
	var digits: String = ""
	var caret: int = 0
	for i in range(value.length()):
		var character: String = value.substr(i, 1)
		if character >= "0" and character <= "9" and digits.length() < 4:
			digits += character
			if i < field.caret_column:
				caret += 1
	if digits != value:
		field.text = digits
		field.caret_column = caret

func _repeat_button(parent: Container, key: String) -> Button:
	if repeat_icon == null:
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dbeaff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 2l4 4-4 4M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4M21 13v2a3 3 0 0 1-3 3H3"/></svg>')
		repeat_icon = ImageTexture.create_from_image(image)
	var button := Button.new()
	button.icon = repeat_icon
	button.expand_icon = true
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(22, 20)
	button.add_theme_constant_override("icon_max_width", 16)
	button.tooltip_text = "Repeat automatically"
	parent.add_child(button)
	button.toggled.connect(func(enabled: bool) -> void:
		session.call("request_continuous", selected, key, enabled))
	return button

func _sync_repeat(button: Button, p: Dictionary, key: String, available: bool) -> void:
	button.set_pressed_no_signal(bool(p.get("continuous", {}).get(key, false)))
	button.disabled = not available
	button.modulate = HUD.ACCENT if button.button_pressed else Color.WHITE
	button.tooltip_text = "Repeat enabled (click to stop)" if button.button_pressed else "Repeat automatically"

func _build_production_summary() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	production_summary.add_child(header)
	var blank := Control.new()
	blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(blank)
	for column in [["Stock", 54], ["Lv", 20], ["/yr", 50], ["Bonus", 42]]:
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
		icon.texture = HUD.ICONS[resource]
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_label := _label(resource, 12)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var stock := _label("", 11)
		stock.autowrap_mode = TextServer.AUTOWRAP_OFF
		stock.custom_minimum_size.x = 54
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(stock)
		var level := _label("", 11)
		level.autowrap_mode = TextServer.AUTOWRAP_OFF
		level.custom_minimum_size.x = 20
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level)
		var rate_label := _label("", 11)
		rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		rate_label.custom_minimum_size.x = 50
		rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rate_label)
		var bonus := _label("", 11)
		bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
		bonus.custom_minimum_size.x = 42
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(bonus)
		production_values[resource] = {"row": row, "stock": stock, "level": level, "rate": rate_label, "bonus": bonus}

func _system_bonus_text(p: Dictionary) -> String:
	var lines: PackedStringArray = []
	var names: Dictionary = {"Metals": "Metal production", "Plastics": "Plastic production", "Crystals": "Crystal production", "Organics": "Organics production", "Tech": "Tech production", "Textiles": "Textile production"}
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var percent: int = roundi(ECONOMY.production_modifier(p, resource) * 100.0)
		if percent != 100:
			lines.append("%s %d%%" % [names[resource], percent])
	var advanced: int = roundi(float(p.get("advanced_bonus", 1.0)) * 100.0)
	if advanced != 100:
		lines.append("Advanced manufacturing %d%% (future)" % advanced)
	return "\n".join(lines)

func _build_economy_cards(parent: Container) -> void:
	var warehouse_section: VBoxContainer = HUD.section(parent, "", true)
	warehouse_section.get_child(0).hide()
	warehouse_card = _make_disclosure(warehouse_section, "Warehouse logistics")
	var warehouse: VBoxContainer = warehouse_card["body"]
	var warehouse_detail: Label = _label("", 12)
	warehouse.add_child(warehouse_detail)
	var warehouse_button: Button = _card_action(warehouse_card, "Upgrade", _operation.bind("economy", "warehouse"))
	warehouse_card["cancel"] = _card_cancel(warehouse_card, func() -> void: pass)
	HUD.action(warehouse_button, HUD.ACCENT, true)
	warehouse_card.merge({"button": warehouse_button, "detail": warehouse_detail, "costs": _cost_grid(warehouse_card["summary"])})
	var habitat_section: VBoxContainer = HUD.section(parent, "", true)
	habitat_section.get_child(0).hide()
	habitation_card = _make_disclosure(habitat_section, "Habitation technology")
	var habitat_body: VBoxContainer = habitation_card["body"]
	var habitat_detail: Label = _label("", 12)
	habitat_body.add_child(habitat_detail)
	habitation_card.merge({"button": _card_action(habitation_card, "Upgrade", _operation.bind("economy", "habitation")), "detail": habitat_detail, "costs": _cost_grid(habitation_card["summary"])})
	HUD.action(habitation_card["button"], HUD.ACCENT, true)
	habitation_card["repeat"] = _repeat_button(habitation_card["actions"], "habitation")
	warehouse_card["repeat"] = _repeat_button(warehouse_card["actions"], "warehouse")
	var orbital_section: VBoxContainer = HUD.section(parent, "", true)
	orbital_section.get_child(0).hide()
	orbital_card = _make_disclosure(orbital_section, "Orbital Eco-Housing")
	var orbital_detail: Label = _label("", 12)
	orbital_card["body"].add_child(orbital_detail)
	orbital_card.merge({"section": orbital_section, "button": _card_action(orbital_card, "Build", _operation.bind("economy", "orbital_housing")), "detail": orbital_detail, "costs": _cost_grid(orbital_card["summary"])})
	HUD.action(orbital_card["button"], HUD.ACCENT, true)
	for resource in ECONOMY.RESOURCES:
		var definition: Dictionary = ECONOMY.ECONOMY_BUILDINGS[resource]
		var section: VBoxContainer = HUD.section(parent, "", true)
		section.get_child(0).hide()
		var disclosure: Dictionary = _make_disclosure(section, str(definition["name"]))
		var card: VBoxContainer = disclosure["body"]
		var effect: Label = _label("", 12)
		card.add_child(effect)
		var detail: Label = _label("", 12)
		card.add_child(detail)
		var button: Button = _card_action(disclosure, "Build", _operation.bind("economy", resource))
		var progress := ProgressBar.new()
		section.add_child(progress)
		section.move_child(progress, card.get_index())
		progress.hide()
		disclosure["progress"] = progress
		disclosure["cancel"] = _card_cancel(disclosure, _cancel_kind.bind("economy_building", resource), progress)
		disclosure["repeat"] = _repeat_button(disclosure["actions"], "economy_building:" + resource)
		HUD.action(button, HUD.ACCENT, true)
		disclosure.merge({"button": button, "detail": detail, "effect": effect, "costs": _cost_grid(disclosure["summary"])})
		economy_cards[resource] = disclosure

# Project exactly one completed building without touching authoritative state.
# Only the buildings dictionary is changed; all other inputs remain current.
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
	if resource in ["Plastics", "Textiles", "Tech"]:
		var capacity_before: float = ECONOMY.INDUSTRIAL_POPULATION_PER_LEVEL * (ECONOMY.production_level(p, resource) + int(p.get("buildings", {}).get(resource, 0)))
		var capacity_after: float = ECONOMY.INDUSTRIAL_POPULATION_PER_LEVEL * (ECONOMY.production_level(preview, resource) + int(buildings[resource]))
		lines.append("Productive population: %s → %s max" % [_compact_amount(capacity_before), _compact_amount(capacity_after)])
	elif resource == "Organics":
		lines.append("Maximum farm output: %.2f → %.2f t/yr" % [ECONOMY.farm_potential(p), ECONOMY.farm_potential(preview)])
		lines.append("Food capacity: %s → %s people" % [_compact_amount(ECONOMY.population_capacity(p)), _compact_amount(ECONOMY.population_capacity(preview))])
	elif ECONOMY.MINED_RESOURCES.has(resource):
		lines.append("Local extraction limit: %.0f t/yr" % ECONOMY.PLANET_MINING_LIMIT)
		if after >= ECONOMY.PLANET_MINING_LIMIT - ECONOMY.EPS:
			lines.append("Output capped at the extraction limit")
	lines.append("At current population and modifiers; before storage limits.")
	return "\n".join(lines)

func _refresh_economy_cards(p: Dictionary, owned: bool) -> void:
	var has_planets: bool = ECONOMY.has_planets(p)
	habitation_card["header"].get_parent().get_parent().visible = has_planets
	orbital_card["section"].visible = not has_planets
	if not has_planets:
		var residents: float = float(p["population"])
		var housing_capacity: float = ECONOMY.eco_capacity(p)
		_disclosure_title(orbital_card, "Orbital Eco-Housing · %d" % int(p.get("orbital_housing", 0)))
		orbital_card["detail"].text = "Population: %s → %s (+5,000)\nEco-Housing capacity: %s → %s\nOrganics surplus: %.2f → %.2f t/yr\nCivilian consumption: 0 t/yr\nResidents serve as crew and regrow (30-year doubling) to housing capacity, independent of planetary limits." % [_compact_amount(residents), _compact_amount(residents + ECONOMY.ORBITAL_HOUSING_POPULATION), _compact_amount(housing_capacity), _compact_amount(housing_capacity + ECONOMY.ORBITAL_HOUSING_POPULATION), ECONOMY.eco_organics(p), ECONOMY.eco_organics(p) + ECONOMY.ECO_HOUSING_ORGANICS]
		orbital_card["button"].disabled = not owned or not ECONOMY.orbital_housing_available(p)
		_set_timed_action(orbital_card["button"], "Build", 0.0)
		_show_cost(orbital_card["costs"], ECONOMY.ORBITAL_HOUSING_COST)
	var habitat_level: int = int(p.get("habitation_level", 0))
	_disclosure_title(habitation_card, "Habitation technology · Lv %d" % habitat_level)
	var penalty: float = -100.0 * ECONOMY.overpopulation_penalty(p)
	var next_penalty: float = -100.0 * ECONOMY.overpopulation_penalty(p, 2.0)
	habitation_card["detail"].text = "Overpopulation penalty: %+.2f%%" % penalty
	var habitat_capacity: float = ECONOMY.habitation_capacity(p)
	if habitat_level < 3:
		habitation_card["detail"].text += " → %+.2f%% (%+.2f pp)" % [next_penalty, next_penalty - penalty]
		habitation_card["detail"].text += "\nHabitation capacity: %s → %s people (2×)" % [_compact_amount(habitat_capacity), _compact_amount(habitat_capacity * 2.0)]
	else:
		habitation_card["detail"].text += "\nHabitation capacity: %s people · Max level" % _compact_amount(habitat_capacity)
	habitation_card["detail"].text += "\nPenalty applies to positive population growth, at current population."
	_sync_repeat(habitation_card["repeat"], p, "habitation", owned and habitat_level < 3)
	habitation_card["button"].disabled = not owned or not ECONOMY.habitation_available(p)
	_set_timed_action(habitation_card["button"], "Max" if habitat_level >= 3 else "Upgrade", -1.0 if habitat_level >= 3 else 0.0)
	habitation_card["costs"].visible = habitat_level < 3
	_show_cost(habitation_card["costs"], ECONOMY.habitation_cost(p))
	var level: int = int(p.get("warehouse_level", 0))
	var warehouse_button: Button = warehouse_card["button"]
	_sync_repeat(warehouse_card["repeat"], p, "warehouse", owned and level < 3)
	warehouse_button.disabled = not owned or not ECONOMY.warehouse_available(p)
	_set_timed_action(warehouse_button, "Max" if level >= 3 else "Upgrade", -1.0 if level >= 3 else 0.0)
	var current_capacity: float = ECONOMY.storage_capacity(p)
	var warehouse_detail: String = "Storage per resource: %s" % _tons(current_capacity, 0)
	if level < 3:
		var next_capacity: float = float(ECONOMY.WAREHOUSE_CAPACITIES[level + 1])
		warehouse_detail += " → %s (+%s)" % [_tons(next_capacity, 0), _tons(next_capacity - current_capacity, 0)]
		warehouse_detail += "\nCapacity: %.1f× current" % (next_capacity / current_capacity)
		warehouse_detail += "\nRequired population: %s" % _compact_amount(float(ECONOMY.WAREHOUSE_POPULATIONS[level]))
		if not ECONOMY.affordable(p, ECONOMY.WAREHOUSE_COSTS[level]):
			warehouse_detail += "\nInsufficient local materials"
		_show_cost(warehouse_card["costs"], ECONOMY.WAREHOUSE_COSTS[level])
	warehouse_card["costs"].visible = level < 3
	_disclosure_title(warehouse_card, "Warehouse logistics · Lv %d" % level)
	warehouse_card["detail"].text = warehouse_detail
	warehouse_button.tooltip_text = warehouse_detail + ("\n" + _cost_text(ECONOMY.WAREHOUSE_COSTS[level]) if level < 3 else "")
	for resource in economy_cards:
		var card: Dictionary = economy_cards[resource]
		var definition: Dictionary = ECONOMY.ECONOMY_BUILDINGS[resource]
		card["header"].get_parent().get_parent().visible = has_planets or ECONOMY.production_available(p, resource)
		var installed: int = int(p.get("buildings", {}).get(resource, 0))
		card["effect"].text = _economy_building_effect(p, resource)
		var job: Dictionary = {}
		for item in p["queue"]:
			if item["kind"] == "economy_building" and item["target"] == resource:
				job = item
				break
		card["progress"].visible = not job.is_empty()
		card["cancel"].visible = not job.is_empty()
		card["cancel"].disabled = not owned or job.is_empty()
		if not job.is_empty():
			card["progress"].value = 100.0 * float(job["progress"]) / float(job["work"])
			_style_progress(card["progress"], p, job)
		var button: Button = card["button"]
		_sync_repeat(card["repeat"], p, "economy_building:" + resource, owned and ECONOMY.production_available(p, resource))
		_set_timed_action(button, "Build", 30.0 if job.is_empty() else float(job["work"]))
		button.disabled = not owned or not ECONOMY.building_available(p, resource) or not ECONOMY.affordable(p, ECONOMY.building_cost(p, resource))
		var cost: String = _cost_text(ECONOMY.building_cost(p, resource))
		var requirement: String = "%s population" % _compact_amount(float(definition["population"]))
		var unmet: PackedStringArray = []
		if job.is_empty():
			if float(p["population"]) + ECONOMY.EPS < float(definition["population"]):
				unmet.append("Requires " + requirement)
			if not ECONOMY.production_available(p, resource):
				unmet.append("No local deposit")
			if not ECONOMY.affordable(p, ECONOMY.building_cost(p, resource)):
				unmet.append("Insufficient local materials")
		card["detail"].text = "\n".join(unmet)
		card["detail"].visible = not unmet.is_empty()
		card["costs"].visible = true
		_show_cost(card["costs"], ECONOMY.building_cost(p, resource))
		_disclosure_title(card, str(definition["name"]) + " · %d" % installed)
		button.tooltip_text = "%s\n%s" % [requirement, cost]

func _body_name(system_index: int, slot: int) -> String:
	var suffixes: Array[String] = ["I", "II", "III", "IV", "V", "VI"]
	return _system_name(system_index) + " " + suffixes[slot]

func _build_yard_overview(parent: Container) -> void:
	yard_overview = VBoxContainer.new()
	yard_overview.add_theme_constant_override("separation", 8)
	parent.add_child(yard_overview)
	yard_title = _label("", 19)
	yard_overview.add_child(yard_title)
	yard_context = _label("", 12)
	yard_context.add_theme_color_override("font_color", HUD.MUTED)
	yard_overview.add_child(yard_context)
	_button("Back to system", func() -> void:
		selected_yard = -1
		_load_thresholds()
		_refresh(), yard_overview)
	yard_status = _label("", 12)
	yard_overview.add_child(yard_status)
	var section: VBoxContainer = HUD.section(yard_overview, "Upgrade", true)
	yard_detail = _label("", 12)
	section.add_child(yard_detail)
	yard_costs = _cost_grid(section)
	yard_progress = ProgressBar.new()
	yard_progress.custom_minimum_size.y = 15
	yard_progress.step = 0.0
	section.add_child(yard_progress)
	var actions := HBoxContainer.new()
	section.add_child(actions)
	yard_upgrade = _button("Upgrade", func() -> void:
		if selected_yard >= 0:
			_operation("yard_upgrade", str(selected_yard)), actions)
	yard_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HUD.action(yard_upgrade, HUD.ACCENT, true)
	yard_cancel = _button("×", func() -> void:
		if selected_yard >= 0:
			_cancel_kind("yard_upgrade", str(selected_yard)), actions)
	yard_cancel.tooltip_text = "Cancel upgrade and refund"
	yard_overview.hide()

func _refresh_yard_overview(system: Dictionary, owned: bool) -> void:
	var yard: Dictionary = system["yards"][selected_yard]
	var level: int = int(yard["level"])
	var owner: int = int(system["owner"])
	var roster: Dictionary = session.get("players")
	var owner_name: String = str(roster.get(owner, {}).get("name", "Player"))
	var operating: bool = ECONOMY.shipyard_operational(system, selected_yard)
	var active: Dictionary = {}
	var pending: Dictionary = {}
	for job in system["queue"]:
		if int(job["id"]) == int(yard["job"]):
			active = job
		if job["kind"] == "yard_upgrade" and job["target"] == str(selected_yard):
			pending = job
	yard_title.text = "Shipyard %d · Lv %d" % [selected_yard + 1, level]
	yard_context.text = "%s · %s" % [_system_name(selected), owner_name]
	yard_context.add_theme_color_override("font_color", _empire_color(owner).lerp(HUD.MUTED, 0.28))
	var max_hp: float = ECONOMY.SHIP_HP * 10.0 * level
	yard_status.text = "%.0f / %.0f HP\n%s" % [float(yard.get("hp", max_hp)), max_hp, "Offline · Requires %s population" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[selected_yard])) if not operating else ("Idle" if active.is_empty() else _job_name(active))]
	yard_detail.text = "Build speed: %.0f → %.0f work/yr\nMaximum ship size: %d → %d\nMaximum HP: %.0f → %.0f\nEco-Housing: 5,000 capacity · +0.2 t/yr Organics (unchanged)" % [ECONOMY.yard_speed(level), ECONOMY.yard_speed(level + 1), ECONOMY.max_size(level), ECONOMY.max_size(level + 1), max_hp, ECONOMY.SHIP_HP * 10.0 * (level + 1)]
	var recipe: Dictionary = ECONOMY._cost("yard_upgrade", level + 1) if pending.is_empty() else pending["cost"]
	_show_cost(yard_costs, recipe)
	_set_timed_action(yard_upgrade, "Upgrade to Lv %d" % (level + 1), ECONOMY._work("yard_upgrade", level + 1))
	yard_upgrade.disabled = not owned or not operating or not pending.is_empty() or not ECONOMY.affordable(system, recipe)
	yard_cancel.visible = not pending.is_empty()
	yard_cancel.disabled = not owned or pending.is_empty()
	var display_job: Dictionary = pending if not pending.is_empty() else active
	yard_progress.visible = not display_job.is_empty()
	if not display_job.is_empty():
		yard_progress.value = 100.0 * float(display_job["progress"]) / float(display_job["work"])
		yard_progress.tooltip_text = _job_name(display_job)
		_style_progress(yard_progress, system, display_job)
	if not pending.is_empty():
		yard_status.text += "\nUpgrade pending"
	elif not ECONOMY.affordable(system, recipe):
		yard_status.text += "\nInsufficient local materials"

func _build_body_overview(parent: Container) -> void:
	body_overview = VBoxContainer.new()
	body_overview.add_theme_constant_override("separation", 8)
	parent.add_child(body_overview)
	body_title = _label("", 19)
	body_overview.add_child(body_title)
	body_context = _label("", 12)
	body_context.add_theme_color_override("font_color", HUD.MUTED)
	body_overview.add_child(body_context)
	_button("Back to system", func() -> void:
		selected_body = -1
		_load_thresholds()
		_refresh(), body_overview)
	var section: VBoxContainer = HUD.section(body_overview, "Planetary defense", true)
	body_defense = _label("", 12)
	section.add_child(body_defense)
	body_status = _label("", 12)
	section.add_child(body_status)
	body_costs = _cost_grid(section)
	body_progress = ProgressBar.new()
	body_progress.custom_minimum_size.y = 14
	body_progress.step = 0.0
	section.add_child(body_progress)
	var actions := HBoxContainer.new()
	section.add_child(actions)
	body_upgrade = _button("Build PDS", _upgrade_selected_body, actions)
	body_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HUD.action(body_upgrade, HUD.ACCENT, true)
	body_cancel = _button("×", _cancel_selected_body, actions)
	body_cancel.tooltip_text = "Cancel construction and refund"
	body_overview.hide()

func _upgrade_selected_body() -> void:
	if selected >= 0 and selected_body >= 0:
		_operation("pds", "")

func _cancel_selected_body() -> void:
	if selected_body < 0:
		return
	var job: Dictionary = ECONOMY.pds_job(_planet())
	if not job.is_empty():
		_cancel_job(int(job["id"]))

func _refresh_body_overview(system: Dictionary, owned: bool) -> void:
	var owner: int = int(system["owner"])
	var roster: Dictionary = session.get("players")
	var owner_name: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
	body_title.text = _body_name(selected, selected_body)
	body_context.text = "%s · %s" % [_system_name(selected), owner_name]
	var defenses: Dictionary = system.get("pds", {})
	var battery: Dictionary = defenses.get(selected_body, {})
	var job: Dictionary = ECONOMY.pds_job(system)
	var building: bool = not job.is_empty()
	var cost: Dictionary = ECONOMY._cost("pds", 1)
	var full: bool = ECONOMY.next_pds(system) < 0
	body_defense.text = "Battery HP: %.0f\nDamage: %.0f per shot · 1 shot/yr\nRange: %.0f" % [ECONOMY.PDS_HP, ECONOMY.PDS_DAMAGE, ECONOMY.LASER_RANGE]
	body_status.text = ("Operational · %.0f / %.0f HP" % [float(battery.get("hp", 0.0)), ECONOMY.PDS_HP] if not battery.is_empty() else "Undefended") + "\nSystem defenses: %d/%d" % [defenses.size(), int(system["planet_count"])]
	body_costs.visible = not full
	if not full:
		_show_cost(body_costs, job["cost"] if building else cost)
	body_progress.visible = building
	if building:
		body_progress.value = 100.0 * float(job["progress"]) / float(job["work"])
		_style_progress(body_progress, system, job)
	body_upgrade.visible = not full
	body_upgrade.disabled = not owned or building or full or not ECONOMY.affordable(system, cost)
	_set_timed_action(body_upgrade, "Build system PDS", ECONOMY._work("pds", 1))
	body_cancel.visible = building
	body_cancel.disabled = not owned or not building

func _build_pds_card(parent: Container) -> void:
	var section: VBoxContainer = HUD.section(parent, "", true)
	section.get_child(0).hide()
	pds_card = _make_disclosure(section, "Planetary defense")
	var body: VBoxContainer = pds_card["body"]
	var detail := _label("", 12)
	body.add_child(detail)
	var summary: VBoxContainer = pds_card["summary"]
	var status := _label("", 11)
	summary.add_child(status)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 15
	section.add_child(progress)
	section.move_child(progress, body.get_index())
	var costs: GridContainer = _cost_grid(summary)
	var action: Button = _card_action(pds_card, "Build", _operation.bind("pds", ""))
	var cancel: Button = _card_cancel(pds_card, _pds_action, progress)
	HUD.action(action, HUD.ACCENT, true)
	pds_card.merge({"detail": detail, "progress": progress, "costs": costs, "button": action, "cancel": cancel, "status": status})

func _pds_action() -> void:
	var job: Dictionary = ECONOMY.pds_job(_planet())
	if not job.is_empty():
		_cancel_job(int(job["id"]))

func _refresh_pds(planet: Dictionary, owned: bool) -> void:
	pds_card["header"].get_parent().get_parent().visible = ECONOMY.has_planets(planet)
	if not ECONOMY.has_planets(planet):
		return
	var count: int = planet.get("pds", {}).size()
	var limit: int = int(planet["planet_count"])
	var job: Dictionary = ECONOMY.pds_job(planet)
	var building: bool = not job.is_empty()
	var full: bool = count >= limit
	var cost: Dictionary = ECONOMY._cost("pds", 1)
	_disclosure_title(pds_card, "Planetary defense · %d/%d" % [count, limit])
	var progress: ProgressBar = pds_card["progress"]
	progress.visible = building
	var action: Button = pds_card["button"]
	_set_timed_action(action, "Complete" if full else "Build", -1.0 if full else ECONOMY._work("pds", 1))
	action.disabled = not owned or full or building or not ECONOMY.affordable(planet, cost)
	pds_card["cancel"].visible = building
	pds_card["cancel"].disabled = not owned or not building
	pds_card["status"].text = "Fully defended" if full else ("Under construction" if building else ("Insufficient local materials" if not ECONOMY.affordable(planet, cost) else ""))
	pds_card["detail"].text = "One battery per planet, assigned automatically\nBattery HP: %.0f\nDamage: %.0f per shot · 1 shot/yr\nRange: %.0f\nSystem defenses: %d%s / %d" % [ECONOMY.PDS_HP, ECONOMY.PDS_DAMAGE, ECONOMY.LASER_RANGE, count, "" if full else " → %d" % (count + 1), limit]
	pds_card["costs"].visible = not full
	if building:
		progress.value = 100.0 * float(job["progress"]) / float(job["work"])
		progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
		_style_progress(progress, planet, job)
		_show_cost(pds_card["costs"], job["cost"])
	elif not full:
		_show_cost(pds_card["costs"], cost)

func _build_cargo_rows(parent: Container, labels: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	parent.add_child(grid)
	cargo_grids.append(grid)
	for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.tooltip_text = resource
		grid.add_child(row)
		var icon := TextureRect.new()
		icon.texture = HUD.ICONS.get(resource)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var title := _label("Antimatter" if resource == ECONOMY.ANTIMATTER else resource, 11)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var amount := _label("0.0", 12)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.custom_minimum_size.x = 42
		amount.add_theme_color_override("font_color", HUD.COLORS[resource])
		row.add_child(amount)
		labels[resource] = amount

func _selected_ship(state: Dictionary) -> Dictionary:
	if selected_ship_id < 0:
		return {}
	for ship in state.get("ships", []):
		if int(ship["id"]) == selected_ship_id:
			return ship
	return {}

func _ship_kind_name(kind: String) -> String:
	return "Logistics ship" if kind == "ship" else ("Mining ship" if kind == "miner" else kind.replace("_", " ").capitalize())

func _remaining_years(state: Dictionary, ship: Dictionary) -> float:
	var points: Array = ECONOMY.military_graph(state)["points"] if ship.get("kind", "") == "fighter" else state["map"]["points"]
	var pos: Vector2 = ECONOMY.combat_position(state, ECONOMY.military_graph(state), ship)
	var mode: String = ship.get("mining_mode", "idle")
	if mode == "outbound":
		return pos.distance_to(ship["mining_target"]) / ECONOMY.SHIP_SPEED
	if mode == "return":
		return pos.distance_to(points[int(ship["at"])]) / ECONOMY.SHIP_SPEED
	var remaining: float = 0.0
	for index in ship["route"]:
		var next: Vector2 = points[int(index)]
		remaining += pos.distance_to(next)
		pos = next
	return remaining / ECONOMY.SHIP_SPEED

func _apply_mining_policy() -> void:
	if selected_field >= 0:
		session.call("request_mining_policy", selected_field, mining_enabled.button_pressed, mining_metals.button_pressed, mining_crystals.button_pressed)

func _command_icon(path: String) -> Texture2D:
	var image := Image.new()
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#c5e5f5" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">' + path + '</g></svg>'
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _command_slot(id: String, hint: String, art: String, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _command_icon(art)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = hint
	button.toggle_mode = true
	button.pressed.connect(action)
	command_card.add_child(button)
	command_buttons[id] = button
	return button

func _build_command_card(parent: VBoxContainer) -> void:
	command_card = GridContainer.new()
	command_card.columns = 5
	command_card.add_theme_constant_override("h_separation", 3)
	command_card.add_theme_constant_override("v_separation", 3)
	parent.add_child(command_card)
	_command_slot("move", "Move · click a destination. Fighters travel without engaging until arrival.", '<path d="M5 16H26M17 7L26 16L17 25"/>', _arm_command.bind("move"))
	_command_slot("stop", "Stop · cancel the order and stop in place.", '<rect x="8" y="8" width="16" height="16" fill="#c5e5f5"/>', _stop_selected)
	hold_button = _command_slot("hold", "Hold position [H] · toggle holding position.", '<path d="M9 6V26M23 6V26M5 10L9 6L13 10M19 10L23 6L27 10M9 16H23"/>', _hold_selected)
	_command_slot("patrol", "Patrol · click another sector or asteroid field.", '<path d="M7 12A10 10 0 0 1 25 10M25 10V4M25 10H19M25 20A10 10 0 0 1 7 22M7 22V28M7 22H13"/>', _arm_command.bind("patrol"))
	_command_slot("attack", "Attack move · click a sector or hostile ship.", '<circle cx="16" cy="16" r="9"/><path d="M16 3V11M16 21V29M3 16H11M21 16H29"/>', _arm_command.bind("attack"))
	_command_slot("load", "Load cargo · click salvage debris to collect it.", '<rect x="7" y="17" width="18" height="10"/><path d="M16 4V20M10 14L16 20L22 14"/>', _arm_command.bind("load"))
	unload_button = _command_slot("unload", "Unload cargo [U] · return cargo to storage.", '<rect x="7" y="17" width="18" height="10"/><path d="M16 20V4M10 10L16 4L22 10"/>', _unload_selected)
	command_hint = _label("", 12)
	parent.add_child(command_hint)
	command_hint.hide()

func _arm_command(mode: String) -> void:
	pending_command = mode if pending_command != mode else ""
	_refresh_command_mode()

func _refresh_command_mode() -> void:
	if not is_instance_valid(command_card):
		return
	for id in command_buttons:
		var button: Button = command_buttons[id]
		button.set_pressed_no_signal(id == pending_command or (id == "hold" and _any_selected_holding()))
	command_hint.visible = not pending_command.is_empty()
	command_hint.text = "Choose %s · Esc / right-click cancels" % ("salvage" if pending_command == "load" else ("patrol destination" if pending_command == "patrol" else "destination"))
	map_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS if not pending_command.is_empty() else Control.CURSOR_ARROW

func _stop_selected() -> void:
	pending_command = ""
	var owned: Array[int] = _selected_owned_units(_state())
	if not owned.is_empty():
		session.call("request_unit_hold", owned, false)
	_refresh_command_mode()

func _execute_pending_command(point: Vector2) -> void:
	var mode: String = pending_command
	pending_command = ""
	_refresh_command_mode()
	if mode == "load":
		var state: Dictionary = _state()
		var wreck: int = _salvage_hit(state, point)
		if wreck >= 0:
			session.call("request_salvage", _selected_owned_units(state), wreck)
	elif mode == "patrol":
		_command_at(point, false, true)
	elif mode == "move":
		_command_at(point, false, false, true)
	elif mode == "attack":
		_command_at(point, false, false, false, true)

func _selection_icon(kind: String) -> Texture2D:
	if not selection_icons.has(kind):
		var points: Array = HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE)
		var coords: PackedStringArray = []
		for vertex in points:
			var v: Vector2 = vertex
			coords.append("%.2f,%.2f" % [16.0 + v.y, 16.0 - v.x])
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><polygon points="' + " ".join(coords) + '" fill="#101f30" stroke="#eaf6ff" stroke-width="1.25" stroke-linejoin="round"/></svg>')
		selection_icons[kind] = ImageTexture.create_from_image(image)
	return selection_icons[kind]

func _select_tile(id: int) -> void:
	selected_units.assign([id])
	selected_ship_id = id
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
			tile.custom_minimum_size = Vector2(38, 38)
			tile.focus_mode = Control.FOCUS_NONE
			tile.icon = _selection_icon(str(craft["kind"]))
			tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.pressed.connect(_select_tile.bind(id))
			selection_grid.add_child(tile)
			selection_tiles[id] = tile
		var hp: float = clampf(float(craft.get("hp", ECONOMY.SHIP_HP)) / ECONOMY.SHIP_HP, 0.0, 1.0)
		var tint: Color = Color("#d94b52") if hp < 0.2 else (Color("#e99e45") if hp < 0.5 else Color("#55b987"))
		if tile.get_meta("health_color", Color.TRANSPARENT) != tint:
			tile.set_meta("health_color", tint)
			tile.add_theme_stylebox_override("normal", HUD.surface(tint.darkened(0.40), tint, 2, 2))
			tile.add_theme_stylebox_override("hover", HUD.surface(tint.darkened(0.18), Color.WHITE, 2, 2))
			tile.add_theme_stylebox_override("pressed", HUD.surface(tint, Color.WHITE, 2, 2))
		tile.tooltip_text = "%s #%d · HP %.0f / %.0f" % [_ship_kind_name(str(craft["kind"])), id, float(craft.get("hp", ECONOMY.SHIP_HP)), ECONOMY.SHIP_HP]
	for id in selection_tiles.keys():
		if not living.has(id):
			var tile: Button = selection_tiles[id]
			selection_grid.remove_child(tile)
			tile.queue_free()
			selection_tiles.erase(id)
	selection_grid.visible = not living.is_empty()

func _refresh_field_panels(state: Dictionary) -> void:
	var field: Dictionary = state["map"]["fields"][selected_field]
	var special: bool = bool(field.get("antimatter", false))
	ship_title.text = _poi_name(state["planets"].size() + selected_field)
	var stock: Dictionary = ECONOMY.field_inventory(field)
	var total: float = float(stock["Metals"]) + float(stock["Crystals"])
	if special:
		ship_detail.text = "Raw antimatter · %s" % _tons(float(stock[ECONOMY.ANTIMATTER])) if float(stock[ECONOMY.ANTIMATTER]) > ECONOMY.EPS else "Depleted"
	elif total <= ECONOMY.EPS:
		ship_detail.text = "Depleted"
	else:
		var metals: int = roundi(100.0 * float(stock["Metals"]) / total)
		ship_detail.text = "Metals ~%d%% · %s\nCrystals ~%d%% · %s" % [metals, _tons(float(stock["Metals"])), 100 - metals, _tons(float(stock["Crystals"]))]
	var access_names: PackedStringArray = []
	for anchor in ECONOMY.field_access_systems(state["map"], field):
		access_names.append(_system_name(anchor))
	ship_detail.tooltip_text = "%d chunks remaining · Access: %s" % [field["chunks"].size(), ", ".join(access_names)]
	ship_cargo.get_parent().hide()
	fleet_title.text = "Mining"
	fleet_detail.hide()
	command_card.hide()
	pending_command = ""
	_refresh_command_mode()
	fleet_cargo.get_parent().hide()
	mining_controls.get_parent().show()
	var policy: Dictionary = ECONOMY.mining_policy(state, _me(), selected_field)
	mining_enabled.set_pressed_no_signal(bool(policy["enabled"]))
	mining_metals.visible = not special
	mining_crystals.visible = not special
	mining_metals.set_pressed_no_signal(bool(policy["Metals"]))
	mining_crystals.set_pressed_no_signal(bool(policy["Crystals"]))
	mining_metals.disabled = not mining_enabled.button_pressed
	mining_crystals.disabled = not mining_enabled.button_pressed

func _refresh_ship_panels(state: Dictionary, ship: Dictionary) -> void:
	mining_controls.get_parent().hide()
	var kind: String = ship.get("kind", "ship")
	var owner: int = int(ship["owner"])
	var roster: Dictionary = session.get("players")
	ship_title.text = "%s #%d" % [_ship_kind_name(kind), int(ship["id"])]
	var route: Array = ship["route"]
	var mode: String = ship.get("mining_mode", "idle")
	var status: String = "Orbiting %s" % _system_name(int(ship["at"]))
	if not route.is_empty():
		status = "%s → %s\nETA %.1f yr" % [_system_name(int(ship["at"])), _system_name(int(route.back())), _remaining_years(state, ship)]
	elif mode in ["outbound", "return"]:
		status = ("To field" if mode == "outbound" else "Returning") + "\nETA %.1f yr" % _remaining_years(state, ship)
	elif mode == "mining":
		status = "Mining field %02d\n%.1f / 5 yr" % [int(ship["field"]) + 1, minf(5.0, float(ship.get("mining_years", 0.0)))]
	elif kind == "miner" and mode == "delivery":
		status = "Waiting for storage"
	elif kind == "miner" and mode == "idle":
		status = "Waiting for accessible ore / storage"
	if kind == "fighter":
		status = "Stationed at %s" % _poi_name(int(ship["at"])) if route.is_empty() else "%s\nETA %.1f yr" % [_poi_name(int(route.back())), _remaining_years(state, ship)]
	if bool(ship.get("retreating", false)):
		var site: int = int(ship.get("repair_site", -1))
		status = "Repairing" if route.is_empty() and site >= 0 and (ship["position"] as Vector2).distance_to(state["map"]["points"][site]) <= ECONOMY.EPS and ECONOMY._repair_site_safe(state, ECONOMY.military_graph(state), owner, site) else "Withdrawing"
	elif int(ship.get("pursuit_target", -1)) >= 0:
		status = "Pursuing"
	elif bool(ship.get("holding", false)):
		status = "Moving to hold position" if ship.has("hold_position") and (ship["position"] as Vector2).distance_to(ship["hold_position"]) > ECONOMY.EPS else "Holding position"
	elif int(ship.get("combat_target", -1)) >= 0:
		status = "Engaged"
	if not bool(ship.get("retreating", false)):
		if int(ship.get("attack_order", -1)) >= 0:
			status = "Attacking #%d" % int(ship["attack_order"])
		elif ship.has("patrol_from"):
			status = "Patrolling → %s" % _poi_name(int(ship["operation_target"]))
	if int(ship.get("salvage_target", -1)) >= 0:
		status = "Collecting salvage" if bool(ship.get("tractor_active", false)) else "Approaching salvage"
	elif bool(ship.get("salvage_delivery", false)):
		status = "Delivering salvage" if int(ship.get("salvage_depot", -1)) >= 0 else "Waiting for salvage storage"
	elif int(ship.get("auto_salvage_target", -1)) >= 0:
		status += " · Salvaging" if bool(ship.get("tractor_active", false)) else " · Approaching debris"
	ship_detail.text = "%s\n%s\nHP %.0f / %.0f" % [str(roster.get(owner, {}).get("name", "Player")), status, float(ship.get("hp", ECONOMY.SHIP_HP)), ECONOMY.SHIP_HP]
	ship_detail.tooltip_text = ""
	ship_cargo.get_parent().show()
	ship_cargo.get_child(0).text = "Cargo %.1f / %.0f t" % [ECONOMY._cargo_total(ship), ECONOMY.cargo_capacity(kind)]
	for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
		var amount: float = float(ship.get("cargo", {}).get(resource, 0.0))
		ship_cargo_labels[resource].text = _tons(amount)
		ship_cargo_labels[resource].get_parent().visible = true
	fleet_title.text = "Fleet"
	fleet_detail.visible = true
	var counts: Dictionary = {"fighter": 0, "colony_ship": 0, "miner": 0, "ship": 0}
	var owned_count: int = 0
	var loaded_owned: bool = false
	var capacity: float = 0.0
	var cargo: Dictionary = ECONOMY.empty_stock()
	for craft in state["ships"]:
		if not selected_units.has(int(craft["id"])):
			continue
		counts[craft["kind"]] += 1
		owned_count += int(int(craft["owner"]) == _me())
		loaded_owned = loaded_owned or (int(craft["owner"]) == _me() and ECONOMY._cargo_total(craft) > ECONOMY.EPS)
		capacity += ECONOMY.cargo_capacity(str(craft["kind"]))
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			cargo[resource] = float(cargo.get(resource, 0.0)) + float(craft.get("cargo", {}).get(resource, 0.0))
	command_card.show()
	var combat_owned: bool = false
	var can_load: bool = false
	for craft in state["ships"]:
		if selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me():
			combat_owned = combat_owned or craft["kind"] == "fighter"
			can_load = can_load or ECONOMY.cargo_free(craft) > ECONOMY.EPS
	for id in command_buttons:
		var button: Button = command_buttons[id]
		button.disabled = owned_count == 0 or (id in ["patrol", "attack"] and not combat_owned) or (id == "load" and not can_load) or (id == "unload" and not loaded_owned)
	if not command_buttons.has(pending_command) or (command_buttons[pending_command] as Button).disabled:
		pending_command = ""
	_refresh_command_mode()
	fleet_detail.text = "%d fighters · %d colony ships · %d miners · %d logistics" % [counts["fighter"], counts["colony_ship"], counts["miner"], counts["ship"]]
	if owned_count < selected_units.size():
		fleet_detail.text += "\n%d owned · %d foreign" % [owned_count, selected_units.size() - owned_count]
	fleet_detail.tooltip_text = "Foreign ships are read-only. Commands affect only your own ships. Ctrl+1–9 assigns a selection group, 1–9 recalls it."
	if owned_count > 0:
		fleet_detail.tooltip_text += " Right-click a hostile ship to focus attack, or a sector to attack-move. Shift-right-click a sector to patrol. Ships collect nearby salvage when safe; right-click to claim manually; U unloads cargo. Right-click empty space to position and hold; Alt-right-click forces a local position. H holds/releases."
	fleet_cargo.get_parent().show()
	fleet_cargo.get_child(0).text = "Cargo %.1f / %.0f t" % [ECONOMY._cargo_total({"cargo": cargo}), capacity]
	if fleet_cargo.get_parent().visible:
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			var amount: float = float(cargo.get(resource, 0.0))
			fleet_cargo_labels[resource].text = _tons(amount)
			fleet_cargo_labels[resource].tooltip_text = "%.1f t" % amount
			fleet_cargo_labels[resource].get_parent().visible = true

func _build_lens_buttons(parent: Container) -> void:
	logistics_lens = _button("Logistics", _toggle_lens.bind("logistics"), parent)
	logistics_lens.toggle_mode = true
	logistics_lens.focus_mode = Control.FOCUS_NONE
	logistics_lens.tooltip_text = "System resource storage"

var diagnostic_label: Label
var diagnostic_button: Button
var diagnostic_elapsed: float = 0.0
var diagnostic_last_bytes: int = -1

func _build_time_controls(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for speed in [0, 1, 2, 5, 10]:
		var label: String = "Ⅱ" if speed == 0 else "%d×" % speed
		var button: Button = _button(label, _set_time_speed.bind(int(speed)), row)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.x = 33
		time_buttons[speed] = button
	diagnostic_button = _button("Perf", func() -> void: diagnostic_label.visible = not diagnostic_label.visible, row)
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
	var can_change: bool = str(session.get("phase")) == "match" and state.get("match_result", {}).is_empty() and (bool(session.get("is_solo")) or multiplayer.is_server())
	for speed in time_buttons:
		var button: Button = time_buttons[speed]
		var active: bool = int(speed) == current
		button.disabled = not can_change
		button.set_pressed_no_signal(active)
		# Disabled guest buttons must still show which speed the host selected.
		if active:
			button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
			button.add_theme_color_override("font_disabled_color", HUD.ACCENT)
		else:
			button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")
		button.tooltip_text = ("Pause simulation" if int(speed) == 0 else "%d× simulation speed" % int(speed)) + ("" if can_change else " (host controlled)")

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
	territory_layer.offset_top = HEADER_HEIGHT + 16
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
uniform sampler2D occupied_tiles : filter_nearest, repeat_disable;
uniform vec2 tile_grid = vec2(1.0);
uniform vec2 world_extent = vec2(1.0);
uniform float padding = 1.0;

vec3 team_color(int team) {
	if (team == 1) return vec3(0.404, 0.831, 0.663);
	if (team == 2) return vec3(0.957, 0.643, 0.416);
	if (team == 3) return vec3(0.467, 0.667, 0.996);
	if (team == 4) return vec3(0.808, 0.569, 0.929);
	if (team == 5) return vec3(0.933, 0.820, 0.420);
	if (team == 6) return vec3(0.941, 0.518, 0.651);
	if (team == 7) return vec3(0.420, 0.796, 0.831);
	return vec3(0.929, 0.459, 0.467);
}
void fragment() {
	ivec2 tile = ivec2(clamp(floor(UV * tile_grid), vec2(0.0), tile_grid - vec2(1.0)));
	if (texelFetch(occupied_tiles, tile, 0).r < 0.5) {
		discard;
	}
	vec2 p = UV * world_extent - vec2(padding);
	// Match ECONOMY.sector_limit: nearest center, clipped by its radius.
	// All POIs participate, including neutral and undiscovered neighbors.
	float best_sq = 1e20;
	float second_sq = 1e20;
	vec2 second_center = vec2(0.0);
	vec4 site = vec4(0.0);
	for (int i = 0; i < site_count; i++) {
		vec4 candidate = texelFetch(site_data, ivec2(i, 0), 0);
		vec2 offset = p - candidate.xy;
		float distance_sq = dot(offset, offset);
		if (distance_sq < best_sq) {
			second_sq = best_sq;
			second_center = site.xy;
			best_sq = distance_sq;
			site = candidate;
		} else if (distance_sq < second_sq) {
			second_sq = distance_sq;
			second_center = candidate.xy;
		}
	}
	int winner = int(site.w + 0.5);
	// The nearest-site decision is discontinuous across bisectors. Use
	// world-coordinate pixel width instead of derivatives of that decision.
	float aa = max(length(fwidth(p)), 0.00001);
	float bisector = -1e10;
	if (second_sq < 1e19) {
		bisector = (best_sq - second_sq) / max(2.0 * length(site.xy - second_center), 0.00001);
	}
	float d = max(sqrt(best_sq) - site.z, bisector);
	// Draw a smooth inward edge, including where the neighboring sector is neutral.
	float inside = 1.0 - smoothstep(-aa, 0.0, d);
	float border = inside * smoothstep(-aa * 2.8, -aa * 1.1, d);
	COLOR = vec4(team_color(winner), winner > 0 ? inside * 0.12 + border * 0.52 : 0.0);
}
"""
	territory_material = ShaderMaterial.new()
	territory_material.shader = shader
	territory_image.material = territory_material
	territory_image.hide()

# One consistent radius per galaxy, based on median nearest-system spacing.
# Outlier systems cannot create enormous wedges; asteroid fields are smaller.
func _refresh_territory(state: Dictionary) -> void:
	if state.is_empty():
		territory_image.hide()
		territory_seed = -1
		territory_last.clear()
		return
	var seed_value: int = int(state["map"]["seed"])
	if territory_seed != seed_value:
		territory_radius = ECONOMY.sector_base_radius(state["map"])
		territory_seed = seed_value
		territory_last.clear()
	var empires: Array[int] = ECONOMY.territory_empires(state)
	var graph: Dictionary = ECONOMY.military_graph(state)
	var contenders: Dictionary = {}
	# The simulation's territory claims can be neutralized by combat. Keep
	# the visual footprint and cycle through hostile players instead.
	for i in range((state["planets"] as Array).size()):
		var planet: Dictionary = state["planets"][i]
		var owner: int = int(planet["owner"])
		if owner > 0 and (float(planet.get("population", 0.0)) > 0.0 or not (planet.get("yards", []) as Array).is_empty()):
			contenders[i] = [owner]
	for ship in state["ships"]:
		if ship.get("kind", "") != "fighter" or bool(ship.get("retreating", false)):
			continue
		var node: int = ECONOMY.local_sector(graph, ship)
		if node < 0:
			continue
		var player: int = int(ship["owner"])
		if not contenders.has(node):
			contenders[node] = []
		if not (contenders[node] as Array).has(player):
			contenders[node].append(player)
	var claims: Array[int] = []
	var cycle: int = floori(territory_cycle_elapsed / 0.85)
	for i in range(empires.size()):
		var players: Array = contenders.get(i, [])
		players.sort()
		var teams: Dictionary = {}
		for player in players:
			teams[int(state["teams"].get(int(player), 0))] = true
		if teams.size() > 1:
			claims.append(_empire_color_index(int(players[cycle % players.size()])))
		else:
			claims.append(_empire_color_index(empires[i]))
	if claims == territory_last:
		return
	territory_last = claims
	var points: Array = ECONOMY.military_graph(state)["points"]
	var sites: Array[Color] = []
	var has_claim: bool = false
	for i in range(points.size()):
		var point: Vector2 = points[i]
		var radius: float = float(graph["sector_radii"][i]) / territory_radius
		has_claim = has_claim or claims[i] > 0
		# Neutral centers clip their neighbors exactly like the simulation.
		sites.append(Color(point.x / territory_radius, point.y / territory_radius, radius, float(claims[i])))
	territory_site_count = sites.size()
	if not has_claim:
		territory_image.hide()
		return
	var data: Image = Image.create_empty(sites.size(), 1, false, Image.FORMAT_RGBAF)
	for i in range(sites.size()):
		data.set_pixel(i, 0, sites[i])
	territory_sites = ImageTexture.create_from_image(data)
	territory_material.set_shader_parameter("site_data", territory_sites)
	territory_material.set_shader_parameter("site_count", territory_site_count)
	var extent: Vector2 = _map_size() / territory_radius + Vector2.ONE * 3.0
	_cache_territory_tiles(sites, extent)
	territory_material.set_shader_parameter("world_extent", extent)
	territory_material.set_shader_parameter("padding", 1.5)
	territory_image.show()
	_position_territory()

# Conservative tile mask: only tiles near a claimed sector disk need
# shading. All POI centers still participate in the nearest-site test.
func _cache_territory_tiles(sites: Array[Color], extent: Vector2) -> void:
	var dimensions := Vector2i(maxi(1, ceili(extent.x)), maxi(1, ceili(extent.y)))
	var cell: Vector2 = extent / Vector2(dimensions)
	var mask: Image = Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	var counts: Dictionary = {}
	for site in sites:
		if site.a > 0.0:
			var team: int = roundi(site.a)
			counts[team] = int(counts.get(team, 0)) + 1
	for site in sites:
		if site.a <= 0.0:
			continue
		var reach: float = site.b + 0.12 * float(counts[roundi(site.a)]) + 2.0
		var center := Vector2(site.r, site.g) + Vector2.ONE * 1.5
		var low: Vector2 = (center - Vector2.ONE * reach) / cell
		var high: Vector2 = (center + Vector2.ONE * reach) / cell
		for y in range(maxi(0, floori(low.y)), mini(dimensions.y - 1, floori(high.y)) + 1):
			for x in range(maxi(0, floori(low.x)), mini(dimensions.x - 1, floori(high.x)) + 1):
				mask.set_pixel(x, y, Color.WHITE)
	territory_material.set_shader_parameter("occupied_tiles", ImageTexture.create_from_image(mask))
	territory_material.set_shader_parameter("tile_grid", Vector2(dimensions))

func _position_territory() -> void:
	var padding: Vector2 = Vector2.ONE * territory_radius * 1.5
	territory_image.position = _screen_point(-padding)
	territory_image.size = (_map_size() + padding * 2.0) * _fit() * zoom

func _show_system_rings(index: int) -> bool:
	return index == selected

func _build_global_bar(stats: Container) -> void:
	for resource in ECONOMY.RESOURCES:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", HUD.surface(Color("#122337"), Color("#284661"), 4, 3))
		stats.add_child(tile)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		tile.add_child(stack)
		var line := HBoxContainer.new()
		stack.add_child(line)
		var icon := TextureRect.new()
		icon.texture = HUD.ICONS[resource]
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var magnitude: float = absf(value)
	var scale: float = 1.0
	var unit: String = "t"
	if magnitude >= 1000000000.0:
		scale = 1000000000.0
		unit = "Gt"
	elif magnitude >= 1000000.0:
		scale = 1000000.0
		unit = "Mt"
	elif magnitude >= 1000.0:
		scale = 1000.0
		unit = "kt"
	var number: String = "%.1f" % (value / scale) if scale > 1.0 or decimals == 1 else "%.0f" % value
	return number + ("" if compact else " ") + unit

func _theoretical_delta(p: Dictionary, resource: String) -> float:
	return ECONOMY.rate(p, resource) - ECONOMY.consumption(p, resource)

func _empire_theoretical_delta(state: Dictionary, resource: String) -> float:
	var total: float = 0.0
	for p in state.get("planets", []):
		if int(p["owner"]) == _me():
			total += _theoretical_delta(p, resource)
	return total

func _set_resource_delta(label: Label, annual: float, parentheses: bool = false) -> void:
	var displayed: float = 0.0 if absf(annual) < 0.05 else annual
	var amount: String = ("+" if displayed > 0.0 else "") + _tons(displayed, 1, true)
	label.text = "(%s)" % amount if parentheses else amount
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

func _flow_name(category: String) -> String:
	if category.begins_with("Construction: "):
		var kind: String = category.trim_prefix("Construction: ")
		match kind:
			"ship": return "Logistics ships"
			"yard": return "Shipyard builds"
			"yard_upgrade": return "Shipyard upgrades"
			"production": return "Production upgrades"
			"pds": return "Planetary defense"
			_: return kind.replace("_", " ").capitalize() + " builds"
	return category

func _resource_breakdown(state: Dictionary, resource: String) -> String:
	if resource == "population":
		var lines: PackedStringArray = ["Population · %.0f people" % float(ECONOMY.empire_totals(state, _me())["population"]), "Current local growth (people/yr)"]
		for i in range(state["planets"].size()):
			var p: Dictionary = state["planets"][i]
			if int(p["owner"]) != _me():
				continue
			var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
			var crew: float = float(p.get("crew_rate", 0.0))
			lines.append("%s · %.0f · %+.2f/yr\n  %+.2f demographic · %+.2f crews · %+.1f%% overpopulation penalty" % [_system_name(i), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p)])
		return "\n".join(lines)
	var totals: Dictionary = ECONOMY.empire_totals(state, _me())
	var lines: PackedStringArray = ["%s  ·  %.2f t stored" % [resource, float(totals["stock"][resource])],
		"%.2f t in transit  /  %.0f t storage" % [float(totals["cargo"][resource]), float(totals["storage_reference"][resource])],
		"Theoretical empire net: %+.2f t/yr (production − demand)" % _empire_theoretical_delta(state, resource),
		"Latest actual local flows (t/yr)"]
	for i in range((state.get("planets", []) as Array).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != _me():
			continue
		var parts: PackedStringArray = []
		var categories: Array = ["Production", "Population", "Mining deliveries", "Salvage deliveries", "Imports", "Exports"]
		for category in p.get("flows", {}):
			if not categories.has(category):
				categories.append(category)
		var net: float = 0.0
		for category in categories:
			var amount: float = ECONOMY.local_flow(p, category, resource)
			if amount <= ECONOMY.EPS:
				continue
			var sign: float = -1.0 if category == "Population" or category == "Exports" or str(category).begins_with("Construction: ") else 1.0
			net += sign * amount
			parts.append("%+.2f %s" % [sign * amount, _flow_name(category)])
		lines.append("%s  %+.2f theoretical · %+.2f actual" % [_system_name(i), _theoretical_delta(p, resource), net])
		if not parts.is_empty():
			lines.append("  " + " · ".join(parts))
	if int(state.get("time_speed", 1)) == 0:
		lines.append("Paused · last simulation step")
	return "\n".join(lines)

func _local_breakdown(p: Dictionary, resource: String) -> String:
	if resource == "population":
		var growth: float = float(p.get("demographic_rate", ECONOMY.population_growth(p)))
		var crew: float = float(p.get("crew_rate", 0.0))
		return "%s · %.0f people\n%+.2f/yr net\n%+.2f demographic change\n%+.2f ship crews\nOverpopulation penalty: %+.1f%%\nOrganics: %.2f produced / %.2f consumed per year\nEco-Housing: %.0f / %.0f residents · +%.2f t/yr Organics" % [_system_name(selected), float(p["population"]), growth - crew, growth, -crew, -100.0 * ECONOMY.overpopulation_penalty(p), ECONOMY.rate(p, "Organics"), ECONOMY.consumption(p, "Organics"), ECONOMY.eco_population(p), ECONOMY.eco_capacity(p), ECONOMY.eco_organics(p)]
	var potential: float = ECONOMY.rate(p, resource)
	var demand: float = ECONOMY.consumption(p, resource)
	var lines: PackedStringArray = ["%s · %.2f t stored" % [resource, float(p["stock"][resource])], "Theoretical: %.2f production − %.2f demand = %+.2f t/yr" % [potential, demand, potential - demand], "Latest actual flows (t/yr)"]
	var categories: Array = ["Production", "Population", "Mining deliveries", "Salvage deliveries", "Imports", "Exports"]
	for category in p.get("flows", {}):
		if not categories.has(category):
			categories.append(category)
	var net: float = 0.0
	for category in categories:
		var amount: float = ECONOMY.local_flow(p, category, resource)
		var sign: float = -1.0 if category == "Population" or category == "Exports" or str(category).begins_with("Construction: ") else 1.0
		net += sign * amount
		if amount > ECONOMY.EPS:
			lines.append("%+.2f %s" % [sign * amount, _flow_name(category)])
	lines.append("%+.2f net" % net)
	return "\n".join(lines)

func _update_resource_hover() -> void:
	if not is_instance_valid(resource_hover_panel):
		return
	var mouse: Vector2 = get_global_mouse_position()
	var resource: String = ""
	for key in global_resource_tiles:
		if global_resource_tiles[key].get_global_rect().has_point(mouse):
			resource = key
			break
	if resource.is_empty() and planet_overview.is_visible_in_tree() and overview_panel.get_global_rect().has_point(mouse) and not _planet().is_empty():
		if population_label.get_parent().get_global_rect().has_point(mouse):
			resource = "local:population"
		else:
			for key in production_values:
				if production_values[key]["row"].get_global_rect().has_point(mouse):
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
	if local and (_planet().is_empty() or not planet_overview.is_visible_in_tree()):
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
	resource_hover_panel.size = Vector2(width, height)
	var popup_y: float = tile_rect.position.y - height if local else tile_rect.end.y
	resource_hover_panel.global_position = Vector2(clampf(tile_rect.position.x, 8.0, viewport.x - width - 8.0), clampf(popup_y, 8.0, maxf(8.0, viewport.y - height - 8.0)))
	resource_hover_panel.show()

func _refresh_global_bar(state: Dictionary) -> void:
	year_label.text = "%d A.D." % ECONOMY.current_year(state)
	year_label.tooltip_text = "One game year per simulation second"
	var totals: Dictionary = ECONOMY.empire_totals(state, _me())
	for resource in ECONOMY.RESOURCES:
		var value: float = float(totals["resources"][resource])
		var annual: float = _empire_theoretical_delta(state, resource)
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
	for i in range(state.get("planets", []).size()):
		var p: Dictionary = state["planets"][i]
		if int(p["owner"]) != _me():
			continue
		population_net += float(p.get("demographic_rate", ECONOMY.population_growth(p))) - float(p.get("crew_rate", 0.0))
		if population_total > 0.0 and float(p["population"]) > 0.0:
			population_segments.append({"name": _system_name(i), "share": float(p["population"]) / population_total, "index": i})
	population_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["share"] > b["share"] if a["share"] != b["share"] else a["index"] < b["index"])
	global_population_label.text = "%s (%+.0f/yr)" % [_compact_amount(population_total), population_net]
	global_population_label.tooltip_text = ""
	global_resource_segments["population"] = population_segments
	global_resource_fills["population"] = 1.0 if population_total > 0.0 else 0.0
	global_resource_strips["population"].queue_redraw()

func _inspector_page(title_text: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title_text
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_tabs.add_child(scroll)
	var page_content := VBoxContainer.new()
	page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_theme_constant_override("separation", 5)
	scroll.add_child(page_content)
	var page := GridContainer.new()
	page.add_theme_constant_override("h_separation", 5)
	page.add_theme_constant_override("v_separation", 5)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_child(page)
	command_grids[title_text] = page
	return page

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
			trade_checks[resource][0].text = "In %d%%" % roundi(float(t["min"]))
			trade_checks[resource][1].text = "Out %d%%" % roundi(float(t["max"]))
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
	session.call("request_operation", selected, kind, target)

func _cancel_job(id: int) -> void:
	session.call("request_cancel", selected, id)

func _refresh() -> void:
	if is_instance_valid(map_canvas):
		map_canvas.queue_redraw()
	if not is_instance_valid(year_label):
		return
	var state: Dictionary = _state()
	var phase: String = str(session.get("phase"))
	_refresh_global_bar(state)
	_refresh_match_result(state)
	_refresh_time_controls(state)
	menu_exit.text = "Main menu" if bool(session.get("is_solo")) else ("Return to lobby" if multiplayer.is_server() else "Leave match")
	if phase == "loading" and multiplayer.is_server():
		menu_exit.text = "Cancel start"
	var planets: Array = state.get("planets", [])
	if not initial_selection_done and not planets.is_empty():
		initial_selection_done = true
		for i in range(planets.size()):
			if int(planets[i]["owner"]) == _me():
				selected = i
				# Center the initial camera on the player's home system.
				zoom = clampf(2.4, MIN_ZOOM, _max_zoom())
				pan = (_map_size() * 0.5 - state["map"]["points"][i]) * _fit() * zoom
				_position_territory()
				_load_thresholds()
				break
	var ship: Dictionary = _selected_ship(state)
	var living: Array[int] = []
	for craft in state.get("ships", []):
		if selected_units.has(int(craft["id"])):
			living.append(int(craft["id"]))
	selected_units = living
	if ship.is_empty():
		selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
		ship = _selected_ship(state)
	if ship.is_empty() and selected_units.is_empty():
		follow_units = false
	var p: Dictionary = _planet()
	var field_selected: bool = selected_field >= 0 and ECONOMY.discovered(state, _me(), "fields", selected_field)
	var ship_selected: bool = not ship.is_empty()
	var other_selected: bool = ship_selected or field_selected
	var body_selected: bool = not other_selected and not p.is_empty() and selected_body >= 0 and selected_body < int(p.get("planet_count", 0))
	if not body_selected:
		selected_body = -1
	# Slot indices compact after destruction. Return to the system rather
	# than silently retargeting an upgrade at a different shipyard.
	var yard_selected: bool = not other_selected and not body_selected and not p.is_empty() and selected_yard >= 0 and selected_yard < p.get("yards", []).size() and selected_yard_count == p.get("yards", []).size()
	if not yard_selected:
		selected_yard = -1
	inspector_panel.visible = true
	console_right_body.visible = not p.is_empty() or other_selected
	# Keep the center panel mounted even when there is no selection;
	# only its contents disappear, leaving a stable blank HUD surface.
	overview_panel.visible = true
	empty_selection.visible = false
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_overview.visible = not p.is_empty() and not other_selected and not body_selected and not yard_selected
	yard_column.visible = planet_overview.visible and overview_panel.visible
	body_overview.visible = body_selected
	yard_overview.visible = yard_selected
	var own_system: bool = not p.is_empty() and int(p.get("owner", -1)) == _me()
	inspector_tabs.visible = not other_selected and own_system
	var current_system: int = selected if not other_selected and not p.is_empty() else -1
	if current_system != last_system_tab_selection:
		if current_system >= 0:
			inspector_tabs.current_tab = 0
		_collapse_details()
		last_system_tab_selection = current_system
	interaction_panel.visible = not other_selected and not p.is_empty() and not own_system
	ship_overview.visible = other_selected
	_refresh_selection_tiles(state)
	if not ship_selected:
		pending_command = ""
		_refresh_command_mode()
	fleet_scroll.visible = other_selected
	fleet_overview.visible = other_selected
	fleet_title.visible = other_selected
	fleet_detail.visible = other_selected
	fleet_cargo.visible = other_selected
	if yard_selected:
		_refresh_yard_overview(p, own_system and phase == "match")
		return
	if body_selected:
		_refresh_body_overview(p, own_system and phase == "match")
		return
	if field_selected:
		_refresh_field_panels(state)
		return
	if ship_selected:
		_refresh_ship_panels(state, ship)
		return
	_refresh_yard_activity(p)
	var owned: bool = not p.is_empty() and int(p["owner"]) == _me() and phase == "match"
	_refresh_colony_choices(state, p, phase)
	for kind in continuous_checks:
		var check: Button = continuous_checks[kind]
		_sync_repeat(check, p, kind, owned and (kind != "ship" or bool(p.get("home", false))))
	colony_button.disabled = not owned
	for slider in trade_sliders.values():
		slider.enabled = owned
		for resource in trade_checks:
			for check in trade_checks[resource]:
				check.disabled = not owned
		if not owned:
			slider.active_handle = -1
		slider.queue_redraw()
	fighter_button.disabled = not owned
	miner_button.disabled = not owned
	ship_button.disabled = true
	if p.is_empty():
		info.text = "Select a system."
		raw_antimatter_label.hide()
		system_owner_label.text = ""
		population_label.text = ""
		population_delta_label.text = ""
		_refresh_build_cards(p, false)
		return
	var owner: int = int(p["owner"])
	var roster: Dictionary = session.get("players")
	var name_text: String = "Neutral" if owner == 0 else str(roster.get(owner, {}).get("name", "Player"))
	info.text = _system_name(selected) + (" · No planets" if not ECONOMY.has_planets(p) else "")
	info.tooltip_text = info.text + (" · Home" if bool(p["home"]) else "")
	system_owner_label.text = name_text
	system_owner_label.tooltip_text = name_text
	system_owner_label.add_theme_color_override("font_color", _empire_color(owner).lerp(HUD.MUTED, 0.28))
	for resource in ECONOMY.RESOURCES:
		var amount: float = float(p["stock"][resource])
		production_values[resource]["stock"].text = _tons(amount)
		production_values[resource]["stock"].tooltip_text = "%.1f t %s stored" % [amount, resource]
		production_values[resource]["level"].text = str(int(p["levels"][resource]) + int(p.get("buildings", {}).get(resource, 0)))
		var percent: int = roundi(100.0 * ECONOMY.production_modifier(p, resource))
		var bonus: Label = production_values[resource]["bonus"]
		bonus.text = "—" if percent == 100 else "%d%%" % (percent - 100) if percent < 100 else "+%d%%" % (percent - 100)
		bonus.add_theme_color_override("font_color", HUD.ACCENT if percent > 100 else (Color("#e4a479") if percent < 100 else HUD.MUTED))
		bonus.tooltip_text = "%.1f%% of baseline output" % (100.0 * ECONOMY.production_modifier(p, resource))
		var annual: float = _theoretical_delta(p, resource)
		var delta_label: Label = production_values[resource]["rate"]
		_set_resource_delta(delta_label, annual)
		delta_label.tooltip_text = "Potential production %.2f t/yr · Demand %.2f t/yr · Theoretical net %+.2f t/yr" % [ECONOMY.rate(p, resource), ECONOMY.consumption(p, resource), annual]
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
	_refresh_pds(p, owned)
	_refresh_economy_cards(p, owned)
	ship_button.disabled = not owned or not bool(p["home"])
	_refresh_build_cards(p, owned)

func _upgrade_yard_at(index: int) -> void:
	if index < 0:
		_cancel_job(-index)
	elif index >= 100:
		_operation("yard", str(index - 100))
	elif ECONOMY._has_job(_planet(), "yard_upgrade", str(index)):
		_cancel_kind("yard_upgrade", str(index))
	else:
		_operation("yard_upgrade", str(index))

func _cancel_yard_at(index: int) -> void:
	if index < 0:
		_cancel_job(-index)
	elif index < 100:
		_cancel_kind("yard_upgrade", str(index))

func _refresh_yard_activity(p: Dictionary) -> void:
	var active: Dictionary = {}
	if not p.is_empty():
		var yards: Array = p["yards"]
		for i in range(yards.size()):
			var yard: Dictionary = yards[i]
			active[i] = {}
			for job in p["queue"]:
				if int(job["id"]) == int(yard["job"]):
					active[i] = job
					break
		# A queued upgrade with no materials may be unassigned; keep its bar visible.
		for i in range(yards.size()):
			if not active[i].is_empty():
				continue
			for queued in p["queue"]:
				if queued["kind"] == "yard_upgrade" and int(queued["target"]) == i:
					active[i] = queued
					break
		var reserved: Dictionary = {}
		for job in p["queue"]:
			if job["kind"] == "yard":
				active[-int(job["id"])] = job
				reserved[int(job["level"])] = true
		for slot in range(yards.size() + 1, ECONOMY.MAX_SHIPYARDS + 1):
			if not reserved.has(slot):
				active[100 + slot] = {}
	yard_activity.get_parent().visible = not p.is_empty()
	for index in yard_activity_rows.keys():
		if not active.has(index):
			var obsolete: Control = yard_activity_rows[index]["row"]
			yard_activity.remove_child(obsolete)
			obsolete.queue_free()
			yard_activity_rows.erase(index)
	for index in active:
		var job: Dictionary = active[index]
		var vacant: bool = int(index) >= 100
		var number: int = int(index) - 100 if vacant else int(index) + 1
		if int(index) < 0:
			number = int(job["level"])
		if not yard_activity_rows.has(index):
			var row := VBoxContainer.new()
			var header := HBoxContainer.new()
			row.add_child(header)
			var title := _label("", 12)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(title)
			var build: Button = _button("Build", _upgrade_yard_at.bind(int(index)), header)
			build.custom_minimum_size = Vector2(48, 22)
			build.add_theme_font_size_override("font_size", 11)
			var vacant_cancel: Button = _button("×", func() -> void: pass, header)
			vacant_cancel.custom_minimum_size = Vector2(23, 22)
			vacant_cancel.disabled = true
			vacant_cancel.tooltip_text = "No construction to cancel"
			var costs: GridContainer = _cost_grid(row)
			var progress := ProgressBar.new()
			progress.step = 0.0
			progress.custom_minimum_size.y = 16
			row.add_child(progress)
			var disclosure: Dictionary = _make_disclosure(row, "Upgrade")
			var upgrade_detail := _label("", 11)
			disclosure["body"].add_child(upgrade_detail)
			var upgrade_costs: GridContainer = _cost_grid(disclosure["summary"])
			var actions: HBoxContainer = disclosure["actions"]
			var upgrade: Button = _card_action(disclosure, "Upgrade", _upgrade_yard_at.bind(int(index)))
			var cancel: Button = _card_cancel(disclosure, _cancel_yard_at.bind(int(index)), progress)
			var repeat: Button = _repeat_button(actions, "yard_upgrade:" + str(index))
			upgrade.custom_minimum_size.y = 24
			upgrade.add_theme_font_size_override("font_size", 11)
			yard_activity.add_child(row)
			disclosure.merge({"row": row, "label": title, "progress": progress, "upgrade": upgrade, "cancel": cancel, "vacant_cancel": vacant_cancel, "repeat": repeat, "build": build, "costs": costs, "upgrade_detail": upgrade_detail, "upgrade_costs": upgrade_costs})
			yard_activity_rows[index] = disclosure
		var label: Label = yard_activity_rows[index]["label"]
		var bar: ProgressBar = yard_activity_rows[index]["progress"]
		var upgrade: Button = yard_activity_rows[index]["upgrade"]
		yard_activity.move_child(yard_activity_rows[index]["row"], mini(number, yard_activity.get_child_count() - 1))
		var repeat: Button = yard_activity_rows[index]["repeat"]
		var build: Button = yard_activity_rows[index]["build"]
		var costs: GridContainer = yard_activity_rows[index]["costs"]
		var can_build: bool = vacant and number == ECONOMY.next_shipyard_slot(p) and int(p["owner"]) == _me() and str(session.get("phase")) == "match"
		build.visible = can_build
		yard_activity_rows[index]["vacant_cancel"].hide()
		if vacant:
			yard_activity_rows[index]["cancel"].hide()
		build.disabled = not can_build or not ECONOMY.affordable(p, ECONOMY._cost("yard", number))
		costs.visible = can_build
		yard_activity_rows[index]["actions"].visible = not vacant
		yard_activity_rows[index]["summary"].visible = not vacant
		yard_activity_rows[index]["row"].visible = number <= p["yards"].size() + 1 if not p.is_empty() else false
		if vacant:
			_collapse_card(yard_activity_rows[index])
			label.text = "Shipyard %d" % number
			bar.visible = false
			upgrade.visible = false
			repeat.visible = false
			var recipe: Dictionary = ECONOMY._cost("yard", number)
			label.tooltip_text = _cost_text(recipe) + " · +5,000 Eco-Housing residents · +0.2 t/yr Organics · Requires %s population to operate" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[number - 1]))
			build.tooltip_text = label.tooltip_text
			_set_timed_action(build, "Build", ECONOMY._work("yard", number))
			_show_cost(costs, recipe)
			continue
		bar.visible = true
		label.tooltip_text = ""
		var existing: bool = int(index) >= 0
		var level: int = int(p["yards"][index]["level"]) if existing else 1
		var pending: bool = existing and ECONOMY._has_job(p, "yard_upgrade", str(index))
		var owned: bool = int(p["owner"]) == _me() and str(session.get("phase")) == "match"
		var operating: bool = existing and ECONOMY.shipyard_operational(p, int(index))
		var cancelling: Button = yard_activity_rows[index]["cancel"]
		upgrade.visible = existing
		repeat.visible = existing
		cancelling.visible = not job.is_empty()
		cancelling.disabled = not owned or job.is_empty()
		if not job.is_empty():
			if cancelling.pressed.is_connected(_cancel_yard_at.bind(int(index))):
				cancelling.pressed.disconnect(_cancel_yard_at.bind(int(index)))
			if cancelling.has_meta("job_callback"):
				cancelling.pressed.disconnect(cancelling.get_meta("job_callback"))
			var callback: Callable = _cancel_job.bind(int(job["id"]))
			cancelling.set_meta("job_callback", callback)
			cancelling.pressed.connect(callback)
		_sync_repeat(repeat, p, "yard_upgrade:" + str(index), repeat.visible and str(session.get("phase")) == "match")
		upgrade.disabled = not owned or not existing or pending or not operating or not ECONOMY.affordable(p, ECONOMY._cost("yard_upgrade", level + 1))
		_set_timed_action(upgrade, "Upgrade", ECONOMY._work("yard_upgrade", level + 1) if existing else -1.0)
		_disclosure_title(yard_activity_rows[index], "Upgrade to Lv %d" % (level + 1) if existing and not pending else ("Upgrade pending" if existing else "Construction · " + _duration_text(float(job["work"]))))
		yard_activity_rows[index]["upgrade_detail"].text = "Build speed %.0f → %.0f work/yr · Max size %d → %d" % [ECONOMY.yard_speed(level), ECONOMY.yard_speed(level + 1), ECONOMY.max_size(level), ECONOMY.max_size(level + 1)] if existing else "Adds a shipyard"
		yard_activity_rows[index]["upgrade_detail"].text += "\nEco-Housing: 5,000 residents per completed shipyard · +0.2 t/yr Organics\nSelf-sustaining crew population regenerates to capacity. Upgrading the shipyard does not add another habitat."
		if existing and not operating:
			yard_activity_rows[index]["upgrade_detail"].text += "\nRequires %s population" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[index]))
		_show_cost(yard_activity_rows[index]["upgrade_costs"], ECONOMY._cost("yard_upgrade", level + 1) if existing else job["cost"])
		upgrade.tooltip_text = "Lv %d • %.0f t Metals • %.0f years" % [level, float(ECONOMY._cost("yard_upgrade", level + 1)["Metals"]), ECONOMY._work("yard_upgrade", level + 1)] if existing else _cost_text(job["cost"], job["allocated"])
		if job.is_empty():
			label.text = "Shipyard %d · Lv %d · %s" % [number, level, "Idle" if operating else "Offline"]
			bar.value = 0.0
			bar.show_percentage = false
			bar.tooltip_text = "Shipyard %d" % (int(index) + 1)
			_style_progress(bar, p, {})
			continue
		bar.show_percentage = true
		var name_text: String = "Logistics ship" if job["kind"] == "ship" else str(job["kind"]).replace("_", " ").capitalize()
		if job["kind"] == "yard_upgrade":
			name_text = "Upgrade to Lv %d" % int(job["level"])
		elif job["kind"] == "yard":
			name_text = "Construction"
		label.text = "Shipyard %d · Lv %d · %s" % [number, level, name_text] if existing else "Shipyard %d · %s" % [number, name_text]
		bar.value = 100.0 * float(job["progress"]) / float(job["work"])
		bar.tooltip_text = "Shipyard %d" % number
		_style_progress(bar, p, job)
		if existing and not operating:
			bar.add_theme_stylebox_override("background", HUD.surface(Color("#33251a"), Color("#db9b54"), 0, 3))
			bar.set_meta("blocked", true)
			bar.tooltip_text = "Blocked: requires %s population" % _compact_amount(float(ECONOMY.SHIPYARD_POPULATION[index]))

func _job_name(item: Dictionary) -> String:
	match str(item["kind"]):
		"ship": return "Logistics ship"
		"pds": return "Planetary defense"
		"yard": return "New shipyard"
		"yard_upgrade": return "Shipyard %d → Lv %d" % [int(item["target"]) + 1, int(item["level"])]
		"production": return "%s → Lv %d" % [str(item["target"]), int(item["level"])]
		_: return str(item["kind"]).replace("_", " ").capitalize()

func _cost_text(cost: Dictionary, allocated: Dictionary = {}) -> String:
	var parts: PackedStringArray = []
	for resource in cost:
		if allocated.is_empty():
			parts.append("%.0f t %s" % [float(cost[resource]), resource])
		else:
			parts.append("%.0f / %.0f t %s" % [float(allocated.get(resource, 0.0)), float(cost[resource]), resource])
	return " · ".join(parts)

func _cancel_kind(kind: String, target: String) -> void:
	var p: Dictionary = _planet()
	# Cancel the newest matching order first, preserving earlier work.
	var orders: Array = p.get("queue", [])
	for i in range(orders.size() - 1, -1, -1):
		var job: Dictionary = orders[i]
		if job["kind"] == kind and job["target"] == target:
			_cancel_job(int(job["id"]))
			return

func _refresh_build_cards(p: Dictionary, owned: bool) -> void:
	var counts: Dictionary = {}
	var first_jobs: Dictionary = {}
	for order in p.get("queue", []):
		var kind: String = order["kind"]
		counts[kind] = int(counts.get(kind, 0)) + 1
		if not first_jobs.has(kind):
			first_jobs[kind] = order
	for kind in build_cards:
		var card: Dictionary = build_cards[kind]
		var count: int = int(counts.get(kind, 0))
		_set_timed_action(card["button"], "Build (%d)" % count if count > 0 else "Build", _ship_build_years(p, kind))
		_show_cost(card["costs"], ECONOMY._cost(kind, 1), float(ECONOMY.CREW_COSTS[kind]))
		var finite: int = int(p.get("maintain", {}).get(kind, 0))
		var unlimited: bool = bool(p.get("continuous", {}).get(kind, false))
		var living: int = ECONOMY.origin_count(_state(), selected, kind) if not p.is_empty() else 0
		var count_text: String = "(%d / ∞)" % living if unlimited else ("(%d / %d)" % [living, finite] if finite > 0 else "(%d)" % living)
		var amount: SpinBox = card["maintain_amount"]
		amount.editable = owned
		if not amount.get_line_edit().has_focus():
			amount.set_value_no_signal(finite)
		card["infinity"].visible = unlimited
		amount.visible = not unlimited
		var caption: String = card["title"].trim_prefix("BUILD ").capitalize() + " " + count_text
		_disclosure_title(card, caption)
		var header: Button = card["header"]
		header.tooltip_text = caption + "\nLiving ships originating at this system"
		card["button"].tooltip_text = _cost_text(ECONOMY._cost(kind, 1)) + " · %.0f population" % float(ECONOMY.CREW_COSTS[kind]) + ("\n%d queued" % count if count > 0 else "")
		var requirements: PackedStringArray = []
		if not p.is_empty():
			if ECONOMY.operational_shipyards(p) == 0:
				requirements.append("Requires an operational shipyard")
			if kind == "ship" and not bool(p.get("home", false)):
				requirements.append("Requires home system")
			if float(p["population"]) < float(ECONOMY.CREW_COSTS[kind]) + 1.0:
				requirements.append("Insufficient population")
			if not ECONOMY.affordable(p, ECONOMY._cost(kind, 1)):
				requirements.append("Insufficient local materials")
		card["button"].disabled = not owned or p.is_empty() or not ECONOMY.affordable(p, ECONOMY._cost(kind, 1)) or (kind == "ship" and not bool(p.get("home", false)))
		card["requirements"].text = "\n".join(requirements)
		card["requirements"].visible = not requirements.is_empty()
		var job: Dictionary = first_jobs.get(kind, {})
		var progress: ProgressBar = card["build_progress"]
		progress.visible = not job.is_empty()
		if not job.is_empty():
			progress.value = 100.0 * float(job["progress"]) / float(job["work"])
			progress.tooltip_text = _cost_text(job["cost"], job["allocated"])
			_style_progress(progress, p, job)
		card["cancel"].visible = not job.is_empty()
		card["cancel"].disabled = not owned or count == 0

func _system_name(index: int) -> String:
	var names: Array = _state().get("map", {}).get("names", [])
	return str(names[index]) if index >= 0 and index < names.size() else "Unknown"

func _load_settings() -> void:
	settings.load("user://warbound_settings.cfg")
	ui_percent = clampi(int(settings.get_value("interface", "scale", 90)), 70, 130)
	music_volume = clampf(float(settings.get_value("audio", "music", 100.0)), 0.0, 100.0)
	sfx_volume = clampf(float(settings.get_value("audio", "sfx", 100.0)), 0.0, 100.0)
	music_muted = bool(settings.get_value("audio", "music_muted", false))
	sfx_muted = bool(settings.get_value("audio", "sfx_muted", false))

func _apply_settings() -> void:
	get_window().content_scale_factor = float(ui_percent) / 100.0
	for bus_name in ["Music", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		var volume: float = music_volume if bus_name == "Music" else sfx_volume
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, volume / 100.0)))
		AudioServer.set_bus_mute(index, music_muted if bus_name == "Music" else sfx_muted)
	upgrade_audio.bus = "SFX"

func _save_settings() -> void:
	settings.set_value("interface", "scale", ui_percent)
	settings.set_value("audio", "music", music_volume)
	settings.set_value("audio", "sfx", sfx_volume)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("audio", "sfx_muted", sfx_muted)
	settings.save("user://warbound_settings.cfg")
	_apply_settings()

func _build_settings_menu() -> void:
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	options.custom_minimum_size.x = 340
	match_menu.add_child(options)
	var scale_row := HBoxContainer.new()
	options.add_child(scale_row)
	var title := _label("UI scale", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(title)
	var scale_value := OptionButton.new()
	scale_row.add_child(scale_value)
	for percent in range(70, 131, 10):
		scale_value.add_item("%d%%" % percent, percent)
	scale_value.select((ui_percent - 70) / 10)
	scale_value.item_selected.connect(func(index: int) -> void:
		ui_percent = scale_value.get_item_id(index)
		_save_settings())
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
		var mute := CheckBox.new()
		mute.text = "Mute"
		mute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mute.custom_minimum_size.y = 30
		mute.button_pressed = music_muted if channel == "Music" else sfx_muted
		row.add_child(mute)
		volume.value_changed.connect(_audio_volume_changed.bind(channel))
		mute.toggled.connect(_audio_mute_changed.bind(channel))

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
		var team: int = int(result["team"])
		var mine: int = int(state.get("teams", {}).get(_me(), 0))
		match_result_dialog.title = "Draw" if team == 0 else ("Victory" if mine == team else "Defeat")
		match_result_dialog.dialog_text = "No surviving teams." if team == 0 else "Team %d wins by conquest." % team
		match_result_dialog.ok_button_text = "Review map"
		match_result_dialog.popup_centered.call_deferred(Vector2i(320, 140))
	elif result.is_empty() and state.get("eliminated", []).has(_me()) and not defeated_shown:
		defeated_shown = true
		match_result_dialog.title = "Empire defeated"
		match_result_dialog.dialog_text = "Your empire has no remaining colony or colony ship."
		match_result_dialog.ok_button_text = "Observe match"
		match_result_dialog.popup_centered.call_deferred(Vector2i(320, 140))

func _open_menu() -> void:
	drag_button = 0
	match_menu.popup_centered(Vector2i(420, 190))

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
	var empty_system: bool = neutral and not ECONOMY.has_planets(p)
	colony_picker.visible = neutral and not empty_system
	send_colony_button.visible = neutral
	send_colony_button.text = "CAPTURE WITH FIGHTERS" if empty_system else "SEND COLONY SHIP"
	var choices: Array[int] = []
	var labels: Array[String] = []
	if neutral:
		for ship in state["ships"]:
			if not ECONOMY.colony_path(state, _me(), ship, selected).is_empty():
				choices.append(int(ship["id"]))
				labels.append("Colony ship #%d • %s" % [int(ship["id"]), _system_name(int(ship["at"]))])
	if choices != colony_choices or colony_picker.item_count == 0:
		var previous: int = -1
		if colony_picker.selected >= 0 and colony_picker.selected < colony_choices.size():
			previous = colony_choices[colony_picker.selected]
		colony_choices = choices
		colony_picker.clear()
		for label_text in labels:
			colony_picker.add_item(label_text)
		if choices.is_empty():
			colony_picker.add_item("No available colony ships")
		else:
			colony_picker.select(maxi(0, choices.find(previous)))
	colony_picker.disabled = choices.is_empty()
	send_colony_button.disabled = choices.is_empty()

func _send_colony() -> void:
	var index: int = colony_picker.selected
	if not send_colony_button.disabled and index >= 0 and index < colony_choices.size():
		session.call("request_colonize", colony_choices[index], selected)

func _reset_view() -> void:
	follow_units = false
	zoom = 1.0
	pan = Vector2.ZERO
	map_canvas.queue_redraw()

# The bottom console reserves a fixed viewport, independent of selection.
func _projection_size() -> Vector2:
	# Reserve the console footprint for camera framing, but let stars and
	# planets continue rendering underneath its opaque stepped panels.
	var hud_height: float = console_panel.size.y + 8.0 if is_instance_valid(console_panel) else 0.0
	return Vector2(map_canvas.size.x, maxf(1.0, map_canvas.size.y - hud_height))

func _map_resized() -> void:
	var fit: float = _fit()
	# Preserve the world position at the camera center as UI scale or
	# window dimensions change, rather than retaining an old pixel offset.
	if previous_map_fit > 0.0:
		var next_zoom: float = minf(zoom, _max_zoom())
		pan *= fit * next_zoom / (previous_map_fit * zoom)
		zoom = next_zoom
	previous_map_fit = fit
	map_canvas.queue_redraw()

func _map_size() -> Vector2:
	return _state().get("map", {}).get("size", MAP.SIZE)

func _fit() -> float:
	var area: Vector2 = _projection_size() - Vector2(24, 52)
	var bounds: Vector2 = _map_size()
	return maxf(0.0001, minf(area.x / bounds.x, area.y / bounds.y))

func _screen_point(point: Vector2) -> Vector2:
	return _camera_center() + pan + (point - _map_size() * 0.5) * _fit() * zoom

func _world_point(point: Vector2) -> Vector2:
	return _map_size() * 0.5 + (point - _camera_center() - pan) / (_fit() * zoom)

func _camera_center() -> Vector2:
	return _projection_size() * 0.5

func _max_zoom() -> float:
	# Scale the close-up ceiling to the actual viewport and map fit. At
	# maximum zoom a fighter is 60% of the full viewport width long.
	var base_scale: float = maxf(0.0001, minf(SHIP_WORLD_SCALE * _fit() * OVERVIEW_MAX_ZOOM, 1.25))
	var target_scale: float = size.x * CLOSEUP_SCREEN_FRACTION / FIGHTER_HULL_LENGTH
	return OVERVIEW_MAX_ZOOM * maxf(1.0, target_scale / base_scale)

func _zoom_at(point: Vector2, multiplier: float) -> void:
	var anchor: Vector2 = _camera_center() if follow_units else point
	var world: Vector2 = _world_point(anchor)
	zoom = clampf(zoom * multiplier, MIN_ZOOM, _max_zoom())
	pan += anchor - _screen_point(world)
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
	var system: Dictionary = state["planets"][index]
	var ideal: float = RADIUS * float(system.get("size_factor", 1.0)) * zoom
	var spacing: float = float(_system_visual(index, state)["spacing"]) * _fit() * zoom
	return clampf(minf(ideal, spacing * 0.39), 4.0, 720.0)

func _body_position(body: Dictionary, radius: float, time: float) -> Vector2:
	var angle: float = float(body["phase"]) + time * float(body["speed"]) * 0.22
	var orbit_radius: float = radius * float(body["orbit"])
	return Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius * 0.65)

func _draw_elliptical_orbit(center: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for step in range(65):
		var angle: float = TAU * float(step) / 64.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.65))
	map_canvas.draw_polyline(points, tint, 0.8, true)

# Generate a unique shaded surface once per visible body; no separate highlight dot.
func _body_texture(body: Dictionary) -> Texture2D:
	if body.has("texture"):
		return body["texture"]
	var noise := FastNoiseLite.new()
	noise.seed = int(body["surface_seed"])
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var material: String = body["resource"]
	var base: Color = HUD.COLORS.get(material, Color("#7d8b9b"))
	base = base.lerp(Color("#7b8790"), float(body["muted"]))
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
			var color: Color = base.lerp(Color("#d6e1e9"), maxf(0.0, terrain) * 0.7).darkened(clampf(0.74 - diffuse * 0.64 - terrain * 0.18, 0.0, 0.85))
			color.a = clampf((1.0 - sqrt(rr)) * 47.0, 0.0, 1.0)
			image.set_pixel(x, y, color)
	body["texture"] = ImageTexture.create_from_image(image)
	return body["texture"]

func _draw_system(index: int, state: Dictionary, pos: Vector2, radius: float, tint: Color) -> void:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 32.0).has_point(pos):
		return
	var system: Dictionary = state["planets"][index]
	var color: Color = _planet_color(system)
	var star_radius: float = maxf(3.0, radius * 0.13) if zoom >= 2.0 and radius >= 18.0 else radius * 0.48
	var star_color: Color = Color("#fff0c4").lerp(color.lightened(0.25), 0.30) if ECONOMY.has_planets(system) else Color("#8ea2bc")
	if zoom >= 2.0 and radius >= 18.0 and (index == selected or not system.get("pds", {}).is_empty()):
		var bodies: Array = _system_visual(index, state)["bodies"]
		for slot in range(bodies.size()):
			if index != selected and not system.get("pds", {}).has(slot):
				continue
			var body: Dictionary = bodies[slot]
			var orbit: float = radius * float(body["orbit"])
			if _show_system_rings(index):
				_draw_elliptical_orbit(pos, orbit, Color(tint, 0.20))
			var point: Vector2 = pos + _body_position(body, radius, game_visual_clock)
			var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
			if Rect2(Vector2.ZERO, map_canvas.size).grow(body_radius).has_point(point):
				if body_radius >= 5.0:
					map_canvas.draw_texture_rect(_body_texture(body), Rect2(point - Vector2.ONE * body_radius, Vector2.ONE * body_radius * 2.0), false)
				else:
					map_canvas.draw_circle(point, body_radius, HUD.COLORS.get(body["resource"], Color("#7d8b9b")).darkened(0.18), true)
				if system.get("pds", {}).has(slot):
					_draw_pds_frame(point, body_radius)
				if index == selected and selected_body == slot:
					map_canvas.draw_arc(point, body_radius + 4.0, 0.0, TAU, 24, HUD.ACCENT, 1.5, true)
					map_canvas.draw_string(get_theme_default_font(), point + Vector2(-90.0, -body_radius - 7.0), _body_name(index, slot), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, HUD.TEXT)
	var pulse: float = 0.96 + 0.04 * sin(visual_clock * 1.2 + float(index))
	for layer in range(5, 0, -1):
		map_canvas.draw_circle(pos, star_radius * (1.0 + float(layer) * 0.33) * pulse, Color(star_color, 0.05), true)
	map_canvas.draw_circle(pos, star_radius * pulse, star_color, true)
	map_canvas.draw_circle(pos, star_radius * 0.55 * pulse, Color("#fffdf1"), true)
	if (zoom < 2.0 or radius < 18.0) and not system.get("pds", {}).is_empty():
		map_canvas.draw_arc(pos, star_radius + 3.0, -PI * 0.8, PI * 0.8, 18, Color("#bdcbd6"), 1.5, true)
	if _show_system_rings(index):
		map_canvas.draw_arc(pos, radius + 1.5, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)

# Thin metallic latitude/longitude ribs, clipped to the planet silhouette.
func _draw_pds_frame(center: Vector2, radius: float) -> void:
	var r: float = radius * 1.08
	var steel := Color("#c4d1dc")
	var shadow := Color("#344655")
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

func _body_hit(point: Vector2, state: Dictionary) -> int:
	if selected < 0 or selected >= state["planets"].size() or not ECONOMY.discovered(state, _me(), "planets", selected):
		return -1
	var radius: float = _planet_radius(selected, state)
	if zoom < 2.0 or radius < 18.0:
		return -1
	var center: Vector2 = _screen_point(state["map"]["points"][selected])
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 32.0).has_point(center):
		return -1
	var bodies: Array = _system_visual(selected, state)["bodies"]
	var hit: int = -1
	var nearest: float = INF
	for slot in range(bodies.size()):
		var body: Dictionary = bodies[slot]
		var position: Vector2 = center + _body_position(body, radius, game_visual_clock)
		var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
		var distance: float = point.distance_to(position)
		if distance <= body_radius + 3.0 and distance < nearest:
			hit = slot
			nearest = distance
	return hit

func _yard_hit(point: Vector2, state: Dictionary) -> Vector2i:
	var hit := Vector2i(-1, -1)
	var nearest: float = INF
	var scale: float = _ship_scale()
	if scale < 0.2:
		return hit
	var elapsed: float = float(state["elapsed"])
	for index in range(state["planets"].size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
		var star: Vector2 = _screen_point(state["map"]["points"][index])
		for slot in range(state["planets"][index]["yards"].size()):
			var center: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, slot, elapsed))
			# Do not steal star selection when a dock overlaps its star.
			if center.distance_to(star) < 8.0 or point.distance_to(star) < 5.0:
				continue
			var axis: Vector2 = Vector2.from_angle(float(slot) * TAU / 3.0 + elapsed * 0.008)
			var offset: Vector2 = point - center
			var distance: float = offset.length_squared()
			if absf(offset.dot(axis)) <= 14.0 * scale + 3.0 and absf(offset.dot(axis.orthogonal())) <= 17.0 * scale + 3.0 and distance < nearest:
				nearest = distance
				hit = Vector2i(index, slot)
	return hit

func _select_at(point: Vector2, additive: bool = false) -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	var points: Array = state["map"]["points"]
	var nearest: float = INF
	var hit: int = -1
	for i in range(points.size()):
		if not ECONOMY.discovered(state, _me(), "planets", i):
			continue
		var distance: float = point.distance_to(_screen_point(points[i]))
		if distance <= _planet_radius(i, state) + 4.0 and distance < nearest:
			nearest = distance
			hit = i
	# Use the same interpolated physical pose for selection and rendering.
	var poses: Dictionary = _ship_poses(state)
	var ship_hit: int = -1
	var ship_distance: float = INF
	for id in poses:
		var distance: float = point.distance_to(poses[id]["point"])
		if distance <= maxf(5.0, 14.0 * _ship_scale()) and distance < ship_distance:
			ship_distance = distance
			ship_hit = int(id)
	var next_ship: int = ship_hit if hit < 0 or nearest > 5.0 or ship_distance < nearest else -1
	var body_slot: int = _body_hit(point, state) if not additive else -1
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
			var focus: Control = get_viewport().gui_get_focus_owner()
			if is_instance_valid(focus):
				focus.release_focus()
			_load_thresholds()
			_refresh()
			return
	if body_slot >= 0:
		selected_yard = -1
		selected_body = body_slot
		selected_ship_id = -1
		selected_units.clear()
		selected_field = -1
		var focus: Control = get_viewport().gui_get_focus_owner()
		if is_instance_valid(focus):
			focus.release_focus()
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
			break
	selected_field = -1
	if selected_ship_id < 0 and hit < 0:
		var fields: Array = state["map"].get("fields", [])
		for i in range(fields.size()):
			if not ECONOMY.discovered(state, _me(), "fields", i):
				continue
			var distance: float = point.distance_to(_screen_point(fields[i]["position"]))
			if distance <= maxf(9.0, float(fields[i]["radius"]) * _fit() * zoom):
				selected_field = i
				break
	selected = -1 if selected_ship_id >= 0 or selected_field >= 0 else hit
	follow_units = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focused.release_focus()
	if selected >= 0:
		_load_thresholds()
	_refresh()

func _select_box(rect: Rect2, additive: bool) -> void:
	var state: Dictionary = _state()
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	if not additive:
		selected_units.clear()
	var poses: Dictionary = _ship_poses(state)
	for craft in state.get("ships", []):
		var id: int = int(craft["id"])
		if poses.has(id) and rect.has_point(poses[id]["point"]) and not selected_units.has(id):
			selected_units.append(id)
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	follow_units = false
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	_refresh()

func _command_at(point: Vector2, force_position: bool = false, patrol: bool = false, move_only: bool = false, explicit_attack: bool = false) -> void:
	var state: Dictionary = _state()
	var owned: Array[int] = _selected_owned_units(state)
	if state.is_empty() or owned.is_empty():
		return
	var fighters: Array[int] = []
	for craft in state["ships"]:
		if owned.has(int(craft["id"])) and craft["kind"] == "fighter":
			fighters.append(int(craft["id"]))
	if not force_position and not patrol and not move_only:
		var poses: Dictionary = _ship_poses(state)
		var target: int = -1
		var nearest: float = maxf(5.0, 14.0 * _ship_scale())
		if not fighters.is_empty():
			for craft in state["ships"]:
				var id: int = int(craft["id"])
				if poses.has(id) and ECONOMY._hostile_hull(state, _me(), craft):
					var d: float = point.distance_to(poses[id]["point"])
					if d < nearest:
						target = id
						nearest = d
		if target >= 0:
			session.call("request_tactical_order", fighters, "attack", target)
			return
		if not explicit_attack:
			var wreck: int = _salvage_hit(state, point)
			if wreck >= 0:
				session.call("request_salvage", owned, wreck)
				return
	var node: int = -1
	var distance: float = INF
	var graph: Dictionary = ECONOMY.military_graph(state)
	var world: Vector2 = _world_point(point)
	var candidates: Array[int] = ECONOMY.military_pois(state, _me())
	var handled_fighters: Dictionary = {}
	# Resolve each fighter's actual current sector first. The same exact
	# geometry drives the visible territory, cursor hit and host validation.
	if not patrol and not fighters.is_empty():
		var local_groups: Dictionary = {}
		for craft in state["ships"]:
			var id: int = int(craft["id"])
			if not fighters.has(id) or bool(craft.get("retreating", false)):
				continue
			var current: int = ECONOMY.sector_at(graph, craft["position"], candidates, ECONOMY.local_sector(graph, craft))
			if current < 0 or not ECONOMY.sector_contains(graph, current, world):
				continue
			if not local_groups.has(current):
				local_groups[current] = []
			(local_groups[current] as Array).append(id)
			handled_fighters[id] = true
		for current in local_groups:
			session.call("request_local_position", local_groups[current], int(current), world, move_only)
		var remaining: Array[int] = []
		for id in fighters:
			if not handled_fighters.has(id):
				remaining.append(id)
		fighters = remaining
		if handled_fighters.size() == owned.size():
			return
	# Command sectors use their simulation boundaries, not the nearest POI
	# center. In particular, clicking across a shared boundary must not
	# silently snap to the adjacent sector's center.
	node = ECONOMY.sector_at(graph, world, candidates)
	if node >= 0:
		distance = point.distance_squared_to(_screen_point(graph["points"][node]))
	else:
		# A direct icon click remains valid; empty space must not become
		# a sector-to-sector move merely because a POI is nearest.
		for candidate in candidates:
			var d: float = point.distance_squared_to(_screen_point(graph["points"][candidate]))
			if d < distance:
				node = candidate
				distance = d
	if node < 0:
		return
	var system_count: int = state["planets"].size()
	var hit_radius: float = 9.0
	if node < system_count:
		var radius: float = _planet_radius(node, state)
		hit_radius = maxf(9.0, radius * (0.13 if zoom >= 2.0 and radius >= 18.0 else 0.48))
	else:
		hit_radius = maxf(9.0, float(state["map"]["fields"][node - system_count]["radius"]) * _fit() * zoom)
	if patrol and not force_position:
		if not fighters.is_empty() and (ECONOMY.sector_contains(graph, node, world) or distance <= hit_radius * hit_radius):
			session.call("request_tactical_order", fighters, "patrol", node)
		return
	if force_position or distance > hit_radius * hit_radius:
		if ECONOMY.sector_contains(graph, node, world):
			var local: Array[int] = []
			for craft in state["ships"]:
				if int(craft["owner"]) == _me() and selected_units.has(int(craft["id"])) and not handled_fighters.has(int(craft["id"])) and ECONOMY.sector_contains(graph, node, craft["position"]) and not bool(craft.get("retreating", false)):
					local.append(int(craft["id"]))
			if not local.is_empty():
				session.call("request_local_position", local, node, world, move_only)
				return
		else:
			return
		if force_position:
			return
	var miners: Array[int] = _selected_miners()
	if not miners.is_empty():
		var field_index: int = node - state["planets"].size()
		var rock_id: int = -1
		var rock_distance: float = INF
		var fields: Array = state["map"].get("fields", [])
		for i in range(fields.size()):
			if not ECONOMY.discovered(state, _me(), "fields", i):
				continue
			for rock in fields[i].get("chunks", []):
				var d: float = point.distance_to(_screen_point(rock["position"]))
				if d < rock_distance and d <= maxf(5.0, float(rock.get("radius", 0.0)) * _fit() * zoom):
					rock_distance = d
					field_index = i
					rock_id = int(rock["id"])
		if field_index < 0:
			field_index = -1
		session.call("request_miner_assignment", miners, field_index, rock_id)
	var colony_sent: bool = false
	for craft in state["ships"]:
		var id: int = int(craft["id"])
		if not selected_units.has(id) or int(craft["owner"]) != _me():
			continue
		if craft["kind"] == "colony_ship" and not colony_sent and node < state["planets"].size() and not ECONOMY.colony_path(state, _me(), craft, node).is_empty():
			session.call("request_colonize", id, node)
			colony_sent = true
	if not fighters.is_empty():
		session.call("request_fighter_move", fighters, node, move_only)

func _selected_miners() -> Array[int]:
	var miners: Array[int] = []
	for craft in _state().get("ships", []):
		if int(craft["owner"]) == _me() and craft["kind"] == "miner" and selected_units.has(int(craft["id"])):
			miners.append(int(craft["id"]))
	return miners

func _selected_owned_units(state: Dictionary) -> Array[int]:
	var owned: Array[int] = []
	for craft in state.get("ships", []):
		if int(craft["owner"]) == _me() and selected_units.has(int(craft["id"])):
			owned.append(int(craft["id"]))
	return owned

func _any_selected_holding() -> bool:
	for craft in _state().get("ships", []):
		if int(craft["owner"]) == _me() and selected_units.has(int(craft["id"])) and bool(craft.get("holding", false)):
			return true
	return false

func _hold_selected() -> void:
	pending_command = ""
	var owned: Array[int] = _selected_owned_units(_state())
	if not owned.is_empty():
		session.call("request_unit_hold", owned, _any_selected_holding())
	_refresh_command_mode()

func _unload_selected() -> void:
	pending_command = ""
	var owned: Array[int] = _selected_owned_units(_state())
	if not owned.is_empty():
		session.call("request_unload_cargo", owned)
	_refresh_command_mode()

func _map_input(event: InputEvent) -> void:
	if match_menu.visible:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		match mouse.button_index:
			MOUSE_BUTTON_MIDDLE:
				if mouse.pressed:
					follow_units = false
				drag_button = MOUSE_BUTTON_MIDDLE if mouse.pressed else 0
			MOUSE_BUTTON_RIGHT:
				if mouse.pressed:
					if not pending_command.is_empty():
						pending_command = ""
						_refresh_command_mode()
					else:
						_command_at(mouse.position, mouse.alt_pressed, mouse.shift_pressed)
			MOUSE_BUTTON_LEFT:
				if not pending_command.is_empty():
					if mouse.pressed:
						_execute_pending_command(mouse.position)
					map_canvas.accept_event()
					return
				if mouse.pressed:
					selecting_units = true
					selection_start = mouse.position
					selection_end = mouse.position
				elif selecting_units:
					selecting_units = false
					if selection_start.distance_to(mouse.position) > 5.0:
						_select_box(Rect2(selection_start, mouse.position - selection_start).abs(), mouse.shift_pressed)
					else:
						_select_at(mouse.position, mouse.shift_pressed)
			MOUSE_BUTTON_WHEEL_UP:
				if mouse.pressed:
					_zoom_at(mouse.position, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse.pressed:
					_zoom_at(mouse.position, 1.0 / 1.15)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if selecting_units:
			selection_end = motion.position
		elif drag_button != 0:
			if motion.button_mask == 0:
				drag_button = 0
			else:
				pan += motion.relative
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
	return ("Antimatter deposit %02d" if index < fields.size() and bool(fields[index].get("antimatter", false)) else "Asteroid field %02d") % (index + 1)

func _ship_position(ship: Dictionary, _points: Array) -> Vector2:
	if ship.has("position"):
		return ship["position"]
	return ECONOMY.combat_position(_state(), ECONOMY.military_graph(_state()), ship)

func _visual_position(visual: Dictionary) -> Vector2:
	return (visual["from"] as Vector2).lerp(visual["to"], clampf(float(visual["age"]) / SNAPSHOT_SECONDS, 0.0, 1.0))

# React to accepted orders in authority snapshots, not speculative UI clicks.
# Only local system-production orders play audio; initial state is silent.
func _sync_upgrade_audio(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	var active: Dictionary = {}
	var added: bool = false
	for system in state.get("planets", []):
		if int(system["owner"]) != _me():
			continue
		for job in system["queue"]:
			if job["kind"] != "economy_building":
				continue
			var id: int = int(job["id"])
			active[id] = true
			if not known_upgrade_jobs.has(id):
				added = true
	if upgrade_audio_initialized and added:
		upgrade_audio.play()
	known_upgrade_jobs = active
	upgrade_audio_initialized = true

func _on_economy_changed() -> void:
	var state: Dictionary = _state()
	_sync_upgrade_audio(state)
	_refresh_territory(state)
	_sync_ship_visuals(state)
	_refresh()

func _sync_ship_visuals(state: Dictionary) -> void:
	var updated: Dictionary = {}
	if not state.is_empty():
		var points: Array = state["map"]["points"]
		for ship in state["ships"]:
			var id: int = int(ship["id"])
			var target: Vector2 = _ship_position(ship, points)
			var previous: Dictionary = ship_visuals.get(id, {})
			if previous.is_empty():
				updated[id] = {"from": target, "to": target, "age": SNAPSHOT_SECONDS}
			elif previous["to"] != target:
				updated[id] = {"from": _visual_position(previous), "to": target, "age": 0.0}
			else:
				updated[id] = previous
	ship_visuals = updated
	for id in ship_offsets.keys():
		if not updated.has(id):
			ship_offsets.erase(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not is_instance_valid(match_menu) or match_menu.visible or str(session.get("phase")) != "match":
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or colony_picker.get_popup().visible:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE and not pending_command.is_empty():
		pending_command = ""
		_refresh_command_mode()
	elif key in [KEY_Q, KEY_E]:
		_cycle_owned_system(-1 if key == KEY_Q else 1)
	elif key == KEY_F:
		# Explicit camera follow: selection changes never move the camera.
		if not selected_units.is_empty() or selected_ship_id >= 0:
			follow_units = true
			_follow_selected_units(_ship_poses(_state()))
	elif key == KEY_H:
		_hold_selected()
	elif key == KEY_U:
		_unload_selected()
	elif key >= KEY_1 and key <= KEY_9:
		if event.ctrl_pressed:
			control_groups[key] = selected_units.duplicate()
		else:
			var group: Array = control_groups.get(key, [])
			pending_command = ""
			_refresh_command_mode()
			if not event.shift_pressed:
				selected_units.clear()
			for craft in _state().get("ships", []):
				var id: int = int(craft["id"])
				if id in group and not selected_units.has(id):
					selected_units.append(id)
			selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
			follow_units = false
			selected = -1
			selected_body = -1
			selected_yard = -1
			selected_field = -1
			_refresh()
	else:
		return
	get_viewport().set_input_as_handled()

func _cycle_owned_system(direction: int) -> void:
	pending_command = ""
	_refresh_command_mode()
	var state: Dictionary = _state()
	if state.is_empty():
		return
	var owned: Array[int] = []
	for i in range(state["planets"].size()):
		if int(state["planets"][i]["owner"]) == _me():
			owned.append(i)
	if owned.is_empty():
		return
	var current: int = owned.find(selected)
	selected = owned[(0 if direction > 0 else owned.size() - 1) if current < 0 else posmod(current + direction, owned.size())]
	selected_body = -1
	selected_yard = -1
	selected_ship_id = -1
	selected_units.clear()
	selected_field = -1
	var world: Vector2 = state["map"]["points"][selected]
	var desired_radius: float = minf(_projection_size().x, _projection_size().y) * 0.27
	var radius_per_zoom: float = minf(RADIUS * float(state["planets"][selected].get("size_factor", 1.0)), float(_system_visual(selected, state)["spacing"]) * _fit() * 0.39)
	zoom = clampf(desired_radius / maxf(0.001, radius_per_zoom), MIN_ZOOM, OVERVIEW_MAX_ZOOM)
	var center: Vector2 = _camera_center()
	pan += center - _screen_point(world)
	_load_thresholds()
	_refresh()

func _keyboard_pan(delta: float) -> void:
	if str(session.get("phase")) != "match" or match_menu.visible:
		return
	if not get_window().has_focus():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	for picker in [colony_picker]:
		if picker.get_popup().visible:
			return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	_pan_camera(direction, delta)

func _pan_camera(direction: Vector2, delta: float) -> void:
	if not direction.is_zero_approx():
		follow_units = false
		pan -= direction.normalized() * KEYBOARD_PAN_SPEED * delta
		map_canvas.queue_redraw()

func _process(delta: float) -> void:
	if selecting_units and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		selecting_units = false
		map_canvas.queue_redraw()
	_keyboard_pan(delta)
	territory_cycle_elapsed += delta
	if territory_cycle_elapsed >= 0.85:
		territory_cycle_elapsed = fmod(territory_cycle_elapsed, 1020.0)
		_refresh_territory(_state())
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
	game_visual_clock += delta * float(_state().get("time_speed", 1))
	for visual in ship_visuals.values():
		if float(visual["age"]) < SNAPSHOT_SECONDS:
			visual["age"] = minf(SNAPSHOT_SECONDS, float(visual["age"]) + delta)
	var state: Dictionary = _state()
	if not state.is_empty():
		var poses: Dictionary = _ship_poses(state, delta)
		_follow_selected_units(poses)
		_sync_destruction_effects(state)
	else:
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
			# The unchanged logistics ship has dark cargo wells and resource-colored bays.
			for index in range(8):
				sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), Color("#182333"), rng))
			for resource in event.get("materials", []):
				for index in range(3):
					sparks.append(_destruction_spark(Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-5.0, 5.0)), HUD.COLORS.get(resource, hull), rng))
		for index in range(5):
			sparks.append(_destruction_spark(Vector2.ZERO, hull, rng))
		ship_destructions.append({"position": event["position"], "angle": angle, "started": visual_clock, "fragments": fragments, "sparks": sparks})
		if ship_destructions.size() > MAX_VISIBLE_DESTRUCTIONS:
			ship_destructions.pop_front()

func _destruction_spark(offset: Vector2, color: Color, rng: RandomNumberGenerator) -> Dictionary:
	var direction: Vector2 = Vector2.from_angle(rng.randf_range(0.0, TAU))
	return {"offset": offset, "velocity": direction * rng.randf_range(18.0, 42.0), "size": rng.randf_range(0.65, 1.65), "color": color}

func _draw_ship_destructions(viewport_bounds: Rect2) -> void:
	var scale: float = maxf(0.2, _ship_scale())
	for effect in ship_destructions:
		var point: Vector2 = _screen_point(effect["position"])
		if not viewport_bounds.grow(maxf(80.0, 44.0 * scale)).has_point(point):
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
			map_canvas.draw_circle(position, maxf(0.65, float(particle["size"]) * scale * (0.55 + fade * 0.45)), Color(particle["color"], fade))
		# Each original outline segment detaches, drifts and tumbles.
		for fragment in effect["fragments"]:
			var offset: Vector2 = fragment["offset"] + fragment["velocity"] * travel
			var half: Vector2 = (fragment["half"] as Vector2).rotated(float(fragment["spin"]) * age)
			var center: Vector2 = point + forward * offset.x + lateral * offset.y
			var edge: Vector2 = forward * half.x + lateral * half.y
			map_canvas.draw_line(center - edge, center + edge, Color(fragment["hull"], fade), maxf(1.0, 2.0 * scale), true)
			map_canvas.draw_line(center - edge, center + edge, Color(fragment["color"], fade), maxf(0.6, scale), true)

# Same source-player hue for every beam. The wider translucent halo
# and brighter core retain readability without changing the allegiance.
func _draw_owned_laser(origin: Vector2, target: Vector2, owner: int, width: float) -> void:
	var tint: Color = _empire_color(owner)
	map_canvas.draw_line(origin, target, Color(tint, 0.28), width * 3.0, true)
	map_canvas.draw_line(origin, target, tint.lightened(0.28), width, true)

func _fighter_beam_origin(pose: Dictionary) -> Vector2:
	return (pose["point"] as Vector2) + (pose["direction"] as Vector2) * FIGHTER_MUZZLE * _ship_scale()

func _hull_polygon(origin: Vector2, forward: Vector2, lateral: Vector2, vertices: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for vertex in vertices:
		polygon.append(origin + forward * vertex.x + lateral * vertex.y)
	return polygon

func _ship_scale() -> float:
	# Preserve the previous overview dimensions. Beyond the old ceiling,
	# scale the actual authored hull geometry continuously with the camera.
	return minf(SHIP_WORLD_SCALE * _fit() * minf(zoom, OVERVIEW_MAX_ZOOM), 1.25) * maxf(1.0, zoom / OVERVIEW_MAX_ZOOM)

func _follow_selected_units(poses: Dictionary) -> void:
	if not follow_units or selecting_units or drag_button != 0 or str(session.get("phase")) != "match":
		return
	var center: Vector2 = Vector2.ZERO
	var count: int = 0
	# Use exactly the interpolated positions that the renderer shows,
	# so the tracked hull stays stationary even between network snapshots.
	if not selected_units.is_empty():
		for id in selected_units:
			if poses.has(id):
				center += poses[id]["point"]
				count += 1
	elif poses.has(selected_ship_id):
		center = poses[selected_ship_id]["point"]
		count = 1
	if count == 0:
		follow_units = false
		return
	pan += _camera_center() - center / float(count)

func _ship_poses(state: Dictionary, delta: float = 0.0) -> Dictionary:
	_sync_ship_visuals(state)
	var points: Array = state["map"]["points"]
	var poses: Dictionary = {}
	for ship in state["ships"]:
		var id: int = int(ship["id"])
		var visual: Dictionary = ship_visuals.get(id, {})
		var pos: Vector2 = _ship_position(ship, points) if visual.is_empty() else _visual_position(visual)
		var direction: Vector2 = ship.get("heading", Vector2.UP)
		var prior: Dictionary = ship_offsets.get(id, {"angle": direction.angle()})
		var weight: float = 1.0 - exp(-delta / SNAPSHOT_SECONDS * 3.0)
		var angle: float = lerp_angle(float(prior["angle"]), direction.angle(), weight)
		if delta > 0.0 or not ship_offsets.has(id):
			ship_offsets[id] = {"angle": angle}
		var mining: bool = ship.get("kind", "") == "miner" and ship.get("mining_mode", "idle") in ["outbound", "mining", "return"]
		poses[id] = {"point": _screen_point(pos), "direction": Vector2.from_angle(angle), "mining": mining}
	return poses

func _draw_logistics_lens(state: Dictionary, font: Font) -> void:
	if active_lens != "logistics":
		return
	var points: Array = state["map"]["points"]
	for i in range(points.size()):
		var system: Dictionary = state["planets"][i]
		if int(system["owner"]) == 0 or not ECONOMY.discovered(state, _me(), "planets", i):
			continue
		var pos: Vector2 = _screen_point(points[i])
		var radius: float = _planet_radius(i, state)
		if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 80.0).has_point(pos):
			continue
		var spacing: float = float(_system_visual(i, state)["spacing"]) * _fit() * zoom
		var scale: float = clampf(spacing / 150.0, 0.22, 1.0)
		var origin: Vector2 = pos + Vector2(-69.0 * scale, radius + 5.0 * scale)
		map_canvas.draw_rect(Rect2(origin - Vector2.ONE * 3.0 * scale, Vector2(144, 38) * scale), Color("#0c1928ec"))
		for r in range(ECONOMY.RESOURCES.size()):
			var resource: String = ECONOMY.RESOURCES[r]
			var cell: Vector2 = origin + Vector2(float(r % 3) * 47.0, floorf(float(r) / 3.0) * 18.0) * scale
			var fraction: float = clampf(float(system["stock"][resource]) / ECONOMY.storage_capacity(system), 0.0, 1.0)
			map_canvas.draw_rect(Rect2(cell, Vector2(44, 14) * scale), Color("#263b50"))
			map_canvas.draw_rect(Rect2(cell, Vector2(44.0 * fraction, 14) * scale), HUD.COLORS[resource].darkened(0.4))
			map_canvas.draw_texture_rect(HUD.ICONS[resource], Rect2(cell, Vector2(13, 13) * scale), false)
			if scale >= 0.8:
				map_canvas.draw_string(font, cell + Vector2(15, 11) * scale, _tons(float(system["stock"][resource]), 0, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
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
		if not ECONOMY.discovered(state, _me(), "planets", node):
			continue
		var center: Vector2 = _screen_point(points[node])
		var radius: float = _planet_radius(node, state)
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
				map_canvas.draw_texture_rect(HUD.ICONS[resource], Rect2(base + radial * 14.0 - Vector2(5, 5), Vector2(10, 10)), false)
				for j in range(count):
					var tip: Vector2 = base + axis * float(j * 5)
					map_canvas.draw_polyline(PackedVector2Array([tip - axis * 4.0 + normal * 3.0, tip, tip - axis * 4.0 - normal * 3.0]), HUD.COLORS[resource], 1.5, true)

func _draw_shipyards(state: Dictionary, index: int, tint: Color, elapsed: float) -> void:
	var planet: Dictionary = state["planets"][index]
	var scale: float = _ship_scale()
	for slot in range(planet["yards"].size()):
		var yard: Dictionary = planet["yards"][slot]
		var angle: float = float(slot) * TAU / 3.0 + elapsed * 0.008
		var axis: Vector2 = Vector2.from_angle(angle)
		var side: Vector2 = axis.orthogonal()
		var point: Vector2 = _screen_point(ECONOMY.shipyard_position(state, index, slot, elapsed))
		if scale < 0.15:
			map_canvas.draw_rect(Rect2(point - Vector2.ONE, Vector2(2.0, 2.0)), tint.lightened(0.25))
			if selected == index and selected_yard == slot:
				map_canvas.draw_arc(point, 9.0, 0.0, TAU, 32, HUD.ACCENT, 1.5, true)
			continue
		var conversion: float = clampf((elapsed - float(yard.get("converted_at", -100.0))) / 3.0, 0.0, 1.0)
		var frame: PackedVector2Array = PackedVector2Array([point - axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale - side * 17.0 * scale, point + axis * 11.0 * scale + side * 17.0 * scale, point - axis * 11.0 * scale + side * 17.0 * scale])
		if conversion < 1.0:
			var heading: Vector2 = yard.get("colony_heading", Vector2.UP)
			var cross: Vector2 = heading.orthogonal()
			var original := PackedVector2Array([point + heading * 12.0 * scale, point + cross * 7.0 * scale, point - heading * 9.0 * scale, point - cross * 7.0 * scale])
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
		if selected == index and selected_yard == slot:
			map_canvas.draw_arc(point, maxf(9.0, 23.0 * scale), 0.0, TAU, 32, HUD.ACCENT, 1.5, true)
		var health: float = float(yard.get("hp", ECONOMY.SHIP_HP * 10.0 * int(yard["level"]))) / (ECONOMY.SHIP_HP * 10.0 * int(yard["level"]))
		if health < 0.999:
			map_canvas.draw_rect(Rect2(point + Vector2(-12, -22) * scale, Vector2(24, 3) * scale), Color("#283748"))
			map_canvas.draw_rect(Rect2(point + Vector2(-12, -22) * scale, Vector2(24 * health, 3) * scale), tint)
		for job in planet["queue"]:
			if int(job["id"]) != int(yard["job"]) or not ECONOMY.SHIP_KINDS.has(job["kind"]):
				continue
			var u: float = clampf(float(job["progress"]) / float(job["work"]), 0.0, 1.0)
			var shape: Array = HULL_OUTLINES.get(str(job["kind"]), FREIGHTER_OUTLINE)
			var hull := PackedVector2Array()
			for vertex in shape:
				hull.append(point + side * vertex.x * scale + axis * vertex.y * scale)
			var edges: int = mini(hull.size(), floori(u * 2.0 * hull.size()))
			for k in range(edges):
				map_canvas.draw_line(hull[k], hull[(k + 1) % hull.size()], tint.lightened(0.4), 1.5 * scale, true)
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
		if not viewport_bounds.grow(radius + 24.0).has_point(point):
			continue
		var tint: Color = HUD.COLORS[pile["resource"]]
		var rotation: float = float(pile["id"]) * 2.4 + game_visual_clock * 0.08
		var axis: Vector2 = Vector2.from_angle(rotation) * radius
		var side: Vector2 = axis.orthogonal() * 0.68
		var shape := PackedVector2Array([point + axis, point + side, point - axis, point - side])
		map_canvas.draw_colored_polygon(shape, tint.darkened(0.25))
		shape.append(shape[0])
		map_canvas.draw_polyline(shape, tint.lightened(0.3), 1.0, true)
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
			elif selected_units.has(claimant):
				map_canvas.draw_line(poses[claimant]["point"], point, Color(color, 0.45), 1.0, true)
		if int(pile["id"]) == hovered:
			var remaining: float = maxf(0.0, float(pile.get("expires_at", float(pile["born"]) + ECONOMY.SALVAGE_MAX_LIFETIME)) - float(state["elapsed"]))
			map_canvas.draw_string(font, point + Vector2(9, -9), "%s · %.1f t · %ds%s" % [pile["resource"], float(pile["amount"]), ceili(remaining), " · Claimed" if claimant >= 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.35))

# All bays represent equal tonnage, with partial, resource-colored fills.
# Smaller combat holds get fewer bays, larger mining holds get more.
func _draw_other_cargo(ship: Dictionary, point: Vector2, forward: Vector2, lateral: Vector2) -> void:
	var kind: String = str(ship["kind"])
	var capacity: float = ECONOMY.cargo_capacity(kind)
	var count: int = ceili(capacity / ECONOMY.FREIGHTER_BAY_CAPACITY)
	var bays: Array = ECONOMY.cargo_bays(ship.get("cargo", {}), capacity, count)
	var per_bay: float = capacity / float(count)
	for k in range(count):
		var center: Vector2
		var half_length: float = 1.05
		var half_width: float = 1.35
		if kind == "miner":
			center = Vector2(5.7 - float(k % 7) * 1.9, -4.8 if k < 7 else 4.8)
			half_length = 0.85
		elif kind == "colony_ship":
			center = Vector2(4.0 - float(k) * 2.65, 0.0)
			half_length = 1.15
		else:
			center = [Vector2(-4.4, 4.7), Vector2(-4.4, -4.7), Vector2(-7.0, 0.0)][k]
		var module: Vector2 = point + forward * center.x + lateral * center.y
		var corners := PackedVector2Array([module + forward * half_length + lateral * half_width, module - forward * half_length + lateral * half_width, module - forward * half_length - lateral * half_width, module + forward * half_length - lateral * half_width])
		map_canvas.draw_colored_polygon(corners, Color("#182333"))
		var start: float = -half_length
		for segment in bays[k]:
			var end: float = minf(half_length, start + 2.0 * half_length * float(segment["amount"]) / per_bay)
			# Fractional tonnes can project to a degenerate polygon.
			if (end - start) * forward.length() >= 0.1:
				var fill := PackedVector2Array([module + forward * end + lateral * half_width, module + forward * start + lateral * half_width, module + forward * start - lateral * half_width, module + forward * end - lateral * half_width])
				map_canvas.draw_colored_polygon(fill, HUD.COLORS[segment["resource"]])
			start = end

func _draw_map() -> void:
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
	for edge in state["map"]["edges"]:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		var known: bool = ECONOMY.discovered(state, _me(), "planets", a) and ECONOMY.discovered(state, _me(), "planets", b)
		var owner_a: int = int(state["planets"][a]["owner"])
		var owner_b: int = int(state["planets"][b]["owner"])
		var color: Color = _empire_color(owner_a).darkened(0.3) if known and owner_a > 0 and owner_a == owner_b else Color("#40566b")
		var a_pos: Vector2 = _screen_point(points[a])
		var b_pos: Vector2 = _screen_point(points[b])
		map_canvas.draw_line(a_pos, b_pos, Color(color, 0.30), 1.0, true)
	# Draw the actual system-to-field routes used by military navigation.
	# A depleted field retains its stable POI and access edges.
	var graph: Dictionary = ECONOMY.military_graph(state)
	for edge in graph["edges"]:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		if b < points.size():
			continue
		var known: bool = ECONOMY.discovered(state, _me(), "planets", a) and ECONOMY.discovered(state, _me(), "fields", b - points.size())
		map_canvas.draw_line(_screen_point(graph["points"][a]), _screen_point(graph["points"][b]), Color(Color("#40566b"), 0.30 if known else 0.15), 1.0, true)
	var font: Font = ThemeDB.fallback_font
	var fields: Array = state["map"].get("fields", [])
	for field_index in range(fields.size()):
		var field: Dictionary = fields[field_index]
		var center: Vector2 = _screen_point(field["position"])
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
				map_canvas.draw_string(font, center + Vector2(-60, float(field["radius"]) * render_scale + 14.0), "Antimatter", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, edge_tint)
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
				asteroid_shape_cache[shape_key] = unit_shape
			var rock := PackedVector2Array()
			for vertex in asteroid_shape_cache[shape_key]:
				rock.append(rock_pos + vertex * rock_radius)
			var tint: Color = HUD.COLORS[chunk["resource"]]
			map_canvas.draw_colored_polygon(rock, tint.darkened(0.25))
			rock.append(rock[0])
			map_canvas.draw_polyline(rock, tint, 0.8, true)
	for i in range(points.size()):
		var pos: Vector2 = _screen_point(points[i])
		if not ECONOMY.discovered(state, _me(), "planets", i):
			map_canvas.draw_string(font, pos + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
			continue
		var radius: float = _planet_radius(i, state)
		var tint: Color = _empire_color(int(state["planets"][i]["owner"]))
		_draw_system(i, state, pos, radius, tint)
		_draw_shipyards(state, i, tint, float(state["elapsed"]))
		var capture: Dictionary = state["planets"][i].get("capture", {})
		if not capture.is_empty():
			var progress: float = clampf(float(capture["held"]) / ECONOMY.CAPTURE_YEARS, 0.0, 1.0)
			var captor: Color = _empire_color(int(capture["player"]))
			map_canvas.draw_arc(pos, radius + 12.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, captor, 3.0, true)
			map_canvas.draw_string(font, pos + Vector2(-60, radius + 26.0), "Capture %d%%" % roundi(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, captor)
		if i == selected and bool(state["planets"][i]["home"]):
			map_canvas.draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(tint, 0.5), 1.0, true)
		if i == selected:
			var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
			for angle in range(4):
				var start: float = float(angle) * TAU / 4.0 + 0.1
				map_canvas.draw_arc(pos, radius + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
		var name_star_radius: float = maxf(3.0, radius * 0.13) if zoom >= 2.0 and radius >= 18.0 else radius * 0.48
		map_canvas.draw_string(font, pos + Vector2(-80, -name_star_radius - 7), _system_name(i), HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("#f4faff") if i == selected else Color(0.83, 0.89, 0.95, 0.65))
	_draw_logistics_lens(state, font)
	var poses: Dictionary = _ship_poses(state)
	_draw_salvage(state, poses, viewport_bounds, font)
	var order_points: Array = ECONOMY.military_graph(state)["points"]
	for craft in state["ships"]:
		var id: int = int(craft["id"])
		if not selected_units.has(id) or not poses.has(id):
			continue
		var start: Vector2 = poses[id]["point"]
		var attack_target: int = int(craft.get("attack_order", -1))
		if poses.has(attack_target):
			var marker: Vector2 = poses[attack_target]["point"]
			map_canvas.draw_line(start, marker, Color("#ff816b80"), 1.5, true)
			map_canvas.draw_arc(marker, maxf(9.0, 15.0 * _ship_scale()), 0.0, TAU, 24, Color("#ff816b"), 1.5, true)
		if craft.has("patrol_from"):
			for endpoint in [craft["patrol_from"], craft["patrol_to"]]:
				map_canvas.draw_arc(_screen_point(order_points[int(endpoint)]), 10.0, 0.0, TAU, 24, Color(HUD.ACCENT, 0.7), 1.5, true)
		if bool(craft.get("holding", false)) and not bool(craft.get("retreating", false)):
			if craft.has("hold_position"):
				var target: Vector2 = _screen_point(craft["hold_position"])
				map_canvas.draw_line(start, target, Color(HUD.ACCENT, 0.5), 1.5, true)
				map_canvas.draw_arc(target, 7.0, 0.0, TAU, 24, HUD.ACCENT, 1.5, true)
			continue
		for node in craft["route"]:
			var finish: Vector2 = _screen_point(order_points[int(node)])
			map_canvas.draw_line(start, finish, Color(HUD.ACCENT, 0.5), 1.5, true)
			start = finish
		if craft["kind"] == "miner":
			var assigned: int = int(craft.get("assigned_field", -1))
			if assigned >= 0:
				var field: Dictionary = state["map"]["fields"][assigned]
				var target: Vector2 = field["position"]
				for rock in field.get("chunks", []):
					if int(rock["id"]) == int(craft.get("assigned_chunk", -1)):
						target = rock["position"]
						break
				var marker: Vector2 = _screen_point(target)
				map_canvas.draw_arc(marker, 9.0, 0.0, TAU, 24, HUD.ACCENT, 1.5, true)
			if craft.get("mining_mode", "") in ["approach", "outbound", "mining"] and craft.has("mining_target"):
				map_canvas.draw_line(start, _screen_point(craft["mining_target"]), Color(HUD.ACCENT, 0.5), 1.5, true)
		if not (craft["route"] as Array).is_empty():
			map_canvas.draw_arc(start, 7.0, 0.0, TAU, 20, HUD.ACCENT, 1.5, true)
	for index in range(points.size()):
		if not ECONOMY.discovered(state, _me(), "planets", index):
			continue
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
			if zoom >= 2.0 and radius >= 18.0:
				origin += _body_position(_system_visual(index, state)["bodies"][slot], radius, game_visual_clock)
			_draw_owned_laser(origin, poses[target]["point"], int(state["planets"][index]["owner"]), 2.0)
	for ship in state["ships"]:
		var shooter: int = int(ship["id"])
		var target: int = int(ship.get("combat_target", -1))
		var yard_target: int = int(ship.get("yard_target", -1))
		if poses.has(shooter) and yard_target < -1 and float(ship.get("yard_laser_until", -1.0)) >= float(state["elapsed"]):
			var encoded: int = -2 - yard_target
			var count: int = (state["planets"] as Array).size()
			if encoded < count * 3:
				var index: int = floori(float(encoded) / 3.0)
				var slot: int = posmod(encoded, 3)
				if slot < state["planets"][index]["yards"].size():
					_draw_owned_laser(_fighter_beam_origin(poses[shooter]), _screen_point(ECONOMY.shipyard_position(state, index, slot, float(state["elapsed"]))), int(ship["owner"]), 1.5)
			else:
				var pds_index: int = posmod(encoded - count * 3, count)
				var pds_slot: int = floori(float(encoded - count * 3) / float(count))
				if state["planets"][pds_index].get("pds", {}).has(pds_slot):
					var endpoint: Vector2 = _screen_point(points[pds_index])
					var pds_radius: float = _planet_radius(pds_index, state)
					if zoom >= 2.0 and pds_radius >= 18.0:
						endpoint += _body_position(_system_visual(pds_index, state)["bodies"][pds_slot], pds_radius, game_visual_clock)
					_draw_owned_laser(_fighter_beam_origin(poses[shooter]), endpoint, int(ship["owner"]), 1.5)
		if poses.has(shooter) and poses.has(target) and float(ship.get("laser_until", 0.0)) >= float(state["elapsed"]):
			_draw_owned_laser(_fighter_beam_origin(poses[shooter]), poses[target]["point"], int(ship["owner"]), 1.0)
	for ship in state["ships"]:
		if not poses.has(int(ship["id"])):
			continue
		var pose: Dictionary = poses[int(ship["id"])]
		var point: Vector2 = pose["point"]
		var direction: Vector2 = pose["direction"]
		var mining: bool = pose["mining"]
		if ship.get("mining_mode", "") == "mining" and ship.has("mining_rock"):
			var aim: Vector2 = _screen_point(ship["mining_rock"]) - point
			if not aim.is_zero_approx():
				direction = aim.normalized()
		var route: Array = ship["route"]
		var empire: Color = _empire_color(int(ship["owner"]))
		var hull: Color = empire.lightened(0.35)
		var scale: float = _ship_scale()
		var side: Vector2 = direction.orthogonal() * scale
		direction *= scale
		var shape := PackedVector2Array([point + direction * 9, point - direction * 6 + side * 5,
			point - direction * 3, point - direction * 6 - side * 5])
		if ship["kind"] == "ship":
			shape = _hull_polygon(point, direction, side, FREIGHTER_OUTLINE)
		elif HULL_OUTLINES.has(ship["kind"]):
			shape = _hull_polygon(point, direction, side, HULL_OUTLINES[ship["kind"]])
		var physical: Vector2 = ship.get("position", Vector2.ZERO)
		var target: Vector2 = ship.get("navigation_target", physical)
		if int(state.get("time_speed", 1)) > 0 and scale >= 0.65 and (not ECONOMY._engaged(ship)) and physical.distance_to(target) > ECONOMY.EPS:
			var engine: Vector2 = point - direction * 9.0
			if viewport_bounds.grow(maxf(24.0, 16.0 * scale)).has_point(engine):
				var particle_count: int = 5 if scale >= 1.0 else 2
				for k in range(particle_count):
					var age: float = fposmod(visual_clock * 3.5 + float(k) / float(particle_count) + float(ship["id"]) * 0.173, 1.0)
					var offset: float = sin(float(k) * 2.4 + float(ship["id"])) * age * 2.5
					var spark: Vector2 = engine - direction * (2.0 + age * 12.0) + side * offset
					map_canvas.draw_circle(spark, maxf(0.75, (2.0 - age) * scale), Color(0.45, 0.85, 1.0, (1.0 - age) * 0.85), false)
		if ship.get("mining_mode", "") == "mining" and not ECONOMY._salvage_active(ship) and not bool(ship.get("holding", false)) and ship.has("mining_rock") and viewport_bounds.grow(maxf(32.0, 14.0 * scale)).has_point(point) and scale >= 0.65:
			var rock: Vector2 = _screen_point(ship["mining_rock"])
			for sign in [-1.0, 1.0]:
				var emitter: Vector2 = point + direction * MINER_MUZZLE.x + side * sign * MINER_MUZZLE.y
				var impact: Vector2 = rock + side * sign * 2.0
				_draw_owned_laser(emitter, impact, int(ship["owner"]), maxf(0.8, scale))
				for k in range(3 if scale >= 1.0 else 1):
					var age: float = fposmod(visual_clock * 4.0 + float(k) * 0.33 + sign * 0.12, 1.0)
					var spark: Vector2 = impact - direction * age * 6.0 + side * sign * age * float(k + 1) * 2.0
					map_canvas.draw_circle(spark, maxf(0.7, scale * (1.0 - age)), Color(1.0, 0.85, 0.45, 1.0 - age), false)
		if not viewport_bounds.grow(maxf(24.0, 18.0 * scale)).has_point(point):
			continue
		if int(ship["id"]) == selected_ship_id or selected_units.has(int(ship["id"])):
			map_canvas.draw_arc(point, maxf(5.0, 15.0 * scale), 0.0, TAU, 32, HUD.ACCENT, 2.0, true)
		# At a distant galaxy overview, the smallest authored edges can
		# collapse into an invalid polygon after projection. Keep the hull
		# visible and owner-colored rather than drawing degenerate geometry.
		if scale < 0.15 or (scale < 0.42 and Geometry2D.triangulate_polygon(shape).is_empty()):
			map_canvas.draw_circle(point, maxf(0.8, 6.0 * scale), hull, true, -1.0, true)
			continue
		map_canvas.draw_colored_polygon(shape, hull)
		if ship["kind"] == "ship" and scale >= 0.42:
			var bays: Array = ECONOMY.freighter_cargo_bays(ship["cargo"])
			for k in range(bays.size()):
				var row: int = floori(float(k - 1) / 2.0)
				var module: Vector2 = point + direction * 11.5 if k == 0 else point + direction * (5.0 - float(row) * 7.0) + side * (-3.5 if k % 2 == 1 else 3.5)
				# The nose bay is slightly shorter to fit within the hull.
				var half_length: float = 2.5 if k == 0 else 3.0
				var corners := PackedVector2Array([module + direction * half_length + side * 3, module - direction * half_length + side * 3, module - direction * half_length - side * 3, module + direction * half_length - side * 3])
				map_canvas.draw_colored_polygon(corners, Color("#182333"))
				var start: float = -half_length
				for segment in bays[k]:
					var end: float = minf(half_length, start + 2.0 * half_length * float(segment["amount"]) / ECONOMY.FREIGHTER_BAY_CAPACITY)
					if (end - start) * scale >= 0.1:
						var filled := PackedVector2Array([module + direction * end + side * 3, module + direction * start + side * 3, module + direction * start - side * 3, module + direction * end - side * 3])
						map_canvas.draw_colored_polygon(filled, HUD.COLORS[segment["resource"]])
					start = end
		elif scale >= 0.42 and HULL_PANELS.has(ship["kind"]) and viewport_bounds.grow(maxf(24.0, 14.0 * scale)).has_point(point):
			# At distant zoom levels the silhouette and allegiance outline are
			# enough. Draw layered panels only when they can actually be seen.
			for panel in HULL_PANELS[ship["kind"]]:
				map_canvas.draw_colored_polygon(_hull_polygon(point, direction, side, panel[1]), _hull_panel_color(empire, panel[0]))
			_draw_other_cargo(ship, point, direction, side)
		var outline: PackedVector2Array = shape.duplicate()
		outline.append(shape[0])
		map_canvas.draw_polyline(outline, Color("#08111b"), 2.5 * scale, true)
		# Identify allegiance on every hull, including loaded ships.
		map_canvas.draw_polyline(outline, empire.lightened(0.2), scale, true)
		var hp: float = clampf(float(ship.get("hp", ECONOMY.SHIP_HP)) / ECONOMY.SHIP_HP, 0.0, 1.0)
		if hp < 1.0 and scale >= 0.65:
			var width: float = clampf(20.0 * scale, 20.0, 100.0)
			var bar_pos: Vector2 = point + Vector2(-width * 0.5, maxf(13.0, 15.0 * scale))
			map_canvas.draw_rect(Rect2(bar_pos, Vector2(width, 3.0)), Color("#182333"))
			map_canvas.draw_rect(Rect2(bar_pos, Vector2(width * hp, 3.0)), Color("#e9a276"))
	_draw_ship_destructions(viewport_bounds)
	if selecting_units and selection_start.distance_to(selection_end) > 5.0:
		var rect: Rect2 = Rect2(selection_start, selection_end - selection_start).abs()
		map_canvas.draw_rect(rect, Color(HUD.ACCENT, 0.12))
		map_canvas.draw_rect(rect, HUD.ACCENT, false, 1.0)
