extends Node2D
class_name CaveWorld

export var level_seed: String
export (int) var mapWidth := 256
export (int) var mapHeight := 240
export (int) var tileSize := 16
export (int) var fillRatio := 40
export (int) var maxTime := 2
export (int) var wallsLimit := 4
export (int) var minRoomArea := 75
export (int) var minWallArea := 30
export (Vector2) var roomCountRange := Vector2(4, 10)
export (Vector2) var roomSizeRange := Vector2(15, 50)
const Player = preload("res://Player.gd")

var autoSmooth := true

var rooms := []

var working := false
var playMode := false

onready var tileMap: TileMap = $TileMap
onready var mapCamera: Camera2D = $mapCamera
onready var generator = $generator
onready var progressBar = $CanvasLayer/Working/VBoxContainer/ProgressBar
onready var debugDrawing = $CanvasLayer/UI/vbox/buttonBox/debugDrawing

var makingARoom := false
var mousePointer := Vector2.ZERO
var mouseRoomCenter: Vector2
var mouseRoomEdge: Vector2
onready var player: Player = $Player


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mapCameraUpdated()
	# playerCameraUpdated()
	updateUI()
	# _on_regen_pressed()


func setUIDisabled(b: bool):
	var btns := [
		$CanvasLayer/UI/vbox/buttonBox/regen,
		$CanvasLayer/UI/vbox/buttonBox/useRooms,
		$CanvasLayer/UI/vbox/buttonBox/useProbRooms,
		$CanvasLayer/UI/vbox/buttonBox/useRandomFill,
		$CanvasLayer/UI/vbox/buttonBox/doCullings,
		$CanvasLayer/UI/vbox/buttonBox/doConnections,
		$CanvasLayer/UI/vbox/buttonBox/autosmooth,
	]
	var forms := [
		$CanvasLayer/UI/vbox/seed,
		$"CanvasLayer/UI/vbox/Map W",
		$"CanvasLayer/UI/vbox/Map H",
		$"CanvasLayer/UI/vbox/Fill Ratio",
		$"CanvasLayer/UI/vbox/Wall Limit",
		$"CanvasLayer/UI/vbox/Min Wall",
		$"CanvasLayer/UI/vbox/Min Room Area",
		$"CanvasLayer/UI/vbox/Min Rooms",
		$"CanvasLayer/UI/vbox/Min Room Size",
		$"CanvasLayer/UI/vbox/Max Room Size",
		$"CanvasLayer/UI/vbox/Max Rooms"
	]
	for btn in btns:
		btn.disabled = b
	for f in forms:
		f.get_node("txt").editable = ! b


func mapCameraUpdated() -> void:
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w / 2, h / 2)
	var zx = w / (get_viewport_rect().size.x)
	var zy = h / (get_viewport_rect().size.y)
	var z = max(zx, zy)
	mapCamera.zoom = Vector2(z, z)


func playerCameraUpdated() -> void:
	var pc: Camera2D = $Player/Camera2d
	var zx = (get_viewport_rect().size.x) / 16
	var zy = (get_viewport_rect().size.y) / 16
	var z = max(zx, zy)
	pc.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	var item := $CanvasLayer/UI
	if ! playMode && Input.is_action_just_pressed("toggle_ui"):
		item.visible = ! item.visible
	if Input.is_action_just_pressed("ui_cancel"):
		if playMode:
			item.visible = true
			playMode = false
			player.setActive(false)
			mapCamera.current = true
			return
		else:
			get_tree().quit()

	var _working := working

	if _working:
		return
	if playMode:
		return

	if event is InputEventMouseMotion:
		generator.mousePointer = get_global_mouse_position()
		update()
	if ! _working && Input.is_mouse_button_pressed(2):
		# var p = get_global_mouse_position()
		print("finding group")
		# highlightTiles = findTileGroup(p.x / tileSize, p.y / tileSize, Tiles.DIRT)
		# print(highlightTiles.size())
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
			generator.makeAMouseArea(mouseRoomCenter / tileSize, mouseRoomEdge / tileSize)
			generator.mapToTileMap(tileMap)
		update()


onready var workingUI = $CanvasLayer/Working


func _process(_delta):
	# exitMutex.lock()
	var _working := working  # read-only copy, should not need a mutex
	# exitMutex.unlock()
	if _working != workingUI.visible:
		print('Change working ui')
		workingUI.visible = _working


func _draw():
	if debugDrawing.pressed:
		generator.drawDebugCanvas(self)


func _physics_process(delta):
	if playMode:
		var input_vector = Vector2.ZERO
		input_vector.x = (
			Input.get_action_strength("ui_right")
			- Input.get_action_strength("ui_left")
		)
		input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_vector = input_vector.normalized()
		player.playerInput(input_vector, delta)


func updateUI() -> void:
	generator.tileSize = tileSize
	$CanvasLayer/h/Time.text = "Time: " + str(generator.time)
	$"CanvasLayer/UI/vbox/Fill Ratio".value = generator.fillRatio
	var asBtn: CheckBox = $CanvasLayer/UI/vbox/buttonBox/autosmooth
	asBtn.pressed = generator.autoSmooth
	var btn: CheckBox = $CanvasLayer/UI/vbox/buttonBox/useRooms
	btn.pressed = generator.useRooms
	btn = $CanvasLayer/UI/vbox/buttonBox/useProbRooms
	btn.pressed = generator.useProbRooms
	btn = $CanvasLayer/UI/vbox/buttonBox/useRandomFill
	btn.pressed = generator.useRandomFill
	btn = $CanvasLayer/UI/vbox/buttonBox/doCullings
	btn.pressed = generator.doCulling
	btn = $CanvasLayer/UI/vbox/buttonBox/doConnections
	btn.pressed = generator.doConnections
	$"CanvasLayer/UI/vbox/Wall Limit".visible = generator.useRandomFill
	$"CanvasLayer/UI/vbox/Fill Ratio".visible = generator.useRandomFill
	$"CanvasLayer/UI/vbox/Min Wall".visible = generator.doCulling
	$"CanvasLayer/UI/vbox/Min Room Area".visible = generator.doCulling
	$"CanvasLayer/UI/vbox/Min Rooms".visible = generator.useRooms
	$"CanvasLayer/UI/vbox/Max Rooms".visible = generator.useRooms
	$"CanvasLayer/UI/vbox/Min Room Size".visible = generator.useRooms
	$"CanvasLayer/UI/vbox/Max Room Size".visible = generator.useRooms

	$"CanvasLayer/UI/vbox/Map H".value = generator.mapHeight
	$"CanvasLayer/UI/vbox/Map W".value = generator.mapWidth
	$"CanvasLayer/UI/vbox/Wall Limit".value = generator.wallsLimit
	$"CanvasLayer/UI/vbox/Min Wall".value = generator.minWallArea
	$"CanvasLayer/UI/vbox/Min Room Area".value = generator.minRoomArea
	$"CanvasLayer/UI/vbox/Min Rooms".value = generator.roomCountRange.x as int
	$"CanvasLayer/UI/vbox/Max Rooms".value = generator.roomCountRange.y as int
	$"CanvasLayer/UI/vbox/Min Room Size".value = generator.roomSizeRange.x as int
	$"CanvasLayer/UI/vbox/Max Room Size".value = generator.roomSizeRange.y as int
	$CanvasLayer/UI/vbox/seed.value = generator.level_seed
	fillRatio = generator.fillRatio
	autoSmooth = generator.autoSmooth
	mapHeight = generator.mapHeight
	mapWidth = generator.mapWidth
	wallsLimit = generator.wallsLimit
	minWallArea = generator.minWallArea
	minRoomArea = generator.minRoomArea
	roomCountRange = generator.roomCountRange
	roomSizeRange = generator.roomSizeRange
	level_seed = generator.level_seed


func updateGeneratorOptions():
	generator.fillRatio = fillRatio
	generator.autoSmooth = autoSmooth
	generator.mapHeight = mapHeight
	generator.mapWidth = mapWidth
	generator.wallsLimit = wallsLimit
	generator.minWallArea = minWallArea
	generator.minRoomArea = minRoomArea
	generator.roomCountRange = roomCountRange
	generator.roomSizeRange = roomSizeRange
	generator.level_seed = level_seed


func _on_regen_pressed():
	debugDrawing.pressed = false
	updateGeneratorOptions()
	generator.regen()


func _on_autosmooth_toggled(button_pressed):
	generator.autoSmooth = button_pressed
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


func _on_seed_value_changed(value):
	if value:
		level_seed = value
	else:
		level_seed = ""


func _on_generator_completed():
	setUIDisabled(false)
	working = false
	generator.mapToTileMap(tileMap, false, 0)
	tileMap.update_bitmask_region()
	tileMap.update_dirty_quadrants()
	update()
	updateUI()
	mapCameraUpdated()


func _on_generator_progress(progress):
	if ! working:
		setUIDisabled(true)
	working = true
	progressBar.value = progress


func _on_generator_update_debug_canvas():
	update()


func _on_generator_update_ui():
	updateUI()


func _on_useRooms_toggled(button_pressed):
	generator.useRooms = button_pressed
	updateUI()


func _on_useProbRooms_toggled(button_pressed):
	generator.useProbRooms = button_pressed
	updateUI()


func _on_doCullings_toggled(button_pressed):
	generator.doCulling = button_pressed
	updateUI()


func _on_doConnections_toggled(button_pressed):
	generator.doConnections = button_pressed
	updateUI()


func _on_useRandomFill_toggled(button_pressed):
	generator.useRandomFill = button_pressed
	updateUI()


func _on_debugDrawing_pressed():
	update()


func _on_ToolButton_pressed():
	generator.requestStop = true


func _on_playButton_pressed():
	$CanvasLayer/UI.visible = false
	print(generator.entrance)
	player.position = generator.entrance * tileSize
	player.setActive(true)
	mapCamera.current = false
	playMode = true
