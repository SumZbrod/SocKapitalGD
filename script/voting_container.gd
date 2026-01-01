class_name VotingContainerNode extends HBoxContainer

const account_scn = preload("res://scene/account.tscn")
var acc_chooses = []
signal change_decition(pid:int)

func _ready() -> void:
	#__test()
	return

func __test():
	var new_accs = [
		{"pid": 1, "name": "a", "ava_id": 1},
		{"pid": 12, "name": "b", "ava_id": 5},
		{"pid": 13, "name": "c", "ava_id": 8},
		{"pid": 2, "name": "z", "ava_id": 2},
		{"pid": 22, "name": "x", "ava_id": 6},
		{"pid": 23, "name": "y", "ava_id": 7},
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
		var new_acc: AccountNode = account_scn.instantiate()
		add_child(new_acc)
		var player = PlayerClass.new(data['pid'], data['name'], data['ava_id'])
		new_acc.setup(player)
		new_acc.change_select.connect(_on_chose_acc)
		acc_chooses.append(false)

func reset_accs():
	var i := 0
	for acc in get_children():
		if acc_chooses[i]:
			acc_chooses[i] = false
		acc.reset()
		i += 1

func disable_accs():
	var i := 0
	for acc in get_children():
		if acc_chooses[i]:
			acc_chooses[i] = false
		acc.reset()
		acc.disabled = true
		i += 1

func _on_chose_acc(toggled_on: bool):
	if toggled_on:
		var i := 0
		for acc in get_children():
			acc.change_press_button(acc_chooses[i] != acc.button_pressed)
			acc_chooses[i] = acc.button_pressed
			if !acc_chooses[i]:
				acc.deselectit()
			i += 1
	else:
		reset_accs()
		
	change_decition.emit(get_choose())
	
func get_choose() -> int:
	for acc in get_children():
		if acc.button_pressed:
			return acc.get_pid()
	return 0
	
func show_voting(pid_variants: Array):
	reset_accs()
	visible = true
	for acc in get_children():
		if acc.get_pid() in pid_variants:
			acc.visible = true
			acc.disabled = false
		else:
			acc.disabled = true
			acc.visible = false

func clear_selaction():
	var i := 0
	for acc in get_children():
		acc_chooses[i] = false
		acc.button_pressed = false
