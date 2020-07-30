extends Node2D
class_name CaveWorld

export var level_seed: String
export (int) var mapWidth := 75
export (int) var mapHeight := 45
export (int) var tileSize := 32
export (int) var fillRatio := 55
export (int) var maxTime := 2
export (int) var wallsLimit := 4
export (Vector2) var roomCountRange := Vector2(3,7)
export (Vector2) var roomSizeRange := Vector2(5,15)

var rooms := []

var rnd := RandomNumberGenerator.new()

var time := 0

onready var tileMap: TileMap = $TileMap
onready var mapCamera: Camera2D = $mapCamera
var map := []
# Dirt is "alive", Walls are "dead"
enum Tiles { DIRT, WALL, GRASS, VOID }

var makingARoom := false
var mousePointer := Vector2.ZERO
var mouseRoomCenter: Vector2
var mouseRoomEdge: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w / 2, h / 2)
	var zx = w / (get_viewport_rect().size.x)
	var zy = h / (get_viewport_rect().size.y)
	var z = max(zx, zy)
	mapCamera.zoom = Vector2(z, z)
	createMapAtTimeZero()


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		timeAdvance()
	if Input.is_action_just_pressed("ui_cancel"):
		createMapAtTimeZero()
	if Input.is_action_just_pressed("ui_right"):
		fillRatio += 1
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_left"):
		fillRatio -= 1
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_up"):
		fillRatio += 5
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("ui_down"):
		fillRatio -= 5
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed('wall_lower'):
		wallsLimit -= 1 * -1 if Input.is_action_pressed("raise_mod") else 1
		createMapAtTimeZero()
		timeAdvance()
	if Input.is_action_just_pressed("clear"):
		fillRatio = 0
		createMapAtTimeZero()
	if Input.is_action_just_pressed("make_rooms"):
		fillRatio = 40
		createMapAtTimeZero()
		makeRooms()
		mapToTileMap()
		updateUI()
		update()
	if event is InputEventMouseMotion:
		mousePointer = get_global_mouse_position()
		update()
	if ! makingARoom && Input.is_mouse_button_pressed(1):
		mouseRoomCenter = get_global_mouse_position()
		mouseRoomEdge = mouseRoomCenter
		makingARoom = true
		update()
	elif makingARoom && event is InputEventMouse:
		mouseRoomEdge = get_global_mouse_position()
		if ! Input.is_mouse_button_pressed(1):
			makingARoom = false
			makeARoom(mouseRoomCenter/tileSize, mouseRoomEdge/tileSize)
			mapToTileMap()
		update()


func _draw():
	if makingARoom:
		var radius := 5.0
		if mouseRoomEdge:
			radius = mouseRoomCenter.distance_to(mouseRoomEdge)
		draw_circle(mouseRoomCenter, radius, Color.red)
	draw_circle(mousePointer, 15.0, Color.green)
	if rooms:
		for r in rooms:
			draw_circle(Vector2(r[0].x * tileSize, r[0].y * tileSize), 32.0, Color.yellow)

func makeRooms() -> void:
	var roomCount := rnd.randi_range(roomCountRange.x as int, roomCountRange.y as int)
	rooms = []
	for _i in range(roomCount):
		var maxRoomSize : int = roomSizeRange.y as int
		var x := rnd.randi_range(1+maxRoomSize, mapWidth-2 - maxRoomSize)
		var y := rnd.randi_range(1+maxRoomSize, mapHeight-2 - maxRoomSize)
		var c := Vector2(x,y)
		var d := rnd.randi_range(roomSizeRange.x as int , roomSizeRange.y as int)
		rooms.append([c, d])
		makeARoom(c, Vector2(x-d,y))


func makeARoom(center: Vector2, edge: Vector2) -> void:
	# Create Our Room
	var maxDistSq := center.distance_squared_to(edge)
	var maxDist := center.distance_to(edge)
	var cx := round(center.x) as int
	var cy := round(center.y) as int
	var tl := Vector2(cx - maxDist, cy - maxDist)
	for _y in range(tl.y, tl.y + maxDist * 2):
		for _x in range(tl.x, tl.x + maxDist * 2):
			var x: int = clamp(_x, 0, mapWidth - 1) as int
			var y: int = clamp(_y, 0, mapHeight - 1) as int
			var tile: int = map[x][y]
			var percent := (
				1.0
				- clamp(
					center.distance_squared_to(Vector2(x, y )) / maxDistSq,
					0.0,
					1.0
				)
			)
			if rnd.randf() < percent:
				tile = Tiles.DIRT
			map[x][y] = tile


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
	if level_seed:
		rnd.seed = hash(level_seed)
	else:
		rnd.randomize()
	tileMap.clear()
	map = []
	rooms = []
	time = 0
	for x in range(0, mapWidth):
		var tmap := []
		map.append(tmap)
		for y in range(0, mapHeight):
			var tile: int = Tiles.WALL
			if x > 0 && x < mapWidth - 1 && y > 0 && y < mapHeight - 1:
				var r = rnd.randi_range(0, 100)
				if r < fillRatio:
					tile = Tiles.DIRT
				else:
					tile = Tiles.WALL
			tmap.append(tile)
	updateUI()
	mapToTileMap()
	# timeAdvance()
