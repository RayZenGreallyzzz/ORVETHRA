extends Control

# Top-right world map, projected directly from the actual road graph.
var streets: Array[PackedVector2Array] = []
var player_xz := Vector2.ZERO
var facing := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func refresh(world_point: Vector2, heading: float) -> void:
    player_xz = world_point
    facing = heading
    queue_redraw()

func _map(point: Vector2) -> Vector2:
    var middle := size * 0.5
    return middle + Vector2(point.x / 107.0, point.y / 93.0) * (size.x * 0.39)

func _draw() -> void:
    var center := size * 0.5
    var radius := size.x * 0.47
    draw_circle(center, radius + 2.0, Color(0.08, 0.09, 0.10, 0.91))
    draw_circle(center, radius, Color(0.26, 0.33, 0.24, 0.93))
    for road in streets:
        for i in range(road.size() - 1):
            var a := _map(road[i])
            var b := _map(road[i + 1])
            if a.distance_to(center) < radius and b.distance_to(center) < radius:
                draw_line(a, b, Color(0.24, 0.23, 0.19), 7, true)
                draw_line(a, b, Color(0.60, 0.54, 0.43), 4, true)
    draw_circle(center, size.x * 0.065, Color(0.61, 0.55, 0.44, 0.92))
    draw_circle(center, size.x * 0.025, Color(0.44, 0.72, 0.88, 1.0))
    # Training clearing moved 8m farther into the left-hand grass.
    var training_icon := _map(Vector2(99.0, 70.0))
    if training_icon.distance_to(center) < radius:
        draw_circle(training_icon, 6.0, Color(0.88, 0.34, 0.35, 1.0))
        draw_arc(training_icon, 8.0, 0, TAU, 24, Color(0.99, 0.85, 0.53, 0.96), 2.0, true)
    # Forgotten Catacombs crypt at the dead-end of the NE road.
    # The street-end crypt sits near the circular map edge; clamp its
    # marker inward so the entrance remains visible on small screens.
    var crypt_icon := _map(Vector2(89.25, 93.0))
    crypt_icon = center + (crypt_icon - center).limit_length(radius - 11.0)
    if crypt_icon.distance_to(center) < radius:
        draw_colored_polygon(PackedVector2Array([
            crypt_icon + Vector2(0, -7), crypt_icon + Vector2(7, 0),
            crypt_icon + Vector2(0, 7), crypt_icon + Vector2(-7, 0)
        ]), Color(0.64, 0.35, 0.77, 1.0))
        draw_arc(crypt_icon, 9.0, 0, TAU, 24, Color("d9baeb"), 1.7, true)
    var cursor := _map(player_xz)
    cursor = center + (cursor - center).limit_length(radius - 13.0)
    var direction := Vector2(-sin(facing), -cos(facing))
    var sideways := Vector2(-direction.y, direction.x)
    draw_colored_polygon(
        PackedVector2Array([cursor + direction * 12.0, cursor - direction * 8.0 + sideways * 6.0, cursor - direction * 8.0 - sideways * 6.0]),
        Color(1.0, 0.83, 0.40)
    )
    draw_arc(center, radius, 0, TAU, 96, Color(0.85, 0.72, 0.46, 0.95), 3.0, true)
