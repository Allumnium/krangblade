extends Node
## Local display preferences persist across menu/match scene changes.
signal fullscreen_changed(enabled: bool)
var previous_mode: Window.Mode = Window.MODE_WINDOWED
var previous_size := Vector2i(1152, 800)
var previous_position := Vector2i.ZERO

class ToggleButton extends Button:
    func _ready() -> void:
        var controls: Node = get_node("/root/WindowControls")
        controls.connect("fullscreen_changed", _refresh)
        pressed.connect(func() -> void: controls.call("toggle_fullscreen"))
        custom_minimum_size.y = 34
        _refresh(bool(controls.call("is_fullscreen")))

    func _refresh(enabled: bool) -> void:
        text = "WINDOWED (F11)" if enabled else "FULLSCREEN (F11)"
        tooltip_text = "F11 or Alt+Enter toggles fullscreen. Esc returns to windowed mode."

func is_fullscreen() -> bool:
    return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func make_button() -> Button:
    return ToggleButton.new()

func toggle_fullscreen() -> void:
    var window: Window = get_window()
    if is_fullscreen():
        window.mode = previous_mode
        if previous_mode == Window.MODE_WINDOWED:
            window.size = previous_size
            window.position = previous_position
    else:
        previous_mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_MAXIMIZED else Window.MODE_WINDOWED
        previous_size = window.size
        previous_position = window.position
        window.mode = Window.MODE_FULLSCREEN
    fullscreen_changed.emit(is_fullscreen())

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
        toggle_fullscreen()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and is_fullscreen():
        toggle_fullscreen()
        get_viewport().set_input_as_handled()
