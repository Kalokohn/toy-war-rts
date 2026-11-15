extends Node3D
## RTS-camera: WASD/pijltjes of muis tegen de rand om te schuiven,
## scrollen om te zoomen, middelste muisknop slepen om te pannen.

const PAN_SPEED := 45.0
const EDGE_MARGIN := 10
const PITCH_DEG := 55.0
const MIN_ZOOM := 12.0
const MAX_ZOOM := 90.0

var camera: Camera3D
var zoom := 30.0
var edge_pan := true
var _drag := false


func _init() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 800.0
	# Lichte tilt-shift: voor- en achtergrond een beetje wazig, zodat het
	# eruitziet als een close-up van echt speelgoed.
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_near_enabled = true
	attr.dof_blur_amount = 0.06
	camera.attributes = attr
	add_child(camera)
	_apply()


func focus(p: Vector3) -> void:
	position = Vector3(p.x, 0, p.z)
	_clamp()


func _apply() -> void:
	var pitch := deg_to_rad(PITCH_DEG)
	camera.position = Vector3(0, sin(pitch) * zoom, cos(pitch) * zoom)
	camera.rotation = Vector3(-pitch, 0, 0)
	var attr := camera.attributes as CameraAttributesPractical
	if attr:
		attr.dof_blur_far_distance = zoom * 1.35
		attr.dof_blur_far_transition = zoom * 1.2
		attr.dof_blur_near_distance = zoom * 0.45
		attr.dof_blur_near_transition = zoom * 0.3


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if edge_pan and DisplayServer.window_is_focused() and not _drag:
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		var size := vp.get_visible_rect().size
		if Rect2(Vector2.ZERO, size).has_point(m):
			if m.x < EDGE_MARGIN: dir.x -= 1
			elif m.x > size.x - EDGE_MARGIN: dir.x += 1
			if m.y < EDGE_MARGIN: dir.y -= 1
			elif m.y > size.y - EDGE_MARGIN: dir.y += 1
	if dir != Vector2.ZERO:
		var speed := PAN_SPEED * (zoom / 42.0) * delta
		position += Vector3(dir.x, 0, dir.y).normalized() * speed
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = maxf(zoom * 0.9, MIN_ZOOM)
			_apply()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = minf(zoom * 1.1, MAX_ZOOM)
			_apply()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		var scale := zoom / 600.0
		position -= Vector3(event.relative.x, 0, event.relative.y) * scale
		_clamp()


func _clamp() -> void:
	var lim := GameData.MAP_HALF
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim + 10.0, lim + 10.0)
