extends Control

# ORVETHRA touch stick. Multi-touch camera control remains independent.
# Draws itself so no texture uploads or external UI assets are required.
var value := Vector2.ZERO
var touch_index := -1
var mouse_down := false
const DEADZONE := 0.11

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    queue_redraw()

func _inside(screen: Vector2) -> bool:
    return Rect2(global_position, size).has_point(screen)

func _set_value(screen: Vector2) -> void:
    var middle := global_position + size * 0.5
    var local := (screen - middle) / (size.x * 0.35)
    local = local.limit_length(1.0)
    var length := local.length()
    if length < DEADZONE:
        value = Vector2.ZERO
    else:
        value = local.normalized() * ((length - DEADZONE) / (1.0 - DEADZONE))
    queue_redraw()

func _release() -> void:
    touch_index = -1
    mouse_down = false
    value = Vector2.ZERO
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1 and _inside(event.position):
            touch_index = event.index
            _set_value(event.position)
        elif not event.pressed and event.index == touch_index:
            _release()
    elif event is InputEventScreenDrag and event.index == touch_index:
        _set_value(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and _inside(event.position):
            mouse_down = true
            _set_value(event.position)
        elif not event.pressed and mouse_down:
            _release()
    elif event is InputEventMouseMotion and mouse_down:
        _set_value(event.position)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release()

func _draw() -> void:
    var mid := size * 0.5
    var radius := size.x * 0.46
    draw_circle(mid, radius, Color(0.10, 0.12, 0.15, 0.35))
    draw_arc(mid, radius, 0, TAU, 96, Color(0.78, 0.70, 0.57, 0.66), 2.2, true)
    draw_arc(mid, radius * 0.78, 0, TAU, 96, Color(0.79, 0.76, 0.70, 0.28), 1.6, true)
    for i in range(4):
        var a := TAU * float(i) / 4.0
        var direction := Vector2(sin(a), -cos(a))
        draw_line(mid + direction * radius * 0.67, mid + direction * radius * 0.81, Color(0.93, 0.85, 0.69, 0.55), 2.0, true)
    var knob_center := mid + value * radius * 0.70
    draw_circle(knob_center, radius * 0.33, Color(0.07, 0.10, 0.13, 0.73))
    draw_arc(knob_center, radius * 0.33, 0, TAU, 64, Color(0.93, 0.82, 0.64, 0.86), 2.3, true)
    draw_circle(knob_center, radius * 0.20, Color(0.63, 0.61, 0.58, 0.30))
