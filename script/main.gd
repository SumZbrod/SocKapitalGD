extends Control

@export var start_player_count := 2
@export var player_cost := 100
@onready var message_label: Label = $VBox/MessageLabel
@onready var input_field: LineEdit = $VBox/InputField
@onready var label_state: Label = $VoitintgBlock/LabelState
@onready var next_button: Button = $VBox/NextButton
@onready var h_slider: HSlider = $VBox/HSlider
@onready var voting_accs: HBoxContainer = $VoitintgBlock/VotingAccs
@onready var my_name: Label = $Account/MyName
@onready var my_ava: NinePatchRect = $Account/MyAva
@onready var my_score: Label = $Account/MyScore
@onready var my_result: Label = $Account/MyResult
@onready var account: VBoxContainer = $Account
const player_account = preload("res://scene/player.tscn")

enum {
	JOIN,
	REQUESTING,
	VOTING,
	GAMEEND,
}
var state := JOIN

const PORT: int = 8080
var SERVER_URL: String = "ws://127.0.0.1:" + str(PORT)

var players_data: Dictionary = {}  # {player_id: {'name':str, 'request_result':int, 'alive': bool 'ready': bool, 'balance': int, 'request': int, 'vote': [{player_id: int}]}}
var game_data: Dictionary = {'init_budget': 0}
var max_time := 1.
var time := 0.

func _ready() -> void:
	input_field.text_submitted.connect(_on_text_submitted)
	state = JOIN
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
		start_server()
	else:
		start_client()

func start_server() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT)
	if err != OK:
		push_error("Ошибка сервера: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Сервер на порту " + str(PORT))
	input_field.visible = false
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func start_client() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_client(SERVER_URL)
	if err != OK:
		push_error("Ошибка клиента: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Подключение...")
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_player_connected(id: int) -> void:
	if state == JOIN:
		var ava_id = players_data.size()
		players_data[id] = {'alive': true, 'ready': false, 'name': id, 'ava_id': ava_id, 'balance': 0, 'request': 0, 'request_result':0, 'vote': []}
		print("Подключился ID " + str(id) + " с информацией: " + str(players_data[id]))
		print(players_data)
	else:
		print("Игра уже началась")
		
func _on_player_disconnected(id: int) -> void:
	players_data.erase(id)  
	print("Отключился ID " + str(id))

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("Подключен! ID: " + str(my_id))

func _on_connection_failed() -> void:
	message_label.text = "Сервер недоступен"

func get_player_data() -> Dictionary:
	var res = {}
	res["h_slider_valuer"] = h_slider.value
	res["input_field_text"] = input_field.text
	return res

func _on_next_button_pressed() -> void:
	var player_data := get_player_data()
	update_game.rpc_id(1, multiplayer.get_unique_id(), player_data)

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_on_next_button_pressed()

@rpc("any_peer", "call_remote", "reliable")
func update_game(pl_id: int, player_data: Dictionary) -> void:
	if multiplayer.is_server():
		match state: 
			JOIN:
				_on_join(pl_id, player_data)
			REQUESTING:
				_on_requesting(pl_id, player_data)
			VOTING:
				_on_voting(pl_id)
			_:
				push_error("Uknown state: %s" % state)

func _on_join(pl_id: int, player_data: Dictionary) -> void:
	if pl_id in players_data:
		players_data[pl_id]['ready'] = !players_data[pl_id]['ready']
		players_data[pl_id]['name'] = player_data['input_field_text']
		var ready_players := 0
		for pl_data in players_data.values():
			if pl_data['ready']:
				ready_players += 1
		var update_date = {}
		var local_update_date = {}
		update_date['label_state'] = "К игре готовы: " + str(ready_players) + " / " + str(players_data.size())
		if players_data[pl_id]['ready']:
			local_update_date['next_button'] = "Готов"
		else:
			local_update_date['next_button'] = "Не готов"
		local_update_date["my_name"] = players_data[pl_id]['name']

		local_update_date["my_ava"] = get_ava_rect(players_data[pl_id]['ava_id']) 
		local_update_date["my_score"] = players_data[pl_id]['balance']
		update_player_data.rpc_id(pl_id, local_update_date)
		var new_acc = player_account.instantiate()
		var acc_info = {"name": players_data[pl_id]['name'], "ava_id": players_data[pl_id]['ava_id']}
		voting_accs.add_child(new_acc)
		new_acc.update(acc_info)
		update_all_player_screen(update_date)
		if check_all_alive_ready():
			change_state(REQUESTING)
		#TODO
		change_state(REQUESTING)
		
func get_ava_rect(_id:int) -> Rect2:
	var r = 341
	var x = _id % 3
	@warning_ignore("integer_division")
	var y = _id / 3
	return Rect2(r*x, r*y, r, r)

@rpc("any_peer", "call_remote", "reliable")
func update_player_data(update_date: Dictionary) -> void:
	for key in update_date:
		match key:
			"my_name":
				my_name.text = update_date[key]
			"my_score":
				my_score.text = str(int(update_date[key]))
			"my_ava":
				my_ava.region_rect = update_date[key]
			"my_result":
				my_result.text = update_date[key]
			"label_state":
				label_state.text = update_date[key]
			"next_button":
				next_button.text = update_date[key]
			"h_slider_max":
				h_slider.max_value = update_date[key]
			"h_slider_value":
				h_slider.value = update_date[key]
			"message_label":
				message_label.text = update_date[key]
			"slider_editable":
				h_slider.editable = update_date[key]
			"voting_vars":
				
			_:
				push_error("Uknown key: %s" % key)
	match state:
		JOIN:
			h_slider.visible = false
			next_button.visible = false
			account.visible = false
		REQUESTING:
			account.visible = true
			next_button.visible = true
			h_slider.visible = true
			input_field.visible = false
		VOTING:
			account.visible = true
			next_button.visible = true
			input_field.visible = false
		_:
			push_error("Uknown state: %s" % state)
			
func check_all_alive_ready() -> bool:
	for pl_id in players_data:
		if !players_data[pl_id]['ready'] and players_data[pl_id]['alive']:
			return false
	return true

func update_all_player_screen(update_date: Dictionary) -> void:
	for pl_id in players_data:
		update_player_data.rpc_id(pl_id, update_date)

func change_state(new_state):
	state = new_state
	update_players_state()
	for pid in players_data:
		players_data[pid]['ready'] = false
	var alive_count := 0
	for pid in players_data:
		if players_data[pid]['alive']:
			alive_count += 1
	if alive_count <= 1:
		state = GAMEEND
	
	match state:
		REQUESTING:
			_set_requesting(alive_count)
		VOTING:
			_set_voting()
		_:
			push_error("Uknown state: %s" % state)

func update_players_state():
	for pid in players_data:
		update_player_state.rpc_id(pid, state)

@rpc("any_peer", "call_remote", "reliable")
func update_player_state(_state):
	state = _state

func _set_requesting(alive_count: int):
	var update_date = {}
	var budget := alive_count * player_cost
	game_data['init_budget'] = budget
	update_date['label_state'] = "Бюджет: %d" % budget
	update_date['h_slider_max'] = budget
	update_date['h_slider_value'] = player_cost
	update_date['next_button'] = "Запросить"
	update_date['slider_editable'] = true
	update_date['message_label'] = "Ваш запрос: %d" % player_cost
	update_all_player_screen(update_date)
	
func _on_requesting(pl_id: int, player_data: Dictionary):
	if !multiplayer.is_server():
		return
	if pl_id in players_data:
		if players_data[pl_id]['ready']:
			return
		var update_player_date = {}
		players_data[pl_id]['ready'] = true
		for key in player_data:
			if key == "h_slider_valuer":
				players_data[pl_id]["request"] = player_data["h_slider_valuer"]
		update_player_date['slider_editable'] = false
		update_player_date['next_button'] = "Ваш запрос: %d" % players_data[pl_id]['request'] 
		update_player_data.rpc_id(pl_id, update_player_date)
		if check_all_alive_ready():
			change_state(VOTING)

func _on_h_slider_value_changed(value: float) -> void:
	var update_date = {}
	match state:
		REQUESTING:
			update_date['message_label'] = "Ваш запрос: %d" % int(value)
		VOTING:
			update_date['message_label'] = "На голосование вы поставили: %d" % int(value)
			
	update_player_data(update_date)

func get_player_property(pid: int, property_name: String):
	match property_name:
		'request':
			return get_tree().get_multiplayer().get_peer(pid).h_slider.value
		_:
			push_error("uncnown property name %s" % property_name)
			
func _set_voting():
	var init_budget = game_data['init_budget']
	var sum_request := 0
	var power_sum_request := 0.
	var inequality_degree := .5 + 2*randf()
	for pid in players_data:
		sum_request += players_data[pid]['request']
		power_sum_request += players_data[pid]['request'] ** inequality_degree
	var shrink_budget = min(init_budget, 2*init_budget - sum_request)
	shrink_budget = max(player_cost, abs(shrink_budget)) * (1 if shrink_budget > 0 else -1)
	print('shrink_budget ', shrink_budget)
	print('power_sum_request ', power_sum_request)
	for pid in players_data:
		if shrink_budget == init_budget:
			players_data[pid]['request_result'] = players_data[pid]['request']
		else:
			players_data[pid]['request_result'] = round((players_data[pid]['request']**inequality_degree) / power_sum_request * shrink_budget)
		players_data[pid]['balance'] += players_data[pid]['request_result']
	
	if shrink_budget <= 0:
		var max_minus := 0
		for pid in players_data:
			if max_minus > players_data[pid]['request_result']:
				max_minus = players_data[pid]['request_result']
		max_minus = 1 + abs(max_minus)
		print("субсидия равна: %d" % max_minus)
		for pid in players_data:
			players_data[pid]['balance'] += max_minus
			
	for pid in players_data:
		var new_player_date = {
			"my_result":  "Получили: " + str(int(players_data[pid]['request_result'])), 
			"label_state": "Выберите за кого голосовать",
			"my_score": players_data[pid]['balance'],
			"next_button": "Пропустить\nголосование",
			"slider_editable": true,
			"h_slider_max": players_data[pid]['balance'],
			"h_slider_value": 0,
		} 
		var voting_vars = []
		for sub_pid in players_data:
			if sub_pid != pid and players_data[sub_pid]['alive']:
				voting_vars.append(players_data[sub_pid]["ava_id"])
		new_player_date["voting_vars"] = voting_vars
		update_player_data.rpc_id(pid, new_player_date)
	print("players_data ", players_data)
	
func _on_voting(pl_id):
	return pl_id
