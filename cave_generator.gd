extends Node
class_name CaveGenerator

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
export (int) var octaves := 4
export (float) var period := 20.0
export (float) var persistence := 0.8

export (bool) var useRooms := true
export (bool) var useProbRooms := true
export (bool) var useRandomFill := true
export (bool) var doCulling := true
export (bool) var doConnections := true

var autoSmooth := true

var rooms := []

var rnd := RandomNumberGenerator.new()

var time := 0
var working := false
var thread: Thread
var mapMutex: Mutex
var optionsMutex: Mutex  # TODO: etiher remove or move all options to seperate object
var exitMutex: Mutex
var genSemaphore: Semaphore
var genAction := ""
var exitThread := false
var requestStop := false
var noise := OpenSimplexNoise.new()

var map := []
var itemMap := []
# TODO: Would be nice to add door_open and door_closed (and maybe door_locked) to either the tiles or items
enum Tiles { DIRT, WALL, GRASS, VOID_TILE }
# Most of these represent tiers of items/enemy spawns, not actual items or enemy spawns
enum Items { NO_ITEM, ENTRANCE, EXIT, ITEM1, ITEM2, ITEM3, ENEMY1, ENEMY2, ENEMY3 }

var makingARoom := false
var mousePointer := Vector2.ZERO
var mouseRoomCenter: Vector2
var mouseRoomEdge: Vector2
var highlightTiles: Room
var listOfRooms := []

# warning-ignore:unused_signal
signal completed
# warning-ignore:unused_signal
signal progress(progress)
# warning-ignore:unused_signal
signal update_debug_canvas
# warning-ignore:unused_signal
signal update_ui


class MouseArea:
    var center := Vector2.ZERO
    var distance := 0


class Room:
    var regions := {}
    var _sz := 0
    var connected := []
    var edges := []
    var center := Vector2.ZERO
    var isConnectedToMain := false
    var isMain := false

    func setConnectedToMain():
        if ! isConnectedToMain:
            isConnectedToMain = true
            for c in connected:
                c[0].setConnectedToMain()

    func isConnected(room: Room) -> bool:
        if self == room:
            return false
        for c in connected:
            if c[0] == room:
                return true
        return false

    func getConnectedRooms(rooms := [self]) -> Array:
        for rarray in connected:
            var room: Room = rarray[0]
            if not rooms.has(room):
                rooms.append(room)
                rooms = room.getConnectedRooms(rooms)
        return rooms

    func connectRoom(room: Room, a: Vector2, b: Vector2) -> void:
        print("Connect %s to %s" % [self, room])
        connected.append([room, a, b, false])
        room.connected.append([self, a, b, false])
        if isConnectedToMain && ! room.isConnectedToMain:
            room.setConnectedToMain()
        elif room.isConnectedToMain && ! isConnectedToMain:
            setConnectedToMain()

    func findEdges(map: Array):
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
                for y in range(ys[0], ys[1] + 1):
                    var v := Vector2(x, y)
                    if (
                        not edges.has(v)
                        && (
                            map[x - 1][y] == Tiles.WALL
                            || map[x + 1][y] == Tiles.WALL
                            || map[x][y - 1] == Tiles.WALL
                            || map[x][y + 1] == Tiles.WALL
                        )
                    ):
                        edges.append(v)
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

    func findClosest(rooms: Array, map: Array):
        """Currently, this find a close-ish room.
    The first round of judges distance by center. Probably should just
    compare all the points everywhere"""
        findEdges(map)
        var closestSq := 999999999999.0
        var closestRoom: Room
        var closestVector: Vector2 = Vector2(999999, 999999)
        var closestSelfVector: Vector2 = center
        for i in rooms.size():
            var room: Room = rooms[i]
            room.findEdges(map)
            if room == self:
                continue

                # connectRoom(closestRoom, closestSelfVector, closestVector)
            if isConnected(room):
                continue

                # connectRoom(closestRoom, closestSelfVector, closestVector)
            for sv in edges:
                for v in room.edges:
                    var tmp: float = sv.distance_squared_to(v)
                    if tmp <= closestSq:
                        closestRoom = room
                        closestSq = tmp
                        closestSelfVector = sv
                        closestVector = v
                    # connectRoom(closestRoom, closestSelfVector, closestVector)
        if closestRoom:
            return [closestRoom, closestSelfVector, closestVector]
        else:
            return []

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
    mapMutex = Mutex.new()
    optionsMutex = Mutex.new()
    exitMutex = Mutex.new()
    genSemaphore = Semaphore.new()
    thread = Thread.new()
    var ok := thread.start(self, "_generator_thread_body")
    if ok != OK:
        print("Thread not started")


func _generator_thread_body(_userData):
    while true:
        var ok := genSemaphore.wait()
        if ok != OK:
            print("Could not wait on semaphore")

            #  Do generator stuff here
        exitMutex.lock()
        var shouldExit := exitThread
        exitMutex.unlock()

        if shouldExit:
            break
            #  Do generator stuff here
        exitMutex.lock()
        exitMutex.unlock()
        optionsMutex.lock()
        requestStop = false
        _sendProgress(0, 100)
        var _action := genAction
        match _action:
            "cull":
                _cull()
            "smooth":
                _smooth()
            "createRooms":
                _createRooms()
            "regen":
                _regen()
            "connectRooms":
                _connectRooms()
        optionsMutex.unlock()
        _sendCompeleted()


func _doGenAction(v: String):
    optionsMutex.lock()
    genAction = v
    optionsMutex.unlock()
    if genSemaphore.post() != OK:
        print("Could not post semaphore")


func cull():
    _doGenAction("cull")


func smooth():
    _doGenAction("smooth")


func createRooms():
    _doGenAction("createRooms")


func regen():
    _doGenAction("regen")


func connectRooms():
    _doGenAction("connectRooms")


func _sendProgress(at: float, total: float):
    call_deferred("emit_signal", "progress", at * 100.0 / total)


func _sendCompeleted():
    call_deferred("emit_signal", "completed")


func clear() -> void:
    fillRatio = 0
    createMapAtTimeZero()


func mouseHighlight(p: Vector2):
    exitMutex.lock()
    working = true
    exitMutex.unlock()
    print("finding group")
# warning-ignore:narrowing_conversion
# warning-ignore:narrowing_conversion
    highlightTiles = findTileGroup(p.x / tileSize, p.y / tileSize, Tiles.DIRT)
    print(highlightTiles.size())
    exitMutex.lock()
    working = false
    exitMutex.unlock()


func drawDebugCanvas(node: Node2D):
	if makingARoom:
		var radius := 5.0
		if mouseRoomEdge:
			radius = mouseRoomCenter.distance_to(mouseRoomEdge)
		node.draw_circle(mouseRoomCenter, radius, Color.red)
	node.draw_circle(mousePointer, 15.0, Color.green)
	# Either get mutexes or make copies or rooms, highlights, etc
	var _highlights: Room
	var _list: Array
	if map.size() == mapWidth:
		_highlights = highlightTiles
		_list = listOfRooms
		if _highlights:
			_highlights.draw(Color("#00FF00" if working else "#0000FF"), tileSize, node)
		# mapMutex.unlock()

	if rooms:
		for r in rooms:
			node.draw_circle(
				Vector2(r.center.x * tileSize, r.center.y * tileSize), 32.0, Color.yellow
			)
	if _list:
		for i in _list.size():
			var r: Room = _list[i]
			r.drawConnections(Color.yellow, tileSize, node)

	if map.size() == mapWidth:
		for x in mapWidth:
			for y in mapHeight:
				var i: int = itemMap[x][y]
				if i:
					node.draw_circle(
						Vector2((x + 0.5) * tileSize, (y + 0.5) * tileSize),
						15,
						Color.seashell if i == Items.ENTRANCE else Color.sienna
					)
				if map[x][y] == Tiles.DIRT:
					var f := noise.get_noise_2d(x, y)
					var c := Color.white
					if f >= 0.15 && f < 0.45:
						c = Color.red
					elif f >= 0.45:
						c = Color.green
					node.draw_rect(
						Rect2(Vector2(x * tileSize, y * tileSize), Vector2(tileSize, tileSize)),
						c * f,
						true
					)
		# mapMutex.unlock()


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
            var r := MouseArea.new()
            r.center = c
            r.distance = d
            rooms.append(r)
            makeAMouseArea(c, Vector2(x - d, y))
            i += 1
        else:
            energy -= 1


func makeAMouseArea(center: Vector2, edge: Vector2) -> void:
	# Create Our MouseArea
	var maxDistSq := center.distance_squared_to(edge)
	var maxDist := center.distance_to(edge)
	var cx := round(center.x) as int
	var cy := round(center.y) as int
	var tl := Vector2(cx - maxDist, cy - maxDist)
	mapMutex.lock()
	for _y in range(tl.y, tl.y + maxDist * 2):
		for _x in range(tl.x, tl.x + maxDist * 2):
			var x: int = clamp(_x, 0, mapWidth - 1) as int
			var y: int = clamp(_y, 0, mapHeight - 1) as int
			var tile: int = map[x][y]
			var percent := (
				1.0
				- clamp(center.distance_squared_to(Vector2(x, y)) / maxDistSq, 0.0, 1.0)
			)
			if not useProbRooms || rnd.randf() < percent:
				tile = Tiles.DIRT
			map[x][y] = tile
	mapMutex.unlock()


func updateUI():
    call_deferred("emit_signal", "update_ui")


func update():
    call_deferred("emit_signal", "update_debug_canvas")


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

                    # iama wall, bro-ham
            else:
                # iama wall, bro-ham
                if walls < wallsLimit:
                    map[x][y] = Tiles.DIRT
    call_deferred("updateUI")


func countWallsInNeighborhood(x: int, y: int) -> int:
    var wallCount := 0
    for xx in range(x - 1, x + 2):
        for yy in range(y - 1, y + 2):
            if xx != x || yy != y:
                if map[xx][yy] == Tiles.WALL:
                    wallCount += 1
    return wallCount


func mapToTileMap(tileMap: TileMap, onlyDirt = false, dirtValue = Tiles.DIRT) -> void:
    """Probably should be in the world's code."""
    mapMutex.lock()
    tileMap.clear()
    for x in range(0, mapWidth):
        for y in range(0, mapHeight):
            var t : int = map[x][y]
            if onlyDirt && t == Tiles.DIRT:
                tileMap.set_cell(x, y, dirtValue)
            elif !onlyDirt:
                tileMap.set_cell(x, y, t)
    mapMutex.unlock()

func generateItemPlaces() -> void:
    pass


func walls_sort_small(a: Room, b: Room) -> bool:
    return a.size() < b.size()


func _cull() -> void:
    var total = mapWidth * mapHeight * 2
    var walls: Array = findGroups(Tiles.WALL, 0, total)
    print("Found %d wall groups" % walls.size())
    walls.sort_custom(self, "walls_sort_small")
    var i := 0
    mapMutex.lock()
    while i < walls.size():
        if requestStop:
            mapMutex.unlock()
            return
        if walls[0].size() < minWallArea:
            print(walls[0].size())
            # make all the walls in this tile group into dirt
            walls[0].setTile(map, Tiles.DIRT)
            walls.remove(0)
        else:
            break
    mapMutex.unlock()
    var dirts: Array = findGroups(Tiles.DIRT, mapWidth * mapHeight, total)
    print("Found %d dirt groups" % dirts.size())
    dirts.sort_custom(self, "walls_sort_small")
    i = 0
    mapMutex.lock()
    while i < dirts.size():
        if requestStop:
            mapMutex.unlock()
            return
        if dirts[0].size() < minRoomArea:
            print(dirts[0].size())
            # make all the walls in this tile group into dirt
            dirts[0].setTile(map, Tiles.WALL)
            dirts.remove(0)
        else:
            break
    listOfRooms = dirts
    mapMutex.unlock()
    call_deferred("mapToTileMap")
    call_deferred("update")


func findGroups(type: int, start: int, total: int) -> Array:
    var groups := []
    for y in range(mapHeight):
        _sendProgress(start, total)
        for x in range(mapWidth):
            start += 1
            var tile: int = map[x][y]
            if tile == type:
                # var v := Vector2(x,y)
                var inGroup := false
                for g in groups:
                    if g.isIn(x, y):
                        inGroup = true
                        break
                if ! inGroup:
                    var tiles: Room = findTileGroup(x, y, type)
                    groups.append(tiles)
    return groups


func queueIfOk(queue: Array, group: Room, x: int, y: int) -> void:
    var v := Vector2(x, y)
    if x >= 0 && x < mapWidth && y >= 0 && y < mapHeight && ! queue.has(v) && ! group.isIn(x, y):
        queue.append(v)


var runlimit = 250


func findTileGroup(x: int, y: int, type: int):
    var data := [Room.new(), [Vector2(x, y)]]
    var start := OS.get_ticks_msec()
    var elapsed := 0.0
    var i := 0
    while data[1].size():
        data = findRestOfGroup(data, type)
        i += 1
    if i > runlimit:
        i = 0
        # Resume execution the next frame.
        elapsed += OS.get_ticks_msec() - start
        highlightTiles = data[0]
        update()
        start = OS.get_ticks_msec()
    print("%f sec at run limit %d" % [elapsed / 1000.0, runlimit])
    highlightTiles = data[0].normalize()
    return data[0]


func findRestOfGroup(data: Array, type: int) -> Array:
    var group: Room = data[0]
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
	mapMutex.lock()
	listOfRooms = []
	highlightTiles = null
	if level_seed:
		rnd.seed = hash(level_seed)
	else:
		rnd.randomize()
	noise.seed = rnd.randi()
	noise.octaves = octaves
	noise.period = period
	noise.persistence = persistence
	map = []
	itemMap = []
	rooms = []
	time = 0
	map.resize(mapWidth)
	itemMap.resize(mapWidth)
	var _fillRatio := fillRatio if useRandomFill else 0
	for x in range(0, mapWidth):
		var tmap := []
		var titems := []
		tmap.resize(mapHeight)
		titems.resize(mapHeight)
		map[x] = tmap
		itemMap[x] = titems
		for y in range(0, mapHeight):
			var tile: int = Tiles.WALL
			if x > 0 && x < mapWidth - 1 && y > 0 && y < mapHeight - 1:
				var r = rnd.randi_range(0, 100)
				if r < _fillRatio:
					tile = Tiles.DIRT
				else:
					tile = Tiles.WALL
			tmap[y] = tile
			titems[y] = Items.NO_ITEM
	mapMutex.unlock()


func doAutoSmoothing():
    if autoSmooth:
        for _i in range(time, maxTime):
            timeAdvance()


func _connectRooms(forceConnect := false):
    mapMutex.lock()
    if listOfRooms.size() == 0:
        cull()
    print("_connectRooms room count %d" % listOfRooms.size())
    _sendProgress(0, listOfRooms.size())
    var mainRoom: Room = listOfRooms[listOfRooms.size() - 1]
    mainRoom.isMain = true
    mainRoom.isConnectedToMain = true

    print("found %d rooms" % listOfRooms.size())
    mapMutex.unlock()
    # if listOfRooms.size() > 1:
    # 	for roomIndex in range(0, listOfRooms.size() - 1):
    # 		var room: Room = listOfRooms[roomIndex]
    # 		var details = room.findClosest(listOfRooms)
    # 		room.connectRoom(details[0], details[1], details[2])

    # Make sure all rooms are connected
    mapMutex.lock()
    var groupMain := []
    var groupDisconnected := []
    if forceConnect:
        for r in listOfRooms:
            if groupMain.has(r) || groupDisconnected.has(r):
                continue
            if r.isConnectedToMain:
                groupMain.append(r)
            else:
                groupDisconnected.append(r)
    else:
        groupMain = listOfRooms
        groupDisconnected = listOfRooms
    print(
        (
            "number of groups disconnected %d group main %d force %s"
            % [groupDisconnected.size(), groupMain.size(), forceConnect]
        )
    )
    _sendProgress(groupMain.size(), listOfRooms.size())
    if groupDisconnected.size() == 0:
        # only one group, everything is connected
        mapMutex.unlock()
        call_deferred("update")
    else:
        # multiple groups. join the closest rooms
        # var cgroup: Array = groups[1]
        var c1: Room
        var d = 99999999999999
        var cdetails := []
        for r1 in groupMain:
            print("r1 %s" % r1)
            if cdetails.size() and not forceConnect:
                cdetails = []
            # if not forceConnect and r1.connected.size() > 0:
            # print("r1 is connected. Skipping")
            # continue
            for g2i in groupDisconnected.size():
                if requestStop:
                    mapMutex.unlock()
                    return
                var r2: Room = groupDisconnected[g2i]
                if r1 == r2:
                    print("r1 == r2. Skipping")
                    continue
                # if not forceConnect and r2.connected.size() > 0:
                # continue
                var details: Array = r1.findClosest(groupDisconnected, map)
                var tmp: float = details[1].distance_squared_to(details[2])
                if tmp < d:
                    cdetails = details
                    d = tmp
                    c1 = r1
                    # cgroup = g2
                    if not forceConnect:
                        c1.connectRoom(cdetails[0], cdetails[1], cdetails[2])
                        break
        if cdetails.size():
            c1.connectRoom(cdetails[0], cdetails[1], cdetails[2])
        mapMutex.unlock()
        _connectRooms(true)


func _carveTunnels():
    var connected := []
    for r in listOfRooms:
        for edge in r.connected:
            var vs := [edge[1], edge[2]]
            if not connected.has(vs):
                _carveTunnel(edge[1], edge[2])
                connected.append(vs)


func _carveTunnel(a: Vector2, b: Vector2):
    mapMutex.lock()
    var dx := abs(b.x - a.x)
    var dy := abs(b.y - a.y)
    var xs := sign(b.x - a.x)
    var ys := sign(b.y - a.y)
    if dx > dy:
        var y: float = a.y
        var r := ys * dy / dx
        for x in range(a.x, b.x, xs):
            var iy = floor(y) as int
            for iiy in range(iy - 1, iy + 2):
                map[x][clamp(iiy, 0, mapHeight)] = Tiles.DIRT
            y += r
    else:
        var x := a.x
        var r := xs * dx / dy
        for y in range(a.y, b.y, ys):
            var ix = floor(x) as int
            for iix in range(ix - 1, ix + 2):
                map[clamp(iix, 0, mapWidth)][y] = Tiles.DIRT
            x += r
    mapMutex.unlock()


# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
    print("_exit_tree")
    cleanup()


func cleanup():
    # Set exit condition to true.
    exitMutex.lock()
    exitThread = true  # Protect with Mutex.
    exitMutex.unlock()

    # Unblock by posting.
    genAction = "exit"
    var _ok := genSemaphore.post()

    # Wait until it exits.
    thread.wait_to_finish()


func _smooth():
    timeAdvance()


func _createRooms():
    createMapAtTimeZero()
    makeRooms()
    doAutoSmoothing()


func _getRandomRoomTile(room: Room) -> Vector2:
    print("_getRandomRoomTile")
    var out: Vector2
    while not out:
        var xs := room.regions.keys()
        var x := rnd.randi_range(xs[1], xs[-1])
        var regions: Array = room.regions[x]
        var ys: Array = regions[rnd.randi_range(0, regions.size())]
        print("ys %s %s %s" % [ys, typeof(ys), TYPE_ARRAY])
        var d = ys[1] - ys[0]
        print("d %s" % d)
        # print("x %s d %s" % [x, d])
        if d >= 3:
            print("d >= 3")
            var y := rnd.randi_range(ys[0], ys[1])
            out = Vector2(x, y)
    print("get random tile %s" % out)
    return out


func _placeEntranceAndExit():
	print("_placeEntranceAndExit")
	# TODO: Should at least make sure the entrance is not close to the exit.
	# TODO: May want to account for other items, if the exits are not placed first
	# TODO: May want to make sure higher tier items/enemies are not placed close to the entrance
	var entranceRoom: Room
	var exitRoom: Room
	if listOfRooms.size() == 1:
		entranceRoom = listOfRooms[0]
		exitRoom = listOfRooms[0]
	else:
		entranceRoom = listOfRooms[rnd.randi_range(0, listOfRooms.size())]
		while not exitRoom:
			var t: Room = listOfRooms[rnd.randi_range(0, listOfRooms.size())]
			if t != entranceRoom:
				exitRoom = t
	print(entranceRoom)
	print(exitRoom)
	var v: Vector2 = _getRandomRoomTile(entranceRoom)
	itemMap[v.x][v.y] = Items.ENTRANCE
	v = _getRandomRoomTile(exitRoom)
	itemMap[v.x][v.y] = Items.EXIT


func _regen():
    createMapAtTimeZero()
    if not requestStop and useRooms:
        makeRooms()
    if not requestStop:
        doAutoSmoothing()
    if not requestStop and doCulling:
        _cull()
    if not requestStop and doConnections:
        _connectRooms()
        if not requestStop:
            _carveTunnels()
            doAutoSmoothing()
        if not requestStop:
            _placeEntranceAndExit()
