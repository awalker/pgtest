tool
extends HBoxContainer
class_name TextField

export(String) var label_text:String# setget _set_label 
var value:String = "" setget _set_value, _get_value

signal value_changed(value)


func _ready():
	if $Label && label_text:
		$Label.text = label_text;
	$txt.text = str(value)

func _set_label(v: String) -> void:
	label_text = v
	if $Label:
		$Label.text = v

func _set_value(v: String) -> void:
	value = v
	if $Label && label_text:
		$Label.text = label_text;
	$txt.text = v

func _get_value() -> String:
	value = $txt.text
	return value

func _on_txt_focus_exited():
	if not Engine.editor_hint:
		emit_signal("value_changed", self.value)
