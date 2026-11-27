extends Control
## Planet map and inspector. Host/solo session owns all simulation mutations.
const MAP = preload("res://scripts/planet_map.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")
const CostButton = preload("res://scripts/cost_button.gd")
const TradeRange = preload("res://scripts/trade_range.gd")
const QUEUE_VIEW = preload("res://scripts/construction_queue_view.gd")
const COMMAND_CARD_UI = preload("res://scripts/command_card_ui.gd")
const COMMAND_HOTKEYS = preload("res://scripts/command_hotkeys.gd")
const MATCH_SETTINGS = preload("res://scripts/match_settings.gd")
const MATCH_NOTICE_UI = preload("res://scripts/match_notice_ui.gd")
const HULL_ART = preload("res://scripts/hull_art.gd")
const FOG_OF_WAR = preload("res://scripts/fog_of_war.gd")
const TERRITORY_VIEW = preload("res://scripts/territory_view.gd")
const CAMERA_VIEW = preload("res://scripts/camera_view.gd")
const UI_COMMAND_DETAILS = {
	"move": "Move directly to any point inside the map.",
	"stop": "Cancel orders and stop.",
	"hold": "Hold position; weapons remain active.",
	"patrol": "Patrol a route. Shift adds waypoints.",
	"attack": "Attack or attack-move. Neutral targets require war confirmation.",
	"load": "Collect floating salvage.",
	"unload": "Deliver cargo or drop in space.",
	"repair": "Repair a friendly ship or structure.",
	"deliver_farm": "Unload harvested Organics early at a nearby station.",
	"guard": "Choose a sector position to defend.",
	"transform": "Establish a station in an eligible neutral system.",
	"auto_wander": "Roam locally when idle.",
	"auto_explore": "Explore connected sectors away from allies when idle.",
	"auto_mine": "Automatically mine enabled asteroid resources and deliver cargo.",
	"auto_salvage": "Collect nearby floating resources when safe and cargo space is available.",
	"auto_repair": "Automatically repair nearby eligible damaged friendly units and structures.",
	"auto_trade": "Move surplus cargo between stations and collect from mining or salvage sites.",
	"auto_farm": "Produce Organics aboard the Colony and deliver full holds when idle.",
	"auto_retreat": "Withdraw damaged armed ships to safety and resume orders after repair.",
	"collect": "Select a Pulsar to collect antimatter; right-click toggles automatic collection."
}
const CODEX = preload("res://scripts/codex.gd")
const BACKDROP = preload("res://scripts/space_background.gd")
const PLANET = preload("res://assets/ui/planet.svg")
const SFX = preload("res://scripts/match_sfx.gd")
const MATCH_AUDIO_TRACKER = preload("res://scripts/match_audio_tracker.gd")
const MATCH_DEVELOPER_TOOLS = preload("res://scripts/match_developer_tools.gd")
const MATCH_CONQUEST_UI = preload("res://scripts/match_conquest_ui.gd")
const CONTROL_GROUP_MANAGER = preload("res://scripts/control_group_manager.gd")
const MATCH_EMPIRE_UI = preload("res://scripts/match_empire_ui.gd")
const MATCH_RESOURCE_HUD = preload("res://scripts/match_resource_hud.gd")
const SHIP_MOTION_VIEW = preload("res://scripts/ship_motion_view.gd")
const WORLD_RENDER_BATCHES = preload("res://scripts/world_render_batches.gd")
const CELESTIAL_VIEW = preload("res://scripts/celestial_view.gd")
const WORLD_EFFECTS = preload("res://scripts/world_effects.gd")
const PLANET_TRAFFIC = preload("res://scripts/planet_traffic_view.gd")
const STRUCTURE_VIEW = preload("res://scripts/structure_view.gd")
const ORDER_VIEW = preload("res://scripts/order_view.gd")
const MINIMAP_VIEW = preload("res://scripts/minimap_view.gd")
const LOGISTICS_VIEW = preload("res://scripts/logistics_view.gd")
const SELECTION_INSPECTOR = preload("res://scripts/selection_inspector.gd")
const TACTICAL_ALERTS = preload("res://scripts/tactical_alerts.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")
const RULES = preload("res://scripts/lobby_rules.gd")
const COLORS = RULES.EMPIRE_COLORS
const CONSOLE_WIDE_WIDTH: float = 1240.0
const OVERVIEW_WIDTH: float = 286.0
const YARD_WIDTH: float = 252.0
const HEADER_HEIGHT: float = 54.0
const LENS_STRIP_WIDTH: float = 32.0
const AUTOCAST_SLOTS = {"auto_explore": "explore", "auto_wander": "wander", "auto_mine": "mine", "auto_salvage": "salvage", "auto_repair": "repair", "auto_trade": "trade", "auto_farm": "farm", "collect": "collect", "auto_retreat": "retreat"}
const OVERVIEW_ART_MAX_MULTIPLIER: float = 4.0
const OVERVIEW_SHIP_MAX_MULTIPLIER: float = 12.0
const OVERVIEW_ART_NORMAL_ZOOM: float = 16.0
const TRADE_MAX_EXTRA_HEIGHT: float = 48.0
# Projected system radius in logical screen pixels, independent of selection.

var session: Node
var developer_tools := MATCH_DEVELOPER_TOOLS.new()
var conquest_ui := MATCH_CONQUEST_UI.new()
var empire_ui := MATCH_EMPIRE_UI.new()
var resource_hud := MATCH_RESOURCE_HUD.new()
var ship_motion := SHIP_MOTION_VIEW.new()
var world_batches := WORLD_RENDER_BATCHES.new()
var celestial_view := CELESTIAL_VIEW.new()
# Draw callbacks are synchronous; camera geometry is fixed for their duration.
var _draw_projection_active: bool = false
var _pose_vision_memo: Dictionary = {}
var _pose_vision_team: int = 0
# Full service target map reused until the authority publishes a change.
var _service_refs_cache: Dictionary = {}
var _service_refs_state: Dictionary = {}
var _service_refs_signature: Array = []
var _draw_projection_size: Vector2
var _draw_map_size: Vector2
var _draw_world_center: Vector2
var _draw_fit: float
var _draw_zoom: float
var world_effects := WORLD_EFFECTS.new()
var planet_traffic := PLANET_TRAFFIC.new()
var structure_view := STRUCTURE_VIEW.new()
var order_view := ORDER_VIEW.new()
var minimap_view := MINIMAP_VIEW.new()
var logistics_view := LOGISTICS_VIEW.new()
var selection_inspector := SELECTION_INSPECTOR.new()
var sound_mixer: Node
var audio_tracker := MATCH_AUDIO_TRACKER.new()
var alert_tracker := TACTICAL_ALERTS.new()
var background_music: AudioStreamPlayer
const MATCH_TRACKS = [preload("res://assets/music/peaceful3.mp3"), preload("res://assets/music/Frontier Echoes.mp3")]
var music_order: Array[int] = []
var last_music_track: int = -1
var music_rng := RandomNumberGenerator.new()

func _play_next_music() -> void:
	if not is_inside_tree() or session == null or str(session.get("phase")) != "match":
		return
	if music_order.is_empty():
		for index in range(MATCH_TRACKS.size()):
			music_order.append(index)
		for index in range(music_order.size() - 1, 0, -1):
			var other: int = music_rng.randi_range(0, index)
			var saved: int = music_order[index]
			music_order[index] = music_order[other]
			music_order[other] = saved
		if music_order.size() > 1 and music_order.back() == last_music_track:
			var saved: int = music_order[0]
			music_order[0] = music_order.back()
			music_order[music_order.size() - 1] = saved
	last_music_track = music_order.pop_back()
	var track := MATCH_TRACKS[last_music_track].duplicate() as AudioStreamMP3
	track.loop = false
	background_music.stream = track
	background_music.play()

var map_canvas: Control
var space_backdrop: ColorRect
var header_panel: PanelContainer
var inspector_panel: PanelContainer
var inspector_slot: Control
var overview_panel: PanelContainer
var console_panel: PanelContainer
var minimap: Control
var match_timer_panel: PanelContainer
var match_timer_label: Label
var lens_column: VBoxContainer
var console_columns: HBoxContainer
var console_center: VBoxContainer
var console_center_spacer: Control
var console_right_body: VBoxContainer
var console_profile: Control
var empty_selection: Label
var command_grids: Dictionary = {}
var hotkeys := COMMAND_HOTKEYS.new()
var match_settings := MATCH_SETTINGS.new()
var notice_ui := MATCH_NOTICE_UI.new()
var station_commands: VBoxContainer
var station_primary_grid: GridContainer
var station_select_yards_button: Button
var build_select_yards_button: Button
var station_upgrade_buttons: Dictionary = {}
var station_build_grid: GridContainer
var station_trade: VBoxContainer
var station_trade_back: Button
var station_build_buttons: Dictionary = {}
var queue_view := QUEUE_VIEW.new()
var command_card_ui := COMMAND_CARD_UI.new()
var station_card: String = "primary"
var station_selected_index: int = -1
var station_queue: HFlowContainer
var station_queue_rows: Dictionary = {}
var station_details: VBoxContainer
var station_columns: HBoxContainer
var yard_columns: HBoxContainer
var station_queue_panel: VBoxContainer
var station_queue_heading: Label
var population_label: Label
var raw_antimatter_label: Label
var population_delta_label: Label
var camera := CAMERA_VIEW.new()
var drag_button: int = 0
var hull_art := HULL_ART.new()
var interaction_scroll: ScrollContainer
var interaction_panel: VBoxContainer
var logistics_overlay: Control
var objectives_overlay: Control
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
var control_group_manager := CONTROL_GROUP_MANAGER.new()
var last_control_group_recall: int = -1
var last_control_group_recall_ms: int = -1000
var control_group_strip: HBoxContainer
var global_selection_strip: HBoxContainer
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
var selected_rock: int = -1
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
var colony_morph_progress: ProgressBar
var fleet_scroll: ScrollContainer
var fleet_overview: VBoxContainer
var depot_controls: VBoxContainer
var depot_policy_rows: Dictionary = {}
var depot_policy_id: int = -1
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
var yard_queue: HFlowContainer
var yard_queue_rows: Dictionary = {}
var command_card: GridContainer
var command_buttons: Dictionary = {}
var pending_command: String = ""
var wall_drag_start: Vector2 = Vector2.INF
var wall_drag_end: Vector2 = Vector2.INF
var fleet_cargo: HBoxContainer
var fleet_cargo_footer: HBoxContainer
var fleet_cargo_labels: Dictionary = {}
var initial_selection_done: bool = false
var game_visual_clock: float = 0.0
var info: Label
var visual_clock: float = 0.0
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

func _ready() -> void:
	theme = HUD.create()
	session = get_node("/root/GameSession")
	developer_tools.session = session
	session.connect("phase_changed", _refresh)
	session.connect("status_changed", _refresh)
	session.connect("economy_changed", _on_economy_changed)
	sound_mixer = SFX.new()
	background_music = AudioStreamPlayer.new()
	music_rng.randomize()
	background_music.finished.connect(_play_next_music)
	add_child(background_music)
	match_settings.configure(background_music, hotkeys, command_card_ui, _label, _button, _command_icon, get_viewport_rect)
	match_settings.load_settings()
	match_settings.apply_settings()
	add_child(sound_mixer)
	get_tree().node_added.connect(_sound_button_added)
	session.connect("chat_changed", _sound_chat)
	_build_ui()
	if OS.is_debug_build():
		developer_tools.build_chat_controls(notice_ui.match_chat_content, _button, notice_ui.local_console_notice, notice_ui.clear_history)
	hotkeys.entries["focus"] = {"scope": "General", "title": "Focus selection", "default": KEY_F}
	hotkeys.load_overrides(match_settings.settings, command_card_ui)
	resource_hud.build_hover(self)
	match_settings.apply_settings()
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
	_build_map_layers()
	_build_match_notices()
	_build_world_effect_batches()
	_build_match_header()
	_build_match_dialogs()
	_build_command_deck()
	_build_right_body()
	var selection_content: VBoxContainer = _build_selection_overview()
	_build_fleet_and_yard_cards(console_right_body, selection_content)
	_build_station_overview()
	_build_station_interaction(console_right_body)
	_build_trade_controls()
	_connect_match_ui_layout()

func _build_map_layers() -> void:
	space_backdrop = ColorRect.new()
	space_backdrop.set_script(BACKDROP)
	space_backdrop.name = "SpaceBackdrop"
	add_child(space_backdrop)
	space_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_territory_layer()
	map_canvas = Control.new()
	add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The scene is full-bleed; only HUD controls have a safe-area inset.
	map_canvas.clip_contents = true
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.gui_input.connect(_map_input)
	map_canvas.draw.connect(_draw_map)
	fog_overlay = Control.new()
	map_canvas.add_child(fog_overlay)
	fog_overlay.z_index = 2
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_overlay.draw.connect(_draw_fog)
	queued_order_overlay = Control.new()
	map_canvas.add_child(queued_order_overlay)
	queued_order_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queued_order_overlay.z_index = 3
	queued_order_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queued_order_overlay.draw.connect(_draw_queued_order_overlay)
	logistics_overlay = Control.new()
	map_canvas.add_child(logistics_overlay)
	logistics_overlay.z_index = 3
	logistics_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logistics_view.configure(map_canvas, logistics_overlay, celestial_view, camera, _screen_point, _station_radius, _fit, _me, _population_texture, _refresh)
	logistics_overlay.draw.connect(_draw_logistics_overlay)
	objectives_overlay = Control.new()
	map_canvas.add_child(objectives_overlay)
	objectives_overlay.z_index = 3
	objectives_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objectives_overlay.draw.connect(_draw_objectives_overlay)


func _build_world_effect_batches() -> void:
	world_batches.build(map_canvas)
	structure_view.configure(map_canvas, world_batches, hull_art, command_card_ui, _screen_point, _station_radius, _job_icon, _draw_damage_bar, _shield_fraction, _ship_scale, _overview_art_multiplier)
	planet_traffic.configure(map_canvas, celestial_view, hull_art, _screen_point, _station_radius, _job_icon)
	order_view.configure(queued_order_overlay, hull_art, celestial_view, camera, _ship_scale, _screen_point, _station_radius, _planet_radius, _salvage_radius, _fit, _me, _fog_visible)
	map_canvas.resized.connect(_map_resized)


func _build_match_notices() -> void:
	notice_ui.build(map_canvas, objectives_overlay, session, HEADER_HEIGHT, MATCH_CONQUEST_UI.OBJECTIVES_WIDTH, _me, _empire_color_index, _jump_notice_location)
	conquest_ui.build(self, session, map_canvas, objectives_overlay, HEADER_HEIGHT, _me, _empire_color_index, _empire_color, command_card_ui.icon, _population_texture)

func _build_match_header() -> void:
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
	row.move_child(leave, 0)
	row.move_child(help, 1)
	resource_hud.build(row, _label, _population_row, _state, _me, _system_name)
	row.move_child(resource_hud.year_label.get_parent(), 2)
	header_panel.minimum_size_changed.connect(_layout_match_header)
	_layout_match_header()

func _layout_match_header() -> void:
	if not is_instance_valid(header_panel) or not is_instance_valid(map_canvas):
		return
	# Reserve the right column only when all header tiles fit at their minimum widths.
	var reserved: float = 0.0 if _state().get("eliminated", []).has(_me()) else MATCH_CONQUEST_UI.OBJECTIVES_WIDTH + 4.0
	var alongside: bool = header_panel.get_combined_minimum_size().x <= maxf(0.0, size.x - 16.0 - reserved)
	header_panel.offset_right = -8.0 - (reserved if alongside else 0.0)
	conquest_ui.header_height = 0.0 if alongside else HEADER_HEIGHT
	conquest_ui.layout()
	objectives_overlay.queue_redraw()


func _build_match_dialogs() -> void:
	codex = CODEX.new()
	codex.hide()
	add_child(codex)
	match_menu = AcceptDialog.new()
	match_menu.title = "Menu"
	match_menu.borderless = true
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
	match_settings.build_menu(match_menu)
	match_result_dialog = AcceptDialog.new()
	match_result_dialog.borderless = true
	match_result_dialog.theme = theme
	match_result_dialog.unresizable = true
	match_result_dialog.ok_button_text = "Review map"
	add_child(match_result_dialog)
	match_result_dialog.add_button("Leave match", false, "leave")
	match_result_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"leave":
			match_result_dialog.hide()
			_leave())


func _build_command_deck() -> void:
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
	minimap_view.configure(minimap, session, territory_view, fog_state, ship_motion, _state, _map_size, _projection_size, _world_point, _me, _ship_poses, _fog_visible, _ship_visible, _empire_color)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	minimap.resized.connect(minimap.queue_redraw)
	# Attached above the map without taking any space from the deck.
	match_timer_panel = PanelContainer.new()
	match_timer_panel.theme = HUD.compact()
	match_timer_panel.add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#284661"), 2, 2))
	match_timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_timer_panel.z_index = 4
	add_child(match_timer_panel)
	match_timer_label = _label("00:00", 11)
	match_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	match_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_timer_label.add_theme_color_override("font_color", HUD.MUTED)
	match_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_timer_panel.add_child(match_timer_label)
	minimap.item_rect_changed.connect(_layout_match_timer)
	match_timer_panel.resized.connect(_layout_match_timer)
	notice_ui.attach_minimap(minimap, match_timer_panel)
	_layout_match_timer()
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
	logistics_view.build(lens_column, LENS_STRIP_WIDTH, _button, _command_icon)
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
	command_card_ui.setup_info(self, inspector_panel, inspector_slot)
	inspector_slot.resized.connect(_layout_right_panel)
	inspector_slot.item_rect_changed.connect(_layout_control_group_strip)
	# Both wings use the same fixed width; only the center expands.
	inspector_panel.size_flags_horizontal = Control.SIZE_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#28466100"), 3, 3))
	developer_tools.build_perf(self, lens_column, _button, _label, _command_icon, LENS_STRIP_WIDTH)


func _build_right_body() -> void:
	# Tabs and fleet commands each own a bounded scroll viewport. A
	# ScrollContainer around a TabContainer collapses its page to zero height.
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_child(body)
	console_right_body = body


func _build_selection_overview() -> VBoxContainer:
	selection_inspector.configure(hull_art, _health_color, _shield_fraction)
	overview_panel = PanelContainer.new()
	console_center.add_child(overview_panel)
	overview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_panel.add_theme_stylebox_override("panel", HUD.surface(HUD.CONSOLE_BACKGROUND, Color("#28466100"), 3, 3))
	var selection_content := VBoxContainer.new()
	overview_panel.add_child(selection_content)
	var selection_row := HBoxContainer.new()
	selection_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_row.add_theme_constant_override("separation", 8)
	selection_content.add_child(selection_row)
	selection_inspector.build_portrait(selection_row, _label, _focus_selection)
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
	selection_inspector.build_tiles(ship_overview)
	ship_detail = _label("", 13)
	ship_overview.add_child(ship_detail)
	colony_morph_progress = ProgressBar.new()
	colony_morph_progress.custom_minimum_size = Vector2(100, 10)
	colony_morph_progress.step = 0.0
	colony_morph_progress.show_percentage = true
	colony_morph_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_overview.add_child(colony_morph_progress)
	colony_morph_progress.hide()
	var crew_row := HBoxContainer.new()
	ship_overview.add_child(crew_row)
	ship_population = _label("", 13)
	ship_population.autowrap_mode = TextServer.AUTOWRAP_OFF
	ship_population.add_theme_color_override("font_color", Color("#b9d9ed"))
	crew_row.add_child(ship_population)
	crew_row.hide()
	selection_inspector.build_weapons(overview, _label)
	return selection_content


func _build_fleet_and_yard_cards(body: VBoxContainer, selection_content: VBoxContainer) -> void:
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
	_build_depot_controls(fleet_overview)
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


func _build_depot_controls(parent: VBoxContainer) -> void:
	depot_controls = VBoxContainer.new()
	parent.add_child(depot_controls)
	depot_controls.add_child(_label("Automatic logistics", 13))
	for resource in ECONOMY.RESOURCES:
		depot_controls.add_child(_label(resource, 11))
		var rows: Dictionary = {}
		for key in ["receive", "dispatch"]:
			var row := HBoxContainer.new()
			depot_controls.add_child(row)
			var check := CheckBox.new()
			check.text = "Receive up to" if key == "receive" else "Dispatch above"
			check.add_theme_font_size_override("font_size", 10)
			_compact_trade_check(check)
			check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(check)
			var percent := SpinBox.new()
			percent.min_value = 0.0
			percent.max_value = 100.0
			percent.step = 1.0
			percent.suffix = "%"
			row.add_child(percent)
			rows[key] = {"check": check, "percent": percent}
			check.toggled.connect(_depot_policy_changed.bind(resource, key))
			percent.value_changed.connect(_depot_policy_changed.bind(resource, key))
		depot_policy_rows[resource] = rows
	depot_controls.hide()

func _refresh_depot_controls(ship: Dictionary, phase: String) -> void:
	var available: bool = selected_units.size() == 1 and ship.get("kind", "") == "resource_depot" and int(ship.get("owner", 0)) == _me() and ECONOMY.static_complete(ship) and phase == "match"
	depot_controls.visible = available
	var id: int = int(ship.get("id", -1)) if available else -1
	var changed: bool = depot_policy_id != id
	depot_policy_id = id
	if not available:
		return
	for resource in ECONOMY.RESOURCES:
		var policy: Dictionary = ECONOMY.depot_policy(ship, resource)
		for key in ["receive", "dispatch"]:
			var controls: Dictionary = depot_policy_rows[resource][key]
			var percent: SpinBox = controls["percent"]
			controls["check"].set_pressed_no_signal(bool(policy[key]))
			if changed or not percent.get_line_edit().has_focus():
				percent.set_value_no_signal(float(policy["ceiling" if key == "receive" else "floor"]))

func _depot_policy_changed(_value: Variant, resource: String, key: String) -> void:
	if depot_policy_id < 0 or not depot_controls.visible:
		return
	var rows: Dictionary = depot_policy_rows[resource]
	var floor_control: SpinBox = rows["dispatch"]["percent"]
	var ceiling_control: SpinBox = rows["receive"]["percent"]
	if floor_control.value > ceiling_control.value:
		if key == "receive":
			floor_control.set_value_no_signal(ceiling_control.value)
		else:
			ceiling_control.set_value_no_signal(floor_control.value)
	session.call("request_depot_policy", depot_policy_id, resource, floor_control.value, ceiling_control.value, rows["receive"]["check"].button_pressed, rows["dispatch"]["check"].button_pressed)

func _build_station_overview() -> void:
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
	station_columns = HBoxContainer.new()
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
	station_queue = queue_view.build(station_queue_panel)
	station_queue.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	station_queue.alignment = FlowContainer.ALIGNMENT_BEGIN
	station_queue_panel.hide()


func _build_station_interaction(body: VBoxContainer) -> void:
	interaction_scroll = ScrollContainer.new()
	interaction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	interaction_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(interaction_scroll)
	interaction_panel = VBoxContainer.new()
	interaction_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_panel.add_theme_constant_override("separation", 8)
	interaction_scroll.add_child(interaction_panel)
	var neutral_grid: GridContainer = command_card_ui.create_grid(interaction_panel)
	send_colony_button = _station_button(neutral_grid, "Colonize", "transform", _send_colony)
	send_colony_button.gui_input.connect(_colonize_autocast_input)
	command_card_ui.set_hint(send_colony_button, "Send the nearest available Colony to this sector. Right-click to send a Colony as soon as one is available.")
	hotkeys.register(send_colony_button, KEY_C, "Neutral System", "colonize", "Colonize")
	command_card_ui.fill_grid(neutral_grid)
	_build_station_command_card(body)


func _build_trade_controls() -> void:
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
		slider.tooltip_text = "%s thresholds\nImport below min · Export above max 100%% = %.0f." % [resource, ECONOMY.TRADE_REFERENCE]
		command_card_ui.register_info(slider, str(resource) + " thresholds")
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
		incoming.tooltip_text = "Import " + str(resource) + "\nEnable imports below the left threshold."
		command_card_ui.register_info(incoming, "Import " + str(resource))
		incoming.add_theme_font_size_override("font_size", 10)
		_compact_trade_check(incoming)
		incoming.button_pressed = true
		switches.add_child(incoming)
		var outgoing := CheckBox.new()
		outgoing.text = "Export"
		outgoing.tooltip_text = "Export " + str(resource) + "\nEnable exports above the right threshold."
		command_card_ui.register_info(outgoing, "Export " + str(resource))
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


func _connect_match_ui_layout() -> void:
	resized.connect(_layout_console)
	console_panel.resized.connect(_map_resized, CONNECT_DEFERRED)
	inspector_panel.resized.connect(_layout_command_grids)
	inspector_slot.resized.connect(_layout_command_grids)
	inspector_panel.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(console_profile.queue_redraw)
	console_center.resized.connect(_layout_command_grids)
	lens_column.resized.connect(console_profile.queue_redraw)
	console_columns.resized.connect(console_profile.queue_redraw)
	_layout_console()


func _layout_match_timer() -> void:
	if not is_instance_valid(match_timer_panel) or not is_instance_valid(minimap):
		return
	match_timer_panel.size = Vector2(maxf(64.0, match_timer_panel.get_combined_minimum_size().x), match_timer_panel.get_combined_minimum_size().y)
	match_timer_panel.global_position = minimap.global_position - Vector2(0.0, match_timer_panel.size.y)

func _layout_console() -> void:
	if not is_instance_valid(console_panel) or not is_instance_valid(station_commands):
		return
	# Keep a stable, useful map at both normal and small window sizes.
	var height: float = roundf(0.9 * minf(clampf(size.y * 0.36, 220.0, 320.0), maxf(135.0, size.y - HEADER_HEIGHT - 180.0)))
	console_panel.offset_top = -8.0 - height
	# The scene still draws behind the stepped HUD. Only the camera's
	# projection reserves the bottom deck; world layers stay full-screen.
	# Symmetric wings occupy at most 48% of the deck together at the
	# usual window sizes. The center receives all remaining width.
	var wing_width: float = clampf(floorf((size.x - 28.0 - LENS_STRIP_WIDTH) * 0.24), 180.0, 320.0)
	minimap.custom_minimum_size.x = wing_width
	inspector_slot.custom_minimum_size.x = wing_width
	inspector_panel.custom_minimum_size.x = wing_width
	if is_instance_valid(control_group_strip):
		_layout_control_group_strip()
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
	var rects: Array[Rect2] = [left_rect, center_rect, right_rect]
	for rect in rects:
		if rect.has_area():
			console_profile.draw_rect(rect, fill)
			console_profile.draw_rect(rect.grow(-0.5), Color(edge, 0.35), false, 1.0)

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
	selection_inspector.layout(console_center, building_group_grid)
	for title in command_grids:
		var grid: GridContainer = command_grids[title]
		var cell_width: float = 160.0 if title == "Trade" else 222.0
		grid.columns = clampi(floori(width / cell_width), 1, 3)
	_layout_right_panel()

func _minimap_input(event: InputEvent) -> void:
	if match_menu.visible or (is_instance_valid(codex) and codex.visible):
		return
	minimap_view.handle_input(event, pending_command, _minimap_order, _minimap_pan_to)

func _minimap_pan_to(world: Vector2) -> void:
	camera.following = false
	_center_world(world)
	_position_territory()
	map_canvas.queue_redraw()
	minimap.queue_redraw()

func _minimap_order(mouse: InputEventMouseButton) -> void:
	var state: Dictionary = _state()
	var hint: Dictionary = minimap_view.order_hint(mouse, state, pending_command)
	if hint.is_empty():
		return
	var point: Vector2 = _screen_point(hint["world"])
	var mode: String = pending_command
	if mode in ["repair", "unload", "load", "collect", "guard", "scan"]:
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
	minimap_view.draw(selected, selected_units, selected_field, selected_rock)

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

func _set_cost_tooltip(button: Button, description: String, cost: Dictionary = {}, crew: float = 0.0, available: Dictionary = {}, kind: String = "") -> void:
	var cost_button: CostButton = button as CostButton
	cost_button.set_recipe(cost, crew, _population_texture() if crew > 0.0 else null, available, kind)
	var shortcut: String = str(button.get_meta("hotkey", ""))
	command_card_ui.set_hint(button, description if shortcut.is_empty() else (description + "\n[" + shortcut + "]" if not description.is_empty() else "[" + shortcut + "]"))

func _available_cost_resources(p: Dictionary, yard: int = -1) -> Dictionary:
	var available: Dictionary = p["stock"].duplicate()
	available["GC"] = ECONOMY.credit_balance(_state(), _me())
	available["Population"] = ECONOMY.available_crew_population(p, yard) if yard >= 0 else maxf(0.0, float(p["population"]) - ECONOMY.reserved_construction_population(p))
	return available

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
	yard_columns = HBoxContainer.new()
	yard_columns.add_theme_constant_override("separation", 8)
	yard_overview.add_child(yard_columns)
	var yard_work := VBoxContainer.new()
	yard_work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yard_columns.add_child(yard_work)
	yard_status = _label("", 12)
	yard_work.add_child(yard_status)
	yard_queue = queue_view.build(yard_work)
	yard_overview.hide()

func _build_yard_command_card(parent: VBoxContainer) -> void:
	yard_command_scroll = VBoxContainer.new()
	yard_command_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(yard_command_scroll)
	yard_command_card = VBoxContainer.new()
	yard_command_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yard_command_scroll.add_child(yard_command_card)
	var grid: GridContainer = command_card_ui.create_grid(yard_command_card)
	yard_command_grid = grid
	for kind in ECONOMY.SHIP_KINDS:
		var button := CostButton.new()
		var caption: String = {"ship": "Freighter", "colony_ship": "Colony", "fighter": "Fighter", "miner": "Harvester", "science_ship": "Science\nvessel", "scout": "Scout", "cruiser": "Cruiser", "destroyer": "Destroyer", "railgun_ship": "Railgun", "construction_ship": "Constructor"}[kind]
		var art: TextureRect = command_card_ui.set_face(button, caption, hull_art.production_icon(kind, HUD.ACCENT))
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
		hotkeys.register(button, {"ship": KEY_D, "colony_ship": KEY_C, "fighter": KEY_A, "miner": KEY_S, "science_ship": KEY_V, "scout": KEY_Q, "cruiser": KEY_E, "destroyer": KEY_F, "railgun_ship": KEY_G, "construction_ship": KEY_H}[kind], "Shipyard", "yard_" + kind, UI_TEXT.ship_kind_name(kind))
	# Rows 1–3: Small, Medium and Large. A locked class shows only
	# its next eligible upgrade; unlocked ships begin in column one.
	for target_level in [2, 3]:
		var upgrade: Button = _button("", _upgrade_selected_yards.bind(target_level), grid, true)
		var class_name_text: String = ECONOMY.size_name(target_level)
		command_card_ui.set_face(upgrade, "Upgrade", command_card_ui.icon("upgrade"))
		yard_upgrades[target_level] = upgrade
		hotkeys.register(upgrade, KEY_U if target_level == 2 else KEY_I, "Shipyard", "yard_upgrade" if target_level == 2 else "yard_upgrade_large", "Upgrade to " + class_name_text)
	yard_top_slots.assign([yard_commands["scout"], yard_commands["fighter"], yard_commands["miner"], yard_commands["construction_ship"]])
	for i in range(8):
		yard_row_spacers.append(command_card_ui.add_spacer(grid))
	var station_button := _button("", _select_yard_station, grid)
	command_card_ui.set_face(station_button, "Station", command_card_ui.icon("select_station"))
	command_card_ui.set_hint(station_button, "Select parent station")
	hotkeys.register(station_button, KEY_Z, "Shipyard", "yard_station", "Select Space Station")
	var build_button: Button = _station_button(grid, "Build", "build", _select_yard_station.bind(true))
	hotkeys.register(build_button, KEY_B, "Shipyard", "yard_station_build", "Station Build")
	var clear := _button("", func() -> void:
		pending_command = ""
		_refresh_command_mode()
		for ref in _selected_yards(_state(), true):
			session.call("request_shipyard_rally", ref.x, ref.y, -1, Vector2.ZERO), grid)
	command_card_ui.set_face(clear, "Clear", command_card_ui.icon("clear_rally"))
	command_card_ui.set_hint(clear, "Clear Rally")
	yard_commands["clear"] = clear
	hotkeys.register(clear, KEY_X, "Shipyard", "yard_clear", "Clear Rally")
	var rally_button := CostButton.new()
	command_card_ui.set_face(rally_button, "Rally", command_card_ui.icon("rally"))
	rally_button.toggle_mode = true
	command_card_ui.set_hint(rally_button, "Rally\nDestination for new ships")
	rally_button.pressed.connect(_arm_command.bind("rally"))
	grid.add_child(rally_button)
	yard_commands["rally"] = rally_button
	hotkeys.register(rally_button, KEY_Y, "Shipyard", "yard_rally", "Rally")
	yard_bottom_slots.assign([station_button, build_button, clear, rally_button])
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
		var kinds: Array = ["ship", "colony_ship", "cruiser"] if target_level == 2 else ["science_ship", "destroyer", "railgun_ship"]
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

func _select_yard_station(open_build: bool = false) -> void:
	# For grouped yards, select the primary yard's parent station.
	_select_building_ref(Vector2i(selected, 0), "station")
	# Selecting refreshes the inspector and resets the station card.
	if open_build and station_selected_index == selected and station_commands.visible:
		_station_card_to("build")

# Shared command-card art. Keep silhouettes legible at compact native UI sizes.
func _station_button(grid: GridContainer, caption: String, key: String, action: Callable) -> Button:
	var button: Button = _button("", action, grid, true)
	var art: TextureRect = command_card_ui.set_face(button, caption, command_card_ui.icon(key))
	var navigation: Dictionary = {"build": "Build\nConstruct resource production, housing, storage, defenses or shipyards.", "trade": "Trade\nSet import and export thresholds for this station.", "return": "Return"}
	if navigation.has(key):
		command_card_ui.set_hint(button, navigation[key])
	button.set_meta("portrait", art)
	return button

func _build_station_command_card(parent: Container) -> void:
	station_commands = VBoxContainer.new()
	station_commands.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station_commands.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(station_commands)
	station_primary_grid = command_card_ui.create_grid(station_commands)
	for i in range(4):
		command_card_ui.add_spacer(station_primary_grid)
	station_upgrade_buttons["reinforced_plating"] = _station_button(station_primary_grid, "Plating", "reinforced_plating", _station_upgrade_pressed.bind("reinforced_plating"))
	station_upgrade_buttons["laser_matrix"] = _station_button(station_primary_grid, "Lasers", "laser_matrix", _station_upgrade_pressed.bind("laser_matrix"))
	hotkeys.register(station_upgrade_buttons["reinforced_plating"], KEY_V, "Station", "station_plating", "Plating")
	hotkeys.register(station_upgrade_buttons["laser_matrix"], KEY_L, "Station", "station_matrix", "Lasers")
	var dyson_button: Button = _station_button(station_primary_grid, "Dyson\nSphere", "dyson_sphere", _station_upgrade_pressed.bind("dyson_sphere"))
	var dyson_slot: Control = command_card_ui.add_spacer(station_primary_grid)
	dyson_slot.custom_minimum_size = dyson_button.custom_minimum_size
	dyson_button.reparent(dyson_slot, false)
	dyson_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	station_upgrade_buttons["dyson_sphere"] = dyson_button
	command_card_ui.add_spacer(station_primary_grid)
	for i in range(4):
		command_card_ui.add_spacer(station_primary_grid)
	# Bottom row: Select Shipyards, Build, Trade, empty.
	station_select_yards_button = _station_button(station_primary_grid, "Shipyards", "yard", _station_select_yards)
	hotkeys.register(station_select_yards_button, KEY_Z, "Station", "station_port_1", "Select Shipyards")
	hotkeys.register(_station_button(station_primary_grid, "Build", "build", _station_card_to.bind("build")), KEY_B, "Station", "station_build", "Build")
	hotkeys.register(_station_button(station_primary_grid, "Trade", "trade", _station_card_to.bind("trade")), KEY_T, "Station", "station_trade", "Trade")
	command_card_ui.add_spacer(station_primary_grid)
	station_build_grid = command_card_ui.create_grid(station_commands)
	var captions: Dictionary = {"warehouse": "Warehouse", "housing": "Habitation", "pds": "PDS", "yard": "Shipyard"}
	for resource in ECONOMY.RESOURCES:
		captions[resource] = str(ECONOMY.ECONOMY_BUILDINGS[resource]["name"]).replace(" ", "\n")
	for key in ECONOMY.RESOURCES + ["warehouse", "housing", "pds", "yard"]:
		var button: Button = _station_button(station_build_grid, captions[key], "habitation" if key == "housing" else key, _station_build.bind(key))
		station_build_buttons[key] = button
		hotkeys.register(button, {"Metals": KEY_R, "Organics": KEY_G, "Crystals": KEY_C, "warehouse": KEY_W, "housing": KEY_H, "pds": KEY_T, "yard": KEY_X}[key], "Station Build", "build_" + key, captions[key].replace("\n", " "))
		if key in ECONOMY.RESOURCES or key in ["warehouse", "housing", "pds", "yard"]:
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
		command_card_ui.add_spacer(station_build_grid)
	# Bottom row: Shipyards, two empty slots, Return.
	build_select_yards_button = _station_button(station_build_grid, "Shipyards", "yard", _station_select_yards)
	hotkeys.register(build_select_yards_button, KEY_Z, "Station Build", "build_select_yards", "Select Shipyards")
	for i in range(2):
		command_card_ui.add_spacer(station_build_grid)
	hotkeys.register(_station_button(station_build_grid, "Return", "return", _station_card_to.bind("primary")), KEY_ESCAPE, "Station Build", "build_return", "Return")
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
	if not _any_selected_station_buildable(key, p):
		return
	if key == "housing" and building_selection_kind != "station":
		key = "habitation" if ECONOMY.has_planets(p) else "orbital_housing"
	if key in ["yard", "pds"]:
		_operation(key)
	else:
		_operation("economy", key)

# Snapshot the active station group before dispatching requests or changing selection.
func _owned_station_selection(state: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if building_selection_kind == "station":
		for ref in selected_buildings:
			if _building_valid(state, ref, "station") and int(state["planets"][ref.x]["owner"]) == _me():
				result.append(ref.x)
	elif _building_valid(state, Vector2i(selected, 0), "station") and int(state["planets"][selected]["owner"]) == _me():
		result.append(selected)
	return result

func _station_select_yards() -> void:
	var state: Dictionary = _state()
	if station_selected_index != selected:
		return
	var refs: Dictionary = {}
	for index in _owned_station_selection(state):
		var count: int = state["planets"][index]["yards"].size()
		for slot in range(count):
			refs[Vector2i(index, slot)] = count
	if refs.is_empty():
		return
	_clear_building_selection()
	building_selection_kind = "shipyard"
	selected_buildings = refs
	_set_building_primary(state, refs.keys()[0], "shipyard")
	camera.following = false
	pending_command = ""
	_load_thresholds()
	_refresh()

func _station_upgrade_pressed(kind: String) -> void:
	if station_selected_index == selected:
		_operation(kind)

func _refresh_station_primary(p: Dictionary, owned: bool) -> void:
	var yard_count: int = 0
	var state: Dictionary = _state()
	for index in _owned_station_selection(state):
		yard_count += state["planets"][index]["yards"].size()
	for shortcut in [station_select_yards_button, build_select_yards_button]:
		var button: Button = shortcut
		button.disabled = not owned or yard_count == 0
		command_card_ui.set_hint(button, "Select all %d completed shipyards at selected stations" % yard_count)
		(button.get_meta("portrait") as TextureRect).modulate = Color(0.55, 0.55, 0.55) if button.disabled else Color.WHITE
	for kind in station_upgrade_buttons:
		var button: Button = station_upgrade_buttons[kind]
		if kind == "dyson_sphere":
			button.visible = p.get("conquest_rewards", []).has(kind) or bool(p["station"].get(kind, false))
		var installed: bool = bool(p["station"].get(kind, false))
		command_card_ui.set_level_badge(button, 1 if installed else 0)
		var pending: bool = ECONOMY.has_queued_job(p, kind, "")
		button.disabled = not owned or not _any_selected_station_buildable(kind, p)
		command_card_ui.set_build_available(button, not button.disabled)
		var hint: String = "Plating I · %.0f s\n+1,500 station HP" if kind == "reinforced_plating" else "Lasers I · %.0f s\n+2 defensive lasers (4 total)"
		if kind == "dyson_sphere":
			hint = "Dyson Sphere · %.0f s\nRequires Dyson Sphere technology\n−50%% local ship material and GC costs"
		_set_cost_tooltip(button, hint % ECONOMY.nominal_work(kind, 1), ECONOMY.base_recipe_cost(kind, 1) if not installed and not pending else {}, 0.0, _available_cost_resources(p))
		if button.disabled and ECONOMY.station_queue_count(p) >= ECONOMY.STATION_QUEUE_LIMIT:
			command_card_ui.add_build_blocker(button, "Station queue full (%d/%d)" % [ECONOMY.station_queue_count(p), ECONOMY.STATION_QUEUE_LIMIT])
		if installed or pending:
			command_card_ui.add_build_blocker(button, "Already installed" if installed else "Upgrade already queued")
		if kind == "dyson_sphere" and not p.get("conquest_rewards", []).has(kind) and not installed:
			command_card_ui.add_build_blocker(button, "Requires Dyson Sphere technology")
		if button.disabled and not owned:
			command_card_ui.add_build_blocker(button, "Requires an owned station")
		(button.get_meta("portrait") as TextureRect).modulate = Color(0.55, 0.55, 0.55) if button.disabled and not installed else Color.WHITE

func _station_repeat_key(p: Dictionary, key: String) -> String:
	if key in ECONOMY.RESOURCES:
		return "economy_building:" + key
	if key in ["warehouse", "pds", "yard"]:
		return key
	if key == "housing":
		return "habitation" if ECONOMY.has_planets(p) else "orbital_housing"
	return ""

func _station_repeat_targets(state: Dictionary, key: String, indices: Array[int]) -> Dictionary:
	var targets: Dictionary = {}
	for index in indices:
		var p: Dictionary = state["planets"][index]
		var repeat_key: String = _station_repeat_key(p, key)
		if not repeat_key.is_empty() and (ECONOMY.station_repeat_available(p, repeat_key) or bool(p.get("continuous", {}).get(repeat_key, false))):
			targets[index] = repeat_key
	return targets

func _station_repeat_input(event: InputEvent, key: String, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed or station_selected_index != selected:
		return
	var state: Dictionary = _state()
	var targets: Dictionary = _station_repeat_targets(state, key, _owned_station_selection(state))
	var enable: bool = false
	for index in targets:
		enable = enable or not bool(state["planets"][index].get("continuous", {}).get(targets[index], false))
	for index in targets:
		session.call("request_continuous", index, targets[index], enable)
	button.accept_event()

func _refresh_station_build(p: Dictionary, owned: bool) -> void:
	var state: Dictionary = _state()
	var indices: Array[int] = _owned_station_selection(state) if owned else []
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
		(button as CostButton).effect_resource = key if key in ECONOMY.RESOURCES else ""
		if key in ECONOMY.RESOURCES:
			current_level = int(p.get("buildings", {}).get(key, 0))
			name_text = str(ECONOMY.ECONOMY_BUILDINGS[key]["name"])
			recipe = ECONOMY.building_cost(p, key)
			eligible = ECONOMY.production_available(p, key)
			available = ECONOMY.building_available(p, key)
			description = "Population: %s required / %s present\n%s" % [UI_TEXT.compact_amount(float(ECONOMY.building_population(key, current_level + 1))), UI_TEXT.compact_amount(float(p["population"])), UI_TEXT.economy_building_effect(p, key)]
		elif key == "warehouse":
			var level: int = int(p.get("warehouse_level", 0))
			current_level = level
			name_text = "Warehouse"
			eligible = level < 3
			available = ECONOMY.warehouse_available(p)
			work = ECONOMY.nominal_work("warehouse", level + 1)
			description = "Storage: %s Metals · %s other resources" % [UI_TEXT.resource_amount(ECONOMY.storage_capacity(p, "Metals"), 0), UI_TEXT.resource_amount(ECONOMY.storage_capacity(p), 0)]
			if eligible:
				recipe = ECONOMY.WAREHOUSE_COSTS[level]
				var preview: Dictionary = p.duplicate()
				preview["warehouse_level"] = level + 1
				description = "Requires %s population\n+%s Metals · +%s other resources (%s each total)" % [UI_TEXT.compact_amount(ECONOMY.WAREHOUSE_POPULATIONS[level]), UI_TEXT.resource_amount(ECONOMY.storage_capacity(preview, "Metals") - ECONOMY.storage_capacity(p, "Metals"), 0), UI_TEXT.resource_amount(ECONOMY.storage_capacity(preview) - ECONOMY.storage_capacity(p), 0), UI_TEXT.resource_amount(ECONOMY.storage_capacity(preview), 0)]
		elif key == "housing":
			kind = "habitation" if ECONOMY.has_planets(p) else "orbital_housing"
			var caption: Label = button.get_meta("caption")
			caption.text = "Habitation" if kind == "habitation" else "Orbital\nhousing"
			(button.get_meta("portrait") as TextureRect).texture = command_card_ui.icon(kind)
			if kind == "habitation":
				var level: int = int(p.get("habitation_level", 0))
				work = ECONOMY.nominal_work(kind, level + 1)
				current_level = level
				name_text = "Habitation"
				eligible = level < 3
				available = ECONOMY.habitation_available(p)
				recipe = ECONOMY.habitation_cost(p) if eligible else {}
				description = "+%s housing capacity (%s total)" % [UI_TEXT.compact_amount(ECONOMY.habitation_capacity(p)), UI_TEXT.compact_amount(ECONOMY.habitation_capacity(p) * 2.0)] if eligible else "Maximum housing: %s" % UI_TEXT.compact_amount(ECONOMY.habitation_capacity(p))
			else:
				work = ECONOMY.nominal_work(kind, 1)
				current_level = int(p.get("orbital_housing", 0))
				name_text = "Orbital Eco-Housing"
				recipe = ECONOMY.ORBITAL_HOUSING_COST
				available = ECONOMY.orbital_housing_available(p)
				var preview: Dictionary = p.duplicate()
				preview["orbital_housing"] = current_level + 1
				description = "+%s housing and residents\n+%.2f/yr Organics" % [UI_TEXT.compact_amount(ECONOMY.ORBITAL_HOUSING_POPULATION), ECONOMY.eco_organics(preview) - ECONOMY.eco_organics(p)]
		elif key == "yard":
			var slot: int = ECONOMY.next_shipyard_slot(p)
			name_text = "Build Shipyard"
			eligible = slot > 0
			if eligible:
				recipe = ECONOMY.base_recipe_cost("yard", slot)
				work = ECONOMY.nominal_work("yard", slot)
			available = eligible
			description = "All shipyard slots occupied"
			if eligible:
				description = "Staffing: %s population\n+1 Small shipyard\n+%s housing and residents" % [UI_TEXT.compact_amount(ECONOMY.SHIPYARD_POPULATION[slot - 1]), UI_TEXT.compact_amount(ECONOMY.ORBITAL_HOUSING_POPULATION)]
		elif key == "pds":
			name_text = "PDS"
			current_level = p.get("pds", {}).size()
			eligible = ECONOMY.next_pds(p) >= 0
			available = eligible and ECONOMY.pds_job(p).is_empty()
			recipe = ECONOMY.base_recipe_cost("pds", 1)
			work = ECONOMY.nominal_work("pds", 1)
			description = "Defends one planet · %.0f damage · Range %.0f\nInvulnerable until station destroyed" % [ECONOMY.PDS_DAMAGE, ECONOMY.PDS_RANGE]
		command_card_ui.set_level_badge(button, current_level)
		if key != "yard":
			name_text += " " + UI_TEXT.roman_level(current_level + (1 if eligible else 0))
		var repeat_targets: Dictionary = _station_repeat_targets(state, key, indices)
		var auto: bool = not repeat_targets.is_empty()
		for index in repeat_targets:
			auto = auto and bool(state["planets"][index].get("continuous", {}).get(repeat_targets[index], false))
		available = owned and available and ECONOMY.station_queue_count(p) < ECONOMY.STATION_QUEUE_LIMIT and ECONOMY.construction_affordable(_state(), p, recipe)
		var grouped: bool = building_selection_kind == "station" and selected_buildings.size() > 1
		var can_build: bool = owned and (_any_selected_station_buildable(key, p) if grouped else available and eligible)
		var permanent_reason: String = UI_TEXT.permanent_station_blocker(p, key)
		var impossible: bool = not indices.is_empty()
		for index in indices:
			impossible = impossible and not UI_TEXT.permanent_station_blocker(state["planets"][index], key).is_empty()
		button.disabled = not owned or (not can_build and repeat_targets.is_empty())
		command_card_ui.set_build_available(button, can_build, impossible)
		(button.get_meta("portrait") as TextureRect).modulate = Color.WHITE if can_build else (Color(0.78, 0.50, 0.50) if impossible else Color(0.55, 0.55, 0.55))
		if button.has_meta("auto_border"):
			(button.get_meta("auto_border") as Control).visible = auto
		_set_cost_tooltip(button, name_text + (" · %.1f s" % work if not recipe.is_empty() else "") + "\n" + description, recipe, 0.0, _available_cost_resources(p))
		if not permanent_reason.is_empty():
			command_card_ui.add_build_blocker(button, permanent_reason)
		elif key in ECONOMY.RESOURCES:
			if float(p["population"]) + ECONOMY.EPS < float(ECONOMY.building_population(key, current_level + 1)):
				command_card_ui.add_build_blocker(button, description.get_slice("\n", 0))
			if ECONOMY.has_queued_job(p, "economy_building", key):
				command_card_ui.add_build_blocker(button, "Upgrade already queued")
		elif key == "warehouse" or kind == "habitation":
			if not eligible:
				command_card_ui.add_build_blocker(button, "Maximum level reached")
			elif ECONOMY.has_queued_job(p, kind, ""):
				command_card_ui.add_build_blocker(button, "Upgrade already queued")
			if key == "warehouse" and eligible and float(p["population"]) + ECONOMY.EPS < float(ECONOMY.WAREHOUSE_POPULATIONS[current_level]):
				command_card_ui.add_build_blocker(button, description.get_slice("\n", 0))
		elif key == "pds":
			if not eligible:
				command_card_ui.add_build_blocker(button, "All planets already defended")
			elif not ECONOMY.pds_job(p).is_empty():
				command_card_ui.add_build_blocker(button, "PDS already queued")
		elif key == "yard" and not eligible:
			command_card_ui.add_build_blocker(button, description)
		if not can_build and ECONOMY.station_queue_count(p) >= ECONOMY.STATION_QUEUE_LIMIT:
			command_card_ui.add_build_blocker(button, "Station queue full (%d/%d)" % [ECONOMY.station_queue_count(p), ECONOMY.STATION_QUEUE_LIMIT])
		if grouped and not can_build:
			command_card_ui.add_build_blocker(button, "No selected station can build this now")
		if not owned:
			command_card_ui.add_build_blocker(button, "Requires an owned station")
		if not repeat_targets.is_empty():
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nRight-click: %s repeat (%d station%s)" % ["Disable" if auto else "Enable", repeat_targets.size(), "" if repeat_targets.size() == 1 else "s"])

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
		if not ECONOMY.yard_fits(system, ref.y, kind):
			continue
		eligible.append(ref)
		enable = enable or not system["yards"][ref.y].get("autobuild", []).has(kind)
	for ref in eligible:
		session.call("request_operation", ref.x, "shipyard_autobuild", "%d:%s:%d" % [ref.y, kind, int(enable)])
	button.accept_event()

func _yard_build_available(system: Dictionary, slot: int, kind: String) -> bool:
	return ECONOMY.yard_fits(system, slot, kind) and ECONOMY.shipyard_operational(system, slot) and ECONOMY.shipyard_queue_count(system, slot) < ECONOMY.SHIPYARD_QUEUE_LIMIT and ECONOMY.construction_affordable(_state(), system, ECONOMY.construction_cost(system, kind, 1), kind, slot)

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
	return ECONOMY.construction_affordable(_state(), system, ECONOMY.base_recipe_cost("yard_upgrade", int(system["yards"][slot]["level"]) + 1))

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
	queue_view.refresh(yard_queue, yard_queue_rows, system, jobs, owned, active_id, _button, _cancel_job, _job_icon, _planet())
	for kind in ECONOMY.SHIP_KINDS:
		var button: Button = yard_commands[kind]
		var recipe: Dictionary = ECONOMY.construction_cost(system, kind, 1)
		button.disabled = not owned or not ECONOMY.yard_fits(system, selected_yard, kind)
		var available: bool = owned and _yard_build_available(system, selected_yard, kind)
		command_card_ui.set_build_available(button, available)
		var auto: bool = yard.get("autobuild", []).has(kind)
		(button.get_meta("auto_border") as Control).visible = auto
		var portrait: TextureRect = button.get_meta("portrait")
		portrait.texture = hull_art.production_icon(kind, _empire_color(int(system["owner"])))
		portrait.modulate = Color.WHITE if available else Color(0.55, 0.55, 0.55)
		_set_cost_tooltip(button, "%s · %.1f s\n%s" % [UI_TEXT.ship_kind_name(kind), ECONOMY.nominal_work(kind, 1) / ECONOMY.yard_speed(level), UI_TEXT.ship_stats(kind)], recipe, float(ECONOMY.CREW_COSTS[kind]), _available_cost_resources(system, selected_yard), kind)
		if not ECONOMY.ship_origin_population_met(system, kind):
			(button as CostButton).unmet_requirements.append(UI_TEXT.colony_population_requirement())
		if not ECONOMY.ship_crew_available(system, kind, selected_yard):
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nInsufficient unreserved population")
			(button as CostButton).unmet_requirements.append("Insufficient unreserved population")
		if not ECONOMY.yard_fits(system, selected_yard, kind):
			command_card_ui.add_build_blocker(button, "Requires %s shipyard (Lv %d)" % [ECONOMY.size_name(ECONOMY.ship_size(kind)), ECONOMY.ship_size(kind)])
		if not operating:
			command_card_ui.add_build_blocker(button, "Shipyard offline — requires %s residents" % UI_TEXT.compact_amount(ECONOMY.SHIPYARD_POPULATION[selected_yard]))
		if ECONOMY.shipyard_queue_count(system, selected_yard) >= ECONOMY.SHIPYARD_QUEUE_LIMIT:
			command_card_ui.add_build_blocker(button, "Shipyard queue full (%d/%d)" % [ECONOMY.shipyard_queue_count(system, selected_yard), ECONOMY.SHIPYARD_QUEUE_LIMIT])
		if not owned:
			command_card_ui.add_build_blocker(button, "Requires an owned shipyard")
		command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nRight-click: %s autobuild" % ("Disable" if auto else "Enable"))
	var rally: Dictionary = yard.get("rally", {})
	var rally_button: Button = yard_commands["rally"]
	rally_button.disabled = not owned
	rally_button.set_pressed_no_signal(pending_command == "rally")
	yard_commands["clear"].disabled = not owned or rally.is_empty()
	for target_level in [2, 3]:
		var upgrade: Button = yard_upgrades[target_level]
		var eligible: bool = level == target_level - 1
		upgrade.disabled = not owned or not eligible or not _yard_can_upgrade(system, selected_yard)
		command_card_ui.set_build_available(upgrade, not upgrade.disabled)
		if level >= target_level:
			_set_cost_tooltip(upgrade, ECONOMY.size_name(target_level) + " unlocked")
			command_card_ui.add_build_blocker(upgrade, "Already unlocked")
		else:
			var hint: String = "Upgrade to %s · %.0f s\nRequires %s resident population for this yard\nUnlocks %s ships · %.1f× build speed\n+%.0f HP · Fully repairs yard" % [ECONOMY.size_name(target_level), ECONOMY.nominal_work("yard_upgrade", target_level), UI_TEXT.compact_amount(ECONOMY.SHIPYARD_POPULATION[selected_yard]), ECONOMY.size_name(target_level), ECONOMY.yard_speed(target_level) / ECONOMY.yard_speed(1), ECONOMY.YARD_HP]
			if not eligible:
				hint += "\nRequires " + ECONOMY.size_name(target_level - 1) + " shipyard"
			_set_cost_tooltip(upgrade, hint, ECONOMY.base_recipe_cost("yard_upgrade", target_level), 0.0, _available_cost_resources(system, selected_yard))
			if not operating:
				command_card_ui.add_build_blocker(upgrade, hint.get_slice("\n", 1))
			if not eligible:
				command_card_ui.add_build_blocker(upgrade, "Requires " + ECONOMY.size_name(target_level - 1) + " shipyard")
			if ECONOMY.shipyard_queue_count(system, selected_yard) >= ECONOMY.SHIPYARD_QUEUE_LIMIT:
				command_card_ui.add_build_blocker(upgrade, "Shipyard queue full")
			if ECONOMY.has_queued_job(system, "yard_upgrade", str(selected_yard)):
				command_card_ui.add_build_blocker(upgrade, "Upgrade already queued")
			if not owned:
				command_card_ui.add_build_blocker(upgrade, "Requires an owned shipyard")


func _job_icon(job: Dictionary, owner: int) -> Texture2D:
	if ECONOMY.SHIP_KINDS.has(job["kind"]):
		return hull_art.production_icon(str(job["kind"]), _empire_color(owner), 44)
	if job["kind"] == "yard_upgrade":
		return command_card_ui.icon("upgrade", 44)
	return command_card_ui.icon(str(job["target"]) if job["kind"] in ["economy_building", "production"] else str(job["kind"]), 44)

func _refresh_station_queue(system: Dictionary, owned: bool) -> void:
	var jobs: Array = []
	for job in system["queue"]:
		if int(job["size"]) == 0 and job["kind"] != "yard_upgrade":
			jobs.append(job)
	station_queue_panel.show()
	station_queue_heading.text = "Queue (%d/%d)" % [jobs.size(), ECONOMY.STATION_QUEUE_LIMIT]
	var active_id: int = int(jobs[0]["id"]) if not jobs.is_empty() else -1
	queue_view.refresh(station_queue, station_queue_rows, system, jobs, owned, active_id, _button, _cancel_job, _job_icon, _planet())

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
	var bodies: Array = celestial_view.system_visual(selected, _state())["bodies"]
	var lines: PackedStringArray = []
	for resource in ECONOMY.ACTIVE_PRODUCTION:
		var sources: Array = planet_traffic.production_sources(bodies, resource)
		if not sources.has(selected_body):
			continue
		var output: float = planet_traffic.production_rate(system, resource) / float(sources.size())
		lines.append("%s · %.2f/yr" % [resource, output])
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

var fog_state := FOG_OF_WAR.new()
var territory_view := TERRITORY_VIEW.new()
var fog_overlay: Control
var queued_order_overlay: Control

func _update_fog(state: Dictionary) -> void:
	fog_state.update(state, _me(), session.get("motion_revision"), Vector2.ZERO if state.is_empty() else _map_size())

func _fog_visible(point: Vector2) -> bool:
	return fog_state.is_visible(point, _map_size())

func _draw_queued_order_overlay() -> void:
	if session == null:
		return
	var state: Dictionary = _state()
	if state.is_empty():
		return
	_begin_draw_projection()
	_draw_command_overlay_content(state)
	_draw_projection_active = false

# Command intent is UI, not world geometry. Keep it above all fog, including
# unexplored space, while limiting live entity targets to observed information.
func _draw_command_overlay_content(state: Dictionary) -> void:
	var viewport_bounds := Rect2(Vector2.ZERO, map_canvas.size)
	var poses: Dictionary = {}
	var service_refs: Dictionary = {}
	var all_refs: Dictionary = _frame_service_refs(state)
	if not selected_units.is_empty():
		poses = _ship_poses(state)
		for id in all_refs:
			var ref: Dictionary = all_refs[id]
			var own: bool = int(ref.get("owner", -1)) == _me()
			var visible: bool = poses.has(id) if ref.get("kind", "") == "ship" else _fog_visible(ref.get("position", Vector2.INF))
			if own or visible:
				service_refs[id] = ref
	_draw_construction_preview(state)
	for ref in _selected_yards(state, true):
		var rally: Dictionary = state["planets"][ref.x]["yards"][ref.y].get("rally", {})
		if not rally.is_empty():
			var start: Vector2 = _screen_point(ECONOMY.shipyard_position(state, ref.x, ref.y, float(state["elapsed"])))
			var target: Vector2 = _screen_point(rally["point"])
			var rally_tint := Color("#ff605c")
			order_view.draw_command_line(queued_order_overlay, start, target, Color(rally_tint, 0.65))
			var pole_top: Vector2 = target + Vector2(0, -23)
			var flag := PackedVector2Array([pole_top, pole_top + Vector2(15, 0), pole_top + Vector2(10, 5), pole_top + Vector2(15, 10), pole_top + Vector2(0, 10)])
			queued_order_overlay.draw_line(target, pole_top, Color("#111b26"), 4.0, true)
			queued_order_overlay.draw_line(target, pole_top, rally_tint, 2.0, true)
			queued_order_overlay.draw_colored_polygon(flag, rally_tint)
			flag.append(flag[0])
			queued_order_overlay.draw_polyline(flag, Color("#111b26"), 1.0, true)
	for gate in state["ships"]:
		if gate.get("kind", "") != "warp_gate" or int(gate["owner"]) != _me():
			continue
		var target: Dictionary = all_refs.get(int(gate.get("warp_destination", -1)), {}).get("entity", {})
		if target.get("kind", "") == "warp_gate" and int(target["owner"]) == _me():
			queued_order_overlay.draw_line(_screen_point(gate["position"]), _screen_point(target["position"]), Color("#855bbf80"), 2.0, true)
	if not selected_units.is_empty():
		order_view.draw_ship_target_rings(state, poses, service_refs, selected_units, selected_ship_id)
	if selected_units.size() > 1:
		order_view.draw_group_formation_ghosts(state, viewport_bounds, selected_units)
	if selected_units.size() == 1:
		var order_graph: Dictionary = ECONOMY.military_graph(state)
		var drawn_sectors: Dictionary = {}
		for craft in state["ships"]:
			var id: int = int(craft["id"])
			if not selected_units.has(id) or not poses.has(id) or int(craft["owner"]) != _me():
				continue
			var start: Vector2 = poses[id]["point"]
			if selected_units.size() == 1:
				order_view.draw_single_command_line(state, order_graph, craft, start, poses, service_refs)
			var active_order: Dictionary = craft.get("unit_order", {})
			var order_tint: Color = order_view.order_color(craft, active_order)
			if craft.has("patrol_from"):
				var from: Vector2 = _screen_point(craft["patrol_start_point"])
				var to: Vector2 = _screen_point(craft["patrol_end_point"])
				if (craft.get("patrol_waypoints", []) as Array).is_empty():
					order_view.draw_command_line(queued_order_overlay, from, to, Color("#b880fa"))
				order_view.draw_formation_order_ghost(craft, active_order, viewport_bounds.grow(60.0 * maxf(0.42, _ship_scale())))
			elif craft.has("launch_rally") and not bool(craft.get("retreating", false)):
				var destination: Vector2 = _screen_point(craft["launch_rally"]["point"])
				var rally_tint := Color("#ff605c")
				order_view.draw_command_route(order_graph, craft, start, destination, rally_tint)
				order_view.draw_destination_ghost(craft["kind"], destination, destination - start, rally_tint)
			elif active_order.get("kind", "") == "follow" and poses.has(int(active_order["target"])):
				var destination: Vector2 = poses[int(active_order["target"])]["point"]
				order_view.draw_command_route(order_graph, craft, start, destination, HUD.ACCENT)
			elif active_order.get("kind", "") == "colonize" and ECONOMY.unit_order_running(craft):
				var star: int = int(active_order["target"])
				if star >= 0 and star < state["planets"].size():
					var center: Vector2 = _screen_point(state["map"]["points"][star])
					queued_order_overlay.draw_arc(center, 4.5, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.65), 0.9, true)
			elif active_order.get("kind", "") in ["sector", "sector_entry"] and ECONOMY.unit_order_running(craft):
				order_view.draw_sector_target(order_graph, int(active_order["target"]), order_tint, drawn_sectors)
			elif active_order.get("kind", "") == "position" and ECONOMY.unit_order_running(craft):
				var endpoint: Vector2 = ECONOMY.unit_order_point(state, order_graph, craft, active_order)
				if endpoint.is_finite():
					var destination: Vector2 = _screen_point(endpoint)
					order_view.draw_destination_ghost(craft["kind"], destination, active_order.get("heading", destination - start), order_tint)
			elif craft.has("local_move_target") and not bool(craft.get("retreating", false)) and active_order.get("kind", "") not in ["attack", "follow", "repair", "deposit", "salvage", "mine", "warp_travel"]:
				var destination: Vector2 = _screen_point(craft["local_move_target"])
				order_view.draw_destination_ghost(craft["kind"], destination, active_order.get("heading", destination - start), order_tint)
	if selected_units.size() > 1:
		order_view.draw_group_command_line(state, poses, service_refs, selected_units, queued_order_overlay)
	if not selected_units.is_empty():
		# The queue renderer cheaply skips ships without queued/patrol legs.
		order_view.draw_queued_chains(queued_order_overlay, state, poses, service_refs, selected_units, viewport_bounds, _fog_visible)
	order_view.draw_formation_preview(state, formation_button, formation_length, formation_mode, formation_path, _formation_orders, _selected_owned_units)
	if selecting_units and selection_start.distance_to(selection_end) > 5.0:
		var rect: Rect2 = Rect2(selection_start, selection_end - selection_start).abs()
		queued_order_overlay.draw_rect(rect, Color(HUD.ACCENT, 0.12))
		queued_order_overlay.draw_rect(rect, HUD.ACCENT, false, 1.0)

func _draw_construction_preview(state: Dictionary) -> void:
	if pending_command not in ["build_depot", "build_cannon", "build_wall"] or match_menu.visible or (is_instance_valid(codex) and codex.visible):
		return
	var mouse: Vector2 = map_canvas.get_local_mouse_position()
	if not _in_visible_playfield(mouse) or notice_ui.contains_point(map_canvas.get_global_mouse_position()):
		return
	var point: Vector2 = _world_point(mouse)
	if pending_command == "build_wall":
		var start: Vector2 = wall_drag_start if wall_drag_start.is_finite() else point
		var points: PackedVector2Array = ECONOMY.wall_preview_points(state, _me(), start, point)
		order_view.draw_wall_preview(points, queued_order_overlay)
	else:
		var kind: String = "resource_depot" if pending_command == "build_depot" else "defense_cannon"
		order_view.draw_destination_ghost(kind, mouse, Vector2.UP, HUD.ACCENT, queued_order_overlay, true)

func _draw_fog() -> void:
	_begin_draw_projection()
	_draw_fog_content()
	_draw_projection_active = false

func _draw_fog_content() -> void:
	if fog_state.texture == null:
		return
	var offset: Vector2 = _screen_point(Vector2.ZERO)
	var scale: float = _fit() * camera.zoom
	var bounds := Rect2(Vector2.ZERO, map_canvas.size)
	fog_state.draw(fog_overlay, bounds, Rect2(offset, _map_size() * scale), _map_size())

func _draw_rock_selection(canvas: Control, rock: Dictionary, scale: float, position: Vector2) -> void:
	var fraction: float = float(rock["remaining"]) / maxf(ECONOMY.EPS, float(rock["initial"]))
	var radius: float = maxf(4.0, float(rock["radius"]) * scale * sqrt(clampf(fraction, 0.0, 1.0)) + 3.0)
	canvas.draw_arc(_screen_point(position), radius, 0.0, TAU, 24, Color(HUD.ACCENT, 0.70), 0.8, true)

# Names are static generated map geography, not live tactical information.
func _ship_visible(state: Dictionary, ship: Dictionary) -> bool:
	if state.get("eliminated", []).has(_me()):
		return true
	var team: int = ECONOMY.combat_group(state, _me())
	if ECONOMY.shares_group_vision(state, team, ECONOMY.combat_group(state, int(ship["owner"]))):
		return true
	return _fog_visible(ship.get("position", Vector2.INF)) and ECONOMY.ship_visible_to_team(state, ship, team)

func _selected_ship(state: Dictionary) -> Dictionary:
	if selected_ship_id < 0:
		return {}
	for ship in state.get("ships", []):
		if int(ship["id"]) == selected_ship_id and _ship_visible(state, ship):
			return ship
	return {}

# Keep a bound callable for the tactical alert tracker.
func _ship_kind_name(kind: String) -> String:
	return UI_TEXT.ship_kind_name(kind)

func _build_field_command_card(parent: Container) -> void:
	field_command_grid = command_card_ui.create_grid(parent)
	# Keep the bottom row for persistent modes, as on ship cards.
	while field_command_grid.get_child_count() < 12:
		command_card_ui.add_spacer(field_command_grid)
	for key in ["enabled", "Metals", "Crystals"]:
		var slot: Control = command_card_ui.add_spacer(field_command_grid)
		var button := Button.new()
		slot.add_child(button)
		var caption: String = "Mining" if key == "enabled" else key
		var art: Texture2D = command_card_ui.icon("auto_mine") if key == "enabled" else HUD.resource_icon(key, 32)
		command_card_ui.set_face(button, caption, art)
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
		hotkeys.register(button, {"enabled": KEY_G, "Metals": KEY_M, "Crystals": KEY_C}[key], "Asteroid Field", "field_" + key, caption)
	command_card_ui.fill_grid(field_command_grid)
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
	if str(session.get("phase")) != "match" or state.is_empty() or selected_field < 0 or selected_rock >= 0 or not ECONOMY.discovered(state, _me(), "fields", selected_field):
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
		var detail: String = "Allow automatic mining in this field." if key == "enabled" else "Allow Harvesters to mine " + key + " here."
		command_card_ui.set_hint(button, "%s · %s\n%s\nClick to toggle [%s]" % [caption, "On" if enabled else "Off", detail, hint])

func _command_icon(path: String, pixels: int = 32) -> Texture2D:
	var image := Image.new()
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#c5e5f5" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">' + path + '</g></svg>'
	image.load_svg_from_string(svg, float(pixels) / 32.0)
	return ImageTexture.create_from_image(image)

func _command_slot(id: String, hint: String, action: Callable, existing_slot: Control = null) -> Button:
	var button := CostButton.new()
	command_card_ui.register_info(button, hint)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = command_card_ui.icon({"auto_repair": "repair", "auto_trade": "trade", "deliver_farm": "unload"}.get(id, id))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	command_card_ui.set_hint(button, hint + "\n" + UI_COMMAND_DETAILS.get(id, ""))
	button.toggle_mode = true
	button.pressed.connect(action)
	var slot: Control = existing_slot if existing_slot != null else command_card_ui.add_spacer(command_card)
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
	hotkeys.register(button, {"move": KEY_M, "stop": KEY_S, "hold": KEY_H, "patrol": KEY_P, "attack": KEY_A, "load": KEY_L, "unload": KEY_D, "repair": KEY_R, "auto_explore": KEY_X, "auto_wander": KEY_W, "auto_mine": KEY_G, "auto_salvage": KEY_V, "auto_repair": KEY_B, "auto_trade": KEY_T, "auto_farm": KEY_N, "deliver_farm": KEY_E, "collect": KEY_C, "guard": KEY_U, "transform": KEY_J, "auto_retreat": KEY_K, "scan": KEY_Q, "build_depot": KEY_F, "cancel_site": KEY_Y, "build_cannon": KEY_I, "upgrade_cannon": KEY_O, "build_wall": KEY_Z}[id], "Fleet", "fleet_" + id, hint)
	return button

func _build_command_card(parent: VBoxContainer) -> void:
	command_card = command_card_ui.create_grid(parent)
	_command_slot("move", "Move", _arm_command.bind("move"))
	_command_slot("stop", "Stop", _stop_selected)
	hold_button = _command_slot("hold", "Hold Position", _hold_selected)
	_command_slot("patrol", "Patrol", _arm_command.bind("patrol"))
	_command_slot("attack", "Attack Move", _arm_command.bind("attack"))
	_command_slot("load", "Load Cargo", _arm_command.bind("load"))
	unload_button = _command_slot("unload", "Drop Cargo", _arm_command.bind("unload"))
	_command_slot("repair", "Repair target", _arm_command.bind("repair"))
	_command_slot("deliver_farm", "Deliver Organics to nearest station", _deliver_farm_selected)
	for id in ["collect", "auto_farm", "auto_trade", "auto_repair", "auto_mine", "auto_salvage", "auto_wander", "auto_retreat", "auto_explore"]:
		if id == "auto_retreat":
			command_card_ui.fill_grid(command_card)
			_command_slot("guard", "Guard sector · return to the chosen point after combat", _arm_command.bind("guard"))
			_command_slot("transform", "Transform into Space Station", _transform_selected)
		var mode: String = AUTOCAST_SLOTS[id]
		var title_text: String = "Collect Antimatter" if mode == "collect" else (mode.capitalize() if mode in ["wander", "explore"] else "Auto-" + mode.capitalize())
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

	# Science vessels cannot load cargo; Scan shares that existing slot.
	_command_slot("scan", "Scan · launch a cloaked reconnaissance probe", _arm_command.bind("scan"), command_card.get_child(5)).hide()
	_command_slot("build_depot", "Build Resource Depot · 600 Metals, 40 Crystals", _arm_command.bind("build_depot"), command_card.get_child(4)).hide()
	_command_slot("cancel_site", "Cancel unfinished construction", _arm_command.bind("cancel_site"), command_card.get_child(8)).hide()
	_command_slot("build_cannon", "Build Defense Cannon · 500 Metals, 60 Crystals", _arm_command.bind("build_cannon"), command_card.get_child(3)).hide()
	_command_slot("upgrade_cannon", "Upgrade completed Defense Cannon", _arm_command.bind("upgrade_cannon"), command_card.get_child(7)).hide()
	_command_slot("build_wall", "Build Wall · click node or drag a connected chain", _arm_command.bind("build_wall"), command_card.get_child(9)).hide()

func _autocast_units(state: Dictionary, mode: String) -> Array:
	var units: Array = []
	for ship in _selected_ship_entries(state):
		if _command_entry(ship) and ECONOMY.supports_autocast(ship, mode):
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
	# Wander always occupies bottom-right; reuse the repair slot for Trade
	# when the active hull type does not support Repair.
	if command_buttons.has("auto_trade") and command_buttons.has("auto_repair"):
		var trade: Button = command_buttons["auto_trade"]
		var desired_slot: Control = command_card.get_child(11 if not _autocast_units(state, "repair").is_empty() else 12)
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
		var has_fighters: bool = _selected_ship_entries(state).any(func(craft: Dictionary) -> bool: return _command_entry(craft) and craft["kind"] in ECONOMY.MILITARY_KINDS)
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
	if command_buttons.has("auto_explore"):
		var explore: Button = command_buttons["auto_explore"]
		var extra: Control = explore.get_parent()
		if extra != command_card.get_child(14):
			explore.reparent(command_card.get_child(14), false)
			explore.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			extra.hide()
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
		var title_text: String = "Collect Antimatter" if mode == "collect" else (mode.capitalize() if mode in ["wander", "explore"] else "Auto-" + mode.capitalize())
		var status: String = "Off" if enabled_count == 0 else ("On" if enabled_count == units.size() else "%d/%d on" % [enabled_count, units.size()])
		var speed: float = maxf(1.0, float(state.get("time_speed", 1)))
		if remaining > ECONOMY.EPS:
			status += " · %.1f s remaining%s" % [remaining / speed, " (paused)" if int(state.get("time_speed", 1)) == 0 else ""]
		var shortcut: String = str(button.get_meta("hotkey", ""))
		command_card_ui.set_hint(button, "%s · %s\nToggle [%s]" % [title_text, status, shortcut])
		if duration > 0.0:
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nCooldown: %.1f s" % duration)
		if mode in ["mine", "salvage", "repair", "trade", "wander", "explore"]:
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\n" + UI_COMMAND_DETAILS.get(id, ""))
		if mode == "collect":
			command_card_ui.set_hint(button, "%s · Auto: %s\n[%s] Select Pulsar · Right-click: Auto\n1 antimatter / %.0f s · Cooldown %.0f s" % [title_text, status, shortcut, ECONOMY.SCIENCE_COLLECTION_YEARS, duration])
		elif mode == "retreat":
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nRetreat at %.0f%% HP; resume after repair." % (100.0 * ECONOMY.WITHDRAW_HP / ECONOMY.SHIP_HP))
		elif mode == "farm":
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nProduces %.1f/s; delivers a full hold when idle." % ECONOMY.COLONY_FARM_RATE)

func _arm_command(mode: String) -> void:
	wall_drag_start = Vector2.INF
	wall_drag_end = Vector2.INF
	pending_command = mode if pending_command != mode else ""
	_refresh_command_mode()

func _draw_active_command(border: Control) -> void:
	border.draw_rect(Rect2(Vector2.ONE * 2.0, border.size - Vector2.ONE * 4.0), Color("#7de4ff"), false, 2.0)

func _active_command(ship: Dictionary) -> String:
	if bool(ship.get("retreating", false)):
		return ""
	if bool(ship.get("holding", false)):
		return "hold"
	if not ECONOMY.unit_order_running(ship):
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
	for ship in _selected_ship_entries(_state()):
		if _command_entry(ship):
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
		var target: int = _entity_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		var depot: Dictionary = ECONOMY.service_targets(state, target).get(target, {}).get("entity", {})
		if depot.get("kind", "") == "resource_depot" and ECONOMY.static_complete(depot):
			var loaders: Array[int] = []
			for craft in _selected_ship_entries(state):
				if _command_entry(craft) and craft["kind"] in ["ship", "construction_ship"] and ECONOMY.cargo_free(craft) > ECONOMY.EPS:
					loaders.append(int(craft["id"]))
			_issue_order(loaders, {"kind": "load_depot", "target": target}, false)
		elif wreck >= 0:
			var eligible: Array[int] = []
			for craft in _selected_ship_entries(state):
				if _command_entry(craft) and ECONOMY.supports_autocast(craft, "salvage") and ECONOMY.cargo_free(craft) > ECONOMY.EPS:
					eligible.append(int(craft["id"]))
			_issue_order(eligible, {"kind": "salvage", "target": wreck}, append)
	elif mode == "guard":
		var state: Dictionary = _state()
		var graph: Dictionary = ECONOMY.military_graph(state)
		var world: Vector2 = minimap_hint.get("world", _world_point(point))
		var node: int = ECONOMY.patrol_node(state, graph, _me(), world)
		var ids: Array[int] = []
		for craft in _selected_ship_entries(state):
			if _command_entry(craft) and craft["kind"] in ECONOMY.MILITARY_KINDS:
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
			if ECONOMY.science_target_valid(state, graph, craft, field):
				eligible.append(int(craft["id"]))
		_issue_order(eligible, {"kind": "collect", "target": field}, append)
	elif mode in ["build_depot", "build_cannon"]:
		_issue_order(_selected_owned_units(_state()), {"kind": mode, "point": minimap_hint.get("world", _world_point(point))}, false)
	elif mode in ["cancel_site", "upgrade_cannon"]:
		var target: int = _entity_hit(_state(), point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		if target >= 0:
			_issue_order(_selected_owned_units(_state()), {"kind": mode, "target": target}, false)
	elif mode == "scan":
		var scan_state: Dictionary = _state()
		var world: Vector2 = minimap_hint.get("world", _world_point(point))
		var ready: Array[int] = []
		for craft in _selected_ship_entries(scan_state):
			if _command_entry(craft) and ECONOMY.science_scan_ready(scan_state, craft):
				ready.append(int(craft["id"]))
		_issue_order(ready, {"kind": "scan", "point": world}, false)
	elif mode == "repair":
		var target: int = _entity_hit(_state(), point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		if target != -1:
			var miners: Array[int] = _selected_repairers()
			miners.erase(target)
			_issue_order(miners, {"kind": "repair", "target": target}, append)
	elif mode == "unload":
		var state: Dictionary = _state()
		var target: int = _entity_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
		var ref: Dictionary = ECONOMY.service_targets(state).get(target, {})
		var owned: Array[int] = _selected_owned_units(state)
		var orders: Array = []
		for ship in state["ships"]:
			if not owned.has(int(ship["id"])) or ECONOMY.cargo_total(ship) <= ECONOMY.EPS:
				continue
			if ECONOMY.friendly_service_target(state, _me(), ref):
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

func _draw_damage_bar(point: Vector2, radius: float, fraction: float, shield: float = -1.0) -> void:
	var show_health: bool = fraction < 1.0
	var show_shield: bool = shield >= 0.0 and shield < 1.0
	if not show_health and not show_shield:
		return
	var width: float = clampf(radius * 2.0, 18.0, 100.0)
	var base: Vector2 = point + Vector2(-width * 0.5, -maxf(8.0, radius) - 6.0)
	if show_health:
		world_batches.queue_health_rect(Rect2(base - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#0a111b"))
		world_batches.queue_health_rect(Rect2(base, Vector2(width, 3.0)), Color("#283748"))
		world_batches.queue_health_rect(Rect2(base, Vector2(width * clampf(fraction, 0.0, 1.0), 3.0)), _health_color(fraction))
	if show_shield:
		var shield_base: Vector2 = base + Vector2(0, 4) if show_health else base
		world_batches.queue_health_rect(Rect2(shield_base - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color("#0a111b"))
		world_batches.queue_health_rect(Rect2(shield_base, Vector2(width, 3.0)), Color("#203f5c"))
		world_batches.queue_health_rect(Rect2(shield_base, Vector2(width * clampf(shield, 0.0, 1.0), 3.0)), Color("#6fbaff"))

func _shield_fraction(entity: Dictionary) -> float:
	var maximum: float = float(entity.get("shield_max", 0.0))
	return float(entity.get("shield", 0.0)) / maximum if maximum > 0.0 else -1.0

func _health_color(fraction: float) -> Color:
	return Color("#e45b60") if fraction < 0.2 else (Color("#eac64a") if fraction < 0.5 else Color("#55c88b"))

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
	selected_rock = -1
	camera.following = false
	pending_command = ""
	_refresh()

func _refresh_field_panels(state: Dictionary) -> void:
	if selected_rock >= 0:
		var rock: Dictionary = fog_state.rock_at(selected_field, selected_rock)
		ship_title.text = "Asteroid"
		ship_detail.text = "Unsurveyed" if not bool(rock.get("surveyed", false)) else "%s · %s" % [str(rock["resource"]), UI_TEXT.resource_amount(float(rock["remaining"]))]
		ship_detail.tooltip_text = ""
		fleet_title.hide()
		fleet_detail.hide()
		field_command_grid.hide()
		command_card.hide()
		fleet_cargo_footer.hide()
		pending_command = ""
		_refresh_command_mode()
		return
	var field: Dictionary = fog_state.field_view(state, selected_field, _map_size())
	ship_title.text = _poi_name(state["planets"].size() + selected_field)
	if field.is_empty():
		ship_detail.text = "Survey unavailable"
		field_command_grid.hide()
		command_card.hide()
		return
	var special: bool = bool(field.get("antimatter", false))
	var stock: Dictionary = ECONOMY.field_inventory(field)
	var total: float = float(stock["Metals"]) + float(stock["Crystals"])
	if special:
		ship_detail.text = "Science vessels collect 1 unit / 30 yr" if float(stock[ECONOMY.ANTIMATTER]) >= 1.0 - ECONOMY.EPS else "Depleted"
	elif total <= ECONOMY.EPS:
		ship_detail.text = "Depleted"
	else:
		var metals: int = roundi(100.0 * float(stock["Metals"]) / total)
		ship_detail.text = "Metals ~%d%% · %s\nCrystals ~%d%% · %s" % [metals, UI_TEXT.resource_amount(float(stock["Metals"])), 100 - metals, UI_TEXT.resource_amount(float(stock["Crystals"]))]
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

func _refresh_ship_panels(state: Dictionary, ship: Dictionary) -> void:
	field_command_grid.hide()
	var kind: String = ship.get("kind", "ship")
	var owner: int = int(ship["owner"])
	ship_title.text = ("Pirate " if int(ship["owner"]) == ECONOMY.PIRATE_OWNER else ("Independent " if bool(ship.get("rogue", false)) else "")) + UI_TEXT.ship_kind_name(kind)
	# Details describe the hull and its statistics, not the current order.
	var status: String = ""
	if kind == "colony_ship":
		status = "Organics %.1f / %.0f" % [float(ship["cargo"].get("Organics", 0.0)), ECONOMY.COLONY_CAPACITY]
	elif kind == "science_ship" and ECONOMY.cargo_total(ship) > ECONOMY.EPS:
		status = "Antimatter: 1 unit"
	if ECONOMY.is_static_structure(ship):
		status = "Construction: %.0f%%" % (float(ship.get("build_progress", 0.0)) * 100.0)
		if kind == "defense_cannon":
			status = "Defense Cannon Lv %d · %.0f damage · R%.0f" % [ECONOMY.cannon_level(ship), ECONOMY.cannon_damage(ship), ECONOMY.cannon_range(ship)]
			if not ECONOMY.static_complete(ship):
				status += "\nConstruction: %.0f%%" % (float(ship.get("build_progress", 0.0)) * 100.0)
		elif kind in ["wall_node", "wall_segment"]:
			status = ("Wall Node" if kind == "wall_node" else "Wall Segment") + (" · Complete" if ECONOMY.static_complete(ship) else " · %.0f%%" % (float(ship["build_progress"]) * 100.0))
		elif ECONOMY.static_complete(ship):
			status = "Resource Depot"
			for resource in ECONOMY.RESOURCES:
				status += "\n%s: %.1f / %.1f" % [resource, float(ship["cargo"].get(resource, 0.0)), ECONOMY.depot_capacity(resource)]
	if ECONOMY.armed(ship):
		status += "\nKills: %d" % int(ship.get("kills", 0))
	if ECONOMY.cargo_capacity(kind) > ECONOMY.EPS:
		var picked: float = float(ship.get("tons_picked", 0.0))
		var dropped: float = float(ship.get("tons_dropped", 0.0))
		status += "\nCargo handled: %.1f (↑ %.1f / ↓ %.1f)" % [picked + dropped, picked, dropped]
	if kind == "colony_ship":
		status += "\nFood produced: %.1f" % float(ship.get("food_produced", 0.0))
	if kind == "warp_gate":
		var destination: Dictionary = ECONOMY.warp_gate(state, owner, int(ship.get("warp_destination", -1)))
		status = "Linked to %s" % _system_name(int(destination["at"])) if not destination.is_empty() else "Unlinked · deploy another gate"
	if owner == _me() and ECONOMY.hull_upkeep(state, ship) > 0.0:
		status += "\nUpkeep: %.0f GC/yr" % ECONOMY.hull_upkeep(state, ship)
		if ship.has("unpaid_since"):
			status += " · Unpaid %.1f yr" % ECONOMY.unpaid_wage_years(state, ship)
	var morphing: bool = ECONOMY.colony_morphing(ship)
	if morphing:
		ship_title.text = "Morphing · Space Station"
		status = ""
	ship_detail.text = status.strip_edges()
	ship_detail.tooltip_text = ""
	var multiple: bool = selected_units.size() > 1
	colony_morph_progress.visible = morphing and not multiple
	if morphing:
		colony_morph_progress.value = 100.0 * float(ship["colony_transform_progress"]) / ECONOMY.COLONY_TRANSFORM_TIME
	ship_title.visible = not multiple
	ship_detail.visible = not multiple and not ship_detail.text.is_empty()
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
		loaded_owned = loaded_owned or (int(craft["owner"]) == _me() and ECONOMY.cargo_total(craft) > ECONOMY.EPS)
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			cargo[resource] = float(cargo.get(resource, 0.0)) + float(craft.get("cargo", {}).get(resource, 0.0))
	if not multiple:
		selected_crew = float(ship.get("crew", 0.0))
	ship_population.text = ("Total crew: " if multiple else "Crew: ") + UI_TEXT.crew_text(selected_crew)
	ship_population.get_parent().show()
	_sync_command_kind(state)
	command_card.visible = not command_kind.is_empty()
	loaded_owned = false
	var combat_owned: bool = false
	var can_load: bool = false
	var has_cargo_hold: bool = false
	var has_farm: bool = false
	var loaded_farm: bool = false
	var has_repairers: bool = not _selected_repairers().is_empty()
	for craft in _selected_ship_entries(state):
		if _command_entry(craft):
			loaded_owned = loaded_owned or ECONOMY.cargo_total(craft) > ECONOMY.EPS
			combat_owned = combat_owned or ECONOMY.armed(craft)
			can_load = can_load or ((ECONOMY.supports_autocast(craft, "salvage") or craft["kind"] == "construction_ship") and ECONOMY.cargo_free(craft) > ECONOMY.EPS)
			has_cargo_hold = has_cargo_hold or ECONOMY.supports_autocast(craft, "salvage") or craft["kind"] == "construction_ship"
			has_farm = has_farm or craft["kind"] == "colony_ship"
			loaded_farm = loaded_farm or (craft["kind"] == "colony_ship" and ECONOMY.cargo_total(craft) > ECONOMY.EPS)
	for id in command_buttons:
		var button: Button = command_buttons[id]
		button.visible = (id != "repair" or has_repairers) and (id not in ["load", "unload"] or has_cargo_hold)
		button.disabled = command_kind.is_empty() or owned_count == 0 or (id == "attack" and not combat_owned) or (id == "patrol" and not _selected_ship_entries(state).any(func(craft: Dictionary) -> bool: return _command_entry(craft) and craft["kind"] in ECONOMY.MILITARY_KINDS)) or (id == "repair" and not has_repairers) or (id == "load" and not can_load) or (id == "unload" and not loaded_owned)
	for build_id in ["build_depot", "cancel_site", "build_cannon", "upgrade_cannon", "build_wall"]:
		command_buttons[build_id].visible = command_kind == "construction_ship"
		command_buttons[build_id].disabled = not command_buttons[build_id].visible or owned_count == 0
	if command_kind == "construction_ship":
		command_buttons["attack"].hide()
		command_buttons["patrol"].hide()
	var scan: Button = command_buttons["scan"]
	scan.visible = command_kind == "science_ship"
	scan.disabled = not scan.visible or not _selected_ship_entries(state).any(func(craft: Dictionary) -> bool: return _command_entry(craft) and ECONOMY.science_scan_ready(state, craft))
	command_card_ui.set_hint(scan, "Scan [Q] · %.0f-year cloaked probe · %.0f-year cooldown" % [ECONOMY.PROBE_LIFETIME, ECONOMY.SCAN_COOLDOWN])
	var transform: Button = command_buttons["transform"]
	var transform_extra: Control = command_card.get_child(17)
	var transform_slot: Control = transform_extra if has_repairers else command_card.get_child(7)
	if transform.get_parent() != transform_slot:
		transform.reparent(transform_slot, false)
		transform.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var graph: Dictionary = ECONOMY.military_graph(state)
	var science: bool = command_kind == "science_ship" and state.get("objectives", {}).get(_me(), {}).get("rewards", []).has("warp_gate")
	var gate: bool = command_kind == "warp_gate"
	transform.visible = has_farm or science or gate
	transform_extra.visible = transform.visible and has_repairers
	if gate:
		for button in command_buttons.values():
			button.visible = button == transform
			button.disabled = button != transform
		transform.disabled = ECONOMY.warp_gate_choices(state, _me(), int(ship.get("id", -1))).is_empty() or owned_count == 0
		command_card_ui.set_hint(transform, "Cycle link destination [J] · right-click an owned linked gate with ships to travel")
	elif science:
		transform.disabled = not _selected_ship_entries(state).any(func(craft: Dictionary) -> bool: return _command_entry(craft) and ECONOMY.can_build_warp_gate(state, graph, craft))
		command_card_ui.set_hint(transform, "Deploy Warp Gate [J] · 1 antimatter + %.0f GC; one gate per owned system" % ECONOMY.WARP_GATE_CREDIT_COST)
	else:
		transform.disabled = not _selected_ship_entries(state).any(func(craft: Dictionary) -> bool: return _command_entry(craft) and ECONOMY.unit_order_valid(state, graph, craft, {"kind": "transform"}, true))
		command_card_ui.set_hint(transform, "Transform into Space Station [J] · construction fee prepaid with colony ship")
	command_buttons["deliver_farm"].visible = has_farm
	command_buttons["deliver_farm"].disabled = not loaded_farm
	if command_kind.is_empty() or not command_buttons.has(pending_command) or (command_buttons[pending_command] as Button).disabled:
		pending_command = ""
	_refresh_command_mode()
	fleet_title.visible = _command_kinds(state).size() > 1
	fleet_title.text = "%s · Tab" % UI_TEXT.ship_kind_name(command_kind)
	fleet_detail.visible = false
	fleet_cargo_footer.visible = ECONOMY.cargo_total({"cargo": cargo}) > ECONOMY.EPS
	if fleet_cargo_footer.visible:
		for resource in ECONOMY.RESOURCES + [ECONOMY.ANTIMATTER]:
			var amount: float = float(cargo.get(resource, 0.0))
			fleet_cargo_labels[resource].text = "%.0f" % amount
			fleet_cargo_labels[resource].tooltip_text = "%.0f items" % amount if resource == ECONOMY.ANTIMATTER else "%.1f" % amount
			fleet_cargo_labels[resource].get_parent().visible = amount > ECONOMY.EPS

func _build_territory_layer() -> void:
	territory_view.build(self)

func _refresh_territory(state: Dictionary) -> void:
	if state.is_empty():
		territory_view.refresh(state, 0, Vector2.ZERO, Callable(), Callable())
		return
	var fog_started: int = Time.get_ticks_usec() if _profiling_publication else 0
	_update_fog(state)
	if _profiling_publication:
		publication_profile["fog"] = float(Time.get_ticks_usec() - fog_started) / 1000.0
		for key in fog_state.profile:
			publication_profile["fog_" + key] = fog_state.profile[key]
	if territory_view.refresh(state, _me(), _map_size(), _empire_color, _fog_visible):
		_position_territory()

func _position_territory() -> void:
	territory_view.set_geometry(_screen_point(Vector2.ZERO), _map_size() * _fit() * camera.zoom)

func _show_system_rings(index: int) -> bool:
	if index != selected or selected_body >= 0 or selected_yard >= 0 or not building_selection_kind.is_empty():
		return false
	var p: Dictionary = _planet()
	return not p.is_empty() and int(p["owner"]) == 0 and not ECONOMY.has_station(p)

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
	command_card_ui.set_face(station_trade_back, "Return", command_card_ui.icon("return"))
	command_card_ui.set_hint(station_trade_back, "Return")
	hotkeys.register(station_trade_back, KEY_ESCAPE, "Station Trade", "trade_return", "Return")
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
	var state: Dictionary = _state()
	if state.is_empty() or selected < 0 or selected >= state["planets"].size():
		return {}
	if not ECONOMY.discovered(state, _me(), "planets", selected):
		return {}
	return fog_state.system_view(state, selected, _map_size())

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
		var capacity: float = ECONOMY.storage_capacity(p, resource)
		slider.set_stock(stock, capacity, HUD.COLORS[resource])
		trade_stock_labels[resource].text = "%s / %s" % [UI_TEXT.resource_amount(stock, 0, true), UI_TEXT.resource_amount(capacity, 0, true)]
		trade_stock_labels[resource].tooltip_text = "%.1f / %.0f" % [stock, capacity]
		command_card_ui.set_hint(slider, "%s thresholds\nImport below min · Export above max 100%% = %.0f units.%s" % [resource, capacity, "\nEdits apply to all selected owned stations; display shows primary station." if building_selection_kind == "station" and selected_buildings.size() > 1 else ""])
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
	var indices: Array[int] = _owned_station_selection(_state())
	var importing: bool = slider.import_enabled
	var exporting: bool = slider.export_enabled
	for index in indices:
		session.call("request_thresholds", index, resource, minimum, maximum, importing, exporting)

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
	if not resource_hud.is_built():
		return
	var state: Dictionary = _state()
	_update_fog(state)
	ship_motion.invalidate_poses()
	_sync_command_kind(state)
	var phase: String = str(session.get("phase"))
	if phase == "match" and not background_music.playing:
		_play_next_music()
	elif phase != "match" and background_music.playing:
		background_music.stop()
	var seconds: int = maxi(0, floori(float(state.get("elapsed", 0.0))))
	var clock: String = "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
	if match_timer_label.text != clock:
		match_timer_label.text = clock
	resource_hud.refresh(state)
	conquest_ui.refresh(state)
	_refresh_global_selection_buttons(state)
	if empire_ui.dialog_visible():
		empire_ui.refresh(state)
	_refresh_match_result(state)
	var speed_started: int = Time.get_ticks_usec() if _profiling_publication else 0
	developer_tools.refresh_speed(state)
	if _profiling_publication:
		publication_profile["developer_speed"] = float(Time.get_ticks_usec() - speed_started) / 1000.0
	menu_exit.text = "Main menu" if bool(session.get("is_solo")) else ("Return to lobby" if multiplayer.is_server() else "Leave match")
	if phase == "loading" and multiplayer.is_server():
		menu_exit.text = "Cancel start"
	var planets: Array = state.get("planets", [])
	if not initial_selection_done and not planets.is_empty():
		for i in range(planets.size()):
			if int(planets[i]["owner"]) == _me() and bool(planets[i].get("home", false)):
				initial_selection_done = true
				selected = i
				control_group_manager.control_groups[1] = {"kind": "station", "refs": {Vector2i(i, 0): 0}}
				if not planets[i]["yards"].is_empty():
					control_group_manager.control_groups[2] = {"kind": "shipyard", "refs": {Vector2i(i, 0): planets[i]["yards"].size()}}
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
	if selected_field >= 0 and selected_rock >= 0 and (fog_state.rock_at(selected_field, selected_rock).is_empty() or not _fog_visible(fog_state.rock_at(selected_field, selected_rock).get("position", Vector2.INF))):
		selected_field = -1
		selected_rock = -1
	var field_selected: bool = selected_field >= 0 and (selected_rock >= 0 or ECONOMY.discovered(state, _me(), "fields", selected_field))
	var ship_selected: bool = not ship.is_empty()
	if not ship_selected and not field_selected and p.is_empty():
		camera.following = false
	var other_selected: bool = ship_selected or field_selected
	var body_selected: bool = not other_selected and not p.is_empty() and selected_body >= 0 and selected_body < int(p.get("planet_count", 0))
	if not body_selected:
		selected_body = -1
	# Slot indices compact after destruction. Return to the system rather
	# than silently retargeting an upgrade at a different shipyard.
	var yard_selected: bool = not other_selected and not body_selected and not p.is_empty() and selected_yard >= 0 and selected_yard < p.get("yards", []).size() and selected_yard_count == p.get("yards", []).size()
	if not yard_selected:
		if selected_yard >= 0:
			camera.following = false
		selected_yard = -1
	# A claimed sector is represented by its station, not a second selectable
	# sector entity. Keep explicit planet, yard and grouped selections intact.
	var system_live: bool = not p.is_empty() and _fog_visible(state["map"]["points"][selected])
	if not other_selected and not body_selected and not yard_selected and system_live and building_selection_kind.is_empty():
		if ECONOMY.has_station(p):
			building_selection_kind = "station"
			selected_buildings[Vector2i(selected, 0)] = 0
		elif int(p["owner"]) != 0:
			selected = -1
			p = {}
	inspector_panel.visible = true
	overview_panel.visible = true
	empty_selection.visible = false
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_overview.visible = not p.is_empty() and not other_selected and not body_selected and not yard_selected and selected_buildings.size() <= 1
	var grouped_buildings: bool = selected_buildings.size() > 1
	selection_inspector.refresh_portrait(ship, p, body_selected, yard_selected, grouped_buildings, selected_units.size(), selected_yard, selected_body, building_selection_kind)
	selection_inspector.refresh_weapons(ship, p, body_selected, yard_selected, grouped_buildings, selected_units.size(), selected_body, building_selection_kind, ship_overview, ship_detail, body_status, planet_overview)
	body_overview.visible = body_selected and not grouped_buildings
	yard_overview.visible = yard_selected and not grouped_buildings
	var details_parent: HBoxContainer = yard_columns if yard_overview.visible else station_columns
	if station_details.get_parent() != details_parent:
		station_details.reparent(details_parent, false)
		details_parent.move_child(station_details, 0)
	_refresh_building_group(state)
	var own_system: bool = system_live and int(p.get("owner", -1)) == _me()
	var owned_station: bool = not other_selected and not body_selected and not yard_selected and own_system and ECONOMY.has_station(p)
	var right_needed: bool = (field_selected and selected_rock < 0) or (ship_selected and state["ships"].any(func(craft: Dictionary) -> bool: return selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me())) or (yard_selected and not _selected_yards(state, true).is_empty()) or owned_station or (not other_selected and not yard_selected and not body_selected and not grouped_buildings and not p.is_empty() and int(p["owner"]) == 0)
	console_right_body.visible = right_needed
	inspector_panel.self_modulate.a = 1.0
	inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	colony_morph_progress.hide()
	ship_title.visible = other_selected
	ship_detail.visible = other_selected
	selection_inspector.refresh_tiles(state, selected_units, selected_ship_id, _select_tile)
	if not ship_selected and not (yard_selected and not _selected_yards(state, true).is_empty() and pending_command == "rally"):
		pending_command = ""
		_refresh_command_mode()
	fleet_scroll.visible = other_selected
	fleet_overview.visible = other_selected
	field_command_grid.visible = field_selected
	_refresh_depot_controls(ship, phase)
	fleet_title.visible = other_selected
	fleet_detail.visible = other_selected
	fleet_cargo_footer.hide()
	station_queue_panel.hide()
	if yard_selected:
		_refresh_local_resources(p)
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
	var owned: bool = system_live and int(p["owner"]) == _me() and phase == "match"
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
	system_owner_label.tooltip_text = system_owner_label.text
	system_owner_label.add_theme_color_override("font_color", _empire_color(owner).lerp(HUD.MUTED, 0.28))
	_refresh_local_resources(p)
	_update_trade_stock(p)
	if building_selection_kind == "station" and not grouped_buildings:
		_refresh_station_queue(p, owned)
	if owned_station:
		_refresh_station_primary(p, owned)
		_refresh_station_build(p, owned)

func _refresh_local_resources(p: Dictionary) -> void:
	for resource in ECONOMY.RESOURCES:
		var amount: float = float(p["stock"][resource])
		production_values[resource]["stock"].text = UI_TEXT.resource_amount(amount)
		production_values[resource]["level"].text = str(int(p["levels"][resource]) + int(p.get("buildings", {}).get(resource, 0)))
		var percent: int = roundi(100.0 * ECONOMY.production_modifier(p, resource))
		var bonus: Label = production_values[resource]["bonus"]
		bonus.text = "—" if percent == 100 else "%d%%" % (percent - 100) if percent < 100 else "+%d%%" % (percent - 100)
		bonus.add_theme_color_override("font_color", HUD.ACCENT if percent > 100 else (Color("#e4a479") if percent < 100 else HUD.MUTED))
		var annual: float = MATCH_RESOURCE_HUD.resource_delta(p, resource)
		var delta_label: Label = production_values[resource]["rate"]
		MATCH_RESOURCE_HUD.set_resource_delta(delta_label, annual)
	var population: float = float(p["population"])
	var raw: float = float(p["stock"].get(ECONOMY.ANTIMATTER, 0.0))
	raw_antimatter_label.visible = raw > ECONOMY.EPS
	raw_antimatter_label.text = "Antimatter · %.0f" % raw
	raw_antimatter_label.tooltip_text = "%.0f / 1 item stored locally" % raw
	population_label.text = "%s" % UI_TEXT.compact_amount(population)
	var change: float = float(p.get("demographic_rate", ECONOMY.population_growth(p))) - float(p.get("crew_rate", 0.0))
	population_delta_label.text = "(%s%s/yr)" % ["+" if change >= 0.0 else "-", UI_TEXT.compact_amount(absf(change))]
	population_delta_label.add_theme_color_override("font_color", Color("#7cdb9b") if change >= 0.0 else Color("#eb8585"))
	population_label.tooltip_text = ""

func _system_name(index: int) -> String:
	var names: Array = _state().get("map", {}).get("names", [])
	return str(names[index]) if index >= 0 and index < names.size() else "Unknown"

func _refresh_match_result(state: Dictionary) -> void:
	if not is_instance_valid(match_result_dialog):
		return
	var result: Dictionary = state.get("match_result", {})
	if not result.is_empty() and not match_result_shown:
		match_result_shown = true
		if is_instance_valid(codex):
			codex.hide()
		var team: int = int(result["team"])
		var mine: int = ECONOMY.combat_group(state, _me())
		match_result_dialog.title = "Draw" if team == 0 else ("Victory" if mine == team else "Defeat")
		if result.has("winner"):
			match_result_dialog.dialog_text = "No surviving empires." if team == 0 else "%s wins by conquest." % _empire_name(team)
		else:
			match_result_dialog.dialog_text = "No surviving teams." if team == 0 else "Team %d wins by conquest." % team
		match_result_dialog.dialog_text = match_result_dialog.title + "\n" + match_result_dialog.dialog_text
		match_result_dialog.ok_button_text = "Review map"
		match_result_dialog.popup_centered.call_deferred(Vector2i(320, 140))
	elif result.is_empty() and state.get("eliminated", []).has(_me()) and not defeated_shown:
		defeated_shown = true
		if is_instance_valid(codex):
			codex.hide()
		match_result_dialog.title = "Empire defeated"
		match_result_dialog.dialog_text = "Empire defeated\nYour remaining ships will continue autonomously."
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
	resource_hud.hide_hover()
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
	# A hidden target must use last-known ownership; the host still validates
	# the actual destination when the command is issued.
	var preview: Dictionary = fog_state.observed_state(state, _map_size()) if neutral else state
	var id: int = ECONOMY.nearest_idle_colony(preview, _me(), selected) if neutral else -1
	var en_route: bool = neutral and ECONOMY.colony_en_route(state, _me(), selected)
	var auto: bool = ECONOMY.colonize_autocast_enabled(state, _me(), selected)
	# Keep the right-click target enabled even without an available hull.
	send_colony_button.disabled = not neutral or state.get("eliminated", []).has(_me())
	var caption: Label = send_colony_button.get_meta("caption")
	caption.text = "Colony\nEn Route" if en_route else ("Colonize\nAuto" if auto else "Colonize")
	caption.modulate = HUD.ACCENT if auto else Color.WHITE
	var hint: String = "Colony already en route" if en_route else ("Send nearest available Colony to this sector" if id >= 0 else "No available Colonies")
	hint += "\nRight-click: send a Colony Ship as soon as one is available · Auto: " + ("On" if auto else "Off")
	var shortcut: String = str(send_colony_button.get_meta("hotkey", ""))
	command_card_ui.set_hint(send_colony_button, hint if shortcut.is_empty() else hint + "\n[" + shortcut + "]")

func _colonize_autocast_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not send_colony_button.disabled:
		var enabled: bool = ECONOMY.colonize_autocast_enabled(_state(), _me(), selected)
		session.call("request_colonize", -3 if enabled else -2, selected)
		send_colony_button.accept_event()

func _send_colony() -> void:
	if not send_colony_button.disabled:
		# -1 requests authoritative nearest-available selection.
		session.call("request_colonize", -1, selected)

func _reset_view() -> void:
	camera.reset()
	map_canvas.queue_redraw()

# The bottom console reserves a fixed viewport, independent of selection.
func _projection_size() -> Vector2:
	if _draw_projection_active:
		return _draw_projection_size
	# Reserve the console footprint for camera framing, but let stars and
	# planets continue rendering underneath its opaque stepped panels.
	var hud_height: float = console_panel.size.y + 8.0 if is_instance_valid(console_panel) else 0.0
	return Vector2(map_canvas.size.x, maxf(1.0, map_canvas.size.y - hud_height))

func _map_resized() -> void:
	_layout_match_header()
	notice_ui.layout()
	# Resize changes the world-space extent, not the requested camera target.
	camera.zoom = minf(camera.zoom, _max_zoom())
	camera.constrain(_projection_size(), _map_size())
	map_canvas.queue_redraw()
	if is_instance_valid(minimap):
		minimap.queue_redraw()

func _map_size() -> Vector2:
	if _draw_projection_active:
		return _draw_map_size
	return _state().get("map", {}).get("size", MAP.SIZE)

func _fit() -> float:
	if _draw_projection_active:
		return _draw_fit
	return camera.fit(_projection_size(), _map_size())

func _begin_draw_projection() -> void:
	_draw_projection_active = false
	_draw_projection_size = _projection_size()
	_draw_map_size = _map_size()
	_draw_fit = camera.fit(_draw_projection_size, _draw_map_size)
	_draw_world_center = camera.world_center(_draw_map_size)
	_draw_zoom = camera.zoom
	_draw_projection_active = true

func _screen_point(point: Vector2) -> Vector2:
	if _draw_projection_active:
		return _draw_projection_size * 0.5 + (point - _draw_world_center) * _draw_fit * _draw_zoom
	return camera.screen_point(point, _projection_size(), _map_size())

func _world_point(point: Vector2) -> Vector2:
	return camera.world_point(point, _projection_size(), _map_size())

func _camera_world_center() -> Vector2:
	if _draw_projection_active:
		return _draw_world_center
	return camera.world_center(_map_size())

func _camera_center() -> Vector2:
	return _projection_size() * 0.5

func _max_zoom() -> float:
	return camera.max_zoom(size.x, _projection_size(), _map_size())

func _zoom_at(point: Vector2, direction: float) -> void:
	camera.zoom_at(point, direction, size.x, _projection_size(), _map_size())
	map_canvas.queue_redraw()

func _planet_radius(index: int, state: Dictionary) -> float:
	return celestial_view.system_world_radius(index, state) * _fit() * camera.zoom

func _draw_system(index: int, state: Dictionary, pos: Vector2, radius: float, tint: Color, remembered_time: float = -1.0) -> float:
	if not Rect2(Vector2.ZERO, map_canvas.size).grow(radius + 32.0).has_point(pos):
		return 0.0
	var system: Dictionary = state["planets"][index]
	var remembered: bool = remembered_time >= 0.0
	var orbit_elapsed: float = remembered_time if remembered else celestial_view.orbit_time(state)
	var color: Color = celestial_view.planet_color(system)
	var star_radius: float = celestial_view.star_draw_radius(radius)
	var star_color: Color = Color("#fff0c4").lerp(color.lightened(0.25), 0.30) if ECONOMY.has_planets(system) else Color("#8ea2bc")
	var detail: float = celestial_view.planet_detail_opacity(index, radius)
	if detail > 0.001:
		var bodies: Array = celestial_view.system_visual(index, state)["bodies"]
		for slot in range(bodies.size()):
			var body: Dictionary = bodies[slot]
			var point: Vector2 = pos + celestial_view.body_position(body, radius, orbit_elapsed)
			var body_radius: float = maxf(1.4, radius * float(body["size"]) * 0.55)
			if Rect2(Vector2.ZERO, map_canvas.size).grow(body_radius).has_point(point):
				if body_radius >= 5.0:
					celestial_view.draw_lit_body(map_canvas, Vector2i(index, slot), body, point, body_radius, detail, world_batches.planet_material(body))
				else:
					map_canvas.draw_circle(point, body_radius, Color(celestial_view.body_base_color(body).darkened(0.18), detail), true)
				if system.get("pds", {}).has(slot):
					celestial_view.draw_pds_frame(point, body_radius, detail, map_canvas)
					if detail >= 0.5:
						_draw_damage_bar(point, body_radius + 4.0, float(system["pds"][slot].get("hp", ECONOMY.PDS_HP)) / ECONOMY.PDS_HP)
				if (index == selected and selected_body == slot) or (building_selection_kind == "pds" and selected_buildings.has(Vector2i(index, slot))):
					world_batches.draw_selection_ring(point, body_radius + 4.0, Color(HUD.ACCENT, detail))
					map_canvas.draw_string(get_theme_default_font(), point + Vector2(-90.0, -body_radius - 7.0), _body_name(index, slot), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color(HUD.TEXT, detail))
	if not remembered:
		planet_traffic.draw_upgrade_deliveries(state, index, pos, radius, detail)
	var opacity: float = 1.0 - 0.4 * smoothstep(0.0, 1.0, log(maxf(camera.zoom, 1.0)) / log(maxf(_max_zoom(), 1.01)))
	celestial_view.draw_star(index, pos, star_radius, star_color, not ECONOMY.has_planets(system), opacity, map_canvas, remembered_time if remembered else visual_clock)
	if bool(system.get("station", {}).get("dyson_sphere", false)):
		celestial_view.draw_pds_frame(pos, star_radius * 1.18, 1.0, map_canvas)
		map_canvas.draw_arc(pos, star_radius * 1.35, 0.0, TAU, 48, Color("#e5b66c"), 1.5, true)
	if detail < 0.5:
		var defense_health: float = 1.0
		for battery in system.get("pds", {}).values():
			defense_health = minf(defense_health, float(battery.get("hp", ECONOMY.PDS_HP)) / ECONOMY.PDS_HP)
		_draw_damage_bar(pos, star_radius + 4.0, defense_health)
	if detail < 0.999 and not system.get("pds", {}).is_empty():
		map_canvas.draw_arc(pos, star_radius + 3.0, -PI * 0.8, PI * 0.8, 18, Color(Color("#bdcbd6"), 1.0 - detail), 1.5, true)
	if detail < 0.999:
		# A small battery marker stays on its actual planet even at overview zoom.
		var bodies: Array = celestial_view.system_visual(index, state)["bodies"]
		for slot in system.get("pds", {}):
			if int(slot) >= 0 and int(slot) < bodies.size():
				var point: Vector2 = pos + celestial_view.body_position(bodies[int(slot)], radius, orbit_elapsed)
				map_canvas.draw_circle(point, 2.0, Color(Color("#bdcbd6"), 1.0 - detail), true)
	if detail < 0.3 and building_selection_kind == "pds":
		# Retain a selection marker when F frames a distant battery group and
		# the individual planet surfaces fade out at overview zoom.
		var bodies: Array = celestial_view.system_visual(index, state)["bodies"]
		for slot in system.get("pds", {}):
			if selected_buildings.has(Vector2i(index, int(slot))) and int(slot) < bodies.size():
				var point: Vector2 = pos + celestial_view.body_position(bodies[int(slot)], radius, orbit_elapsed)
				world_batches.draw_selection_ring(point, 6.0)
	if _show_system_rings(index):
		map_canvas.draw_arc(pos, maxf(5.0, star_radius) + 3.0, 0.0, TAU, 48, Color(tint, 0.65), 1.5, true)
	return detail

func _empire_color_index(owner: int) -> int:
	if owner == 0:
		return 0
	var roster: Dictionary = session.get("players")
	return clampi(int(roster.get(owner, {}).get("color", 0)), 0, RULES.MAX_PLAYERS)

func _empire_color(owner: int) -> Color:
	if owner == ECONOMY.PIRATE_OWNER:
		return Color("#85888b")
	return COLORS[_empire_color_index(owner)]


func _body_hit(point: Vector2, state: Dictionary) -> Vector2i:
	var hit := Vector2i(-1, -1)
	var nearest: float = INF
	for index in range(state["planets"].size()):
		if not ECONOMY.discovered(state, _me(), "planets", index) or not _fog_visible(state["map"]["points"][index]):
			continue
		var radius: float = _planet_radius(index, state)
		if celestial_view.planet_detail_opacity(index, radius) < 0.3:
			continue
		var center: Vector2 = _screen_point(state["map"]["points"][index])
		if point.distance_to(center) > radius + 32.0:
			continue
		var bodies: Array = celestial_view.system_visual(index, state)["bodies"]
		for slot in range(bodies.size()):
			var body: Dictionary = bodies[slot]
			var position: Vector2 = center + celestial_view.body_position(body, radius, celestial_view.orbit_time(state))
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
			if not _fog_visible(ECONOMY.shipyard_position(state, index, slot, elapsed)):
				continue
			var distance: float = offset.length_squared()
			if absf(offset.dot(axis)) <= 14.0 * scale + 3.0 and absf(offset.dot(axis.orthogonal())) <= 17.0 * scale + 3.0 and distance < nearest:
				nearest = distance
				hit = Vector2i(index, slot)
	return hit

func _station_radius() -> float:
	# Scale the projected art, not its orbital position or simulation radius.
	return maxf(5.0, 58.0 * _fit() * camera.zoom * _overview_art_multiplier())

func _station_hit(point: Vector2, state: Dictionary) -> int:
	var hit: int = -1
	var nearest: float = INF
	for index in range(state["planets"].size()):
		if not ECONOMY.has_station(state["planets"][index]) or not _fog_visible(ECONOMY.station_position(state, index, float(state["elapsed"]))) or not ECONOMY.discovered(state, _me(), "planets", index):
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
	control_group_strip.z_index = 4
	control_group_strip.theme = HUD.compact()
	control_group_strip.add_theme_constant_override("separation", 2)
	add_child(control_group_strip)
	control_group_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control_group_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_center.resized.connect(_layout_control_group_strip)
	console_center_spacer.resized.connect(_layout_control_group_strip)
	console_center_spacer.item_rect_changed.connect(_layout_control_group_strip)
	for number in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]:
		var button := _button(str(number), _recall_control_group.bind(number), control_group_strip)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(CONTROL_GROUP_MANAGER.EMPTY_GROUP_WIDTH, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", CONTROL_GROUP_MANAGER.GROUP_ICON_WIDTH)
		button.add_theme_font_size_override("font_size", 11)
		button.disabled = true
		control_group_manager.control_group_buttons[number] = button
	control_group_strip.minimum_size_changed.connect(_layout_control_group_strip, CONNECT_DEFERRED)
	_layout_control_group_strip()

func _layout_control_group_strip() -> void:
	if not is_instance_valid(control_group_strip):
		return
	var left: float = console_center_spacer.global_position.x
	var right: float = inspector_slot.global_position.x if is_instance_valid(inspector_slot) else left + console_center.size.x
	var bottom: float = console_center_spacer.global_position.y + console_center_spacer.size.y + console_center.get_theme_constant("separation") - 3.0
	var group_min: float = control_group_strip.get_combined_minimum_size().x
	var group_right: float = right
	var group_bottom: float = bottom
	if is_instance_valid(global_selection_strip):
		global_selection_strip.size = global_selection_strip.get_combined_minimum_size()
		global_selection_strip.global_position = Vector2(right - global_selection_strip.size.x, bottom - global_selection_strip.size.y)
		group_right = global_selection_strip.global_position.x - 6.0
		# At very narrow widths keep both strips usable without overlapping.
		if group_right - left < group_min:
			group_right = right
			group_bottom = global_selection_strip.global_position.y - 3.0
	var strip_width: float = minf(540.0, maxf(group_min, group_right - left))
	control_group_strip.size = Vector2(strip_width, 26.0)
	control_group_strip.global_position = Vector2(left + maxf(0.0, (group_right - left - control_group_strip.size.x) * 0.5), group_bottom - control_group_strip.size.y)

func _prune_control_group(state: Dictionary, group: Dictionary) -> Dictionary:
	return control_group_manager.prune(state, group, _me(), _building_valid)

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
	control_group_manager.assign(state, number, _current_control_group(state), additive, _me(), _building_valid)
	_refresh_control_groups(state)

func _refresh_control_groups(state: Dictionary) -> void:
	control_group_manager.refresh(state, _me(), _building_valid, hull_art, command_card_ui)

func _recall_control_group(number: int, additive: bool = false) -> void:
	var state: Dictionary = _state()
	var group: Dictionary = _prune_control_group(state, control_group_manager.control_groups.get(number, {}))
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
	selected_rock = -1
	selected_ship_id = -1
	selected_units.clear()
	camera.following = false
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
	if not _fog_visible(state["map"]["points"][ref.x]):
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
	var body: Dictionary = celestial_view.system_visual(ref.x, state)["bodies"][ref.y]
	return (state["map"]["points"][ref.x] as Vector2) + celestial_view.body_position(body, celestial_view.system_world_radius(ref.x, state), celestial_view.orbit_time(state))

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
	selected_rock = -1

func _select_building_ref(ref: Vector2i, kind: String) -> void:
	var state: Dictionary = _state()
	if not _building_valid(state, ref, kind, int(selected_buildings.get(ref, -1))):
		return
	_clear_building_selection()
	_set_building_primary(state, ref, kind)
	if kind == "station":
		building_selection_kind = kind
		selected_buildings[ref] = 0
	camera.following = false
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
		if kind == "pds" and celestial_view.planet_detail_opacity(index, _planet_radius(index, state)) < 0.3:
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
	if is_instance_valid(global_selection_strip) and global_selection_strip.get_global_rect().has_point(global_point):
		return false
	if is_instance_valid(control_group_strip) and control_group_strip.get_global_rect().has_point(global_point):
		return false
	for panel in [minimap, match_timer_panel, lens_column, overview_panel, inspector_panel]:
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
		camera.following = false
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
			SELECTION_INSPECTOR.style_selection_tile(row)
			row.set_meta("kind", kind)
			building_group_rows[ref] = row
		var button: Button = building_group_rows[ref]
		var name_text: String = "%s · Shipyard %d · Lv %d" % [_system_name(ref.x), ECONOMY.shipyard_port(system, ref.y), int(system["yards"][ref.y]["level"])] if kind == "shipyard" else _system_name(ref.x) + " · Space Station" if kind == "station" else _body_name(ref.x, ref.y)
		var maximum: float = ECONOMY.station_max_hp(system) if kind == "station" else ECONOMY.PDS_HP if kind == "pds" else ECONOMY.YARD_HP * int(system["yards"][ref.y]["level"])
		var entity: Dictionary = system["station"] if kind == "station" else system["pds"][ref.y] if kind == "pds" else system["yards"][ref.y]
		var hp: float = float(entity.get("hp", maximum))
		var tint: Color = _health_color(clampf(hp / maximum, 0.0, 1.0))
		button.icon = hull_art.selection_portrait_icon(kind)
		button.add_theme_color_override("icon_normal_color", tint)
		button.add_theme_color_override("icon_hover_color", tint)
		button.add_theme_color_override("icon_pressed_color", tint)
		command_card_ui.set_hint(button, "%s · %.0f / %.0f HP%s" % [name_text, hp, maximum, "" if int(system["owner"]) == _me() else " · Foreign"])

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
		var population_met: bool = false
		var crew_available: float = 0.0
		var operating_fit: bool = false
		var queue_space: bool = false
		for ref in refs:
			var system: Dictionary = state["planets"][ref.x]
			eligible = eligible or _yard_build_available(system, ref.y, kind)
			population_met = population_met or (ECONOMY.yard_fits(system, ref.y, kind) and ECONOMY.ship_origin_population_met(system, kind))
			if ECONOMY.yard_fits(system, ref.y, kind):
				crew_available = maxf(crew_available, ECONOMY.available_crew_population(system, ref.y, kind))
				if ECONOMY.shipyard_operational(system, ref.y):
					operating_fit = true
					queue_space = queue_space or ECONOMY.shipyard_queue_count(system, ref.y) < ECONOMY.SHIPYARD_QUEUE_LIMIT
			can_toggle = can_toggle or ECONOMY.yard_fits(system, ref.y, kind)
			auto = auto or system["yards"][ref.y].get("autobuild", []).has(kind)
		var button: Button = yard_commands[kind]
		button.disabled = not can_toggle
		command_card_ui.set_build_available(button, eligible)
		(button.get_meta("auto_border") as Control).visible = auto
		var portrait: TextureRect = button.get_meta("portrait")
		portrait.texture = hull_art.production_icon(kind, _empire_color(_me()))
		portrait.modulate = Color.WHITE if eligible else Color(0.55, 0.55, 0.55)
		_set_cost_tooltip(button, "%s · Cost per ship\n1 per eligible yard\n%s\nRight-click: toggle autobuild" % [UI_TEXT.ship_kind_name(kind), UI_TEXT.ship_stats(kind)], ECONOMY.construction_cost(state["planets"][refs[0].x] if not refs.is_empty() else {}, kind, 1), float(ECONOMY.CREW_COSTS[kind]), available.merged({"Population": crew_available}, true), kind)
		if crew_available + ECONOMY.EPS < float(ECONOMY.CREW_COSTS[kind]) and not refs.is_empty():
			command_card_ui.set_hint(button, command_card_ui.hint(button) + "\nInsufficient unreserved population")
			(button as CostButton).unmet_requirements.append("Insufficient unreserved population")
		if kind == "colony_ship" and not refs.is_empty() and not population_met:
			(button as CostButton).unmet_requirements.append(UI_TEXT.colony_population_requirement())
		if not eligible:
			if refs.is_empty():
				command_card_ui.add_build_blocker(button, "Requires an owned shipyard")
			elif not can_toggle:
				command_card_ui.add_build_blocker(button, "Requires %s shipyard" % ECONOMY.size_name(ECONOMY.ship_size(kind)))
			elif not operating_fit:
				command_card_ui.add_build_blocker(button, "Matching shipyards offline — insufficient staffing")
			elif not queue_space:
				command_card_ui.add_build_blocker(button, "Matching shipyard queues full")
			else:
				command_card_ui.add_build_blocker(button, "No selected shipyard meets all requirements")
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
		command_card_ui.set_build_available(upgrade, not upgrade.disabled)
		_set_cost_tooltip(upgrade, "Upgrade eligible %s shipyards to %s\nUnlocks next ship class · Faster construction\nFully repairs each yard" % [ECONOMY.size_name(target_level - 1), ECONOMY.size_name(target_level)], ECONOMY.base_recipe_cost("yard_upgrade", target_level), 0.0, available)
		if upgrade.disabled:
			var reasons: Array[String] = []
			for ref in refs:
				var system: Dictionary = state["planets"][ref.x]
				if int(system["yards"][ref.y]["level"]) != target_level - 1:
					continue
				if not ECONOMY.shipyard_operational(system, ref.y) and not reasons.has("Insufficient shipyard staffing"):
					reasons.append("Insufficient shipyard staffing")
				if ECONOMY.shipyard_queue_count(system, ref.y) >= ECONOMY.SHIPYARD_QUEUE_LIMIT and not reasons.has("Shipyard queue full"):
					reasons.append("Shipyard queue full")
				if ECONOMY.has_queued_job(system, "yard_upgrade", str(ref.y)) and not reasons.has("Upgrade already queued"):
					reasons.append("Upgrade already queued")
			for reason in reasons:
				command_card_ui.add_build_blocker(upgrade, reason)
			command_card_ui.add_build_blocker(upgrade, "No selected shipyard meets all requirements")
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
		if distance <= maxf(5.0, hull_art.ui_radius(str(poses[id]["kind"])) * _ship_scale() * HULL_ART.visual_scale(str(poses[id]["kind"]))) and distance < ship_distance:
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
			selected_rock = -1
			camera.following = false
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
			camera.following = false
			if double_click:
				_select_visible_buildings(state, ref, "station")
			_load_thresholds()
			_refresh()
			return
	if body_hit.x >= 0:
		selected = body_hit.x
		selected_yard = -1
		selected_body = body_hit.y
		camera.following = false
		selected_ship_id = -1
		selected_units.clear()
		selected_field = -1
		selected_rock = -1
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
				var team: int = ECONOMY.combat_group(state, _me())
				if ECONOMY.combat_group(state, int(craft["owner"])) != team:
					selected_units.clear()
					selected_ship_id = -1
				for other in state["ships"]:
					var id: int = int(other["id"])
					if ECONOMY.combat_group(state, int(other["owner"])) == team and other["kind"] == kind and poses.has(id) and _in_visible_playfield(poses[id]["point"]) and not selected_units.has(id):
						selected_units.append(id)
				if not selected_units.is_empty():
					selected_ship_id = selected_units[0]
			break
	selected_field = -1
	selected_rock = -1
	if selected_ship_id < 0:
		var asteroid_hit: Vector2i = _asteroid_hit(point, state, false)
		if asteroid_hit.x >= 0:
			selected_field = asteroid_hit.x
			selected_rock = asteroid_hit.y
		if hit >= state["planets"].size():
			hit = -1
	# Direct star hits remain selectable independently of old sector geometry.
	if selected_ship_id < 0 and selected_field < 0:
		var closest: float = INF
		for index in range(state["planets"].size()):
			if not ECONOMY.discovered(state, _me(), "planets", index):
				continue
			var distance: float = point.distance_to(_screen_point(state["map"]["points"][index]))
			if distance <= maxf(9.0, celestial_view.star_draw_radius(_planet_radius(index, state))) and distance < closest:
				closest = distance
				hit = index
	selected = -1 if selected_ship_id >= 0 or selected_field >= 0 else hit
	camera.following = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused):
		focused.release_focus()
	if selected >= 0:
		var system: Dictionary = fog_state.system_view(state, selected, _map_size())
		var owner: int = int(system.get("owner", 0))
		if _fog_visible(state["map"]["points"][selected]) and owner > 0 and ECONOMY.has_station(system) and ECONOMY.combat_group(state, owner) == ECONOMY.combat_group(state, _me()):
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
	# Keep only commandable hulls in a box selection, including Shift-add.
	var commandable: Dictionary = {}
	for craft in state.get("ships", []):
		if _is_commandable_ship(craft):
			commandable[int(craft["id"])] = true
	for id in selected_units.duplicate():
		if not commandable.has(id):
			selected_units.erase(id)
	for craft in state.get("ships", []):
		if not commandable.has(int(craft["id"])):
			continue
		var id: int = int(craft["id"])
		if poses.has(id) and rect.has_point(poses[id]["point"]) and not selected_units.has(id):
			selected_units.append(id)
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	camera.following = false
	selected = -1
	selected_body = -1
	selected_yard = -1
	selected_field = -1
	selected_rock = -1
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
		if distance <= maxf(5.0, hull_art.ui_radius(str(poses[id]["kind"])) * _ship_scale() * HULL_ART.visual_scale(str(poses[id]["kind"]))) and distance < nearest:
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

# Return (internal pool, rock id); pulsars retain id -1. Empty belt
# space has no selectable object. Use the same snapshot as rendering.
func _asteroid_hit(point: Vector2, state: Dictionary, mining: bool) -> Vector2i:
	var result := Vector2i(-1, -1)
	var best: float = INF
	var scale: float = _fit() * camera.zoom
	for index in range(state["map"].get("fields", []).size()):
		var field: Dictionary = state["map"]["fields"][index]
		var known: bool = ECONOMY.discovered(state, _me(), "fields", index)
		var distance: float = point.distance_to(_screen_point(field["position"]))
		if bool(field.get("antimatter", false)):
			if known and distance <= maxf(9.0, float(field["radius"]) * scale * 0.16) and distance < best:
				best = distance
				result = Vector2i(index, -1)
			continue
		if distance > float(field.get("rock_extent", field["radius"])) * scale + 4.0 or (mining and not known):
			continue
		var transforms: Array[Transform2D] = MAP.asteroid_orbit_transforms(field, celestial_view.orbit_time(state))
		for rock in fog_state.rock_view(index).get("live", []):
			if mining and not bool(rock.get("surveyed", false)):
				continue
			var fraction: float = clampf(float(rock["remaining"]) / maxf(ECONOMY.EPS, float(rock["initial"])), 0.0, 1.0)
			var hit_radius: float = maxf(2.5, float(rock["radius"]) * scale * sqrt(fraction))
			var d: float = point.distance_to(_screen_point(MAP.asteroid_orbit_position(rock, transforms)))
			if fraction > 0.0 and d < best and d <= hit_radius:
				best = d
				result = Vector2i(index, int(rock["id"]))
	return result

func _command_at(point: Vector2, force_position: bool = false, patrol: bool = false, move_only: bool = true, explicit_attack: bool = false, append: bool = false, contextual: bool = false, minimap_hint: Dictionary = {}) -> void:
	var state: Dictionary = _state()
	var owned: Array[int] = _selected_owned_units(state, not patrol and not explicit_attack)
	if state.is_empty() or owned.is_empty():
		return
	var graph: Dictionary = ECONOMY.military_graph(state)
	var world: Vector2 = minimap_hint.get("world", _world_point(point))
	if patrol:
		var anchor: int = ECONOMY.patrol_node(state, graph, _me(), world)
		var fighters: Array[int] = []
		for craft in state["ships"]:
			if owned.has(int(craft["id"])) and craft["kind"] in ECONOMY.MILITARY_KINDS:
				fighters.append(int(craft["id"]))
		if anchor >= 0:
			_issue_order(fighters, {"kind": "patrol", "target": anchor, "point": world}, append)
		return
	var target: int = -1
	if not force_position and (contextual or explicit_attack):
		target = _entity_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["entity"])
	var ref: Dictionary = ECONOMY.service_targets(state).get(target, {})
	if state.has("diplomacy") and explicit_attack and not ref.is_empty():
		var other: int = int(ref.get("owner", 0))
		if other > 0 and other != _me() and not ECONOMY.empires_hostile(state, _me(), other):
			if ECONOMY.diplomatic_relation(state, _me(), other) == ECONOMY.DIPLO_NEUTRAL and ref.get("kind", "") != "pds":
				var armed_ids: Array[int] = []
				for craft in state["ships"]:
					if owned.has(int(craft["id"])) and int(craft["owner"]) == _me() and ECONOMY.armed(craft):
						armed_ids.append(int(craft["id"]))
				if not armed_ids.is_empty():
					_confirm_war(other, armed_ids, target)
			# Do not turn a rejected attack on an ally/truce into movement.
			return
	var wreck: int = -1
	if contextual and not force_position:
		wreck = _salvage_hit(state, point) if minimap_hint.is_empty() else int(minimap_hint["wreck"])
	var field: int = -1
	var rock_id: int = -1
	if contextual and not force_position and not minimap_hint.is_empty():
		field = int(minimap_hint["field"])
	elif contextual and not force_position:
		var asteroid_hit: Vector2i = _asteroid_hit(point, state, true)
		field = asteroid_hit.x
		rock_id = asteroid_hit.y
	# Only a direct hit on a known neutral star is a settlement command.
	# Empty space inside a legacy sector remains an ordinary move.
	var colony_target: int = -1
	if contextual and not force_position and not explicit_attack and ref.is_empty() and field < 0 and wreck < 0:
		if not minimap_hint.is_empty():
			colony_target = int(minimap_hint.get("star", -1))
		else:
			var closest: float = INF
			for index in range(state["planets"].size()):
				if not ECONOMY.discovered(state, _me(), "planets", index):
					continue
				var distance: float = point.distance_to(_screen_point(state["map"]["points"][index]))
				if distance <= maxf(9.0, celestial_view.star_draw_radius(_planet_radius(index, state))) and distance < closest:
					closest = distance
					colony_target = index
		if colony_target >= 0:
			var system: Dictionary = fog_state.system_view(state, colony_target, _map_size())
			if system.is_empty() or int(system.get("owner", -1)) != 0 or ECONOMY.has_station(system):
				colony_target = -1
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
		if not ref.is_empty() and armed and ECONOMY.hostile_hull(state, _me(), ref):
			order = {"kind": "attack", "target": target}
		elif contextual and ref.get("entity", {}).get("kind", "") == "warp_gate" and int(ref.get("owner", -1)) == _me() and ECONOMY.warp_order_valid(state, craft, target):
			order = {"kind": "warp_travel", "target": target}
		elif contextual and ref.get("kind") == "ship" and ECONOMY.friendly_service_target(state, _me(), ref):
			if id == target:
				continue
			order = {"kind": "follow", "target": target, "guard": craft["kind"] in ECONOMY.MILITARY_KINDS}
		elif contextual and ref.get("kind") == "station" and ECONOMY.can_deposit(state, craft, target):
			order = {"kind": "deposit", "target": target}
		elif colony_target >= 0 and craft["kind"] == "colony_ship":
			order = {"kind": "colonize", "target": colony_target}
		elif field >= 0 and bool(state["map"]["fields"][field].get("antimatter", false)) and craft["kind"] == "science_ship" and ECONOMY.cargo_total(craft) <= ECONOMY.EPS:
			order = {"kind": "collect", "target": field}
		elif wreck >= 0 and ECONOMY.supports_autocast(craft, "salvage") and ECONOMY.cargo_free(craft) > ECONOMY.EPS:
			salvage_ids.append(id)
			continue
		elif field >= 0 and rock_id >= 0 and craft["kind"] == "miner" and not bool(state["map"]["fields"][field].get("antimatter", false)):
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
		if selected_units.has(int(craft["id"])) and int(craft["owner"]) == _me() and kind != "probe" and not ECONOMY.is_static_structure(craft) and not ECONOMY.colony_morphing(craft) and not kinds.has(kind):
			kinds.append(kind)
	kinds.sort()
	return kinds

func _sync_command_kind(state: Dictionary) -> void:
	var kinds: Array[String] = _command_kinds(state)
	if command_selection != selected_units or not kinds.has(command_kind):
		command_selection.assign(selected_units)
		command_kind = kinds[0] if not kinds.is_empty() else ""

# Selected ship dictionaries in roster order; avoids scanning every hull
# with an Array search, and skips the roster entirely when nothing is selected.
func _selected_ship_entries(state: Dictionary) -> Array:
	if selected_units.is_empty():
		return []
	var lookup: Dictionary = {}
	for id in selected_units:
		lookup[id] = true
	var entries: Array = []
	for craft in state.get("ships", []):
		if lookup.has(int(craft["id"])):
			entries.append(craft)
	return entries

# Shared eligibility for box selection and command dispatch, independent of active type.
func _is_commandable_ship(craft: Dictionary) -> bool:
	return int(craft["owner"]) == _me() and craft.get("kind", "") not in ["warp_gate", "probe"] and not ECONOMY.is_static_structure(craft) and not ECONOMY.colony_morphing(craft)

func _command_entry(craft: Dictionary) -> bool:
	return _is_commandable_ship(craft) and str(craft["kind"]) == command_kind

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

func _selected_repairers() -> Array[int]:
	var miners: Array[int] = []
	for craft in _selected_ship_entries(_state()):
		if _command_entry(craft) and ECONOMY.supports_autocast(craft, "repair"):
			miners.append(int(craft["id"]))
	return miners

func _selected_owned_units(state: Dictionary, all_types: bool = false) -> Array[int]:
	var owned: Array[int] = []
	for craft in _selected_ship_entries(state):
		if _is_commandable_ship(craft) and (all_types or _command_entry(craft)):
			owned.append(int(craft["id"]))
	return owned

func _any_selected_holding() -> bool:
	for craft in _selected_ship_entries(_state()):
		if _command_entry(craft) and bool(craft.get("holding", false)):
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
		for ship in _selected_ship_entries(state):
			if _command_entry(ship) and ECONOMY.can_build_warp_gate(state, graph, ship):
				ids.append(int(ship["id"]))
		_issue_order(ids, {"kind": "warp_build"})
		return
	for ship in _selected_ship_entries(state):
		if _command_entry(ship) and ECONOMY.unit_order_valid(state, graph, ship, {"kind": "transform"}, Input.is_key_pressed(KEY_SHIFT)):
			ids.append(int(ship["id"]))
	if not ids.is_empty():
		_issue_order(ids, {"kind": "transform"}, Input.is_key_pressed(KEY_SHIFT))

func _deliver_farm_selected() -> void:
	var ids: Array[int] = []
	for ship in _selected_ship_entries(_state()):
		if ship["kind"] == "colony_ship" and _command_entry(ship) and ECONOMY.cargo_total(ship) > ECONOMY.EPS:
			ids.append(int(ship["id"]))
	pending_command = ""
	_issue_order(ids, {"kind": "unload"}, Input.is_key_pressed(KEY_SHIFT))
	_refresh_command_mode()

func _unload_selected() -> void:
	_arm_command("unload")

func _formation_orders(state: Dictionary) -> Array:
	var entries: Array = []
	var owned: Array[int] = _selected_owned_units(state, formation_mode not in ["attack", "patrol"])
	if owned.is_empty() or formation_length < ORDER_VIEW.MIN_FORMATION_DRAG:
		return entries
	var graph: Dictionary = ECONOMY.military_graph(state)
	var stroke := PackedVector2Array()
	for point in formation_path:
		stroke.append(_world_point(point))
	var ships: Dictionary = {}
	var origins: Dictionary = {}
	for ship in state["ships"]:
		if owned.has(int(ship["id"])) and not bool(ship.get("retreating", false)) and (formation_mode != "attack" or ECONOMY.armed(ship)) and (formation_mode != "patrol" or ship["kind"] in ECONOMY.MILITARY_KINDS):
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
		entries.append({"ids": owned, "order": order, "hull": ship["kind"], "valid": ECONOMY.unit_order_valid(state, graph, ship, order, formation_append)})
		return entries
	for slot in ECONOMY.polyline_formation_slots(origins, stroke):
		var ship: Dictionary = ships[slot["id"]]
		var point: Vector2 = slot["point"]
		var node: int = ECONOMY.patrol_node(state, graph, _me(), point)
		var order: Dictionary = {"kind": "patrol" if formation_mode == "patrol" else "position", "target": node, "point": point, "move_only": formation_mode != "attack", "heading": slot["heading"]}
		entries.append({"ids": [ship["id"]], "order": order, "hull": ship["kind"], "valid": ECONOMY.unit_order_valid(state, graph, ship, order, formation_append)})
	return entries

func _append_formation_point(point: Vector2, force: bool = false) -> void:
	var distance: float = formation_path[-1].distance_to(point)
	if distance <= 0.0 or (distance < 2.0 and not force):
		return
	formation_length += distance
	if formation_path.size() >= 2048:
		formation_path.remove_at(1)
	formation_path.append(point)

func _begin_formation(mouse: InputEventMouseButton) -> void:
	formation_button = mouse.button_index
	formation_path = PackedVector2Array([mouse.position])
	formation_length = 0.0
	formation_mode = pending_command
	formation_append = mouse.shift_pressed
	formation_force_position = mouse.alt_pressed
	selecting_units = false
	camera.following = false

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
	if notice_ui.contains_point(map_canvas.get_global_mouse_position()):
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and notice_ui.jump_tactical_alert(mouse.position):
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
					camera.following = false
				drag_button = MOUSE_BUTTON_MIDDLE if mouse.pressed else 0
			MOUSE_BUTTON_RIGHT:
				if mouse.pressed:
					if pending_command in ["repair", "unload", "load", "rally", "collect", "guard", "scan", "build_depot", "cancel_site", "build_cannon", "upgrade_cannon"]:
						_execute_pending_command(mouse.position, mouse.shift_pressed)
					elif not pending_command.is_empty() and pending_command not in ["move", "attack", "patrol"]:
						pending_command = ""
						_refresh_command_mode()
					elif selected_yard >= 0:
						_set_rally_at(mouse.position)
			MOUSE_BUTTON_LEFT:
				if pending_command == "build_wall":
					if mouse.pressed:
						wall_drag_start = _world_point(mouse.position)
						wall_drag_end = wall_drag_start
					elif wall_drag_start.is_finite():
						_issue_order(_selected_owned_units(_state()), {"kind": "build_wall", "start": wall_drag_start, "point": _world_point(mouse.position)}, false)
						wall_drag_start = Vector2.INF
						wall_drag_end = Vector2.INF
						pending_command = ""
						_refresh_command_mode()
					map_canvas.queue_redraw()
					map_canvas.accept_event()
					return
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
					_zoom_at(mouse.position, match_settings.wheel_zoom_percent / 100.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse.pressed:
					_zoom_at(mouse.position, -match_settings.wheel_zoom_percent / 100.0)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if pending_command == "build_wall" and wall_drag_start.is_finite():
			wall_drag_end = _world_point(motion.position)
		elif formation_button != 0:
			_append_formation_point(motion.position)
		elif selecting_units:
			selection_end = motion.position
		elif drag_button != 0:
			if motion.button_mask == 0:
				drag_button = 0
			else:
				_center_world(_camera_world_center() - motion.relative / (_fit() * camera.zoom))
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

# UI cues are local, while world cues use the same authority snapshots as
# combat visuals. No audio events or additional network traffic are required.
func _sound_button_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		var button: BaseButton = node
		if not button.pressed.is_connected(_sound_click):
			button.pressed.connect(_sound_click)

func _sound_click() -> void:
	sound_mixer.play_cue("click")

func _sound_chat() -> void:
	if str(session.get("phase")) == "match" and not session.get("match_chat").is_empty():
		notice_ui.sync_history(_state(), alert_tracker.alerts)
		sound_mixer.play_cue("notice")

func _sync_upgrade_audio(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	audio_tracker.sync_upgrade_audio(state, _me(), sound_mixer)

func _sync_world_audio(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		return
	var center: Vector2 = _camera_world_center()
	var radius: float = clampf(_projection_size().length() / maxf(0.0001, _fit() * camera.zoom) * 0.55, 650.0, 9000.0)
	audio_tracker.sync_world_audio(state, _me(), center, radius, camera.zoom, _ship_visible, sound_mixer)

func _alert_off_camera(point: Vector2) -> bool:
	return not Rect2(Vector2(0, HEADER_HEIGHT), (_projection_size() - Vector2(0, HEADER_HEIGHT)).max(Vector2.ONE)).has_point(_screen_point(point))

func _jump_notice_location(alert: Dictionary) -> void:
	var destination: Vector2 = alert["point"]
	var target: int = int(alert.get("target", -1))
	if target >= 0:
		for ship in _state().get("ships", []):
			if int(ship["id"]) == target:
				destination = ship["position"]
				break
	camera.following = false
	formation_button = 0
	selecting_units = false
	_center_world(destination)
	_position_territory()
	map_canvas.queue_redraw()
	sound_mixer.play_cue("click")

func _sync_tactical_alerts(state: Dictionary) -> void:
	if state.is_empty() or str(session.get("phase")) != "match":
		alert_tracker.reset()
		notice_ui.clear_hit_rects()
		return
	alert_tracker.sync(state, _me(), Time.get_ticks_msec(), territory_view.region_graph, territory_view.friendly_sectors, _alert_off_camera, _ship_visible, _ship_kind_name, _poi_name, Callable(sound_mixer, "play_cue"))

var publication_profile: Dictionary = {}
var _profiling_publication: bool = false

func _on_economy_changed() -> void:
	publication_profile.clear()
	_profiling_publication = true
	var state: Dictionary = _state()
	var started: int = Time.get_ticks_usec()
	_sync_upgrade_audio(state)
	_sync_world_audio(state)
	publication_profile["audio"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	_refresh_territory(state)
	publication_profile["territory_fog"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	_sync_tactical_alerts(state)
	notice_ui.sync_history(state, alert_tracker.alerts)
	publication_profile["alerts_history"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	ship_motion.sync(state, session)
	publication_profile["motion"] = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	_refresh()
	publication_profile["inspector"] = float(Time.get_ticks_usec() - started) / 1000.0
	_profiling_publication = false

func _input(event: InputEvent) -> void:
	if empire_ui.war_confirmation_visible():
		return
	if not event is InputEventKey or not event.pressed or event.echo or not notice_ui.is_built() or str(session.get("phase")) != "match":
		return
	var key: int = event.keycode
	var enter: bool = key in [KEY_ENTER, KEY_KP_ENTER]
	if notice_ui.is_open():
		if enter or key == KEY_ESCAPE:
			var message: String = notice_ui.match_chat_edit.text.strip_edges()
			if enter and message.begins_with("/"):
				notice_ui.match_chat_edit.clear()
				if OS.is_debug_build():
					developer_tools.submit_command(message)
				else:
					notice_ui.local_console_notice("Unknown command.")
				notice_ui.layout()
				notice_ui.match_chat_edit.grab_focus()
			else:
				if enter and not message.is_empty():
					session.call("send_chat", message)
				notice_ui.close()
			get_viewport().set_input_as_handled()
		return
	if not enter or event.alt_pressed or event.ctrl_pressed or event.meta_pressed or _dev_console_modal_open():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	notice_ui.open(_state(), alert_tracker.alerts)
	get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if empire_ui.war_confirmation_visible():
		return
	if (notice_ui.is_open()):
		return
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
	if is_instance_valid(match_settings.hotkey_dialog) and match_settings.hotkey_dialog.visible:
		return
	if key == KEY_ESCAPE:
		if match_menu.visible:
			match_menu.hide()
		elif not pending_command.is_empty() or formation_button != 0 or selecting_units:
			formation_button = 0
			selecting_units = false
			pending_command = ""
			_refresh_command_mode()
		elif not hotkeys.trigger(KEY_ESCAPE):
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
	elif key == hotkeys.value("focus", hotkeys.overrides):
		_focus_selection()
	elif key == hotkeys.value("army", hotkeys.overrides):
		_select_all_military()
	elif not hotkeys.trigger(key):
		return
	get_viewport().set_input_as_handled()

func _build_global_selection_strip() -> void:
	global_selection_strip = HBoxContainer.new()
	global_selection_strip.theme = HUD.compact()
	global_selection_strip.z_index = 5
	global_selection_strip.add_theme_constant_override("separation", 3)
	add_child(global_selection_strip)
	for entry in [["stations", "Stations", "station", KEY_F1], ["army", "Army", "fighter", KEY_F2], ["shipyards", "Shipyards", "shipyard", KEY_F3]]:
		var action: Callable = _select_all_military if entry[0] == "army" else _select_all_buildings.bind(entry[2])
		var button: Button = _button("", action, global_selection_strip)
		command_card_ui.set_face(button, entry[1], hull_art.selection_portrait_icon(entry[2]))
		command_card_ui.set_hint(button, "Select all owned " + str(entry[1]).to_lower())
		hotkeys.register(button, int(entry[3]), "General", entry[0], "Select all " + str(entry[1]).to_lower())
	var empire_button: Button = _button("", _open_empire, global_selection_strip)
	command_card_ui.set_face(empire_button, "Empire", _command_icon('<circle cx="16" cy="16" r="6"/><circle cx="5" cy="6" r="3"/><circle cx="27" cy="6" r="3"/><circle cx="16" cy="28" r="2"/><path d="M8 9L12 12M24 9L20 12M16 22V26"/>'))
	command_card_ui.set_hint(empire_button, "Empire\nFleet management & diplomacy")
	hotkeys.register(empire_button, KEY_F4, "General", "empire", "Empire")
	empire_ui.build(self, session, _me, _empire_color, hull_art.selection_portrait_icon, _label)
	for button in global_selection_strip.get_children():
		button.custom_minimum_size = Vector2(52, 40)
		var caption: Label = button.get_meta("caption")
		caption.add_theme_font_size_override("font_size", 10)
	global_selection_strip.resized.connect(_layout_control_group_strip)
	_layout_control_group_strip()

func _refresh_global_selection_buttons(state: Dictionary) -> void:
	if not is_instance_valid(global_selection_strip):
		return
	var has_station: bool = false
	var has_army: bool = false
	var has_yard: bool = false
	var player: int = _me()
	for system in state.get("planets", []):
		if int(system["owner"]) != player:
			continue
		has_station = has_station or ECONOMY.has_station(system)
		has_yard = has_yard or not system["yards"].is_empty()
		if has_station and has_yard:
			break
	for craft in state.get("ships", []):
		if int(craft["owner"]) == player and craft["kind"] in ECONOMY.MILITARY_KINDS:
			has_army = true
			break
	var station_button: Button = global_selection_strip.get_child(0)
	var army_button: Button = global_selection_strip.get_child(1)
	var yard_button: Button = global_selection_strip.get_child(2)
	station_button.disabled = not has_station
	army_button.disabled = not has_army
	yard_button.disabled = not has_yard

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
	selected_rock = -1
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
	camera.following = false
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
	selected_rock = -1
	selected_units.clear()
	for craft in state["ships"]:
		if craft["kind"] in ECONOMY.MILITARY_KINDS and int(craft["owner"]) == _me():
			selected_units.append(int(craft["id"]))
	selected_ship_id = selected_units[0] if not selected_units.is_empty() else -1
	var now: int = Time.get_ticks_msec()
	var center_army: bool = last_control_group_recall == -2 and now - last_control_group_recall_ms <= 400
	last_control_group_recall = -1 if center_army else -2
	last_control_group_recall_ms = now
	camera.following = false
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
	if empire_ui.war_confirmation_visible():
		return
	if (notice_ui.is_open()):
		return
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
	var velocity: Vector2 = direction.normalized() * match_settings.keyboard_pan_percent / 100.0 + edge_direction.normalized() * match_settings.mouse_pan_percent / 100.0
	velocity = velocity.limit_length(maxf(match_settings.keyboard_pan_percent, match_settings.mouse_pan_percent) / 100.0)
	_pan_camera(velocity, delta)

func _sync_match_mouse_mode() -> void:
	var active: bool = str(session.get("phase")) == "match" and get_window().has_focus()
	var modal: bool = ((notice_ui.is_open())) or match_menu.visible or (is_instance_valid(codex) and codex.visible) or (is_instance_valid(match_result_dialog) and match_result_dialog.visible)
	var target: Input.MouseMode = Input.MOUSE_MODE_CONFINED if active and not modal else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != target:
		Input.mouse_mode = target

func _pan_camera(direction: Vector2, delta: float) -> void:
	if not direction.is_zero_approx():
		camera.pan(direction, delta, _projection_size(), _map_size())
		map_canvas.queue_redraw()

func _process(delta: float) -> void:
	conquest_ui.pulse(delta)
	if formation_button != 0 and not Input.is_mouse_button_pressed(formation_button):
		formation_button = 0
		map_canvas.queue_redraw()
	if selecting_units and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		selecting_units = false
		map_canvas.queue_redraw()
	_sync_match_mouse_mode()
	_keyboard_pan(delta)
	resource_hud.update_hover(self, codex, station_details, overview_panel, population_label, production_values, selected, _planet)
	command_card_ui.refresh_info(get_viewport())
	developer_tools.update_perf(delta)
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
	ship_motion.advance(delta)
	var state: Dictionary = _state()
	if not state.is_empty():
		celestial_view.update_orbit_clock(state, delta)
		celestial_view.update_planet_detail(state, delta, _fit(), camera.zoom)
		var poses: Dictionary = _ship_poses(state, delta)
		_follow_selection(state, poses)
		if is_instance_valid(space_backdrop):
			space_backdrop.call("set_camera_pose", _camera_world_center(), _fit() * camera.zoom, camera.zoom)
		world_effects.sync_destructions(state, visual_clock, _empire_color, hull_art)
	else:
		celestial_view.reset_clocks()
		camera.following = false
		world_effects.reset_destructions()
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

func _draw_owned_laser(origin: Vector2, target: Vector2, owner: int, width: float) -> void:
	world_effects.draw_owned_laser(origin, target, owner, width, _empire_color, world_batches)

func _fighter_beam_origin(pose: Dictionary) -> Vector2:
	return (pose["point"] as Vector2) + (pose["direction"] as Vector2) * WORLD_EFFECTS.FIGHTER_MUZZLE * _ship_scale()

func _draw_blaster_tracers(state: Dictionary, ship: Dictionary, poses: Dictionary) -> void:
	world_effects.draw_blaster_tracers(state, ship, poses, celestial_view, _screen_point, _empire_color, _ship_scale, world_batches)

func _draw_ship_laser(ship: Dictionary, pose: Dictionary, endpoint: Vector2, width: float) -> Dictionary:
	var draw_pose: Dictionary = pose.duplicate()
	world_effects.draw_ship_laser(ship, draw_pose, endpoint, width, _ship_scale, _empire_color, world_batches)
	return draw_pose

func _overview_art_multiplier(maximum: float = OVERVIEW_ART_MAX_MULTIPLIER) -> float:
	# Wheel zoom is logarithmic; blend in the same space for a smooth
	# overview-to-tactical transition, with exact maximum/1x endpoints.
	var progress: float = clampf(log(maxf(camera.zoom, CAMERA_VIEW.MIN_ZOOM) / CAMERA_VIEW.MIN_ZOOM) / log(OVERVIEW_ART_NORMAL_ZOOM / CAMERA_VIEW.MIN_ZOOM), 0.0, 1.0)
	return lerpf(maximum, 1.0, smoothstep(0.0, 1.0, progress))

func _ship_scale(structure: bool = false) -> float:
	# Preserve the authored close-up ceiling and camera framing.
	var base: float = minf(CAMERA_VIEW.SHIP_WORLD_SCALE * _fit() * minf(camera.zoom, CAMERA_VIEW.OVERVIEW_MAX_ZOOM), 1.25) * maxf(1.0, camera.zoom / CAMERA_VIEW.OVERVIEW_MAX_ZOOM)
	return base * _overview_art_multiplier(OVERVIEW_ART_MAX_MULTIPLIER if structure else OVERVIEW_SHIP_MAX_MULTIPLIER)

func _focus_selection() -> void:
	var state: Dictionary = _state()
	if state.is_empty():
		return
	camera.following = true
	_follow_selection(state, _ship_poses(state))
	_position_territory()
	map_canvas.queue_redraw()

func _bounds_zoom(bounds: Rect2) -> float:
	return camera.bounds_zoom(bounds, size.x, _projection_size(), _map_size())

func _center_world(point: Vector2) -> void:
	camera.set_world_center(point, _projection_size(), _map_size())

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
	camera.zoom = _bounds_zoom(Rect2(-extent, extent * 2.0))
	_center_world(state["map"]["points"][index])
	_position_territory()
	map_canvas.queue_redraw()

func _follow_selection(state: Dictionary, poses: Dictionary, center_only: bool = false) -> void:
	if (not camera.following and not center_only) or selecting_units or drag_button != 0 or str(session.get("phase")) != "match":
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
	if selected_field >= 0 and selected_field < fields.size():
		var rock: Dictionary = fog_state.rock_at(selected_field, selected_rock)
		if selected_rock >= 0 and not rock.is_empty():
			var position: Vector2 = rock["position"]
			if _fog_visible(position):
				position = MAP.asteroid_orbit_position(rock, MAP.asteroid_orbit_transforms(fields[selected_field], celestial_view.orbit_time(state)))
			_center_world(position)
		elif selected_rock < 0 and ECONOMY.discovered(state, _me(), "fields", selected_field):
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
	camera.following = false

func _ship_poses(state: Dictionary, delta: float = 0.0) -> Dictionary:
	_pose_vision_memo.clear()
	_pose_vision_team = ECONOMY.combat_group(state, _me())
	# Freeze the same projection once instead of per hull.
	var was_active: bool = _draw_projection_active
	if not was_active:
		_begin_draw_projection()
	var projection: Array = [_draw_projection_size * 0.5, _draw_world_center, _draw_fit, _draw_zoom]
	_draw_projection_active = was_active
	return ship_motion.poses(state, delta, session, _pose_ship_visible, _screen_point, projection)

func _frame_service_refs(state: Dictionary) -> Dictionary:
	var signature: Array = [session.get("snapshot_revision"), session.get("motion_revision"), state.get("elapsed"), state["ships"].size()]
	if not is_same(state, _service_refs_state) or signature != _service_refs_signature:
		_service_refs_cache = ECONOMY.service_targets(state)
		_service_refs_state = state
		_service_refs_signature = signature
	return _service_refs_cache

# _ship_visible with the owner's shared-vision result memoized per pose pass.
func _pose_ship_visible(state: Dictionary, ship: Dictionary) -> bool:
	if fog_state.observing:
		return true
	var owner: int = int(ship["owner"])
	var shared: Variant = _pose_vision_memo.get(owner)
	if shared == null:
		shared = ECONOMY.shares_group_vision(state, _pose_vision_team, ECONOMY.combat_group(state, owner))
		_pose_vision_memo[owner] = shared
	if bool(shared):
		return true
	return _fog_visible(ship.get("position", Vector2.INF)) and ECONOMY.ship_visible_to_team(state, ship, _pose_vision_team)

func _salvage_radius(pile: Dictionary) -> float:
	return maxf(3.0, sqrt(float(pile["amount"])) * 1.6 * _fit() * camera.zoom)

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
func _draw_salvage(state: Dictionary, poses: Dictionary, viewport_bounds: Rect2, font: Font) -> void:
	if state.get("salvage", {}).is_empty():
		return
	var hovered: int = _salvage_hit(state, map_canvas.get_local_mouse_position())
	var ships_by_id: Dictionary = {}
	for ship in state["ships"]:
		ships_by_id[int(ship["id"])] = ship
	for pile in state.get("salvage", {}).values():
		if not _fog_visible(pile["position"]):
			continue
		var point: Vector2 = _screen_point(pile["position"])
		var radius: float = _salvage_radius(pile)
		if not viewport_bounds.grow(radius * 2.6 + 24.0).has_point(point):
			continue
		var tint: Color = HUD.COLORS[pile["resource"]]
		world_batches.draw_resource_glow(point, radius * 2.6, tint, 0.58)
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
			map_canvas.draw_string(font, point + Vector2(9, -9), "%s · %.1f · %ds%s" % [pile["resource"], float(pile["amount"]), ceili(remaining), " · Claimed" if claimant >= 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.35))

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
		world_batches.queue_cargo_rect(corners, Color("#182333"))
		var start: float = -half_length
		for segment in bays[k]:
			var end: float = minf(half_length, start + 2.0 * half_length * float(segment["amount"]) / per_bay)
			# Fractional tonnes can project to a degenerate polygon.
			if (end - start) * forward.length() >= 0.1:
				var fill := PackedVector2Array([module + forward * end + lateral * half_width, module + forward * start + lateral * half_width, module + forward * start - lateral * half_width, module + forward * end - lateral * half_width])
				world_batches.draw_cargo_segment(fill, HUD.COLORS[segment["resource"]])
			start = end

func _transfer_anchor(state: Dictionary, poses: Dictionary, refs: Dictionary, id: int, resource: String, bay: int) -> Vector2:
	var ref: Dictionary = refs.get(id, {})
	if ref.get("kind", "") == "station":
		var node: int = int(ref["node"])
		if not ECONOMY.discovered(state, _me(), "planets", node):
			return Vector2.INF
		return STRUCTURE_VIEW.bay_point(_screen_point(ECONOMY.station_position(state, node, float(state["elapsed"]))), _station_radius(), float(state["elapsed"]), resource, bay)
	if not poses.has(id):
		return Vector2.INF
	var pose: Dictionary = poses[id]
	var kind: String = str(pose["kind"])
	var offset: Vector2 = Vector2.ZERO
	if kind == "ship":
		offset = hull_art.freighter_bay_center(bay)
	elif kind == "miner":
		offset = Vector2(5.7, -4.8 if bay == 0 else 4.8)
	elif kind == "colony_ship":
		offset = Vector2(4.0 - float(bay) * 2.65, 0.0)
	var axis: Vector2 = pose["direction"]
	return (pose["point"] as Vector2) + (axis * offset.x + axis.orthogonal() * offset.y) * _ship_scale() * HULL_ART.visual_scale(kind)

func _draw_map() -> void:
	_begin_draw_projection()
	_draw_map_content()
	_draw_projection_active = false

# Client-only light sources, using the already visibility-filtered hull poses.
func _prepare_world_lighting(state: Dictionary, points: Array, poses: Dictionary, bounds: Rect2, render_scale: float) -> void:
	var stars: Array = []
	var lamps: Array = []
	var center: Vector2 = bounds.get_center()
	var radius: float = maxf(12.0, 10800.0 * render_scale)
	var blockers: Array = []
	for index in range(points.size()):
		if not ECONOMY.discovered(state, _me(), "planets", index) or not fog_state.is_explored(points[index], _map_size()):
			continue
		var pos: Vector2 = _screen_point(points[index])
		if not bounds.grow(radius).has_point(pos):
			continue
		var tint: Color = Color("#ffe6bb") if ECONOMY.has_planets(state["planets"][index]) else Color("#a7c9ff")
		_keep_near_light(stars, [pos, radius, tint, 1.55, center.distance_squared_to(pos), true])
		world_batches.draw_resource_glow(pos, minf(radius, 240.0), tint, 0.15)
		# Only nearby visible planets cast eclipses, and only onto other planets.
		if not _fog_visible(points[index]):
			continue
		var system_radius: float = _planet_radius(index, state)
		if celestial_view.planet_detail_opacity(index, system_radius) > 0.05:
			for body in celestial_view.system_visual(index, state)["bodies"]:
				var at: Vector2 = pos + celestial_view.body_position(body, system_radius, celestial_view.orbit_time(state))
				var disc_radius: float = system_radius * float(body["size"]) * 0.55
				if disc_radius >= 5.0 and bounds.grow(disc_radius * 2.0).has_point(at):
					_keep_near_light(blockers, [at, disc_radius, null, 0.0, center.distance_squared_to(at)])
	var scale: float = _ship_scale()
	var running: bool = int(state.get("time_speed", 1)) > 0
	if scale >= 0.325:
		for ship in state["ships"]:
			var id: int = int(ship["id"])
			if not poses.has(id) or bool(ship.get("cloaked", false)) or ECONOMY.is_static_structure(ship):
				continue
			var pose: Dictionary = poses[id]
			var pos: Vector2 = pose["point"]
			var hull_scale: float = scale * HULL_ART.visual_scale(str(ship["kind"]))
			if hull_scale < 0.65 or not bounds.grow(120.0 * hull_scale).has_point(pos):
				continue
			var direction: Vector2 = pose["direction"]
			var thrust: float = ship_motion.thrust_for(id) if running else 0.0
			if thrust <= 0.035:
				continue
			pos = world_batches.exhaust_center(str(ship["kind"]), pos, direction, hull_scale, thrust)
			var radius_px: float = (22.0 + 18.0 * thrust) * hull_scale
			var strength: float = 0.32 * thrust
			if bounds.grow(radius_px).has_point(pos):
				_keep_near_light(lamps, [pos, radius_px, _empire_color(int(ship["owner"])), strength, center.distance_squared_to(pos)])
	var impacts: Array = world_effects.impact_lights(state, poses, _frame_service_refs(state), bounds, scale, celestial_view.orbit_time(state), _screen_point, _fog_visible, _empire_color)
	# Keep the total 16-source shader budget; hits take precedence over
	# local navigation lamps. Add one glow per retained impact.
	for entry in impacts:
		world_batches.queue_lamp_glow(entry[0], float(entry[1]) * 0.55, entry[2], minf(0.9, float(entry[3])))
	world_batches.set_world_lights((stars + impacts + lamps.slice(0, maxi(0, 16 - stars.size() - impacts.size()))).slice(0, 16), blockers)

func _keep_near_light(lights: Array, entry: Array) -> void:
	if lights.size() >= 8 and float(entry[4]) >= float(lights.back()[4]):
		return
	var index: int = lights.size()
	while index > 0 and float(entry[4]) < float(lights[index - 1][4]):
		index -= 1
	lights.insert(index, entry)
	if lights.size() > 8:
		lights.pop_back()

func _draw_map_content() -> void:
	_update_fog(_state())
	fog_overlay.queue_redraw()
	queued_order_overlay.queue_redraw()
	logistics_overlay.queue_redraw()
	objectives_overlay.queue_redraw()
	celestial_view.begin_frame()
	world_batches.begin_frame()
	if session == null:
		return
	var state: Dictionary = _state()
	if state.is_empty():
		return
	celestial_view.prepare_map(state)
	var viewport_bounds := Rect2(Vector2.ZERO, map_canvas.size)
	var render_scale: float = _fit() * camera.zoom
	var points: Array = state["map"]["points"]
	var poses: Dictionary = _ship_poses(state)
	_prepare_world_lighting(state, points, poses, viewport_bounds, render_scale)
	celestial_view.set_asteroid_lights(map_canvas, world_batches.world_lights)
	var font: Font = ThemeDB.fallback_font
	var fields: Array = state["map"].get("fields", [])
	var remembered_state: Dictionary = fog_state.observed_state(state, _map_size())
	for field_index in range(fields.size()):
		var field: Dictionary = fields[field_index]
		var center: Vector2 = _screen_point(field["position"])
		if not viewport_bounds.grow(float(field.get("rock_extent", field["radius"])) * render_scale * 2.0 + 40.0).has_point(center):
			continue
		if not bool(field.get("antimatter", false)):
			var live_rocks: Array = fog_state.rock_view(field_index).get("live", [])
			var transforms: Array[Transform2D] = MAP.asteroid_orbit_transforms(field, celestial_view.orbit_time(state))
			celestial_view.draw_asteroid_chunks({"chunks": live_rocks}, viewport_bounds, render_scale, map_canvas, _draw_projection_size * 0.5, _draw_world_center, _draw_fit, _draw_zoom, world_batches.light_level(center), visual_clock, field_index, transforms)
			if selected_field == field_index and selected_rock >= 0:
				var rock: Dictionary = fog_state.rock_at(field_index, selected_rock)
				if not rock.is_empty() and _fog_visible(rock["position"]):
					_draw_rock_selection(map_canvas, rock, render_scale, MAP.asteroid_orbit_position(rock, transforms))
			continue
		if not ECONOMY.discovered(state, _me(), "fields", field_index):
			if bool(field.get("antimatter", false)):
				map_canvas.draw_string(font, center + Vector2(-10, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, HUD.MUTED)
			continue
		var field_live: bool = _fog_visible(field["position"])
		field = fog_state.field_view(state, field_index, _map_size())
		if field.is_empty():
			continue
		var boundary := PackedVector2Array()
		for vertex in field["outline"]:
			boundary.append(_screen_point(vertex))
		if not boundary.is_empty():
			var special: bool = bool(field.get("antimatter", false))
			var edge_tint: Color = HUD.COLORS[ECONOMY.ANTIMATTER] if special else Color("#b9ac77")
			if selected_field == field_index:
				boundary.append(boundary[0])
				map_canvas.draw_polyline(boundary, HUD.ACCENT, 1.5, true)
			if special:
				map_canvas.draw_string(font, center + Vector2(-60, float(field["radius"]) * render_scale + 14.0), "Pulsar", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, edge_tint)
		if bool(field.get("antimatter", false)):
			var pulse: float = 0.5 + 0.5 * sin(visual_clock * 3.0) if field_live else 0.5
			var star_radius: float = maxf(4.0, float(field["radius"]) * render_scale * 0.16)
			var glow: Color = HUD.COLORS[ECONOMY.ANTIMATTER]
			world_batches.draw_resource_glow(center, star_radius * 2.0, glow, 0.6 + pulse * 0.4)
			map_canvas.draw_circle(center, star_radius, glow.lightened(0.7), true, -1.0, true)
			var axis: Vector2 = Vector2.from_angle(visual_clock * 0.8 if field_live else 0.0)
			map_canvas.draw_line(center - axis * star_radius * 4.0, center + axis * star_radius * 4.0, Color(glow, 0.45 + pulse * 0.4), maxf(1.0, star_radius * 0.45), true)
			continue
	for i in range(points.size()):
		var pos: Vector2 = _screen_point(points[i])
		if not ECONOMY.discovered(state, _me(), "planets", i):
			continue
		var live: bool = _fog_visible(points[i])
		var system: Dictionary = fog_state.system_view(state, i, _map_size())
		if system.is_empty():
			# Discovery may precede the first local observation.
			map_canvas.draw_circle(pos, 3.0, HUD.MUTED)
			continue
		var view: Dictionary = state if live else remembered_state
		var seen_at: float = float(state["elapsed"]) if live else fog_state.observed_time(i)
		var radius: float = _planet_radius(i, view)
		var tint: Color = _empire_color(int(system["owner"]))
		var detail: float = _draw_system(i, view, pos, radius, tint, -1.0 if live else seen_at)
		if not live or _fog_visible(ECONOMY.station_position(state, i, float(state["elapsed"]))):
			structure_view.draw_station(view, i, tint, seen_at, building_selection_kind, selected_buildings)
			structure_view.draw_shipyards(view, i, tint, seen_at, selected, selected_yard, building_selection_kind, selected_buildings)
		# Incoming resource pods must remain visible as they cross the
		# opaque station hull and enter its storage bays.
		if live and detail >= 0.05:
			planet_traffic.draw_production(state, i, pos, radius, detail)
		if _show_system_rings(i):
			var phase: float = 0.6 + 0.35 * sin(visual_clock * 3.0)
			for angle in range(4):
				var start: float = float(angle) * TAU / 4.0 + 0.1
				map_canvas.draw_arc(pos, maxf(5.0, celestial_view.star_draw_radius(radius)) + 8.0, start, start + 1.15, 14, Color(HUD.ACCENT, phase), 2.0, true)
	var pose_overrides: Dictionary = {}
	_draw_salvage(state, poses, viewport_bounds, font)
	var service_refs: Dictionary = _frame_service_refs(state)
	for index in range(points.size()):
		if not ECONOMY.discovered(state, _me(), "planets", index) or not _fog_visible(points[index]):
			continue
		var system: Dictionary = state["planets"][index]
		var station: Dictionary = system.get("station", {})
		if float(station.get("missile_until", -1.0)) >= float(state["elapsed"]) and station.has("missile_endpoint"):
			var launch: Vector2 = _screen_point(station["missile_origin"])
			var impact: Vector2 = _screen_point(station["missile_endpoint"])
			var phase: float = clampf(1.0 - (float(station["missile_until"]) - celestial_view.orbit_time(state)) / 0.65, 0.0, 1.0)
			var tip: Vector2 = launch.lerp(impact, phase)
			world_batches.queue_beam(tip - launch.direction_to(impact) * 12.0, tip, Color("#ffb36b"), 2.0)
			world_batches.queue_projectile(tip, 2.0, Color("#fff2d2"))
		var weapons: Array = system.get("station", {}).get("weapons", [])
		for emitter in range(weapons.size()):
			var weapon: Dictionary = weapons[emitter]
			var target: int = int(weapon["target"])
			if (not poses.has(target) and not weapon.has("wall_laser_endpoint")) or float(weapon["laser_until"]) < float(state["elapsed"]):
				continue
			var center: Vector2 = _screen_point(ECONOMY.station_position(state, index, float(state["elapsed"])))
			var endpoint: Vector2 = _screen_point(weapon["wall_laser_endpoint"]) if weapon.has("wall_laser_endpoint") else poses[target]["point"]
			var offset: Vector2 = center.direction_to(endpoint).orthogonal() * (float(emitter) * 2.0 - float(weapons.size() - 1)) * 4.0 * _ship_scale(true)
			_draw_owned_laser(center + offset, endpoint, int(system["owner"]), 1.5)
		var defenses: Dictionary = state["planets"][index].get("pds", {})
		if defenses.is_empty():
			continue
		var radius: float = _planet_radius(index, state)
		for slot in defenses:
			var battery: Dictionary = defenses[slot]
			var target: int = int(battery["target"])
			if (not poses.has(target) and not battery.has("wall_laser_endpoint")) or float(battery["laser_until"]) < float(state["elapsed"]):
				continue
			var origin: Vector2 = _screen_point(points[index])
			if celestial_view.planet_detail_opacity(index, radius) >= 0.5:
				origin += celestial_view.body_position(celestial_view.system_visual(index, state)["bodies"][slot], radius, celestial_view.orbit_time(state))
			var endpoint: Vector2 = _screen_point(battery["wall_laser_endpoint"]) if battery.has("wall_laser_endpoint") else poses[target]["point"]
			_draw_owned_laser(origin, endpoint, int(state["planets"][index]["owner"]), 2.0)
	for ship in state["ships"]:
		var shooter: int = int(ship["id"])
		if not poses.has(shooter):
			continue
		if float(ship.get("cannon_until", -1.0)) >= float(state["elapsed"]) and ship.has("cannon_endpoint"):
			world_batches.queue_beam(poses[shooter]["point"], _screen_point(ship["cannon_endpoint"]), Color("#f4be64"), 3.0)
		if ship.has("blaster_fired"):
			_draw_blaster_tracers(state, ship, poses)
		if float(ship.get("railgun_until", -1.0)) >= float(state["elapsed"]) and ship.has("railgun_endpoint"):
			var rail_origin: Vector2 = _screen_point(ship["railgun_origin"])
			var rail_end: Vector2 = _screen_point(ship["railgun_endpoint"])
			world_batches.queue_beam(rail_origin, rail_end, Color("#739dff"), 4.0)
			world_batches.queue_beam(rail_origin, rail_end, Color("#e7f2ff"), 1.5)
		if float(ship.get("missile_until", -1.0)) >= float(state["elapsed"]) and ship.has("missile_endpoint"):
			var a: Vector2 = _screen_point(ship["missile_origin"])
			var b: Vector2 = _screen_point(ship["missile_endpoint"])
			var phase: float = clampf(1.0 - (float(ship["missile_until"]) - celestial_view.orbit_time(state)) / 0.65, 0.0, 1.0)
			var axis: Vector2 = a.direction_to(b)
			for launcher in range(ECONOMY.missile_count(str(ship["kind"]))):
				var offset: Vector2 = axis.orthogonal() * (float(launcher) - float(ECONOMY.missile_count(str(ship["kind"])) - 1) * 0.5) * 6.0 * sin(phase * PI)
				var launch: Vector2 = a
				if poses.has(shooter):
					var facing: Vector2 = poses[shooter]["direction"]
					var mount: Vector2 = Vector2(4, 0) if ship["kind"] == "cruiser" else Vector2(8, -8 if launcher == 0 else 8)
					launch += (facing * mount.x + facing.orthogonal() * mount.y) * _ship_scale()
				var tip: Vector2 = launch.lerp(b, phase) + offset
				world_batches.queue_beam(tip - axis * 12.0, tip, Color("#ffb36b"), 2.0)
				world_batches.queue_projectile(tip, 2.0, Color("#fff2d2"))
		var target: int = int(ship.get("combat_target", -1))
		var yard_target: int = int(ship.get("yard_target", -1))
		var wall_beam: bool = ship.has("wall_laser_endpoint") and float(ship.get("wall_laser_until", -1.0)) >= float(state["elapsed"])
		if wall_beam:
			pose_overrides[shooter] = _draw_ship_laser(ship, pose_overrides.get(shooter, poses[shooter]), _screen_point(ship["wall_laser_endpoint"]), 1.5 if yard_target < -1 else 1.0)
		if not wall_beam and poses.has(shooter) and yard_target < -1 and float(ship.get("yard_laser_until", -1.0)) >= float(state["elapsed"]):
			var encoded: int = -2 - yard_target
			var count: int = (state["planets"] as Array).size()
			if encoded < count * 3:
				var index: int = floori(float(encoded) / 3.0)
				var slot: int = posmod(encoded, 3)
				if slot < state["planets"][index]["yards"].size():
					pose_overrides[shooter] = _draw_ship_laser(ship, pose_overrides.get(shooter, poses[shooter]), _screen_point(ECONOMY.shipyard_position(state, index, slot, float(state["elapsed"]))), 1.5)
			elif encoded >= count * 9:
				var station_index: int = encoded - count * 9
				if station_index < count and ECONOMY.has_station(state["planets"][station_index]):
					pose_overrides[shooter] = _draw_ship_laser(ship, pose_overrides.get(shooter, poses[shooter]), _screen_point(ECONOMY.station_position(state, station_index, float(state["elapsed"]))), 1.5)
			else:
				var pds_index: int = posmod(encoded - count * 3, count)
				var pds_slot: int = floori(float(encoded - count * 3) / float(count))
				if state["planets"][pds_index].get("pds", {}).has(pds_slot):
					var endpoint: Vector2 = _screen_point(points[pds_index])
					var pds_radius: float = _planet_radius(pds_index, state)
					if celestial_view.planet_detail_opacity(pds_index, pds_radius) >= 0.5:
						endpoint += celestial_view.body_position(celestial_view.system_visual(pds_index, state)["bodies"][pds_slot], pds_radius, celestial_view.orbit_time(state))
					pose_overrides[shooter] = _draw_ship_laser(ship, pose_overrides.get(shooter, poses[shooter]), endpoint, 1.5)
		if not wall_beam and poses.has(shooter) and poses.has(target) and float(ship.get("laser_until", 0.0)) >= float(state["elapsed"]):
			pose_overrides[shooter] = _draw_ship_laser(ship, pose_overrides.get(shooter, poses[shooter]), poses[target]["point"], 1.0)
		if bool(ship.get("retreating", false)) and poses.has(shooter) and (ship["route"] as Array).is_empty():
			var site: int = int(ship.get("repair_site", -1))
			if site >= 0 and site < state["planets"].size():
				var world: Vector2 = ECONOMY.station_position(state, site, float(state["elapsed"]))
				if int(ship["at"]) == site and (ship["position"] as Vector2).distance_to(world) <= ECONOMY.STATION_REPAIR_RANGE + ECONOMY.EPS and ECONOMY.repair_site_safe(state, ECONOMY.military_graph(state), int(ship["owner"]), site):
					var hub: Vector2 = _screen_point(ECONOMY.station_position(state, site, celestial_view.orbit_time(state)))
					var end: Vector2 = poses[shooter]["point"]
					var aim: Vector2 = hub.direction_to(end)
					if not aim.is_zero_approx():
						for side in [-1.0, 1.0]:
							var muzzle: Vector2 = hub + (aim * 0.8 + aim.orthogonal() * side * 0.35) * _station_radius()
							world_batches.queue_beam(muzzle, end, Color("#59e8a4"), 1.4)
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
				var repair_pose: Dictionary = pose_overrides.get(shooter, poses[shooter]).duplicate()
				repair_pose["direction"] = axis
				pose_overrides[shooter] = repair_pose
				for side in [-1.0, 1.0]:
					var muzzle: Vector2 = origin + (axis * WORLD_EFFECTS.MINER_MUZZLE.x + axis.orthogonal() * side * WORLD_EFFECTS.MINER_MUZZLE.y) * _ship_scale()
					world_batches.queue_beam(muzzle, endpoint, Color("#59e8a4"), 1.4)
	var ship_scale: float = _ship_scale()
	var ship_overview: float = _overview_art_multiplier(OVERVIEW_SHIP_MAX_MULTIPLIER)
	var ship_metrics_cache: Dictionary = {}
	var owner_color_cache: Dictionary = {}
	var hull_color_cache: Dictionary = {}
	var hull_texture_cache: Dictionary = {}
	var detailed_hulls: bool = ship_scale >= 0.42
	var simulation_running: bool = int(state.get("time_speed", 1)) > 0
	var selected_lookup: Dictionary = {}
	for id in selected_units:
		selected_lookup[id] = true
	for ship in state["ships"]:
		if not poses.has(int(ship["id"])):
			continue
		var ship_id: int = int(ship["id"])
		var kind: String = str(ship["kind"])
		var owner: int = int(ship["owner"])
		var pose: Dictionary = pose_overrides.get(ship_id, poses[ship_id])
		var point: Vector2 = pose["point"]
		var scale: float = ship_scale * HULL_ART.visual_scale(kind)
		if not viewport_bounds.grow(maxf(32.0, 80.0 * scale)).has_point(point):
			continue
		var direction: Vector2 = pose["direction"]
		if not bool(ship.get("holding", false)) and ship.get("mining_mode", "") == "mining" and ship.has("mining_rock") and not ECONOMY.ship_engaged(ship) and int(ship.get("yard_target", -1)) >= -1:
			var aim: Vector2 = _screen_point(ship["mining_rock"]) - point
			if not aim.is_zero_approx():
				direction = aim.normalized()
		var empire: Color
		if owner_color_cache.has(owner):
			empire = owner_color_cache[owner]
		else:
			empire = _empire_color(owner)
			owner_color_cache[owner] = empire
		var hull: Color
		if hull_color_cache.has(owner):
			hull = hull_color_cache[owner]
		else:
			hull = empire.lightened(0.35)
			hull_color_cache[owner] = hull
		var side: Vector2 = direction.orthogonal() * scale
		direction *= scale
		var cloaked: bool = bool(ship.get("cloaked", false))
		var thrust: float = ship_motion.thrust_for(ship_id)
		if not cloaked and scale >= 0.65 and not ECONOMY.is_static_structure(ship):
			# Match the same interpolated heading used by the light prepass.
			# Weapon/mining pose overrides must not detach the glow from its plume.
			var engine_axis: Vector2 = poses[ship_id]["direction"]
			if simulation_running and thrust > 0.035:
				world_batches.queue_exhaust(kind, point, engine_axis, scale, thrust, ship_id, viewport_bounds, empire)
				var plume_center: Vector2 = world_batches.exhaust_center(kind, point, engine_axis, scale, thrust)
				var nozzle: Vector2 = HULL_ART.paired_nozzle(kind)
				for sign in ([-1.0, 1.0] if not nozzle.is_zero_approx() else [0.0]):
					world_batches.queue_lamp_glow(plume_center + engine_axis.normalized().orthogonal() * nozzle.y * sign * scale, (9.0 + 8.0 * thrust) * scale, empire, (0.16 if sign != 0.0 else 0.25) * thrust)
		if bool(ship.get("mining_active", false)) and ship.get("mining_mode", "") == "mining" and not ECONOMY.salvage_active(ship) and not bool(ship.get("holding", false)) and ship.has("mining_rock") and viewport_bounds.grow(maxf(32.0, 14.0 * scale)).has_point(point) and scale >= 0.65:
			var rock: Vector2 = _screen_point(ship["mining_rock"])
			for sign in [-1.0, 1.0]:
				var emitter: Vector2 = point + direction * WORLD_EFFECTS.MINER_MUZZLE.x + side * sign * WORLD_EFFECTS.MINER_MUZZLE.y
				var impact: Vector2 = rock + side * sign * 2.0
				_draw_owned_laser(emitter, impact, int(ship["owner"]), maxf(0.8, scale))
				for k in range(3 if scale >= 1.0 else 1):
					var age: float = fposmod(visual_clock * 4.0 + float(k) * 0.33 + sign * 0.12, 1.0)
					var spark: Vector2 = impact - direction * age * 6.0 + side * sign * age * float(k + 1) * 2.0
					map_canvas.draw_circle(spark, maxf(0.7, scale * (1.0 - age)), Color(1.0, 0.85, 0.45, 1.0 - age), false)
		if ship_id == selected_ship_id or selected_lookup.has(ship_id):
			var radius: float = maxf(5.0, hull_art.ui_radius(kind) * scale)
			world_batches.draw_selection_ring(point, radius)
		# At a distant galaxy overview, the smallest authored edges can
		# collapse into an invalid polygon after projection. Keep the hull
		# visible and owner-colored rather than drawing degenerate geometry.
		var metrics: Dictionary = ship_metrics_cache.get(kind, {})
		if metrics.is_empty():
			metrics = {"radius": hull_art.ui_radius(kind), "max_hp": ECONOMY.ship_max_hp(kind), "half_size": hull_art.texture_half_size(kind), "flag_offset": hull_art.ship_flag_offset(kind)}
			ship_metrics_cache[kind] = metrics
		var radius: float = float(metrics["radius"])
		var maximum_hp: float = ECONOMY.hull_max_hp(ship) if ECONOMY.is_static_structure(ship) else float(metrics["max_hp"])
		var half_size: float = float(metrics["half_size"])
		var shield: float = _shield_fraction(ship)
		_draw_damage_bar(point, radius * scale, float(ship.get("hp", maximum_hp)) / maximum_hp, shield)
		if kind == "colony_ship" and ship.has("colony_transform_progress"):
			structure_view.draw_colony_transform(ship, point, direction.normalized(), scale, empire, float(state["elapsed"]))
			continue
		if kind == "wall_segment":
			var wall_color: Color = empire if ECONOMY.static_complete(ship) else Color(empire, 0.35)
			map_canvas.draw_line(_screen_point(ship["wall_a"]), _screen_point(ship["wall_b"]), wall_color, maxf(2.0, scale * 5.0), true)
			continue
		if kind == "warp_gate":
			var gate_radius: float = maxf(5.0, 44.0 * scale)
			map_canvas.draw_circle(point, gate_radius, Color("#382b58"), true, -1.0, true)
			map_canvas.draw_arc(point, gate_radius, 0.0, TAU, 32, empire, maxf(1.0, scale * 2.0), true)
			map_canvas.draw_arc(point, gate_radius * 0.72, 0.0, TAU, 32, Color("#b998ff"), maxf(1.0, scale * 2.0), true)
			map_canvas.draw_circle(point, gate_radius * 0.48, Color("#151225"), true, -1.0, true)
			continue
		if scale < 0.15 * ship_overview:
			world_batches.queue_overview_hull(world_batches.overview_dot_texture(hull), point, 0.0, maxf(0.8, 6.0 * scale / ship_overview) * ship_overview, cloaked)
			continue
		# hull_texture formats a string key; resolve it once per kind/owner.
		var owner_textures: Dictionary = hull_texture_cache.get(kind, {})
		if owner_textures.is_empty():
			hull_texture_cache[kind] = owner_textures
		var texture: Texture2D = owner_textures.get(owner)
		if texture == null:
			texture = hull_art.hull_texture(kind, empire, detailed_hulls)
			owner_textures[owner] = texture
		if shield > 0.0:
			world_batches.queue_overview_hull(hull_art.shield_texture(kind), point, direction.angle(), (half_size + 8.0) * scale, cloaked)
		var art_angle: float = direction.angle() + HULL_ART.sprite_heading_offset(kind)
		world_batches.queue_overview_hull(texture, point, art_angle, half_size * scale, cloaked)
		if logistics_view.ship_flags_enabled and owner > 0 and not bool(ship.get("rogue", false)) and not ECONOMY.is_static_structure(ship) and kind != "probe":
			var flag_at: Vector2 = point + direction * float(metrics["flag_offset"])
			world_batches.queue_ship_flag(flag_at, clampf(1.6 * scale, 1.1, 4.0), Color(empire.lightened(0.18), 0.45 if cloaked else 1.0))
		if kind == "ship" and scale >= 0.42:
			# Foreground bay fills on the authored hull. Preserve fractional cargo
			# and ten independent display bays in the existing cargo batch.
			var bays: Array = ECONOMY.freighter_cargo_bays(ship["cargo"])
			for k in range(bays.size()):
				var offset: Vector2 = hull_art.freighter_bay_center(k)
				var bay_center: Vector2 = point + direction * offset.x + side * offset.y
				var start: float = -3.0
				for segment in bays[k]:
					var end: float = minf(3.0, start + 6.0 * float(segment["amount"]) / ECONOMY.FREIGHTER_BAY_CAPACITY)
					if (end - start) * scale >= 0.1:
						var corners := PackedVector2Array([bay_center + direction * end + side * 3.0, bay_center + direction * start + side * 3.0, bay_center + direction * start - side * 3.0, bay_center + direction * end - side * 3.0])
						world_batches.draw_cargo_segment(corners, HUD.COLORS[segment["resource"]])
					start = end
		elif kind == "science_ship":
			if float(ship.get("cargo", {}).get(ECONOMY.ANTIMATTER, 0.0)) >= 1.0 - ECONOMY.EPS:
				var tint: Color = HUD.COLORS[ECONOMY.ANTIMATTER]
				var pulse: float = 0.5 + 0.5 * sin(visual_clock * 4.0)
				# The cargo sits above the sprite, not underneath its opaque panels.
				world_batches.queue_cargo_light(point, maxf(2.0, 8.0 * scale), tint, 0.7 + 0.3 * pulse)
				world_batches.queue_cargo_light(point, maxf(1.0, (2.5 + pulse) * scale), tint.lightened(0.5), 1.0)
				for k in range(3):
					var angle: float = visual_clock * 2.0 + TAU * float(k) / 3.0
					world_batches.queue_cargo_light(point + Vector2.from_angle(angle) * 5.0 * scale, maxf(0.7, scale), tint, 1.0)
		elif scale >= 0.42:
			_draw_other_cargo(ship, point, direction, side)
	world_effects.draw_destructions(viewport_bounds, visual_clock, _ship_scale, _screen_point, world_batches)
	world_batches.flush_world(visual_clock, hull_art)
	var transfer_poses: Dictionary = poses
	if not pose_overrides.is_empty():
		transfer_poses = poses.duplicate()
		for id in pose_overrides:
			transfer_poses[id] = pose_overrides[id]
	world_effects.draw_cargo_transfers(state, transfer_poses, service_refs, viewport_bounds, visual_clock, _ship_scale, map_canvas, _transfer_anchor)
	world_batches.flush_indicators()

func _draw_logistics_overlay() -> void:
	if session == null:
		return
	var state: Dictionary = _state()
	if not state.is_empty():
		logistics_view.draw(state, ThemeDB.fallback_font)

func _draw_objectives_overlay() -> void:
	if session == null:
		return
	var state: Dictionary = _state()
	if state.is_empty():
		return
	conquest_ui.draw(state)
	notice_ui.draw(ThemeDB.fallback_font)

func _empire_name(id: int) -> String:
	return empire_ui.empire_name(id)

func _confirm_war(other: int, ids: Array = [], target: int = -1) -> void:
	empire_ui.confirm_war(other, ids, target)

func _open_empire() -> void:
	empire_ui.open()

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
	if ECONOMY.station_queue_count(p) >= ECONOMY.STATION_QUEUE_LIMIT:
		return false
	if key in ECONOMY.RESOURCES:
		return ECONOMY.building_available(p, key) and ECONOMY.construction_affordable(_state(), p, ECONOMY.building_cost(p, key))
	match key:
		"warehouse":
			return ECONOMY.warehouse_available(p) and ECONOMY.construction_affordable(_state(), p, ECONOMY.WAREHOUSE_COSTS[int(p.get("warehouse_level", 0))])
		"housing":
			if ECONOMY.has_planets(p):
				return ECONOMY.habitation_available(p) and ECONOMY.construction_affordable(_state(), p, ECONOMY.habitation_cost(p))
			return ECONOMY.orbital_housing_available(p) and ECONOMY.construction_affordable(_state(), p, ECONOMY.ORBITAL_HOUSING_COST)
		"yard":
			var level: int = ECONOMY.next_shipyard_slot(p)
			return level > 0 and ECONOMY.construction_affordable(_state(), p, ECONOMY.base_recipe_cost("yard", level))
		"pds":
			return ECONOMY.next_pds(p) >= 0 and ECONOMY.pds_job(p).is_empty() and ECONOMY.construction_affordable(_state(), p, ECONOMY.base_recipe_cost("pds", 1))
	return ECONOMY.station_upgrade_available(p, key) and ECONOMY.construction_affordable(_state(), p, ECONOMY.base_recipe_cost(key, 1))

# Local debug-build command registry. No evaluation and no development RPCs.
func _dev_console_modal_open() -> bool:
	if conquest_ui.dialog_visible() or empire_ui.dialog_visible():
		return true
	for dialog in [match_menu, match_result_dialog, codex, match_settings.hotkey_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			return true
	return false
