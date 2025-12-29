class_name PlayerClass extends CheckButton
#@onready var label_name: Label = $Name
#@onready var nine_patch_rect: NinePatchRect = $LabelName
@onready var nine_patch_rect: NinePatchRect = $Account/NinePatchRect
@onready var label_name: Label = $Account/LabelName
var pid : int
var alive := true 
var ready_state := false 
var player_name: String
var ava_id: int
var balance := 0 
var request := 0 
var request_result := 0 
var vote := {}
var place := 0



func update(data: Dictionary):
	var r = 341
	var x = data['ava_id'] % 3
	var y = data['ava_id'] / 3
	nine_patch_rect.region_rect = Rect2(r*x, r*y, r, r)
	label_name.text = str(data['name'])
	pid = data['pid']

func get_pid():
	return pid
#
#func _ready() -> void:
	#return
	#__test()
	

func __test():
	update({'name': 'test', 'ava_id': 7})
