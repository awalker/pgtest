extends Node2D

export(int) var mapWidth = 256
export(int) var mapHeight = 256
export(int) var tileSize = 32
export(int) var fillRatio = 36
export(int) var maxTime = 5

var time := 0

onready var tileMap = $TileMap
onready var mapCamera = $mapCamera
enum Tiles {DIRT, WALL, GRASS, VOID}


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
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

func timeAdvance():
	time += 1
	for y in range(1,mapHeight-1):
		for x in range(1,mapWidth-1):
			var walls = countWallsInNeighborhood(x, y)
			tileMap.set_cell(x,y, Tiles.DIRT if walls < 5 else Tiles.WALL )

func countWallsInNeighborhood(x, y):
	var wallCount = 0
	for xx in range(x-1,x+2):
		for yy in range(y-1,y+2):
			if xx != x || yy != y:
				if tileMap.get_cell(xx,yy) == Tiles.WALL:
					wallCount += 1
	return wallCount


func createMapAtTimeZero():
	tileMap.clear()
	time = 0
	for x in range(0,mapWidth):
		for y in range(0, mapHeight):
			var tile = Tiles.WALL
			if x > 0 && x < mapWidth-1 && y > 0 && y < mapHeight-1:
				tile = Tiles.DIRT if (randi() % 101) < fillRatio else Tiles.WALL
			tileMap.set_cell(x,y,tile)
