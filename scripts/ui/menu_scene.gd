extends Node3D
## Achtergrond van het hoofdmenu: een klein slagveld op het kleed met
## soldaatjes tegen dino's, en een camera die er langzaam omheen draait.

const Entity := preload("res://scripts/game/entity.gd")
const Room := preload("res://scripts/visual/room.gd")

var _cam: Camera3D
var _t := 0.0
var _id := 900000


func _ready() -> void:
	Room.build(self, GameData.MAP_HALF)
	# Toy Soldiers (blauw) links, Toy Dinos (rood) rechts.
	_add("building", "hq", 0, Vector3(-17, 0, -6), 0)
	_add("building", "barracks", 0, Vector3(-15, 0, 7), 20)
	_add("building", "tower", 0, Vector3(-8, 0, -11), 0)
	_add("building", "volcano", 1, Vector3(17, 0, -5), 0)
	_add("building", "hatchery", 1, Vector3(15, 0, 8), -20)
	_add("building", "lookout", 1, Vector3(8, 0, -11), 0)
	_add("resource", "blocks", -1, Vector3(-2, 0, -9), 0)
	_add("resource", "marbles", -1, Vector3(3, 0, -10), 0)
	_add("resource", "batteries", -1, Vector3(0, 0, 9), 0)
	for i in 6:
		var u := _add("unit", "rifleman", 0, Vector3(-6.0 + (i % 2) * 1.6, 0, -3.0 + i * 1.3), 90)
		u.state = "attack"
		u._atk_t = randf() * 1.0
	for i in 2:
		_add("unit", "worker", 0, Vector3(-11.0, 0, -1.0 + i * 1.6), 60)
	var dinos := ["velociraptor", "velociraptor", "dilophosaurus", "triceratops", "trex", "velociraptor"]
	for i in dinos.size():
		var spots := [Vector3(4.5, 0, -4.5), Vector3(5.0, 0, -2.0), Vector3(4.2, 0, 0.6), Vector3(7.5, 0, -0.5), Vector3(9.5, 0, -4.0), Vector3(4.6, 0, 3.4)]
		var u := _add("unit", dinos[i], 1, spots[i], -90)
		u.state = "attack"
		u._atk_t = randf() * 1.0
	var p := _add("unit", "pteranodon", 1, Vector3(2, 0, 3), -120)
	p.moving = true
	_cam = Camera3D.new()
	_cam.fov = 42
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 34.0
	attr.dof_blur_far_transition = 20.0
	attr.dof_blur_amount = 0.08
	_cam.attributes = attr
	add_child(_cam)
	_cam.current = true
	_place_cam()


func _add(kind: String, type: String, slot: int, pos: Vector3, rot_deg: float) -> Node3D:
	_id += 1
	var e := Entity.new()
	e.setup(_id, kind, type, slot, pos, 1.0)
	e.rotation_degrees.y = rot_deg
	e.net_rot = e.rotation.y
	add_child(e)
	return e


func _place_cam() -> void:
	var a := 0.35 + sin(_t * 0.07) * 0.35
	_cam.position = Vector3(sin(a) * 26.0, 11.0, cos(a) * 26.0)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	_cam.position += _cam.transform.basis.x * -6.0


func _process(delta: float) -> void:
	_t += delta
	_place_cam()
