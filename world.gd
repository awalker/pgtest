extends Node2D

export(int) var mapWidth = 75
export(int) var mapHeight = 45
export(int) var tileSize = 32
export(int) var fillRatio = 40
export(int) var maxTime = 2
export(int) var birthLimit = 4
export(int) var deathLimit = 3

var time := 0

onready var tileMap = $TileMap
onready var mapCamera = $mapCamera
var map := []
# Dirt is "alive", Walls are "dead"
enum Tiles {DIRT, WALL, GRASS, VOID}


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	# rand_seed(13375)
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w/2, h/2)
	var zx = w/(get_viewport_rect().size.x)
	var zy = h/(get_viewport_rect().size.y)
	var z = max(zx,zy)
	mapCamera.zoom = Vector2(z,z)
	print(z)
	createMapAtTimeZero()

func _unhandled_input(_event):
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
	if Input.is_action_just_pressed('death_lower'):
		deathLimit -= 1 * -1 if Input.is_action_pressed("raise_mod") else 1
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed('birth_lower'):
		birthLimit -= 1 * -1 if Input.is_action_pressed("raise_mod") else 1
		createMapAtTimeZero()
		timeAdvance()

func updateUI():
	$CanvasLayer/h/Time.text = "Time: " + str(time)
	$CanvasLayer/h/fillRatio.text = "Fill Ratio: " + str(fillRatio)
	$CanvasLayer/h/birthLimit.text = "Birth Limit: " + str(birthLimit)
	$CanvasLayer/h/deathLimit.text = "Death Limit: " + str(deathLimit)

func timeAdvance():
	time += 1
	for y in range(1,mapHeight-1):
		for x in range(1,mapWidth-1):
			var walls = countWallsInNeighborhood(x, y)
			if map[x][y] == Tiles.DIRT:
				if walls < deathLimit:
					map[x][y] = Tiles.WALL
				else:
					map[x][y] = Tiles.DIRT
			else:
				if walls > birthLimit:
					map[x][y] = Tiles.WALL
				else:
					map[x][y] = Tiles.DIRT
	updateUI()
	mapToTileMap()

func countWallsInNeighborhood(x, y):
	var wallCount = 0
	for xx in range(x-1,x+2):
		for yy in range(y-1,y+2):
			if xx != x || yy != y:
				if map[xx][yy] == Tiles.WALL:
					wallCount += 1
	return wallCount

func mapToTileMap():
	for x in range(0,mapWidth):
		for y in range(0, mapHeight):
			tileMap.set_cell(x,y, map[x][y])


func createMapAtTimeZero():
	tileMap.clear()
	map = []
	time = 0
	for x in range(0,mapWidth):
		var tmap = []
		map.append(tmap)
		for y in range(0, mapHeight):
			var tile = Tiles.WALL
			if x > 0 && x < mapWidth-1 && y > 0 && y < mapHeight-1:
				var r = (randi() % 100) + 1
				if r < fillRatio:
					tile = Tiles.DIRT
				else:
					tile =  Tiles.WALL
			tmap.append(tile)
	updateUI()
	mapToTileMap()
	# timeAdvance()
