extends Node3D
## Vitrine voor de modellen (start met `-- --showcase=units` of `=buildings`,
## `=resources`). Zet alle modellen op een rij in de kamer en maakt een
## screenshot als `--screenshot=pad.png` is meegegeven.

const ToyModels := preload("res://scripts/visual/toy_models.gd")
const Room := preload("res://scripts/visual/room.gd")

var what := "units"
var _t := 0.0


func _ready() -> void:
	Room.build(self, GameData.MAP_HALF)
	var list := []
	var spacing := 2.2
	match what:
		"units":
			list = ["worker", "rifleman", "mini_raptor", "velociraptor", "dilophosaurus", "triceratops", "pteranodon", "trex"]
		"buildings":
			list = ["hq", "storage", "house", "barracks", "tower", "volcano", "nest", "hatchery", "fossil_lab", "lookout"]
			spacing = 8.5
		"resources":
			list = ["plastic", "blocks", "batteries", "marbles"]
			spacing = 4.5
	var x := -spacing * (list.size() - 1) * 0.5
	for i in list.size():
		var row := 0
		var pos := Vector3(x + i * spacing, 0, 0)
		if what == "buildings":
			row = i / 5
			pos = Vector3(-spacing * 2 + (i % 5) * spacing, 0, row * 10.0 - 5.0)
		var b := ToyModels.build(list[i], GameData.player_color(i % 4 if what != "units" else (0 if i < 2 else 1)), i + 1)
		var n: Node3D = b["root"]
		n.position = pos
		if list[i] == "pteranodon":
			n.position.y = 1.6
		n.rotation_degrees.y = 25
		add_child(n)
	var cam := Camera3D.new()
	cam.fov = 40
	match what:
		"units":
			cam.position = Vector3(0, 4.5, 11.5)
			cam.rotation_degrees = Vector3(-18, 0, 0)
		"buildings":
			cam.position = Vector3(0, 26, 26)
			cam.rotation_degrees = Vector3(-42, 0, 0)
		"resources":
			cam.position = Vector3(0, 5.5, 10)
			cam.rotation_degrees = Vector3(-25, 0, 0)
	add_child(cam)
	cam.current = true


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5:
		var main := get_tree().current_scene
		if main.args.has("screenshot"):
			get_viewport().get_texture().get_image().save_png(main.args["screenshot"])
			print("SHOWCASE opgeslagen: ", main.args["screenshot"])
		get_tree().quit()
