extends RefCounted
## Per-match conquest presentation. Authority owns goals, rewards and mutations.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")
const OBJECTIVES_WIDTH: float = 328.0

var session: Node
var map_canvas: Control
var objectives_overlay: Control
var header_height: float
var local_player: Callable
var color_index: Callable
var empire_color: Callable
var reward_icon: Callable
var viewport_rect: Callable
var conquest_buttons: Dictionary = {}
var objective_refresh_buttons: Dictionary = {}
var conquest_scoreboard_toggle: Button
var conquest_scoreboard_expanded: bool = false
var objectives_toggle: Button
var objectives_expanded: bool = true
var conquest_category: String = "economic"
var conquest_dialog: Window
var conquest_cards: VBoxContainer
var conquest_card_signature: String = ""
var conquest_pulse_time: float = 0.0

func build(owner: Control, session_node: Node, canvas: Control, overlay: Control, header: float, player_query: Callable, color_index_query: Callable, color_query: Callable, icon_query: Callable) -> void:
	session = session_node
	map_canvas = canvas
	objectives_overlay = overlay
	header_height = header
	local_player = player_query
	color_index = color_index_query
	empire_color = color_query
	reward_icon = icon_query
	viewport_rect = owner.get_viewport_rect
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
	objectives_toggle = Button.new()
	map_canvas.add_child(objectives_toggle)
	objectives_toggle.z_index = 4
	objectives_toggle.focus_mode = Control.FOCUS_NONE
	_style_objective_header_button(objectives_toggle, HUD.ACCENT)
	objectives_toggle.text = "−"
	objectives_toggle.tooltip_text = "Collapse objectives"
	objectives_toggle.pressed.connect(_toggle_objectives)
	conquest_scoreboard_toggle = Button.new()
	map_canvas.add_child(conquest_scoreboard_toggle)
	conquest_scoreboard_toggle.z_index = 4
	conquest_scoreboard_toggle.focus_mode = Control.FOCUS_NONE
	_style_objective_header_button(conquest_scoreboard_toggle, HUD.ACCENT)
	conquest_scoreboard_toggle.text = "+"
	conquest_scoreboard_toggle.tooltip_text = "Expand total conquest points"
	conquest_scoreboard_toggle.pressed.connect(_toggle_conquest_scoreboard)
	conquest_dialog = Window.new()
	conquest_dialog.title = "Choose an upgrade"
	conquest_dialog.borderless = true
	conquest_dialog.theme = owner.theme
	conquest_dialog.transient = true
	conquest_dialog.exclusive = true
	conquest_dialog.unresizable = true
	conquest_dialog.visible = false
	owner.add_child(conquest_dialog)
	conquest_dialog.close_requested.connect(conquest_dialog.hide)
	var conquest_background := PanelContainer.new()
	conquest_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	conquest_background.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#45617b"), 14, 4))
	conquest_dialog.add_child(conquest_background)
	conquest_cards = VBoxContainer.new()
	conquest_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conquest_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conquest_cards.add_theme_constant_override("separation", 8)
	conquest_background.add_child(conquest_cards)
	layout()


func pulse(delta: float) -> void:
	conquest_pulse_time += delta
	var glow: float = 0.5 + 0.5 * sin(conquest_pulse_time * TAU / 1.4)
	for button in conquest_buttons.values():
		button.modulate = Color(0.78 + glow * 0.65, 0.68 + glow * 0.57, 0.45 + glow * 0.47) if button.visible and not button.disabled else Color.WHITE

func dialog_visible() -> bool:
	return is_instance_valid(conquest_dialog) and conquest_dialog.visible

func draw(state: Dictionary) -> void:
	var progress: Dictionary = state.get("objectives", {}).get(local_player.call(), {})
	var completed: Dictionary = progress.get("completed", {})
	var font: Font = ThemeDB.fallback_font
	var x: float = maxf(8.0, map_canvas.size.x - OBJECTIVES_WIDTH)
	var y: float = header_height + 24.0
	var clock: float = float(state.get("objective_clock", 0.0))
	objectives_overlay.draw_string(font, Vector2(x, y), "OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b8d9ef"))
	objectives_overlay.draw_line(Vector2(x, y + 5.0), Vector2(x + font.get_string_size("OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, y + 5.0), Color("#b8d9ef"), 1.0)
	y += 26.0
	if objectives_expanded:
		for objective in ECONOMY.active_objectives(progress, clock):
			var category: String = objective["track"]
			var key: String = objective["id"]
			var done: bool = completed.has(key)
			var tint: Color = Color("#8ee2a9") if done else Color.WHITE
			objectives_overlay.draw_string(font, Vector2(x, y), category.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#b8d9ef"))
			y += 23.0
			var pos := Vector2(x, y)
			var counter: String = objective["counter"]
			var counter_width: float = font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var label_width: float = maxf(40.0, map_canvas.size.x - 12.0 - counter_width - pos.x - 8.0)
			objectives_overlay.draw_string_outline(font, pos, objective["label"], HORIZONTAL_ALIGNMENT_LEFT, label_width, 12, 4, Color("#101824"))
			objectives_overlay.draw_string(font, pos, objective["label"], HORIZONTAL_ALIGNMENT_LEFT, label_width, 12, tint)
			objectives_overlay.draw_string(font, Vector2(map_canvas.size.x - 12.0 - counter_width, y), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
			var parts: PackedStringArray = counter.split("/")
			var fraction: float = 1.0 if done else 0.0
			if parts.size() == 2 and parts[1].strip_edges().is_valid_float():
				fraction = clampf(parts[0].strip_edges().to_float() / maxf(1.0, parts[1].strip_edges().to_float()), 0.0, 1.0)
			var bar_width: float = map_canvas.size.x - x - 12.0
			objectives_overlay.draw_rect(Rect2(Vector2(x, y + 4.0), Vector2(bar_width, 3.0)), Color("#263b50"))
			objectives_overlay.draw_rect(Rect2(Vector2(x, y + 4.0), Vector2(bar_width * fraction, 3.0)), Color("#73c6ad") if category == "economic" else Color("#dfab77"))
			y += 29.0
	_draw_conquest_scoreboard(state, font, x, y + 4.0)

func _toggle_objectives() -> void:
	objectives_expanded = not objectives_expanded
	objectives_toggle.text = "−" if objectives_expanded else "+"
	objectives_toggle.tooltip_text = "Collapse objectives" if objectives_expanded else "Expand objectives"
	layout()
	objectives_overlay.queue_redraw()

func _toggle_conquest_scoreboard() -> void:
	conquest_scoreboard_expanded = not conquest_scoreboard_expanded
	conquest_scoreboard_toggle.text = "−" if conquest_scoreboard_expanded else "+"
	conquest_scoreboard_toggle.tooltip_text = "Collapse total conquest points" if conquest_scoreboard_expanded else "Expand total conquest points"
	objectives_overlay.queue_redraw()

func _draw_conquest_scoreboard(state: Dictionary, font: Font, x: float, y: float) -> void:
	var edge: float = map_canvas.size.x - 12.0
	var width: float = maxf(1.0, edge - x)
	var header_tint := Color("#b8d9ef")
	var outline := Color("#101824")
	var header_width: float = maxf(1.0, width - ceilf(font.get_height(13)) - 4.0)
	objectives_overlay.draw_string_outline(font, Vector2(x, y), "TOTAL CONQUEST POINTS", HORIZONTAL_ALIGNMENT_LEFT, header_width, 13, 4, outline)
	objectives_overlay.draw_string(font, Vector2(x, y), "TOTAL CONQUEST POINTS", HORIZONTAL_ALIGNMENT_LEFT, header_width, 13, header_tint)
	objectives_overlay.draw_line(Vector2(x, y + 5.0), Vector2(x + minf(header_width, font.get_string_size("TOTAL CONQUEST POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x), y + 5.0), header_tint, 1.0)
	if not conquest_scoreboard_expanded:
		return
	var roster: Dictionary = session.get("players")
	var all_progress: Dictionary = state.get("objectives", {})
	var players: Array = state.get("teams", {}).keys()
	# Stable order keeps rows from jumping when points are earned or spent.
	players.sort_custom(func(a, b) -> bool:
		var color_a: int = color_index.call(int(a))
		var color_b: int = color_index.call(int(b))
		return int(a) < int(b) if color_a == color_b else color_a < color_b)
	var column: float = minf(58.0, width * 0.22)
	var name_width: float = maxf(1.0, width - column * 3.0 - 8.0)
	y += 20.0
	for index in range(ECONOMY.REWARD_CATEGORIES.size()):
		var category: String = ECONOMY.REWARD_CATEGORIES[index]
		var at := Vector2(edge - column * float(3 - index), y)
		objectives_overlay.draw_string_outline(font, at, category.capitalize(), HORIZONTAL_ALIGNMENT_RIGHT, column, 11, 4, outline)
		objectives_overlay.draw_string(font, at, category.capitalize(), HORIZONTAL_ALIGNMENT_RIGHT, column, 11, header_tint)
	y += 5.0
	objectives_overlay.draw_line(Vector2(x, y), Vector2(edge, y), Color("#45617b"), 1.0)
	y += 16.0
	for player in players:
		var id: int = int(player)
		var name_text: String = str(roster.get(id, {}).get("name", "Player %d" % id))
		var tint: Color = empire_color.call(id)
		var progress: Dictionary = all_progress.get(id, {})
		objectives_overlay.draw_string_outline(font, Vector2(x, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, name_width, 12, 4, outline)
		objectives_overlay.draw_string(font, Vector2(x, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, name_width, 12, tint)
		for index in range(ECONOMY.REWARD_CATEGORIES.size()):
			var points: int = ECONOMY.lifetime_reward_points(progress, str(ECONOMY.REWARD_CATEGORIES[index]))
			var at := Vector2(edge - column * float(3 - index), y)
			var value: String = str(points)
			var value_tint: Color = Color("#dceaf4") if points > 0 else Color("#8296a8")
			objectives_overlay.draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_RIGHT, column, 12, 4, outline)
			objectives_overlay.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_RIGHT, column, 12, value_tint)
		y += 18.0

func _style_objective_header_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", HUD.surface(Color("#193448"), accent.darkened(0.35), 1, 2))
	button.add_theme_stylebox_override("hover", HUD.surface(Color("#285268"), accent, 1, 2))
	button.add_theme_stylebox_override("pressed", HUD.surface(Color("#24526a"), accent, 1, 2))
	button.add_theme_stylebox_override("disabled", HUD.surface(Color("#101c29"), Color("#263748"), 1, 2))
	button.add_theme_color_override("font_color", accent.lightened(0.25))

func layout() -> void:
	if conquest_buttons.is_empty():
		return
	var state: Dictionary = session.get("economy")
	var progress: Dictionary = state.get("objectives", {}).get(local_player.call(), {})
	var font: Font = ThemeDB.fallback_font
	var height: float = ceilf(font.get_height(13))
	var upgrade_width: float = 52.0
	var x: float = maxf(8.0, map_canvas.size.x - OBJECTIVES_WIDTH)
	var y: float = header_height + 24.0
	objectives_toggle.visible = not state.is_empty()
	objectives_toggle.position = Vector2(x + font.get_string_size("OBJECTIVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0, roundf(y - font.get_ascent(13)))
	objectives_toggle.size = Vector2(height, height)
	y += 26.0
	var visible_categories: Array = []
	for objective in ECONOMY.active_objectives(progress, float(state.get("objective_clock", 0.0))):
		visible_categories.append(objective["track"])
	for category in ECONOMY.REWARD_CATEGORIES:
		var button: Button = conquest_buttons[category]
		var refresh: Button = objective_refresh_buttons[category]
		button.visible = objectives_expanded and not state.is_empty() and visible_categories.has(category)
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
	conquest_scoreboard_toggle.visible = not state.is_empty()
	conquest_scoreboard_toggle.position = Vector2(x + font.get_string_size("TOTAL CONQUEST POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0, roundf(y + 4.0 - font.get_ascent(13)))
	conquest_scoreboard_toggle.size = Vector2(height, height)

func _request_objective_refresh(category: String) -> void:
	var progress: Dictionary = session.get("economy").get("objectives", {}).get(local_player.call(), {})
	var key: String = str(progress.get("active_goals", {}).get(category, ""))
	if not key.is_empty():
		session.call("request_objective_refresh", category, key)

func refresh(state: Dictionary) -> void:
	if conquest_buttons.is_empty():
		return
	var progress: Dictionary = state.get("objectives", {}).get(local_player.call(), {})
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
	layout()
	if is_instance_valid(conquest_dialog) and conquest_dialog.visible:
		if ECONOMY.reward_points(progress, conquest_category) <= 0:
			conquest_dialog.hide()
			conquest_card_signature = ""
		else:
			_refresh_reward_cards()

func _refresh_reward_cards() -> void:
	var progress: Dictionary = session.get("economy").get("objectives", {}).get(local_player.call(), {})
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
	heading.add_theme_font_size_override("font_size", 17)
	conquest_cards.add_child(heading)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conquest_cards.add_child(cards)
	for key in ECONOMY.reward_offer(progress, conquest_category):
		var reward: Array = ECONOMY.CONQUEST_REWARDS[key]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var unique: bool = ECONOMY.reward_is_unique(str(key))
		var repeatable: bool = ECONOMY.reward_repeatable(str(key))
		var frame: StyleBoxFlat = HUD.surface(Color("#24203d") if unique else Color("#102b40"), Color("#b697ff") if unique else Color("#d6b46a"), 8, 6)
		frame.set_border_width_all(2)
		frame.shadow_color = Color("#0a0f19")
		frame.shadow_size = 4
		card.add_theme_stylebox_override("panel", frame)
		cards.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		card.add_child(content)
		var art := TextureRect.new()
		HUD.fixed_icon(art, reward_icon.call(str(reward[4]), 48), 48)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(art)
		var rarity := Label.new()
		rarity.text = "UNIQUE · ONE PLAYER" if unique else ("RESEARCH · RANK %d" % (ECONOMY.reward_rank(progress.get("rewards", []), str(key)) + 1) if repeatable else "TECHNOLOGY")
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
		title_label.custom_minimum_size.y = 34
		content.add_child(title_label)
		content.add_child(HSeparator.new())
		var benefit := Label.new()
		benefit.text = reward[1]
		benefit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		benefit.add_theme_font_size_override("font_size", 13)
		benefit.modulate = Color("#c8f3db")
		content.add_child(benefit)
		if not str(reward[2]).is_empty():
			var drawback := Label.new()
			drawback.text = reward[2]
			drawback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			drawback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			drawback.add_theme_font_size_override("font_size", 12)
			drawback.modulate = Color("#ffb4a4")
			content.add_child(drawback)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(spacer)
		var buy := Button.new()
		buy.text = "SELECT · 1 CP"
		buy.tooltip_text = "Only the first player to select this upgrade can acquire it." if unique else "Spend 1 conquest point"
		buy.custom_minimum_size.y = 30
		buy.disabled = points < 1
		HUD.action(buy, Color("#e9cb7c"))
		buy.add_theme_stylebox_override("normal", HUD.surface(Color("#5a4824"), Color("#edc76f"), 5, 4))
		buy.add_theme_stylebox_override("hover", HUD.surface(Color("#80642c"), Color("#fff0b2"), 5, 4))
		content.add_child(buy)
		buy.pressed.connect(_buy_conquest_reward.bind(str(key), generation, cards))
	if ECONOMY.reward_offer(progress, conquest_category).is_empty():
		var empty := Label.new()
		empty.text = "Preparing reward choices…"
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
	var progress: Dictionary = session.get("economy").get("objectives", {}).get(local_player.call(), {})
	if ECONOMY.reward_points(progress, category) <= 0 or ECONOMY.reward_offer(progress, category).is_empty():
		return
	conquest_category = category
	conquest_card_signature = ""
	_refresh_reward_cards()
	var viewport_size: Vector2 = viewport_rect.call().size
	conquest_dialog.popup_centered(Vector2i(mini(780, int(viewport_size.x) - 32), mini(380, int(viewport_size.y) - 56)))
