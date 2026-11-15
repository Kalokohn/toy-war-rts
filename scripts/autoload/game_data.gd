extends Node
## Alle speldata op een plek: resources, units, gebouwen en spelerkleuren.
## Balanswaarden zijn een eerste gok en makkelijk aan te passen.

const MAX_PLAYERS := 4
const MAP_HALF := 100.0
const POP_MAX := 200

const RESOURCES := ["plastic", "blocks", "batteries", "marbles"]
const RESOURCE_NAMES := {
	"plastic": "Plastic",
	"blocks": "Blokjes",
	"batteries": "Batterijen",
	"marbles": "Knikkers",
}
const RESOURCE_COLORS := {
	"plastic": Color(0.95, 0.35, 0.35),
	"blocks": Color(0.85, 0.6, 0.3),
	"batteries": Color(0.95, 0.8, 0.2),
	"marbles": Color(0.45, 0.75, 0.95),
}
const START_RESOURCES := {"plastic": 200, "blocks": 200, "batteries": 100, "marbles": 100}

const PLAYER_COLORS := [
	Color(0.2, 0.45, 0.95),
	Color(0.9, 0.2, 0.2),
	Color(0.2, 0.72, 0.25),
	Color(0.95, 0.8, 0.15),
]
const PLAYER_COLOR_NAMES := ["Blauw", "Rood", "Groen", "Geel"]

## Resourcebronnen op de kaart. "type" van de bron = de resource die hij geeft.
const RESOURCE_NODES := {
	"plastic": {"name": "Speelgoedkist", "amount": 400, "radius": 1.6, "height": 2.4},
	"blocks": {"name": "Blokkenstapel", "amount": 300, "radius": 1.5, "height": 2.8},
	"batteries": {"name": "Batterijpak", "amount": 500, "radius": 1.2, "height": 1.9},
	"marbles": {"name": "Knikkerzak", "amount": 400, "radius": 1.3, "height": 1.4},
}

const UNITS := {
	"worker": {
		"name": "Opwindsoldaatje", "hp": 40, "speed": 5.0, "radius": 0.45,
		"cost": {"plastic": 50}, "train_time": 8.0, "pop": 1,
		"damage": 3, "range": 0.6, "cooldown": 1.5, "sight": 0.0,
		"can_gather": true, "can_build": true, "gather_rate": 1.2, "carry": 10,
	},
	"rifleman": {
		"name": "Geweerschutter", "hp": 70, "speed": 4.5, "radius": 0.5,
		"cost": {"plastic": 60, "batteries": 20}, "train_time": 10.0, "pop": 1,
		"damage": 7, "range": 7.0, "cooldown": 1.2, "sight": 12.0,
	},
}

const BUILDINGS := {
	"hq": {
		"name": "Speelgoeddoos", "hp": 1500, "size": 8.0, "height": 5.0,
		"cost": {}, "build_time": 60.0, "dropoff": true, "pop": 10, "trains": ["worker"],
	},
	"storage": {
		"name": "Opslagkist", "hp": 400, "size": 4.0, "height": 2.8,
		"cost": {"blocks": 100}, "build_time": 15.0, "dropoff": true,
	},
	"house": {
		"name": "Lego-huisje", "hp": 300, "size": 4.0, "height": 3.0,
		"cost": {"blocks": 50}, "build_time": 12.0, "pop": 10,
	},
	"barracks": {
		"name": "Barak", "hp": 800, "size": 6.0, "height": 4.0,
		"cost": {"blocks": 150}, "build_time": 25.0, "trains": ["rifleman"],
	},
	"tower": {
		"name": "Wachttoren", "hp": 600, "size": 3.0, "height": 7.2,
		"cost": {"blocks": 50, "marbles": 100}, "build_time": 20.0,
		"damage": 8, "range": 11.0, "cooldown": 1.5,
	},
}

## Wat een worker kan bouwen, met sneltoets.
const BUILD_MENU := [["house", "H"], ["storage", "O"], ["barracks", "B"], ["tower", "T"]]

var _mat_cache := {}


func can_build_type(btype: String) -> bool:
	for item in BUILD_MENU:
		if item[0] == btype:
			return true
	return false


func can_afford(stock: Dictionary, cost: Dictionary) -> bool:
	for res in cost:
		if stock.get(res, 0) < cost[res]:
			return false
	return true


func pay(stock: Dictionary, cost: Dictionary) -> void:
	for res in cost:
		stock[res] = stock.get(res, 0) - cost[res]


func missing_text(stock: Dictionary, cost: Dictionary) -> String:
	var parts := []
	for res in cost:
		if stock.get(res, 0) < cost[res]:
			parts.append(RESOURCE_NAMES[res])
	return "Niet genoeg " + ", ".join(parts)


func cost_text(cost: Dictionary) -> String:
	var parts := []
	for res in cost:
		parts.append("%d %s" % [cost[res], RESOURCE_NAMES[res]])
	return ", ".join(parts) if parts.size() > 0 else "gratis"


func player_color(slot: int) -> Color:
	if slot < 0 or slot >= PLAYER_COLORS.size():
		return Color(0.8, 0.8, 0.8)
	return PLAYER_COLORS[slot]


func display_name(kind: String, type: String) -> String:
	match kind:
		"unit":
			return UNITS[type]["name"]
		"building":
			return BUILDINGS[type]["name"]
		"resource":
			return RESOURCE_NODES[type]["name"]
	return type


## Gedeelde materialen, zodat niet elk blokje een eigen materiaal krijgt.
func make_mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(true), unshaded]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.45
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m
