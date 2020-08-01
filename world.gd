extends Node2D
class_name CaveWorld

export var level_seed: String
export (int) var mapWidth := 256
export (int) var mapHeight := 240
export (int) var tileSize := 32
export (int) var fillRatio := 40
export (int) var maxTime := 2
export (int) var wallsLimit := 4
export (int) var minRoomArea := 75
export (int) var minWallArea := 30
export (Vector2) var roomCountRange := Vector2(4, 10)
export (Vector2) var roomSizeRange := Vector2(15, 50)

var autoSmooth := true

var rooms := []

var rnd := RandomNumberGenerator.new()

var time := 0
var working := false

onready var tileMap: TileMap = $TileMap
onready var mapCamera: Camera2D = $mapCamera
var map := []
# Dirt is "alive", Walls are "dead"
enum Tiles { DIRT, WALL, GRASS, VOID }

var makingARoom := false
var mousePointer := Vector2.ZERO
var mouseRoomCenter: Vector2
var mouseRoomEdge: Vector2
var highlightTiles: TileGroup
var listOfRooms := []


class Room:
	var center := Vector2.ZERO
	var distance := 0


class TileGroup:
	var regions := {}
	var _sz := 0
	var connected := []
	var edges := []
	var center := Vector2.ZERO
	var isConnectedToMain := false
	var isMain := false

	func isConnected(room: TileGroup) -> bool:
		if self == room:
			return false
		for c in connected:
			if c[0] == room:
				return true
		return false

	func getConnectedRooms(rooms := [self]) -> Array:
		for rarray in connected:
			var room: TileGroup = rarray[0]
			if not rooms.has(room):
				rooms.append(room)
				rooms = room.getConnectedRooms(rooms)
		return rooms

	func connectRoom(room: TileGroup, a: Vector2, b: Vector2) -> void:
		print("Connect %s to %s" % [self, room])
		connected.append([room, a, b])
		room.connected.append([self, a, b])
		isConnectedToMain = room.isConnectedToMain || isConnectedToMain
		room.isConnectedToMain = isConnectedToMain

	func findEdges():
		var minx := 9999999
		var miny := 9999999
		var maxy := -9999999
		var maxx := -9999999
		if edges.size() > 0:
			return
		for x in regions.keys():
			minx = min(minx, x) as int
			maxx = max(maxx, x) as int
			for ys in regions.get(x):
				miny = min(miny, ys[0]) as int
				maxy = max(maxy, ys[1]) as int
				edges.append(Vector2(x, ys[0]))
				edges.append(Vector2(x, ys[1]))
		center = Vector2(minx + (maxx - minx) / 2.0, miny + (maxy - miny) / 2.0)

	func insert(x: int, y: int) -> void:
		_sz = 0
		if regions.empty():
			regions[x] = [[y, y]]
			return
		else:
			if ! regions.has(x):
				regions[x] = [[y, y]]
				return
			var ys: Array = regions.get(x)
			for i in ys.size():
				var r: Array = ys[i]
				if y < r[0] - 1:
					ys.insert(i, [y, y])
					return
				if y >= r[0] && y <= r[1]:
					return
				elif r[0] - 1 == y:
					r[0] = y
					normalizeRegion(r)
					return
				elif r[1] + 1 == y:
					r[1] = y
					normalizeRegion(r)
					return
			ys.append([y, y])

	func normalize() -> void:
		_sz = 0
		for x in regions.keys():
			normalizeX(regions[x])

	func normalizeRegion(r: Array) -> void:
		var a := min(r[0], r[1])
		var b := max(r[0], r[1])
		r[0] = a
		r[1] = b

	func normalizeX(ys: Array, offset := 0) -> void:
		if ys.size() > offset + 1:
			if ys[offset][1] >= ys[offset + 1][0]:
				ys[offset][0] = min(ys[offset][0], ys[offset + 1][0])
				ys[offset][1] = max(ys[offset][1], ys[offset + 1][1])
				ys.remove(offset + 1)
				normalizeX(ys, offset)
			else:
				normalizeX(ys, offset + 1)

	func isIn(x: int, y: int) -> bool:
		if regions.empty():
			return false
		if regions.has(x):
			var ys: Array = regions.get(x)
			for r in ys:
				if y >= r[0] && y <= r[1]:
					return true
		return false

	func findClosest(rooms: Array):
		"""Currently, this find a close-ish room and connects in together. 
		The first round of judges distance by center. Probably should just 
		compare all the points everywhere"""
		findEdges()
		var closestSq := 999999999999.0
		var closestRoom: TileGroup
		var closestVector: Vector2
		var closestSelfVector: Vector2
		for i in rooms.size():
			var room: TileGroup = rooms[i]
			room.findEdges()
			if room == self:
				continue
			if isConnected(room):
				continue
			var tmp := room.center.distance_squared_to(center)
			if tmp < closestSq:
				closestSq = tmp
				closestRoom = room
		if closestRoom:
			closestSq = 999999999999.0
			closestSelfVector = center
			closestVector = closestRoom.center
			for sv in edges:
				for v in closestRoom.edges:
					var tmp: float = sv.distance_squared_to(v)
					if tmp <= closestSq:
						closestSq = tmp
						closestSelfVector = sv
						closestVector = v
			connectRoom(closestRoom, closestSelfVector, closestVector)

	func drawConnections(color: Color, tileSize: int, node: Node2D) -> void:
		var worldCenter = center * tileSize
		node.draw_rect(
			Rect2(worldCenter, Vector2(tileSize, tileSize)),
			Color.blue if isMain else Color.red,
			true
		)
		for c in connected:
			node.draw_line(c[1] * tileSize, c[2] * tileSize, color, tileSize)
		for edge in edges:
			var v: Vector2 = edge * tileSize
			node.draw_rect(Rect2(v, Vector2(tileSize, tileSize)), color, true)

	func draw(color: Color, tileSize: int, node: Node2D) -> void:
		for x in regions.keys():
			var ys: Array = regions[x]
			for yrange in ys:
				var s := Vector2(x * tileSize, yrange[0] * tileSize)
				var e := Vector2((x + 1) * tileSize, (yrange[1] + 1) * tileSize)
				node.draw_rect(Rect2(s, e - s), color, true)

	func setTile(map: Array, type: int) -> void:
		for x in regions.keys():
			var ys: Array = regions[x]
			for yrange in ys:
				for y in range(yrange[0], yrange[1] + 1):
					map[x][y] = type

	func size() -> int:
		if _sz:
			return _sz
		var size := 0
		for x in regions.keys():
			var ys: Array = regions[x]
			for yrange in ys:
				size += (yrange[1] - yrange[0]) + 1
		_sz = size
		return size

	# func addPoint(x:int, y:int) -> void:
	# var r := Rect2(Vector2(x,y), Vector(1,1))


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# $"CanvasLayer/UI/vbox/Map W".label_text = "Map W"
	# $"CanvasLayer/UI/vbox/Map H".label_text = "Map H"
	mapCameraUpdated()
	_on_regen_pressed()


func mapCameraUpdated() -> void:
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w / 2, h / 2)
	var zx = w / (get_viewport_rect().size.x)
	var zy = h / (get_viewport_rect().size.y)
	var z = max(zx, zy)
	mapCamera.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	if working:
		return
	if Input.is_action_just_pressed("toggle_ui"):
		var item := $CanvasLayer/UI
		item.visible = ! item.visible
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if Input.is_action_just_pressed("clear"):
		fillRatio = 0
		createMapAtTimeZero()
		mapToTileMap()
	if event is InputEventMouseMotion:
		mousePointer = get_global_mouse_position()
		update()
	if ! working && Input.is_mouse_button_pressed(2):
		working = true
		var p = get_global_mouse_position()
		print("finding group")
		var result = findTileGroup(p.x / tileSize, p.y / tileSize, Tiles.DIRT)
		highlightTiles = yield(result, "completed")
		print(highlightTiles.size())
		update()
		working = false
	if ! makingARoom && Input.is_mouse_button_pressed(1):
		mouseRoomCenter = get_global_mouse_position()
		mouseRoomEdge = mouseRoomCenter
		makingARoom = true
		update()
	elif makingARoom && event is InputEventMouse:
		mouseRoomEdge = get_global_mouse_position()
		if ! Input.is_mouse_button_pressed(1):
			makingARoom = false
			makeARoom(mouseRoomCenter / tileSize, mouseRoomEdge / tileSize)
			mapToTileMap()
		update()


onready var workingUI = $CanvasLayer/Working


func _process(_delta):
	if working != workingUI.visible:
		print('Change working ui')
		workingUI.visible = working


func _draw():
	if makingARoom:
		var radius := 5.0
		if mouseRoomEdge:
			radius = mouseRoomCenter.distance_to(mouseRoomEdge)
		draw_circle(mouseRoomCenter, radius, Color.red)
	draw_circle(mousePointer, 15.0, Color.green)
	if rooms:
		for r in rooms:
			draw_circle(Vector2(r.center.x * tileSize, r.center.y * tileSize), 32.0, Color.yellow)
	if highlightTiles:
		highlightTiles.draw(Color("#00FF00" if working else "#0000FF"), tileSize, self)
	if listOfRooms:
		for i in listOfRooms.size():
			var r: TileGroup = listOfRooms[i]
			r.drawConnections(Color.yellow, tileSize, self)


func makeRooms() -> void:
	var roomCount := rnd.randi_range(roomCountRange.x as int, roomCountRange.y as int)
	rooms = []
	var i := 0
	var energy := 100
	while i < roomCount && energy > 0:
		# Check existing room and attempt to reduce overlap. Some overlap would be ok(?)
		var maxRoomSize: int = roomSizeRange.y as int
		var x := rnd.randi_range(1 + maxRoomSize, mapWidth - 2 - maxRoomSize)
		var y := rnd.randi_range(1 + maxRoomSize, mapHeight - 2 - maxRoomSize)
		var c := Vector2(x, y)
		var d := rnd.randi_range(roomSizeRange.x as int, roomSizeRange.y as int)
		var closest := 999999.0
		for room in rooms:
			closest = min(closest, room.center.distance_squared_to(c))
		if closest > maxRoomSize * maxRoomSize * 0.75:
			var r := Room.new()
			r.center = c
			r.distance = d
			rooms.append(r)
			makeARoom(c, Vector2(x - d, y))
			i += 1
		else:
			energy -= 1


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
				- clamp(center.distance_squared_to(Vector2(x, y)) / maxDistSq, 0.0, 1.0)
			)
			if rnd.randf() < percent:
				tile = Tiles.DIRT
			map[x][y] = tile


func updateUI() -> void:
	$CanvasLayer/h/Time.text = "Time: " + str(time)
	$"CanvasLayer/UI/vbox/Fill Ratio".value = fillRatio
	var asBtn: CheckBox = $CanvasLayer/UI/vbox/buttonBox/autosmooth
	asBtn.pressed = autoSmooth
	$"CanvasLayer/UI/vbox/Map H".value = mapHeight
	$"CanvasLayer/UI/vbox/Map W".value = mapWidth
	$"CanvasLayer/UI/vbox/Wall Limit".value = wallsLimit
	$"CanvasLayer/UI/vbox/Min Wall".value = minWallArea
	$"CanvasLayer/UI/vbox/Min Room Area".value = minRoomArea
	$"CanvasLayer/UI/vbox/Min Rooms".value = roomCountRange.x as int
	$"CanvasLayer/UI/vbox/Max Rooms".value = roomCountRange.y as int
	$"CanvasLayer/UI/vbox/Min Room Size".value = roomSizeRange.x as int
	$"CanvasLayer/UI/vbox/Max Room Size".value = roomSizeRange.y as int
	$CanvasLayer/UI/vbox/seed.value = level_seed


func timeAdvance() -> void:
	highlightTiles = null
	rooms = []  # Some rooms make join or disappear, so just start over
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
	update()


func walls_sort_small(a: TileGroup, b: TileGroup) -> bool:
	return a.size() < b.size()


func cull(alreadyWorking := false) -> void:
	if working && ! alreadyWorking:
		return
	working = true
	var walls: Array = yield(findGroups(Tiles.WALL), "completed")
	print("Found %d wall groups" % walls.size())
	walls.sort_custom(self, "walls_sort_small")
	var i := 0
	while i < walls.size():
		yield(get_tree(), "idle_frame")
		if walls[0].size() < minWallArea:
			print(walls[0].size())
			# make all the walls in this tile group into dirt
			walls[0].setTile(map, Tiles.DIRT)
			walls.remove(0)
		else:
			break
	var dirts: Array = yield(findGroups(Tiles.DIRT), "completed")
	print("Found %d dirt groups" % dirts.size())
	dirts.sort_custom(self, "walls_sort_small")
	i = 0
	while i < dirts.size():
		yield(get_tree(), "idle_frame")
		if dirts[0].size() < minRoomArea:
			print(dirts[0].size())
			# make all the walls in this tile group into dirt
			dirts[0].setTile(map, Tiles.WALL)
			dirts.remove(0)
		else:
			break
	mapToTileMap()
	listOfRooms = dirts
	working = alreadyWorking


func findGroups(type: int) -> Array:
	var groups := []
	for y in range(mapHeight):
		yield(get_tree(), "idle_frame")
		for x in range(mapWidth):
			var tile: int = map[x][y]
			if tile == type:
				# var v := Vector2(x,y)
				var inGroup := false
				for g in groups:
					if g.isIn(x, y):
						inGroup = true
						break
				if ! inGroup:
					var tiles: TileGroup = yield(findTileGroup(x, y, type), "completed")
					groups.append(tiles)
	return groups


func queueIfOk(queue: Array, group: TileGroup, x: int, y: int) -> void:
	var v := Vector2(x, y)
	if x >= 0 && x < mapWidth && y >= 0 && y < mapHeight && ! queue.has(v) && ! group.isIn(x, y):
		queue.append(v)


var runlimit = 250


func findTileGroup(x: int, y: int, type: int):
	var data := [TileGroup.new(), [Vector2(x, y)]]
	var start := OS.get_ticks_msec()
	var elapsed := 0.0
	var i := 0
	yield(get_tree(), "idle_frame")
	while data[1].size():
		data = findRestOfGroup(data, type)
		i += 1
		if i > runlimit:
			i = 0
			# Resume execution the next frame.
			elapsed += OS.get_ticks_msec() - start
			highlightTiles = data[0]
			update()
			yield(get_tree(), "idle_frame")
			start = OS.get_ticks_msec()
	print("%f sec at run limit %d" % [elapsed / 1000.0, runlimit])
	highlightTiles = data[0].normalize()
	return data[0]


func findRestOfGroup(data: Array, type: int) -> Array:
	var group: TileGroup = data[0]
	var queue: Array = data[1]

	var mine: Vector2 = queue.pop_front()
	if mine == null:
		return data

	var x = clamp(mine.x, 0, mapWidth)
	var y = clamp(mine.y, 0, mapHeight)
	if x != mine.x || y != mine.y:
		return data
	# var v := Vector2(x,y)
	if ! group.isIn(x, y) && map[x][y] == type:
		group.insert(x, y)
		queueIfOk(queue, group, x - 1, y)
		queueIfOk(queue, group, x + 1, y)
		queueIfOk(queue, group, x, y - 1)
		queueIfOk(queue, group, x, y + 1)
	return data


func createMapAtTimeZero() -> void:
	listOfRooms = []
	highlightTiles = null
	if level_seed:
		rnd.seed = hash(level_seed)
	else:
		rnd.randomize()
	tileMap.clear()
	map = []
	rooms = []
	time = 0
	map.resize(mapWidth)
	for x in range(0, mapWidth):
		var tmap := []
		tmap.resize(mapHeight)
		map[x] = tmap
		for y in range(0, mapHeight):
			var tile: int = Tiles.WALL
			if x > 0 && x < mapWidth - 1 && y > 0 && y < mapHeight - 1:
				var r = rnd.randi_range(0, 100)
				if r < fillRatio:
					tile = Tiles.DIRT
				else:
					tile = Tiles.WALL
			tmap[y] = tile
	updateUI()
	# timeAdvance()


func doAutoSmoothing():
	if autoSmooth:
		for _i in range(time, maxTime):
			timeAdvance()


func connectRooms(alreadyWorking := false):
	if working && ! alreadyWorking:
		return
	working = true
	if listOfRooms.size() == 0:
		yield(cull(true), "completed")
	else:
		yield(get_tree(), "idle_frame")
	var mainRoom: TileGroup = listOfRooms[listOfRooms.size() - 1]
	mainRoom.isMain = true
	mainRoom.isConnectedToMain = true

	print("found %d rooms" % listOfRooms.size())
	if listOfRooms.size() > 1:
		for roomIndex in range(0, listOfRooms.size() - 1):
			var room: TileGroup = listOfRooms[roomIndex]
			room.findClosest(listOfRooms)

	# Make sure all rooms are connected
	var energy = 0
	while energy < 4:
		energy += 1
		var groups := []  # we need a better way to build our groups, this isn't accounting for friend-of-a-friend, etc
		for r in listOfRooms:
			var found := false
			for g in groups:
				found = g.has(r)
				if found:
					break
			if not found:
				groups.append(r.getConnectedRooms())
		print("number of groups %d" % groups.size())
		if groups.size() == 1:
			# only one group, everything is connected
			break
		else:
			# multiple groups. join the closest rooms
			var g1: Array = groups[0]
			var cgroup: Array = groups[1]
			var c1: TileGroup
			var d = 99999999999999
			for r1 in g1:
				yield(get_tree(), "idle_frame")
				for g2i in groups.size() - 1:
					var g2: Array = groups[g2i + 1]
					for r2 in g2:
						var tmp: float = r1.center.distance_squared_to(r2.center)
						if tmp < d:
							d = tmp
							c1 = r1
							cgroup = g2
			c1.findClosest(cgroup)
	update()
	working = alreadyWorking


func _on_smooth_pressed():
	timeAdvance()
	mapToTileMap()
	updateUI()
	update()


func _on_createRooms_pressed():
	createMapAtTimeZero()
	makeRooms()
	doAutoSmoothing()
	mapToTileMap()
	updateUI()
	update()


func _on_regen_pressed():
	createMapAtTimeZero()
	doAutoSmoothing()
	mapToTileMap()
	mapCameraUpdated()
	updateUI()
	update()


func _on_autosmooth_toggled(button_pressed):
	print(button_pressed)
	autoSmooth = button_pressed
	updateUI()


func _on_Map_H_value_changed(value):
	mapHeight = value


func _on_Map_W_value_changed(value):
	mapWidth = value


func _on_Fill_Ratio_value_changed(value):
	fillRatio = clamp(value, 0, 100) as int
	$"CanvasLayer/UI/vbox/Fill Ratio".value = fillRatio


func _on_Wall_Limit_value_changed(value):
	wallsLimit = value


func _on_Min_Room_Area_value_changed(value):
	minRoomArea = value


func _on_Min_Wall_value_changed(value):
	minWallArea = value


func _on_Min_Rooms_value_changed(value):
	roomCountRange.x = value


func _on_Max_Rooms_value_changed(value):
	roomCountRange.y = value


func _on_Min_Room_Size_value_changed(value):
	roomSizeRange.x = value


func _on_Max_Room_Size_value_changed(value):
	roomSizeRange.y = value


func _on_cull_pressed():
	cull()


func _on_connectRooms_pressed():
	connectRooms()


func _on_seed_value_changed(value):
	if value:
		level_seed = value
	else:
		level_seed = ""
