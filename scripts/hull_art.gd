extends RefCounted
## Client-only canonical hull silhouettes and texture caches for portraits, shields and world art.
const ECONOMY = preload("res://scripts/economy_rules.gd")
const FREIGHTER_OUTLINE: Array[Vector2] = [Vector2(23, 4), Vector2(19, 8), Vector2(-20, 8), Vector2(-20, -8), Vector2(19, -8), Vector2(23, -4)]
# Authored top-down silhouette and interior panel geometry in hull-local
# coordinates (forward, lateral). Freighter has five paired cargo rows.
const HULL_OUTLINES: Dictionary = {
	"probe": [Vector2(8, 0), Vector2(3, 5), Vector2(-4, 5), Vector2(-7, 0), Vector2(-4, -5), Vector2(3, -5)],
	"railgun_ship": [Vector2(33, 0), Vector2(27, 3), Vector2(9, 3), Vector2(6, 9), Vector2(-12, 12), Vector2(-26, 9), Vector2(-30, 5), Vector2(-30, -5), Vector2(-26, -9), Vector2(-12, -12), Vector2(6, -9), Vector2(9, -3), Vector2(27, -3)],
	"scout": [Vector2(12, 0), Vector2(4, 2), Vector2(-2, 5), Vector2(-8, 5), Vector2(-6, 2), Vector2(-10, 1.8), Vector2(-10, -1.8), Vector2(-6, -2), Vector2(-8, -5), Vector2(-2, -5), Vector2(4, -2)],
	"cruiser": [Vector2(25, 0), Vector2(19, 4), Vector2(13, 5), Vector2(6, 13), Vector2(-5, 13), Vector2(-9, 7), Vector2(-19, 7), Vector2(-25, 4), Vector2(-25, 0), Vector2(-25, -4), Vector2(-19, -7), Vector2(-9, -7), Vector2(-5, -13), Vector2(6, -13), Vector2(13, -5), Vector2(19, -4)],
	"destroyer": [Vector2(44, 0), Vector2(38, 7), Vector2(32, 7), Vector2(29, 18), Vector2(20, 20), Vector2(8, 16), Vector2(1, 10), Vector2(-12, 10), Vector2(-18, 23), Vector2(-32, 23), Vector2(-40, 17), Vector2(-40, 9), Vector2(-44, 6), Vector2(-44, 0), Vector2(-44, -6), Vector2(-40, -9), Vector2(-40, -17), Vector2(-32, -23), Vector2(-18, -23), Vector2(-12, -10), Vector2(1, -10), Vector2(8, -16), Vector2(20, -20), Vector2(29, -18), Vector2(32, -7), Vector2(38, -7)],
	"science_ship": [Vector2(14, 0), Vector2(12, 7), Vector2(7, 12), Vector2(0, 14), Vector2(-7, 12), Vector2(-12, 7), Vector2(-14, 0), Vector2(-12, -7), Vector2(-7, -12), Vector2(0, -14), Vector2(7, -12), Vector2(12, -7)],
	"fighter": [Vector2(12, 0), Vector2(6, 2.5), Vector2(2.5, 3), Vector2(-3, 8), Vector2(-7, 7.5), Vector2(-6, 3), Vector2(-10, 2.5), Vector2(-10, -2.5), Vector2(-6, -3), Vector2(-7, -7.5), Vector2(-3, -8), Vector2(2.5, -3), Vector2(6, -2.5)],
	"miner": [Vector2(10, 5), Vector2(6, 5), Vector2(3, 7), Vector2(-5, 7), Vector2(-8, 4), Vector2(-8, -4), Vector2(-5, -7), Vector2(3, -7), Vector2(6, -5), Vector2(10, -5), Vector2(10, -2.5), Vector2(5, -2.5), Vector2(4, 0), Vector2(5, 2.5), Vector2(10, 2.5)],
	"colony_ship": [Vector2(13, 0), Vector2(8, 3), Vector2(5, 3.5), Vector2(3, 6.5), Vector2(-5, 7), Vector2(-9, 4), Vector2(-11, 3), Vector2(-11, -3), Vector2(-9, -4), Vector2(-5, -7), Vector2(3, -6.5), Vector2(5, -3.5), Vector2(8, -3)]
}
const HULL_PANELS: Dictionary = {
	"probe": [[Color("#9bd9dc"), [Vector2(6, 0), Vector2(1, 3), Vector2(-4, 0), Vector2(1, -3)]]],
	"railgun_ship": [[Color("#98b8d0"), [Vector2(31, 0), Vector2(8, 2), Vector2(-18, 3), Vector2(-18, -3), Vector2(8, -2)]], [Color("#384d63"), [Vector2(5, 7), Vector2(-12, 10), Vector2(-26, 7), Vector2(-26, -7), Vector2(-12, -10), Vector2(5, -7)]], [Color("#b5dfff"), [Vector2(27, 1), Vector2(3, 1), Vector2(3, -1), Vector2(27, -1)]]],
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

var production_icons: Dictionary = {}
var hull_textures: Dictionary = {}
var shield_textures: Dictionary = {}
var selection_portrait_icons: Dictionary = {}

func freighter_bay_center(index: int) -> Vector2:
	return Vector2(14.0 - float(floori(float(index) / 2.0)) * 7.0, -3.5 if index % 2 == 0 else 3.5)

func freighter_bay_vertices(index: int) -> Array:
	var center: Vector2 = freighter_bay_center(index)
	return [center + Vector2(3, 3), center + Vector2(-3, 3), center + Vector2(-3, -3), center + Vector2(3, -3)]

func portrait_points(vertices: Array, factor: float = 1.0) -> String:
	var coordinates: PackedStringArray = []
	for vertex in vertices:
		var v: Vector2 = vertex
		coordinates.append("%.2f,%.2f" % [32.0 + v.y * 1.85 * factor, 32.0 - v.x * 1.85 * factor])
	return " ".join(coordinates)

func ui_radius(kind: String) -> float:
	return float({"ship": 24.0, "cruiser": 27.0, "destroyer": 46.0, "railgun_ship": 33.0, "warp_gate": 44.0}.get(kind, 15.0))

func portrait_scale(kind: String) -> float:
	return float({"ship": 0.6, "cruiser": 0.52, "destroyer": 0.30, "railgun_ship": 0.42}.get(kind, 1.0))

func texture_half_size(kind: String) -> float:
	return 50.0 if kind == "destroyer" else 40.0

func production_icon(kind: String, tint: Color, pixels: int = 64) -> Texture2D:
	var key: String = "%s:%s:%d" % [kind, tint.to_html(false), pixels]
	if not production_icons.has(key):
		var portrait_factor: float = portrait_scale(kind)
		var outline: String = portrait_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE), portrait_factor)
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g transform="translate(32 32) scale(1.13) translate(-32 -32)">'
		art += '<polygon points="%s" fill="#18283c" stroke="#%s" stroke-width="1.8" stroke-linejoin="round"/>' % [outline, tint.lightened(0.35).to_html(false)]
		for panel in HULL_PANELS.get(kind, []):
			var color: Color = panel_color(tint, panel[0])
			art += '<polygon points="%s" fill="#%s"/>' % [portrait_points(panel[1], portrait_factor), color.lightened(0.12).to_html(false)]
		if kind == "ship":
			for bay in range(ECONOMY.FREIGHTER_BAY_COUNT):
				art += '<polygon points="%s" fill="#32465c" stroke="#9bb6cb" stroke-width="0.8"/>' % portrait_points(freighter_bay_vertices(bay), 0.6)
		art += '<polygon points="%s" fill="none" stroke="#%s" stroke-width="1.25" stroke-linejoin="round"/></g></svg>' % [outline, tint.lightened(0.50).to_html(false)]
		var image := Image.new()
		image.load_svg_from_string(art, float(pixels) / 64.0)
		production_icons[key] = ImageTexture.create_from_image(image)
	return production_icons[key]

func selection_portrait_icon(kind: String) -> Texture2D:
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
			art += '<polygon points="%s"/>' % portrait_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE), portrait_scale(kind))
			for panel in HULL_PANELS.get(kind, []):
				art += '<polygon points="%s" stroke-width="0.55" opacity="0.68"/>' % portrait_points(panel[1], portrait_scale(kind))
			if kind == "ship":
				for bay in range(ECONOMY.FREIGHTER_BAY_COUNT):
					art += '<polygon points="%s" stroke-width="0.7"/>' % portrait_points(freighter_bay_vertices(bay), 0.6)
		var image := Image.new()
		image.load_svg_from_string(art + '</g></svg>')
		selection_portrait_icons[kind] = ImageTexture.create_from_image(image)
	return selection_portrait_icons[kind]

func hull_texture(kind: String, empire: Color, detailed: bool) -> Texture2D:
	var key: String = "%s:%s:%s" % [kind, empire.to_html(false), str(detailed)]
	if not hull_textures.has(key):
		var vertices: Array = HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE if kind == "ship" else [Vector2(9, 0), Vector2(-6, 5), Vector2(-3, 0), Vector2(-6, -5)])
		var outline: String = hull_svg_points(vertices)
		var half: float = texture_half_size(kind)
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="%s %s %s %s">' % [-half, -half, half * 2.0, half * 2.0]
		art += '<polygon points="%s" fill="#%s"/>' % [outline, empire.lightened(0.35).to_html(false)]
		if detailed and kind not in ["ship", "science_ship"]:
			for panel in HULL_PANELS.get(kind, []):
				art += '<polygon points="%s" fill="#%s"/>' % [hull_svg_points(panel[1]), panel_color(empire, panel[0]).to_html(false)]
		art += '<polygon points="%s" fill="none" stroke="#08111b" stroke-width="2.5" stroke-linejoin="round"/>' % outline
		art += '<polygon points="%s" fill="none" stroke="#%s" stroke-width="1" stroke-linejoin="round"/></svg>' % [outline, empire.lightened(0.2).to_html(false)]
		var image := Image.new()
		image.load_svg_from_string(art)
		hull_textures[key] = ImageTexture.create_from_image(image)
	return hull_textures[key]

func shield_texture(kind: String) -> Texture2D:
	if not shield_textures.has(kind):
		var outline: String = hull_svg_points(HULL_OUTLINES.get(kind, FREIGHTER_OUTLINE))
		var half: float = texture_half_size(kind) + 8.0
		# Three soft bands and a bright rim, baked once per hull type.
		var art: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="%s %s %s %s"><g fill="none" stroke-linejoin="round">' % [-half, -half, half * 2.0, half * 2.0]
		for band in [[4.0, 0.10], [2.75, 0.18], [1.75, 0.36], [0.7, 0.75]]:
			art += '<polygon points="%s" stroke="#77ccff" stroke-width="%s" opacity="%s"/>' % [outline, band[0], band[1]]
		art += '</g></svg>'
		var image := Image.new()
		image.load_svg_from_string(art)
		shield_textures[kind] = ImageTexture.create_from_image(image)
	return shield_textures[kind]

func hull_svg_points(vertices: Array) -> String:
	var coordinates: PackedStringArray = []
	for vertex in vertices:
		coordinates.append("%.2f,%.2f" % [vertex.x, vertex.y])
	return " ".join(coordinates)

func panel_color(empire: Color, original: Color) -> Color:
	# Use the original value contrast as a shading template, not its class
	# hue; keep the dark cockpit and bright lights readable on every color.
	var value: float = original.get_luminance()
	return empire.darkened(0.72).lerp(empire.lightened(0.75), clampf(value, 0.0, 1.0))

func polygon(origin: Vector2, forward: Vector2, lateral: Vector2, vertices: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex in vertices:
		result.append(origin + forward * vertex.x + lateral * vertex.y)
	return result

func is_shield_texture(texture: Texture2D) -> bool:
	return shield_textures.values().has(texture)
