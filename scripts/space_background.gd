extends ColorRect
## GPU-animated shared star field, behind all interactive controls.
const STAR_SHADER = preload("res://assets/ui/starfield.gdshader")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := ShaderMaterial.new()
    mat.shader = STAR_SHADER
    material = mat
