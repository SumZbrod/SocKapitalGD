class_name AccountNode extends VBoxContainer

@onready var check_button: CheckButton = $CheckButton
@onready var label_name: Label = $LabelName
@onready var nine_patch_rect: NinePatchRect = $NinePatchRect
@onready var score_label: Label = $ScoreLabel
@onready var message_label: Label = $MessageLabel
signal change_select(value: bool)

var button_pressed: bool
var disabled: bool
var pid: int

func _ready() -> void:
	make_material_unique()

func make_material_unique():
	var nine_patch_rect_material = nine_patch_rect.get_material()
	if nine_patch_rect_material:
		var unique_material = material.duplicate(true)
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

func make_visible_personal_data():
	score_label.visible = true
	message_label.visible = true

func _on_check_button_toggled(toggled_on: bool) -> void:
	emit_signal("change_select", toggled_on)
	button_pressed = check_button.button_pressed
	disabled = check_button.disabled

func get_pid():
	return pid
