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
onready var generator = $generator

var makingARoom := false
var mousePointer := Vector2.ZERO
var mouseRoomCenter: Vector2
var mouseRoomEdge: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mapCameraUpdated()
	updateUI()
	# _on_regen_pressed()


func mapCameraUpdated() -> void:
	var w = (mapWidth) * tileSize
	var h = (mapHeight) * tileSize
	mapCamera.position = Vector2(w / 2, h / 2)
	var zx = w / (get_viewport_rect().size.x)
	var zy = h / (get_viewport_rect().size.y)
	var z = max(zx, zy)
	mapCamera.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_ui"):
		var item := $CanvasLayer/UI
		item.visible = ! item.visible
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	var _working := working

	if _working:
		return
	if event is InputEventMouseMotion:
		mousePointer = get_global_mouse_position()
		update()
	if ! _working && Input.is_mouse_button_pressed(2):
		var p = get_global_mouse_position()
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
	generator.drawDebugCanvas(self)


func updateUI() -> void:
	$CanvasLayer/h/Time.text = "Time: " + str(generator.time)
	$"CanvasLayer/UI/vbox/Fill Ratio".value = generator.fillRatio
	var asBtn: CheckBox = $CanvasLayer/UI/vbox/buttonBox/autosmooth
	asBtn.pressed = generator.autoSmooth
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


func updateGeneratorOptions():
	pass


func _on_smooth_pressed():
	updateGeneratorOptions()
	generator.smooth()


func _on_createRooms_pressed():
	updateGeneratorOptions()
	generator.createRooms()


func _on_regen_pressed():
	updateGeneratorOptions()
	generator.regen()


func _on_autosmooth_toggled(button_pressed):
	generator.autoSmooth = button_pressed


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
	generator.cull()


func _on_connectRooms_pressed():
	generator.connectRooms()


func _on_seed_value_changed(value):
	if value:
		level_seed = value
	else:
		level_seed = ""


func _on_generator_completed():
	working = false
	generator.mapToTileMap(tileMap)
	update()
	updateUI()


func _on_generator_progress(_progress):
	working = true


func _on_generator_update_debug_canvas():
	update()


func _on_generator_update_ui():
	updateUI()
