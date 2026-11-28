extends RefCounted
## Per-match Empire dialog and war confirmation. Authority owns all rule changes.
const HUD = preload("res://scripts/ui_theme.gd")
const UI_TEXT = preload("res://scripts/ui_text.gd")
const ECONOMY = preload("res://scripts/economy_rules.gd")

var owner: Control
var session: Node
var local_player: Callable
var empire_color: Callable
var portrait_icon: Callable
var make_label: Callable
var empire_dialog: Window
var empire_rows: VBoxContainer
var diplomacy_rows: VBoxContainer
var diplomacy_signature: String = ""
var war_confirmation: ConfirmationDialog
var empire_controls: Dictionary = {}
var empire_signature: String = ""

func dialog_visible() -> bool:
	return is_instance_valid(empire_dialog) and empire_dialog.visible

func war_confirmation_visible() -> bool:
	return is_instance_valid(war_confirmation) and war_confirmation.visible

func _state() -> Dictionary:
	return session.get("economy")

func _me() -> int:
	return local_player.call()

func _label(value: String, font_size: int = 14) -> Label:
	return make_label.call(value, font_size)

func build(owner_node: Control, session_node: Node, player_query: Callable, color_query: Callable, portrait_query: Callable, label_factory: Callable) -> void:
	owner = owner_node
	session = session_node
	local_player = player_query
	empire_color = color_query
	portrait_icon = portrait_query
	make_label = label_factory
	# Size the window from the viewport, never from dynamically added rows.
	empire_dialog = Window.new()
	empire_dialog.title = "Empire"
	empire_dialog.borderless = true
	empire_dialog.theme = owner.theme
	empire_dialog.transient = true
	empire_dialog.exclusive = true
	empire_dialog.unresizable = true
	empire_dialog.wrap_controls = false
	empire_dialog.visible = false
	owner.add_child(empire_dialog)
	empire_dialog.close_requested.connect(empire_dialog.hide)
	empire_dialog.window_input.connect(_empire_window_input)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", HUD.surface(Color("#0c1928"), Color("#45617b"), 12, 4))
	empire_dialog.add_child(background)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	background.add_child(content)
	var heading := Label.new()
	heading.text = "Empire"
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	content.add_child(split)
	var diplomacy_scroll := ScrollContainer.new()
	diplomacy_scroll.custom_minimum_size.x = 240
	diplomacy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diplomacy_scroll.size_flags_stretch_ratio = 0.8
	diplomacy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(diplomacy_scroll)
	diplomacy_rows = VBoxContainer.new()
	diplomacy_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diplomacy_rows.add_theme_constant_override("separation", 3)
	diplomacy_scroll.add_child(diplomacy_rows)
	split.add_child(VSeparator.new())
	var fleet := VBoxContainer.new()
	fleet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet.size_flags_stretch_ratio = 1.4
	split.add_child(fleet)
	fleet.add_child(_label("Fleet targets", 18))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fleet.add_child(scroll)
	empire_rows = VBoxContainer.new()
	empire_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empire_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(empire_rows)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	HUD.action(close)
	content.add_child(close)
	close.pressed.connect(empire_dialog.hide)

func _diplomacy_action(action: String, other: int, enabled: bool = true) -> void:
	session.call("request_diplomacy", action, other, enabled)

func empire_name(id: int) -> String:
	if ECONOMY.is_imperial_owner(session.get("economy"), id):
		return "The Empire"
	var roster: Dictionary = session.get("players")
	return str(roster.get(id, {}).get("name", "Empire %d" % id))

func confirm_war(other: int, ids: Array = [], target: int = -1) -> void:
	if is_instance_valid(war_confirmation):
		return
	war_confirmation = ConfirmationDialog.new()
	var dialog: ConfirmationDialog = war_confirmation
	dialog.title = "Declare war?"
	dialog.borderless = true
	dialog.dialog_text = "Declare war on %s?" % empire_name(other)
	if not ids.is_empty():
		dialog.dialog_text += "\nThe selected armed ships will attack."
	dialog.ok_button_text = "Declare war"
	dialog.theme = owner.theme
	dialog.transient = true
	dialog.exclusive = true
	var parent: Node = empire_dialog if is_instance_valid(empire_dialog) and empire_dialog.visible else owner
	parent.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if ids.is_empty():
			session.call("request_diplomacy", "declare_war", other)
		else:
			session.call("request_confirmed_attack", other, ids, target)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(360, 160))

func _diplomacy_button(row: Container, title: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.disabled = disabled
	HUD.action(button)
	row.add_child(button)
	button.pressed.connect(action)
	return button

func _refresh_diplomacy_rows(state: Dictionary) -> void:
	if not is_instance_valid(diplomacy_rows):
		return
	var active: bool = state.has("diplomacy")
	diplomacy_rows.visible = active
	if not active:
		diplomacy_signature = ""
		return
	var me: int = _me()
	var others: Array = state["teams"].keys()
	others.erase(me)
	others.sort()
	var rows: Array = []
	for id in others:
		var other: int = int(id)
		var entry: Dictionary = state["diplomacy"].get(ECONOMY._diplomacy_pair(me, other), {})
		rows.append([other, empire_name(other), ECONOMY.diplomatic_relation(state, me, other), entry, state.get("eliminated", []).has(other)])
	var signature: String = str([rows, state.get("eliminated", []).has(me), state.get("match_result", {})])
	if signature == diplomacy_signature:
		return
	diplomacy_signature = signature
	for child in diplomacy_rows.get_children():
		diplomacy_rows.remove_child(child)
		child.queue_free()
	var heading := _label("Diplomacy", 18)
	diplomacy_rows.add_child(heading)
	for data in rows:
		var other: int = int(data[0])
		var relation: String = str(data[2])
		var entry: Dictionary = data[3]
		var inactive: bool = bool(data[4]) or state.get("eliminated", []).has(me) or not state.get("match_result", {}).is_empty()
		var panel := PanelContainer.new()
		diplomacy_rows.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		var title_row := HBoxContainer.new()
		column.add_child(title_row)
		var name_label := _label(str(data[1]), 15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true
		name_label.modulate = empire_color.call(other)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_label)
		var status: String = "Eliminated" if bool(data[4]) else relation.capitalize()
		if relation == ECONOMY.DIPLO_TRUCE:
			status = "Truce until %d" % (ECONOMY.START_YEAR + ceili(float(entry.get("until", 0.0))))
		var status_label := _label(status, 13)
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title_row.add_child(status_label)
		if inactive:
			continue
		var actions := HFlowContainer.new()
		actions.add_theme_constant_override("h_separation", 4)
		actions.add_theme_constant_override("v_separation", 4)
		column.add_child(actions)
		if relation != ECONOMY.DIPLO_WAR:
			var grant: bool = ECONOMY.open_borders(state, me, other)
			var incoming: bool = ECONOMY.open_borders(state, other, me)
			var border_button: Button = _diplomacy_button(actions, "Open Borders: " + ("On" if grant else "Off"), _diplomacy_action.bind("open_borders", other, not grant))
			border_button.tooltip_text = "Allow their ships through your future walls. Their permission: " + ("Open" if incoming else "Closed") + ". Does not authorize attacks."
		match relation:
			ECONOMY.DIPLO_NEUTRAL:
				var proposer: int = int(entry.get("alliance_offer", 0))
				_diplomacy_button(actions, "Accept alliance" if proposer == other else ("Alliance offered" if proposer == me else "Offer alliance"), _diplomacy_action.bind("alliance", other, true), proposer == me)
				_diplomacy_button(actions, "Declare war", confirm_war.bind(other, [], -1))
			ECONOMY.DIPLO_WAR:
				var proposer: int = int(entry.get("peace_offer", 0))
				_diplomacy_button(actions, "Accept peace" if proposer == other else ("Peace offered" if proposer == me else "Offer peace"), _diplomacy_action.bind("peace", other, true), proposer == me)
			ECONOMY.DIPLO_ALLIED:
				for permission in ["vision", "trade"]:
					var local_enabled: bool = bool(entry.get(permission, {}).get(me, true))
					var effective: bool = ECONOMY.diplomacy_allows(state, me, other, permission)
					var button: Button = _diplomacy_button(actions, "%s: %s" % [permission.capitalize(), "On" if local_enabled else "Off"], _diplomacy_action.bind(permission, other, not local_enabled))
					button.tooltip_text = "Enabled for both empires" if effective else "Disabled by one or both empires"
				_diplomacy_button(actions, "Leave alliance", _diplomacy_action.bind("break_alliance", other, true))
				column.add_child(_label("Repair: On · trade settlement pending", 12))
	diplomacy_rows.add_child(HSeparator.new())

func _empire_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		empire_dialog.set_input_as_handled()
		empire_dialog.hide()

func refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	_refresh_diplomacy_rows(state)
	var counts: Dictionary = ECONOMY.empire_fleet_counts(state, _me())
	var targets: Dictionary = state.get("empire_targets", {}).get(_me(), {})
	var visible_kinds: Array = []
	for kind in ["scout", "fighter", "miner", "construction_ship", "ship", "colony_ship", "science_ship", "cruiser", "destroyer", "railgun_ship"]:
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
			portrait.texture = portrait_icon.call(kind)
			portrait.custom_minimum_size = Vector2(28, 28)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(portrait)
			var body := VBoxContainer.new()
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(body)
			var top := HBoxContainer.new()
			body.add_child(top)
			var name_label := Label.new()
			name_label.text = UI_TEXT.ship_kind_name(kind)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(name_label)
			var counter := Label.new()
			top.add_child(counter)
			var target_input := SpinBox.new()
			target_input.min_value = 0
			target_input.max_value = 500
			target_input.step = 1
			target_input.tooltip_text = "Target ships"
			top.add_child(target_input)
			var slider := HSlider.new()
			slider.max_value = ECONOMY.EMPIRE_TARGET_STEPS.size() - 1
			slider.step = 0.005
			slider.tick_count = 0
			slider.ticks_on_borders = true
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(slider)
			var tick_labels := Control.new()
			tick_labels.custom_minimum_size.y = 11
			tick_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(tick_labels)
			tick_labels.draw.connect(_draw_empire_tick_labels.bind(tick_labels, slider))
			tick_labels.resized.connect(tick_labels.queue_redraw)
			slider.drag_ended.connect(_empire_slider_released.bind(kind, slider))
			slider.value_changed.connect(_empire_preview.bind(kind, slider, counter))
			slider.value_changed.connect(func(value: float) -> void: target_input.set_value_no_signal(ECONOMY.empire_target_at_tick(value)))
			target_input.value_changed.connect(func(value: float) -> void:
				slider.set_value_no_signal(ECONOMY.empire_target_tick(int(value)))
				session.call("request_empire_target", kind, int(value)))
			empire_controls[kind] = {"slider": slider, "counter": counter, "target": target_input}
	for kind in empire_controls:
		var entry: Dictionary = empire_controls[kind]
		var slider: HSlider = entry["slider"]
		var desired: int = int(targets.get(kind, 0))
		var target_input: SpinBox = entry["target"]
		if not slider.has_focus() and not target_input.get_line_edit().has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			target_input.set_value_no_signal(desired)
			slider.set_value_no_signal(ECONOMY.empire_target_tick(desired))
		var counter: Label = entry["counter"]
		_empire_preview(slider.value, kind, slider, counter)

func _draw_empire_tick_labels(labels: Control, slider: HSlider) -> void:
	var font: Font = ThemeDB.fallback_font
	var inset: float = slider.get_theme_icon("grabber").get_size().x * 0.5
	var steps: Array = ECONOMY.EMPIRE_TARGET_STEPS
	for index in range(steps.size()):
		if int(steps[index]) not in [0, 10, 50, 100, 300, 500]:
			continue
		var caption: String = str(steps[index])
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var x: float = lerpf(inset, labels.size.x - inset, float(index) / float(steps.size() - 1))
		labels.draw_string(font, Vector2(clampf(x - width * 0.5, 0.0, maxf(0.0, labels.size.x - width)), 11.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#b8d9ef"))

func _empire_preview(value: float, kind: String, _slider: HSlider, counter: Label) -> void:
	var counts: Dictionary = ECONOMY.empire_fleet_counts(_state(), _me())
	var live: int = int(counts["live"].get(kind, 0))
	var queued: int = int(counts["queued"].get(kind, 0))
	var desired: int = ECONOMY.empire_target_at_tick(value)
	counter.text = "%d active · %d queued" % [live, queued]
	counter.modulate = Color("#8ee2a9") if live + queued >= desired else Color("#e9cb7c")

func _empire_slider_released(changed: bool, kind: String, slider: HSlider) -> void:
	if changed:
		session.call("request_empire_target", kind, ECONOMY.empire_target_at_tick(slider.value))
	slider.release_focus()

func open() -> void:
	if str(session.get("phase")) != "match":
		return
	var viewport: Vector2 = owner.get_viewport_rect().size
	var target := Vector2i(maxi(1, mini(980, int(viewport.x) - 32)), maxi(1, mini(620, int(viewport.y) - 32)))
	# Set the outer dimensions before populating the scroll content.
	empire_dialog.size = target
	refresh(_state())
	empire_dialog.popup_centered(target)

