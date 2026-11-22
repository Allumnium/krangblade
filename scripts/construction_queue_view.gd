extends RefCounted
## Construction queue tile presentation; match retains selection and cancellation dispatch.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const HUD = preload("res://scripts/ui_theme.gd")

func build(parent: Container) -> HFlowContainer:
	var queue := HFlowContainer.new()
	queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Center the flow's minimum-height block in the space below the header.
	# Filling the width lets each wrapped line stay centered independently.
	queue.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	queue.alignment = FlowContainer.ALIGNMENT_BEGIN
	queue.add_theme_constant_override("h_separation", 6)
	queue.add_theme_constant_override("v_separation", 6)
	parent.add_child(queue)
	return queue

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

func _job_name(item: Dictionary, selected_system: Dictionary) -> String:
	match str(item["kind"]):
		"ship": return "Freighter"
		"economy_building": return str(ECONOMY.ECONOMY_BUILDINGS[item["target"]]["name"])
		"warehouse": return "Warehouse logistics → Lv %d" % int(item["level"])
		"habitation": return "Habitation technology → Lv %d" % int(item["level"])
		"orbital_housing": return "Orbital Eco-Housing"
		"pds": return "PDS"
		"yard": return "Build Shipyard %d" % int(item.get("station_slot", item["level"]))
		"yard_upgrade": return "Shipyard %d → Lv %d" % [ECONOMY.shipyard_port(selected_system, int(item["target"])), int(item["level"])]
		"reinforced_plating": return "Plating"
		"laser_matrix": return "Lasers"
		"dyson_sphere": return "Dyson Sphere"
		"production": return "%s → Lv %d" % [str(item["target"]), int(item["level"])]
		_: return str(item["kind"]).replace("_", " ").capitalize()

func refresh(queue: HFlowContainer, rows: Dictionary, system: Dictionary, jobs: Array, owned: bool, active_id: int, make_button: Callable, cancel_job: Callable, job_icon: Callable, selected_system: Dictionary) -> void:
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
			var cancel: Button = make_button.call("", cancel_job.bind(id), row)
			cancel.focus_mode = Control.FOCUS_NONE
			cancel.custom_minimum_size = Vector2(57, 57)
			cancel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cancel.expand_icon = true
			cancel.add_theme_constant_override("icon_max_width", 44)
			cancel.icon = job_icon.call(job, int(system["owner"]))
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
		tile.tooltip_text = "%s · %s (%.0f%%)%s%s" % [_job_name(job, selected_system), ("Delivering" if job.has("delivery_slot") else ("Building" if id == active_id else "Queued")), percent, "\n" + widgets["bar"].tooltip_text if blocked else "", "\nCancel: full refund" if owned else ""]

		if float(job.get("credit_cost", 0.0)) > 0.0:
			tile.tooltip_text += "\n%.0f GC reserved%s" % [float(job["credit_cost"]), " · refunded on cancellation" if owned else ""]
