extends Node2D
class_name CaveWorld

export (int) var mapWidth := 75
export (int) var mapHeight := 45
export (int) var tileSize := 32
export (int) var fillRatio := 55
export (int) var maxTime := 2
export (int) var wallsLimit := 4

var time := 0

onready var tileMap: TileMap = $TileMap
onready var mapCamera: Camera2D = $mapCamera
var map := []
# Dirt is "alive", Walls are "dead"
enum Tiles { DIRT, WALL, GRASS, VOID }


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	# rand_seed(13375)
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w / 2, h / 2)
	var zx = w / (get_viewport_rect().size.x)
	var zy = h / (get_viewport_rect().size.y)
	var z = max(zx, zy)
	mapCamera.zoom = Vector2(z, z)
	print(z)
	createMapAtTimeZero()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		timeAdvance()
	if Input.is_action_just_pressed("ui_cancel"):
		createMapAtTimeZero()
	if Input.is_action_just_pressed("ui_right"):
		fillRatio += 1
		print(fillRatio)
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_left"):
		fillRatio -= 1
		print(fillRatio)
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_up"):
		fillRatio += 5
		print(fillRatio)
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_down"):
		fillRatio -= 5
		print(fillRatio)
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed('wall_lower'):
		wallsLimit -= 1 * -1 if Input.is_action_pressed("raise_mod") else 1
		createMapAtTimeZero()
		timeAdvance()


func updateUI() -> void:
	$CanvasLayer/h/Time.text = "Time: " + str(time)
	$CanvasLayer/h/fillRatio.text = "Fill Ratio: " + str(fillRatio)
	$CanvasLayer/h/wallsLimit.text = "Walls Limits: " + str(wallsLimit)


func timeAdvance() -> void:
	time += 1
	for y in range(1, mapHeight - 1):
		for x in range(1, mapWidth - 1):
			var walls = countWallsInNeighborhood(x, y)
			if map[x][y] == Tiles.DIRT:
				if walls > wallsLimit:
					map[x][y] = Tiles.WALL
			else:
				# iama wall, bro-ham
				if walls < wallsLimit:
					map[x][y] = Tiles.DIRT
	updateUI()
	mapToTileMap()


func countWallsInNeighborhood(x: int, y: int) -> int:
	var wallCount := 0
	for xx in range(x - 1, x + 2):
		for yy in range(y - 1, y + 2):
			if xx != x || yy != y:
				if map[xx][yy] == Tiles.WALL:
					wallCount += 1
	return wallCount


func mapToTileMap() -> void:
	for x in range(0, mapWidth):
		for y in range(0, mapHeight):
			tileMap.set_cell(x, y, map[x][y])


func createMapAtTimeZero() -> void:
	tileMap.clear()
	map = []
	time = 0
	for x in range(0, mapWidth):
		var tmap := []
		map.append(tmap)
		for y in range(0, mapHeight):
			var tile: int = Tiles.WALL
			if x > 0 && x < mapWidth - 1 && y > 0 && y < mapHeight - 1:
				var r = (randi() % 100) + 1
				if r < fillRatio:
					tile = Tiles.DIRT
				else:
					tile = Tiles.WALL
			tmap.append(tile)
	updateUI()
	mapToTileMap()
	# timeAdvance()
