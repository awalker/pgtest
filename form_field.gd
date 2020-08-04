tool
extends HBoxContainer
class_name FormField

export (String) var label_text: String  # setget _set_label
var value: int = 0 setget _set_value, _get_value
signal value_changed(value)


func _ready():
	if $Label && label_text:
		$Label.text = label_text
	$txt.text = str(value)


func _set_label(v: String) -> void:
	label_text = v
	if $Label:
		$Label.text = v


func _set_value(v: int) -> void:
	value = v
	if $Label && label_text:
		$Label.text = label_text
	$txt.text = str(v)


func _get_value() -> int:
	value = int($txt.text)
	return value


func set_disabled(b: bool):
	$txt.disabled = b


func _on_txt_focus_exited():
	if not Engine.editor_hint:
		emit_signal("value_changed", self.value)


func _on_txt_focus_entered():
	$txt.select()
