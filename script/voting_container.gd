class_name VotingContainerClass extends HBoxContainer

const player_account = preload("res://scene/player.tscn")
var acc_chooses = []
signal change_decition(pid:int)
#
#func _ready() -> void:
	#__test()
	#return
	#
func __test():
	var new_accs = [
		{"pid": 1, "name": "a", "ava_id": 1},
		{"pid": 12, "name": "b", "ava_id": 5},
		{"pid": 13, "name": "c", "ava_id": 8},
	]
	add_new_members(new_accs)

func add_new_members(data_list: Array):
	var childrens = get_children()
	for data in data_list:
		var skip_flag = false
		for child in childrens:
			if child.get_pid() == data['pid']:
				skip_flag = true
		if skip_flag:
			continue
		var new_acc: PlayerClass = player_account.instantiate()
		add_child(new_acc)
		new_acc.update(data)
		new_acc.toggled.connect(_on_chose_acc)
		acc_chooses.append(false)

func _on_chose_acc(toggled_on: bool):
	if toggled_on:
		var i := 0
		for acc in get_children():
			acc.button_pressed = acc_chooses[i] != acc.button_pressed
			acc_chooses[i] = acc.button_pressed
			i += 1
	change_decition.emit(get_choose())
	
func get_choose() -> int:
	for acc in get_children():
		if acc.button_pressed:
			return acc.get_pid()
	return 0
	
func show_voting(pid_variants: Array):
	visible = true
	for acc in get_children():
		if acc.get_pid() in pid_variants:
			acc.visible = true
			acc.disabled = false
		else:
			acc.disabled = true
			acc.visible = false
