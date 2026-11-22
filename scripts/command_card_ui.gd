extends RefCounted
## Reusable command-card presentation. Does not own selection, hotkeys or orders.
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")
const CostButton = preload("res://scripts/cost_button.gd")

# Per-match texture cache, keyed by command and requested pixel size.
var _icons: Dictionary = {}
var _unavailable_build_style: StyleBoxFlat = HUD.surface(Color("#0b1621"), Color("#263748"), 3, 5)
var _impossible_build_style: StyleBoxFlat = HUD.surface(Color("#24181e"), Color("#58343e"), 3, 5)
const INFO_HEIGHT_RATIO: float = 0.55
const INFO_MAX_HEIGHT_RATIO: float = 0.65
const INFO_PADDING: Vector2 = Vector2(7.0, 5.0)
var _info_host: Panel
var _anchor: Control
var _deck_slot: Control
var _info: RichTextLabel
var _hovered: Control
var _signature: String = ""


func create_grid(parent: Container) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(grid)
	return grid

func add_spacer(grid: GridContainer) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slot)
	return slot

func fill_grid(grid: GridContainer) -> void:
	while grid.get_child_count() < 16:
		add_spacer(grid)

func set_face(button: Button, caption: String, picture: Texture2D) -> TextureRect:
	register_info(button, caption.replace("\n", " "))
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

# Manual construction eligibility is independent of right-click automation.
func set_build_available(button: Button, available: bool, impossible: bool = false) -> void:
	var visual_state: int = 0 if available else (2 if impossible else 1)
	if int(button.get_meta("build_visual_state", -1)) == visual_state:
		return
	button.set_meta("build_available", available)
	button.set_meta("build_visual_state", visual_state)
	for style in ["normal", "hover", "pressed", "disabled"]:
		if available:
			button.remove_theme_stylebox_override(style)
		else:
			button.add_theme_stylebox_override(style, _impossible_build_style if impossible else _unavailable_build_style)

# Keep displayed requirements and their red styling in sync.
func add_build_blocker(button: Button, reason: String) -> void:
	if reason.is_empty():
		return
	var cost_button: CostButton = button as CostButton
	if not cost_button.unmet_requirements.has(reason):
		cost_button.unmet_requirements.append(reason)
	var description: String = hint(button)
	if not description.split("\n").has(reason):
		set_hint(button, description + "\n" + reason)

func set_level_badge(button: Button, level: int) -> void:
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
	label.text = UI_TEXT.roman_level(level)

func hint(button: Control) -> String:
	return str(button.get_meta("command_hint", "")) if button.has_meta("command_hint") else button.tooltip_text

func set_hint(button: Control, hint: String) -> void:
	if button.has_meta("command_hint"):
		button.set_meta("command_hint", hint)
		button.tooltip_text = ""
	else:
		button.tooltip_text = hint

# Fixed-size overlay, deliberately not a Container. Text can never resize
# the card deck or stretch the information background across the map.
func setup_info(parent: Control, anchor: Control, deck_slot: Control) -> void:
	_anchor = anchor
	_deck_slot = deck_slot
	_info_host = Panel.new()
	_info_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_host.clip_contents = true
	_info_host.z_index = 100
	_info_host.theme = HUD.compact()
	_info_host.add_theme_stylebox_override("panel", HUD.surface(Color("#101b29"), Color("#6385a4"), 0, 3))
	parent.add_child(_info_host)
	_info_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_info = RichTextLabel.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.fit_content = false
	_info.scroll_active = false
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_constant_override("line_separation", 0)
	_info.add_theme_color_override("default_color", HUD.TEXT)
	_info_host.add_child(_info)
	_info_host.hide()

func register_info(control: Control, title: String) -> void:
	if not control.has_meta("command_hint"):
		control.set_meta("command_hint", control.tooltip_text)
	control.set_meta("command_title", title)
	control.tooltip_text = ""

func refresh_info(viewport: Viewport) -> void:
	if not is_instance_valid(_info_host) or not is_instance_valid(_anchor) or not is_instance_valid(_deck_slot):
		return
	var control: Control = viewport.gui_get_hovered_control()
	while is_instance_valid(control) and not control.has_meta("command_title"):
		control = control.get_parent() as Control
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		_info_host.hide()
		_hovered = null
		return
	var title: String = str(control.get_meta("command_title"))
	var description: String = str(control.get_meta("command_hint", ""))
	if description.is_empty() or description.begins_with("["):
		description = title + ("\n" + description if not description.is_empty() else "")
	var recipe: Dictionary = {}
	var missing: Array[String] = []
	var unmet: Array[String] = []
	var crew_icon: Texture2D = null
	var effect: String = ""
	if control is CostButton:
		var cost_button: CostButton = control as CostButton
		recipe = cost_button.recipe
		missing = cost_button.missing
		unmet = cost_button.unmet_requirements
		crew_icon = cost_button.crew_icon
		effect = cost_button.effect_resource
	# Match the actual command wing exactly, including on narrow windows.
	var right: float = _anchor.global_position.x + _anchor.size.x
	var bottom: float = _anchor.global_position.y
	var width: float = _anchor.size.x
	var available_height: float = maxf(0.0, bottom - 4.0)
	var target_height: float = minf(roundf(_deck_slot.size.y * INFO_HEIGHT_RATIO), available_height)
	var max_height: float = minf(roundf(_deck_slot.size.y * INFO_MAX_HEIGHT_RATIO), available_height)
	if width <= INFO_PADDING.x * 2.0 or target_height <= INFO_PADDING.y * 2.0:
		_info_host.hide()
		_hovered = null
		return
	var signature: String = str([description, recipe, missing, unmet, effect, width, target_height, max_height])
	if _hovered != control or _signature != signature:
		_hovered = control
		_signature = signature
		_info_host.size = Vector2(width, target_height)
		_info.position = INFO_PADDING
		_info.size = _info_host.size - INFO_PADDING * 2.0
		_info.add_theme_font_size_override("normal_font_size", 12)
		CostButton.fill_info(_info, description, recipe, missing, crew_icon, effect, unmet)
		# Prefer the normal text size. Shrink only for longer descriptions;
		# the panel can grow slightly, but never beyond 65% of the deck.
		for font_size in [12, 11, 10]:
			_info.add_theme_font_size_override("normal_font_size", font_size)
			if _info.get_content_height() <= _info.size.y:
				break
		var content_height: float = float(_info.get_content_height()) + INFO_PADDING.y * 2.0
		_info_host.size = Vector2(width, clampf(content_height, target_height, max_height))
		_info.size = _info_host.size - INFO_PADDING * 2.0
	# No cursor-relative offset and no content-driven positioning.
	_info_host.global_position = Vector2(right - width, bottom - _info_host.size.y)
	_info_host.show()

func icon(kind: String, pixels: int = 64) -> Texture2D:
	var key: String = "%s:%d" % [kind, pixels]
	if _icons.has(key):
		return _icons[key]
	var paths: Dictionary = {
		"auto_retreat": '<path fill="#f6aa79" d="M3 16L15 4V11H28V21H15V28Z"/><path stroke="#ffe5cc" stroke-width="2" d="M18 7L28 7M18 25L28 25"/>',
		"auto_explore": '<circle cx="16" cy="16" r="13" fill="none" stroke="#8bd5ed" stroke-width="2"/><path d="M23 5L19 19L5 26L12 12Z" fill="#b4e9f9"/><circle cx="16" cy="16" r="2" fill="#122337"/>',
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
		"dyson_sphere": '<circle cx="16" cy="16" r="12" fill="#e7ae54" stroke="#b6d4eb" stroke-width="2"/><ellipse cx="16" cy="16" rx="6" ry="12" fill="none" stroke="#e0eef9" stroke-width="2"/><path d="M4 16H28M7 10H25M7 22H25" stroke="#e0eef9" stroke-width="1.5"/>',
		"laser_matrix": '<path fill="#829caf" d="M2 24L9 17L15 23L8 30ZM10 16L17 9L23 15L16 22Z"/><path stroke="#ff776f" stroke-width="4" d="M11 21L26 6M19 13L29 3"/><path stroke="#ffe9d8" stroke-width="1.3" d="M11 21L26 6M19 13L29 3"/>',
		"pds": '<circle cx="15" cy="18" r="11" fill="#5c90ad"/><path fill="#97c3d8" d="M5 17Q15 10 25 17L24 22Q15 16 6 22Z"/><path fill="#b3ccdf" d="M12 4H25L29 8V13H19L15 19L10 16L15 10H12Z"/><path stroke="#ff8c75" stroke-width="2.5" d="M25 7L30 2"/><path fill="#eaf6fc" d="M18 6H24V9H18Z"/>',
		"Metals": '<path fill="#9fb8c9" d="M2 17H30V29H2ZM5 6H10V18H5ZM13 2H18V18H13Z"/><path fill="#cbd9e3" d="M2 17L12 11V17L21 11V17L30 11V20H2Z"/><path fill="#344b60" d="M6 23H12V27H6ZM16 23H26V27H16Z"/><path fill="#ffd194" d="M5 6H10V9H5ZM13 2H18V5H13Z"/>',
		"Organics": '<path fill="#658b72" d="M2 24Q2 9 16 5Q30 9 30 24V29H2Z"/><path fill="#a6e0b5" d="M3 24Q3 11 16 5Q29 11 29 24H26Q26 14 16 9Q6 14 6 24Z"/><path fill="#b8e28e" d="M16 25Q5 22 9 15Q16 16 16 21Q18 13 24 13Q27 21 17 25Z"/><path stroke="#d0eaca" stroke-width="1.5" d="M16 29V20"/>',
		"Crystals": '<path fill="#849ab6" d="M3 13H29V28H3Z"/><path fill="#4a607a" d="M6 15H26V25H6Z"/><path fill="#bb9bf5" d="M16 2L24 11L20 23H12L8 11Z"/><path fill="#e7d6ff" d="M16 2L16 23L8 11Z"/><path fill="#c6deed" d="M3 26H29V29H3Z"/>'
	}
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g stroke-linecap="round" stroke-linejoin="round">' + str(paths.get(kind, paths["build"])) + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg, float(pixels) / 32.0)
	_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]
