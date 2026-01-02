class_name AccountNode extends VBoxContainer

@onready var label_name: Label = $LabelName
@onready var nine_patch_rect: NinePatchRect = $NinePatchRect
@onready var score_label: Label = $ScoreLabel
@onready var message_label: Label = $MessageLabel
@onready var role_label: Label = $RoleLabel

signal change_select(value: bool)

var button_pressed: bool
var disabled: bool = true
var pid: int
var deselected: bool = false

func _ready() -> void:
	make_material_unique()

func make_material_unique():
	var nine_patch_rect_material = nine_patch_rect.get_material()
	if nine_patch_rect_material:
		var unique_material = nine_patch_rect_material.duplicate(true)
		nine_patch_rect.set_material(unique_material)

func setup(player:PlayerClass):
	pid = player.get_pid()
	label_name.text = player.get_player_name()
	nine_patch_rect.region_rect = player.get_ava_rect()

func update(data):
	for key in data:
		match key:
			"name": 
				label_name.text = str(data[key])
			"score":
				score_label.text = str(data[key])
			"message":
				message_label.text = str(data[key])
			"role":
				role_label.text = str(data[key])

func make_visible_personal_data():
	score_label.visible = true
	message_label.visible = true

func get_pid():
	return pid

func set_ava_mode(value:int):
	var ava_material:ShaderMaterial = nine_patch_rect.get_material()
	ava_material.set_shader_parameter("mode", value)

func change_press_button(value):
	button_pressed = value
	set_ava_mode(int(button_pressed))

func _on_button_pressed() -> void:
	if !disabled:
		change_press_button(!button_pressed)
		emit_signal("change_select", button_pressed)
		deselected = false
		
func _on_button_mouse_entered() -> void:
	if !disabled and !button_pressed:
		set_ava_mode(3)

func _on_button_mouse_exited() -> void:
	if !disabled and !button_pressed:
		if deselected:
			set_ava_mode(2)
		else:
			set_ava_mode(0)

func reset() -> void:
	set_ava_mode(0)
	deselected = false

func deselectit() -> void:
	set_ava_mode(2)
	deselected = true
	 
