extends Control

@export var start_player_count := 5
@export var player_cost := 100
@onready var message_label: Label = $VBox/MessageLabel
@onready var input_field: LineEdit = $VBox/InputField
@onready var next_button: Button = $VBox/NextButton
@onready var h_slider: HSlider = $VBox/HSlider
@onready var my_name: Label = $Account/MyName
@onready var my_ava: NinePatchRect = $Account/MyAva
@onready var my_score: Label = $Account/MyScore
@onready var my_result: Label = $Account/MyResult
@onready var account: VBoxContainer = $Account
@onready var history_log: TextEdit = $HistoryLog
@onready var ping_timer: Timer = $PingTimer

@onready var label_state: Label = $UpperBlock/LabelState
@onready var voting_container: VotingContainerClass = $UpperBlock/VotingContainer
@onready var state_timer: Timer = $StateTimer
var new_state
var game_history := ''
var peer := WebSocketMultiplayerPeer.new()

enum {
	JOIN,
	REQUESTING,
	VOTING,
	ELIMINATING,
	GAMEEND,
}
var state := JOIN

var players_data: Dictionary = {}  # {player_id: {'place': int, 'name':str, 'request_result':int, 'alive': bool 'ready': bool, 'balance': int, 'request': int, 'vote': {player_id: int}}}
var offline_players := {};
var game_data: Dictionary = {'init_budget': 0, 'voting': {}, 'vote_winner': {}}
var ava_id_shift := randi() % 9
var ava_id_step:int = [1, 2, 4, 5, 7, 8].pick_random()
var player_codes = {}

const PORT: int = 8080
var SERVER_URL: String

func _process(_delta):
	if peer:
		peer.poll()

func _ready() -> void:
	if OS.has_feature("web"):
		SERVER_URL = "wss://soc-kapital.ru/ws/"  # Обязательно wss и путь /ws/
	else:
		SERVER_URL = "ws://127.0.0.1:" + str(PORT)
	var args = OS.get_cmdline_args()
	
	for arg in args:
		arg = arg as String
		if arg.begins_with(">"):
			arg = arg.right(-1)
			var players_names = arg.split(" ")
			for pl_name in players_names:
				var code = randi() % 1_0000
				player_codes[str(code)] = {'name': pl_name, 'not_used': true}
				print("%s %d" % [pl_name, code])
	if !player_codes:
		var names = "ABCDEXYZW".split()
		for i in range(start_player_count):
			player_codes[str(i)] = {'name': names[i], 'not_used': true}
	start_player_count = player_codes.size()
	voting_container.change_decition.connect(_on_change_voting)
	input_field.text_submitted.connect(_on_text_submitted)
	state = JOIN
	
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
		start_server()
	else:
		start_client()
	
func start_server() -> void:
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
	var err: Error = peer.create_client(SERVER_URL)
	if err != OK:
		push_error("Ошибка клиента: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Подключение...")
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_player_connected(pid: int) -> void:
	_server_restore_screen(pid)

func _on_player_disconnected(id: int) -> void:
	if id in players_data:
		offline_players[players_data[id]['peer_addres']] = players_data[id]
		players_data.erase(id)  
	print("Отключился ID " + str(id))

func _on_connected_to_server() -> void:
	var pid = multiplayer.get_unique_id()
	_server_restore_screen(pid)
	print("Подключен! ID: " + str(pid))

@rpc("any_peer", "call_remote", "reliable")
func _server_restore_screen(pid: int):
	if !multiplayer.is_server():
		return
	var peer_addres = multiplayer.multiplayer_peer.get_peer_address(pid)
	if peer_addres in offline_players:
		players_data[pid] = offline_players[peer_addres]
		players_data[pid]['ready'] = true
		offline_players.erase(peer_addres)

func _on_connection_failed() -> void:
	message_label.text = "Сервер недоступен"

@rpc("any_peer", "call_remote", "reliable")
func _server_create_new_player(id: int, code_text: String):
	if !multiplayer.is_server():
		return
	if code_text in player_codes:
		if player_codes[code_text]['not_used']:
			var ava_id = (ava_id_shift + ava_id_step*players_data.size()) % 9
			var peer_addres = multiplayer.multiplayer_peer.get_peer_address(id)
			players_data[id] = {'peer_addres': peer_addres, 'alive': true, 'ready': false, 'name': player_codes[code_text]['name'], 'ava_id': ava_id, 'balance': 0, 'request': 0, 'request_result':0, 'vote': {}, 'place': 0}
		else:
			var update_date = {
				"message_label" : "Этот код уже использован"
			}
			_client_change_screen_data.rpc_id(id, update_date)
	else:
		var update_date = {
				"message_label" : "Неправильный код"
		}
		_client_change_screen_data.rpc_id(id, update_date)
		
func get_player_screen_data() -> Dictionary:
	var res = {
		"h_slider_value": h_slider.value,
		"input_field_text": input_field.text,
		"vote_pid": voting_container.get_choose(),
	}
	return res

func _on_next_button_pressed() -> void:
	var player_data := get_player_screen_data()
	_server_update_game.rpc_id(1, multiplayer.get_unique_id(), player_data)
	
func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if state != JOIN:
		return
	_server_create_new_player.rpc_id(1, multiplayer.get_unique_id(), text)
	_on_next_button_pressed()

@rpc("any_peer", "call_remote", "reliable")
func _server_update_game(pid: int, player_screen_data: Dictionary) -> void:
	if !multiplayer.is_server():
		push_warning("[_server_update_game] not server")
		return
	if pid not in players_data:
		push_warning("[_server_update_game] pid not in players_data")
		push_warning("[_server_update_game] %s" % str(players_data))
		return
	if players_data[pid]['ready']: 
		push_warning("[_server_update_game] already ready")
		return
	if !players_data[pid]['alive']:
		push_warning("[_server_update_game] player died")
		return
	match state: 
		JOIN:
			_server_update_game_on_join(pid, player_screen_data)
		REQUESTING:
			_server_update_game_on_requesting(pid, player_screen_data)
		VOTING:
			_server_update_game_on_voting(pid, player_screen_data)
		_:
			push_warning("[update_game] Uknown state: %s" % state)
	_client_update_submit_screen.rpc_id(pid, players_data[pid])
	
@rpc("any_peer", "call_remote", "reliable")
func _client_update_submit_screen(player_data):
	match state: 
		JOIN:
			_client_update_submit_screen_on_join(player_data)
		REQUESTING:
			_client_update_submit_screen_on_requesting(player_data)
		VOTING:
			_client_update_submit_screen_on_voting(player_data)
		_:
			push_warning("[update_my_screen] Uknown state: %s" % state)

func get_accs_list():
	var new_accs = []
	for sub_pid in players_data:
		var new_acc = {
			'pid' = sub_pid,
			'ava_id' = players_data[sub_pid]['ava_id'],
			'name' = players_data[sub_pid]['name'],
		}
		new_accs.append(new_acc)
	return new_accs

## Вызывается после нажатия next_button или ввода имени
## Должен обновлять имя и обновлять VotingContaine
## Проверяет что игру можно начинать
## Не даёт повторного выполнения
func _server_update_game_on_join(pid: int, _player_data: Dictionary) -> void:
	# Обновление инфы об игроке
	players_data[pid]['ready'] = true
	
	# Обновление данных экрана игроков
	var ready_alive_players := get_alive_ready_count()
	var update_date = {
		'label_state': "К игре готовы: %d / %d" % [ready_alive_players, start_player_count],
		'new_accs': get_accs_list(),
	}
	_server_update_alive_client_screen_data(update_date)

	# Проверка готовности к игре
	if check_all_alive_ready() and players_data.size() == start_player_count:
		_server_set_state_aside(REQUESTING)

func _client_update_submit_screen_on_join(player_data: Dictionary):
	input_field.editable = false
	input_field.visible = false
	next_button.visible = true
	next_button.disabled = true
	
	var r = 341
	var x = player_data['ava_id'] % 3
	@warning_ignore("integer_division")
	var y = player_data['ava_id'] / 3
	var ava_rect = Rect2(r*x, r*y, r, r)
		
	var update_data = {
		'next_button': "Готов",
		"my_name": player_data['name'],
		"my_ava": ava_rect,
		"my_score": str(int(player_data['balance'])),
	}
	_client_change_screen_data(update_data)

@rpc("any_peer", "call_remote", "reliable")
## Меняет информацию содержащиюся на экране
func _client_change_screen_data(update_date: Dictionary) -> void:
	for key in update_date:
		match key:
			"my_name":
				my_name.text = update_date[key]
			"my_score":
				my_score.text = update_date[key]
			"my_ava":
				my_ava.region_rect = update_date[key]
			"my_result":
				my_result.text = update_date[key]
			"label_state":
				label_state.text = update_date[key]
			"next_button":
				next_button.text = update_date[key]
			"next_button_disabled":
				next_button.disabled = update_date[key]
			"h_slider_max":
				h_slider.max_value = update_date[key]
			"h_slider_value":
				h_slider.value = update_date[key]
			"message_label":
				message_label.text = update_date[key]
			"slider_editable":
				h_slider.editable = update_date[key]
			"new_accs":
				voting_container.add_new_members(update_date[key])
			"voting_vars":
				voting_container.show_voting(update_date[key])
			"clear_selaction":
				voting_container.clear_selaction()
			"history_log":
				history_log.visible = true
				history_log.text = update_date[key]
			_:
				push_warning("[change_screen_data] Uknown key: %s" % key)

# Меняет отображаемые элеементы на экране 
func _client_change_screen_properties() -> void:
	match state:
		JOIN:
			next_button.disabled = false
			h_slider.visible = false
			next_button.visible = false
			account.visible = false
		REQUESTING:
			next_button.disabled = false
			account.visible = true
			next_button.visible = true
			h_slider.visible = true
			input_field.visible = false
			voting_container.visible = false
		VOTING:
			next_button.disabled = false
			next_button.visible = true
			voting_container.visible = true
			account.visible = true
			input_field.visible = false
			h_slider.visible = true
		ELIMINATING:
			next_button.disabled = false
			voting_container.visible = true
			h_slider.visible = false
			next_button.visible = false
		_:
			push_warning("[change_screen_properties] Uknown state: %s" % state)

func get_alive_ready_count() -> int:
	var res := 0
	for pl_id in players_data:
		if players_data[pl_id]['ready'] and players_data[pl_id]['alive']:
			res += 1
	return res

func get_alive_count() -> int:
	var res := 0
	for pl_id in players_data:
		if players_data[pl_id]['alive']:
			res += 1
	return res

func check_all_alive_ready() -> bool:
	for pl_id in players_data:
		if !players_data[pl_id]['ready'] and players_data[pl_id]['alive']:
			return false
	return true

func _server_update_alive_client_screen_data(update_date: Dictionary) -> void:
	for pid in players_data:
		if players_data[pid]['alive']:
			_client_change_screen_data.rpc_id(pid, update_date)

func _server_update_all_client_screen_data(update_date: Dictionary) -> void:
	for pid in players_data:
		_client_change_screen_data.rpc_id(pid, update_date)
		
func _server_change_state():
	send_dead_log()
	state = new_state
	var alive_count = get_alive_count()
	if alive_count <= 1:
		state = GAMEEND
		
	for pid in players_data:
		players_data[pid]['ready'] = false
	
	match state:
		REQUESTING:
			_server_set_requesting_state(alive_count)
		VOTING:
			_server_set_voting_state()
		ELIMINATING:
			_server_set_eliminating_state()
		GAMEEND:
			_server_set_gameend_state()
		_:
			push_warning("[_server_change_state] Uknown state: %s" % state)
	_server_update_alive_players_state()
	
func _server_update_alive_players_state():
	for pid in players_data:
		if players_data[pid]['alive']:
			_client_update_player_state.rpc_id(pid, state)

@rpc("any_peer", "call_remote", "reliable")
func _client_update_player_state(_state):
	if state != _state:
		state = _state
		_client_change_screen_properties()

func reset_game_data():
	game_data = {'init_budget': 0, 'voting': {}, "vote_winner": {}}

func reset_player_request_vote():
	for pid in players_data:
		players_data[pid]['request'] = 0
		players_data[pid]['request_result'] = 0
		players_data[pid]['vote'] = {}
		
## Подготавливает информацию обигроках к началу нового раунда
## Отправляет новые данные об экранах универсальную игроков
func _server_set_requesting_state(alive_count: int):
	reset_player_request_vote()
	reset_game_data()
	
	var budget := alive_count * player_cost
	game_data['init_budget'] = budget
	var init_screen_data = {
		'label_state': "Бюджет: %d" % budget,
		'h_slider_max': budget,
		'h_slider_value': player_cost,
		'next_button': "Запросить",
		'slider_editable': true,
		'message_label': "Ваш запрос: %d" % player_cost,
	}
	_server_update_alive_client_screen_data(init_screen_data)

## Добавляет информацию об запросе игрока на получение баллов
func _server_update_game_on_requesting(pid: int, player_data: Dictionary):
	players_data[pid]['ready'] = true
	players_data[pid]["request"] = player_data["h_slider_value"]

	if check_all_alive_ready():
		calc_request_result()
		_server_set_state_aside(VOTING)

func _client_update_submit_screen_on_requesting(player_data):
	var update_data = {
		'slider_editable': false,
		'next_button': "Ваш запрос: %d" % player_data['request'],
		'next_button_disabled': true,
	}
	_client_change_screen_data(update_data)

func _on_h_slider_value_changed(value: float) -> void:
	var update_date = {}
	match state:
		REQUESTING:
			update_date['message_label'] = "Ваш запрос: %d" % int(value)
		VOTING:
			update_date['message_label'] = "На голосование вы поставили: %d" % int(value)
			_on_change_voting(voting_container.get_choose())
	_client_change_screen_data(update_date)

func calc_request_result():
	var init_budget = game_data['init_budget']
	var sum_request := 0
	var power_sum_request := 0.
	var inequality_degree := .5 + 2*randf()
	for pid in players_data:
		sum_request += players_data[pid]['request']
		power_sum_request += players_data[pid]['request'] ** inequality_degree
	
	var shrink_budget = min(init_budget, 2*init_budget - sum_request)
	shrink_budget = max(player_cost, abs(shrink_budget)) * (1 if shrink_budget > 0 else -1)
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
		game_history += "субсидия равна: %d\n" % max_minus
		
		for pid in players_data:
			players_data[pid]['balance'] += max_minus
	
func _server_set_voting_state():
	for pid in players_data:
		if !players_data[pid]['alive']:
			continue
		var voting_vars = []
		for sub_pid in players_data:
			if sub_pid != pid and players_data[sub_pid]['alive']:
				voting_vars.append(sub_pid)
		var new_player_date = {
			"my_result":  "Запросили: " + str(int(players_data[pid]['request'])) + "\nПолучили: " + str(int(players_data[pid]['request_result'])), 
			"label_state": "Выберите за кого голосовать",
			"my_score": str(int(players_data[pid]['balance'])),
			"next_button": "Пропустить\nголосование",
			"slider_editable": true,
			"h_slider_max": players_data[pid]['balance'],
			"h_slider_value": 0,
			"voting_vars": voting_vars,
		} 
		players_data[pid]['request'] = 0
		players_data[pid]['request_result'] = 0
		players_data[pid]['vote'] = {}
		_client_change_screen_data.rpc_id(pid, new_player_date)
	game_data["voting"] = {}
	game_data["vote_winner"] = {}
	
func _server_update_game_on_voting(pid: int, player_data: Dictionary) -> void:
	var vote_pid = player_data['vote_pid'] 
	var vote_value = player_data["h_slider_value"]
	if vote_pid > 0 and vote_value > 0:
		players_data[pid]['vote'] = {players_data[vote_pid]['name']: vote_value}
		players_data[pid]['balance'] -= vote_value 
		if vote_pid in game_data["voting"]:
			game_data["voting"][vote_pid] += vote_value 
		else:
			game_data["voting"][vote_pid] = vote_value 
	else:
		players_data[pid]['vote'] = {}
	players_data[pid]['ready'] = true
	if check_all_alive_ready():
		calc_voting_result()
		_server_set_state_aside(ELIMINATING)
		
func _client_update_submit_screen_on_voting(player_data):
	var update_data = {
		"next_button": "Вы проголосовали",
		"next_button_disabled": true,
		"slider_editable": false,
		"my_score": str(int(player_data['balance'])),
	}
	_client_change_screen_data(update_data)

func _on_change_voting(pid:int):
	if state != VOTING:
		return
	if pid > 0 and h_slider.value > 0:
		next_button.text = "Проголосовать"
	else:
		next_button.text = "Пропустить\nголосование"

func calc_voting_result():
	var max_vote := 0
	var max_pid := 0
	var selected_pid := []
	for pid in game_data['voting']:
		if max_vote < game_data['voting'][pid]:
			max_pid = pid
			max_vote = game_data['voting'][pid]
	
	if max_pid > 0:
		for pid in players_data:
			if pid not in game_data['voting']:
				continue
			if players_data[pid]['alive'] and game_data['voting'][pid] >= max_vote:
				selected_pid.append(pid)
	else:
		var max_balance := 0
		if max_pid <= 0:
			for pid in players_data:
				if players_data[pid]['alive'] and players_data[pid]['balance'] > max_balance:
					max_balance = players_data[pid]['balance']
					max_pid = pid
			if max_pid:
				selected_pid = [max_pid]
	game_data['vote_winner'] = []
	for pid in selected_pid:
		var winner := {
			'pid': pid,
			'balance': players_data[pid]['balance'],
			'name': players_data[pid]['name'],
		}
		game_data['vote_winner'].append(winner)
		
func _server_set_eliminating_state():
	if game_data['vote_winner']:
		var label_state_str := "" 
		var message_label_str := "" 
		var voting_vars_array := []
		var alive_count = get_alive_count() 
		for acc_data in game_data['vote_winner']:
			var pid = acc_data['pid']
			players_data[pid]['alive'] = false
			players_data[pid]['place'] = alive_count
			_client_make_gameover.rpc_id(pid)
			voting_vars_array.append(pid)
			label_state_str += "Игру покидает: %s\n" % acc_data['name']
			message_label_str += "У %s было на счету %d\n" % [acc_data['name'], acc_data['balance']]
		var update_data = {
			'label_state':  label_state_str,
			'message_label': message_label_str,
			'voting_vars': voting_vars_array,
			'clear_selaction': true,
		}
		_server_update_all_client_screen_data(update_data)
		_server_set_state_aside(REQUESTING)
	else:
		push_warning("vote winner didn't calc")
		calc_voting_result()

@rpc("any_peer", "call_remote", "reliable")
func _client_make_gameover() -> void:
	_client_change_screen_data({"label_state": "Вы проиграли"})
	label_state.visible = true
	next_button.disabled = true
	next_button.visible = false
	account.visible = true
	h_slider.visible = false
	input_field.visible = false
	voting_container.visible = true

func send_dead_log():
	var log_message := '~~~~~~~~~~~~~~~~{0}~~~~~~~~~~~~~~~\n'.format([get_alive_count()])
	var alive_acc = []
	for pid in players_data:
		if players_data[pid]['alive']:
			alive_acc.append(pid)
			var pid_data = players_data[pid] 
			if state == REQUESTING:
				log_message += "{0} запросил {1} получил {2} баланс равен {3}\n".format([pid_data['name'], int(pid_data['request']), int(pid_data['request_result']), int(pid_data['balance'])])
			if state == VOTING:
				log_message += "{0} проголосовал {1}\n".format([pid_data['name'], str(pid_data['vote'])])
	game_history += log_message
	var update_date = {
		'history_log': game_history,
		"voting_vars": alive_acc,
	}
	for pid in players_data:
		if !players_data[pid]['alive']:
			_client_change_screen_data.rpc_id(pid, update_date)

func _server_set_state_aside(state_):
	if state_ != state:
		new_state = state_
		state_timer.start()
	else:
		push_warning("State уже имеет занчение: %d" % state)
	
func _on_state_timer_timeout() -> void:
	_server_change_state()

func _server_set_gameend_state() -> void:
	var win_pid: int 
	var last_message = ''
	for pid in players_data:
		if players_data[pid]['alive']:
			win_pid = pid
			players_data[pid]['place'] = 1
			
	for i in range(1, 1+start_player_count):
		for pid in players_data:
			if players_data[pid]['place'] == i:
				last_message += "#%d: %s\n" % [i, players_data[pid]['name']]
			
	var update_data = {
		'message_label': last_message,
		'clear_selaction': true,
		'history_log': game_history,
	}
	if !win_pid:
		update_data['label_state'] = "Все проиграли"
		update_data['voting_vars'] = []
	else:
		update_data['label_state'] = "Выиграл %s: %d" % [players_data[win_pid]['name'], players_data[win_pid]['balance']]
		update_data['voting_vars'] = [win_pid]
		
	_server_update_all_client_screen_data(update_data)
	
func print_time():
	var time_dict = Time.get_time_dict_from_system()
	print("%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second])
		
func _on_ping_timer_timeout() -> void:
	if multiplayer.is_server():
		print_time()
		return  
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		keep_alive_dummy.rpc_id(1, multiplayer.get_unique_id()) 

@rpc("any_peer", "reliable")
func keep_alive_dummy(pid) -> void:
	if pid in players_data:
		print("[%s] %d" % [players_data[pid]['name'], pid])
	
