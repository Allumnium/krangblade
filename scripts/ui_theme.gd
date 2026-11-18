extends RefCounted
## Shared UI styles; gameplay and network state are not referenced here.
const TEXT := Color("#e2f0ff")
const MUTED := Color("#8ca5be")
const ACCENT := Color("#62cbe8")
const CONSOLE_BACKGROUND := Color("#080c12")
const COLORS = {
	"Metals": Color("#c1cedc"), "Plastics": Color("#f6a45b"),
	"Textiles": Color("#48d6c1"), "Organics": Color("#8ed779"),
	"Tech": Color("#5dbdff"), "Crystals": Color("#c8a2ff"), "Raw antimatter": Color("#f279d7")
}
const ICONS = {
	"Metals": preload("res://assets/ui/metals.svg"),
	"Plastics": preload("res://assets/ui/plastics.svg"),
	"Textiles": preload("res://assets/ui/textiles.svg"),
	"Organics": preload("res://assets/ui/organics.svg"),
	"Tech": preload("res://assets/ui/tech.svg"),
	"Crystals": preload("res://assets/ui/crystals.svg")
}

# Rasterize fixed-size resource icons once at their actual HUD dimensions.
# World overlays and scalable portraits still use their original textures.
static var pixel_icons: Dictionary = {}

static func resource_icon(resource: String, pixels: int) -> Texture2D:
	var source: Texture2D = ICONS.get(resource)
	if source == null or source.get_width() == pixels:
		return source
	var key: String = "%s:%d" % [resource, pixels]
	if not pixel_icons.has(key):
		var image: Image = source.get_image()
		image.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
		pixel_icons[key] = ImageTexture.create_from_image(image)
	return pixel_icons[key]

static func fixed_icon(control: TextureRect, texture: Texture2D, pixels: int) -> void:
	control.texture = texture
	control.custom_minimum_size = Vector2(pixels, pixels)
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func surface(bg: Color, edge: Color, margin: int = 8, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

static func create() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_stylebox("panel", "TooltipPanel", surface(Color("#101b29"), Color("#6385a4"), 7, 3))
	result.set_color("font_color", "TooltipLabel", Color.WHITE)
	result.set_font_size("font_size", "TooltipLabel", 14)
	result.set_color("default_color", "RichTextLabel", TEXT)
	result.set_stylebox("panel", "PanelContainer", surface(Color("#0c1928ed"), Color("#284661"), 10))
	result.set_stylebox("panel", "TabContainer", surface(Color("#091624"), Color("#284661"), 6))
	result.set_stylebox("tab_selected", "TabContainer", surface(Color("#193c52"), ACCENT, 7, 3))
	result.set_stylebox("tab_unselected", "TabContainer", surface(Color("#122337"), Color("#284661"), 7, 3))
	result.set_stylebox("tab_hovered", "TabContainer", surface(Color("#23475e"), ACCENT, 7, 3))
	result.set_color("font_selected_color", "TabContainer", TEXT)
	result.set_color("font_unselected_color", "TabContainer", MUTED)
	result.set_color("font_hovered_color", "TabContainer", TEXT)
	result.set_stylebox("panel", "PopupMenu", surface(Color("#122439"), Color("#3a627e"), 6))
	result.set_stylebox("panel", "AcceptDialog", surface(Color("#0c1928"), Color("#284661"), 16))
	result.set_stylebox("embedded_border", "Window", surface(Color("#0c1928"), ACCENT, 8))
	result.set_color("title_color", "Window", TEXT)
	result.set_color("font_color", "AcceptDialog", TEXT)
	var normal := surface(Color("#14283b"), Color("#34546e"), 7)
	var hover := surface(Color("#1d3b51"), ACCENT, 7)
	var pressed := surface(Color("#24526a"), ACCENT, 7)
	var disabled := surface(Color("#101c29"), Color("#263748"), 7)
	var focus := surface(Color.TRANSPARENT, ACCENT, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, normal)
		result.set_stylebox("hover", type, hover)
		result.set_stylebox("pressed", type, pressed)
		result.set_stylebox("disabled", type, disabled)
		result.set_stylebox("focus", type, focus)
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, Color.WHITE)
		result.set_color("font_pressed_color", type, Color.WHITE)
		result.set_color("font_disabled_color", type, Color("#607387"))
	result.set_stylebox("normal", "LineEdit", surface(Color("#081523"), Color("#2b4660"), 6))
	result.set_stylebox("read_only", "LineEdit", disabled)
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_stylebox("panel", "ItemList", surface(Color("#081522"), Color("#284661"), 5))
	result.set_stylebox("selected", "ItemList", pressed)
	result.set_stylebox("selected_focus", "ItemList", pressed)
	result.set_color("font_color", "ItemList", TEXT)
	result.set_constant("v_separation", "ItemList", 5)
	result.set_stylebox("background", "ProgressBar", surface(Color("#091420"), Color("#29445c"), 0, 3))
	result.set_stylebox("fill", "ProgressBar", surface(Color("#237f9f"), ACCENT, 0, 3))
	result.set_color("font_color", "ProgressBar", TEXT)
	result.set_stylebox("scroll", "VScrollBar", surface(Color("#0a1420"), Color("#192d40"), 2))
	result.set_stylebox("grabber", "VScrollBar", surface(Color("#355a74"), Color("#487b97"), 3))
	result.set_stylebox("grabber_highlight", "VScrollBar", surface(Color("#477f99"), ACCENT, 3))
	result.set_stylebox("grabber_pressed", "VScrollBar", surface(Color("#477f99"), ACCENT, 3))
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_stylebox("hover", "PopupMenu", hover)
	return result

static func compact() -> Theme:
	var result: Theme = create()
	result.default_font_size = 12
	result.set_stylebox("panel", "PanelContainer", surface(CONSOLE_BACKGROUND, Color("#284661"), 3, 3))
	result.set_stylebox("panel", "TabContainer", surface(CONSOLE_BACKGROUND, Color("#284661"), 3, 3))
	for type in ["HBoxContainer", "VBoxContainer"]:
		result.set_constant("separation", type, 3)
	for type in ["Button", "OptionButton", "LineEdit"]:
		for name in ["normal", "hover", "pressed", "disabled", "read_only"]:
			if result.has_stylebox(name, type):
				var style: StyleBox = result.get_stylebox(name, type).duplicate()
				style.set_content_margin_all(3)
				result.set_stylebox(name, type, style)
	for name in ["panel", "tab_selected", "tab_unselected", "tab_hovered"]:
		var style: StyleBox = result.get_stylebox(name, "TabContainer").duplicate()
		style.set_content_margin_all(3)
		result.set_stylebox(name, "TabContainer", style)
	return result

static func action(button: Button, accent: Color = ACCENT, dense: bool = false) -> void:
	var margin: int = 3 if dense else 7
	button.add_theme_stylebox_override("normal", surface(Color("#193448"), accent.darkened(0.35), margin, 3 if dense else 5))
	button.add_theme_stylebox_override("hover", surface(Color("#285268"), accent, margin, 3 if dense else 5))
	button.add_theme_color_override("font_color", accent.lightened(0.25))

static func section(parent: Container, title_text: String, dense: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", surface(CONSOLE_BACKGROUND if dense else Color("#0a1726ed"), Color("#233e56"), 3 if dense else 9, 3 if dense else 5))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2 if dense else 6)
	panel.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 12)
	body.add_child(title)
	return body
