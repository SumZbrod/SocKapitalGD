extends Control
@export var start_player_count := 5
@onready var message_label: Label = $VBox/MessageLabel
@onready var input_field: LineEdit = $VBox/InputField
@onready var next_button: Button = $VBox/NextButton
@onready var h_slider: HSlider = $VBox/HSlider
@onready var account: AccountNode = $Account
@onready var history_log: TextEdit = $HistoryLog
@onready var ping_timer: Timer = $PingTimer
@onready var label_clock: Label = $UpperBlock/LabelClock
@onready var label_state: Label = $UpperBlock/LabelState
@onready var voting_container: VotingContainerNode = $UpperBlock/VotingContainer
@onready var state_timer: Timer = $StateTimer
var new_state
var peer := WebSocketMultiplayerPeer.new()
const account_scn = preload("res://scene/account.tscn")
var my_player_account: PlayerClass

enum {
	JOIN,
	REQUESTING,
	VOTING,
	ELIMINATING,
	GAMEEND,
}
var state := JOIN

var player_list := PlayerListClass.new()
var player_codes = {}
var gost_code = "-6767"
const PORT = 8080
var SERVER_URL: String

var clock := .0
const wait_time := 5 * 60 #TODO

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
		if arg.begins_with("#"):
			arg = arg.right(-1)
			start_player_count = int(arg)
	if !player_codes:
		var names = "ABCDEXYZW".split()
		for i in range(start_player_count):
			player_codes[str(i+1)] = {'name': names[i], 'not_used': true}
	start_player_count = player_codes.size()
	voting_container.change_decition.connect(_on_change_voting)
	input_field.text_submitted.connect(_on_text_submitted)
	state = JOIN
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
		start_server()
	else:
		start_client()

func _process(delta):
	if peer:
		peer.poll()
	if clock > 0:
		clock = max(0, clock-delta)
		update_clock()
		
func time_convert(time_in_sec):
	time_in_sec = int(time_in_sec)
	var seconds = time_in_sec%60
	var minutes = (time_in_sec/60)%60
	return "%02d:%02d" % [minutes, seconds]

func update_clock():
	if multiplayer.is_server():
		return
	if clock > 0:
		label_clock.text = time_convert(clock)
	else:
		label_clock.text = ''
		_client_send_my_data()

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

func _on_player_connected(_pid: int) -> void:
	return 
	
func _on_player_disconnected(pid: int) -> void:
	player_list.erase(pid)
	print("Отключился ID " + str(pid))

func _on_connected_to_server() -> void:
	var pid = multiplayer.get_unique_id()
	print("Подключен! ID: " + str(pid))

func _on_connection_failed() -> void:
	message_label.text = "Сервер недоступен"

@rpc("any_peer", "call_remote", "reliable")
func _server_create_new_player(pid: int, code_text: String):
	if !multiplayer.is_server():
		return
	if code_text in player_codes:
		if player_codes[code_text]['not_used']:
			player_list.make_player(pid, player_codes[code_text]['name'])
		else:
			var update_date = {
				"message_label" : "Этот код уже использован"
			}
			_client_change_screen_data.rpc_id(pid, update_date)
	elif code_text == str(gost_code):
		player_list.make_gost(pid)
	else:
		var update_date = {
			"message_label" : "Неправильный код"
		}
		_client_change_screen_data.rpc_id(pid, update_date)

func get_player_screen_data() -> Dictionary:
	var res = {
		"h_slider_value": h_slider.value,
		"input_field_text": input_field.text,
		"vote_pid": voting_container.get_choose(),
	}
	return res

func _client_send_my_data() -> void:
	var player_data := get_player_screen_data()
	_server_update_game.rpc_id(1, multiplayer.get_unique_id(), player_data)

func _on_next_button_pressed() -> void:
	clock = 0
	update_clock()
	
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
	if !player_list.is_exist(pid):
		push_warning("[_server_update_game] pid not in players_data")
		push_warning("[_server_update_game] %d" % pid)
		return
	if player_list.is_ready(pid): 
		push_warning("[_server_update_game] already ready")
		return
	_client_update_submit_screen.rpc_id(pid)
	if !player_list.is_alive(pid):
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
	
@rpc("any_peer", "call_remote", "reliable")
func _client_sync_player(player_dict: Dictionary):
	if my_player_account:
		my_player_account.sync(player_dict)
	else:
		my_player_account = player_list.from_dict(player_dict)

func _server_setup_all_alive_account():
	for pid in player_list.get_alive_pids():
		_client_setup_account.rpc_id(pid)

func _server_sync_all_player():
	for pid in player_list.get_pids():
		_client_sync_player.rpc_id(pid, player_list.get_dict(pid))

@rpc("any_peer", "call_remote", "reliable")
func _client_update_submit_screen():
	match state: 
		JOIN:
			_client_update_submit_screen_on_join()
		REQUESTING:
			_client_update_submit_screen_on_requesting()
		VOTING:
			_client_update_submit_screen_on_voting()
		_:
			push_warning("[update_my_screen] Uknown state: %s" % state)

@rpc("any_peer", "call_remote", "reliable")
func _client_setup_account():
	if !my_player_account:
		push_warning("бляы ", my_player_account)
	account.setup(my_player_account)

## Вызывается после нажатия next_button или ввода имени
## Должен обновлять имя и обновлять VotingContaine
## Проверяет что игру можно начинать
## Не даёт повторного выполнения
func _server_update_game_on_join(pid: int, _player_screen_data:Dictionary) -> void:
	player_list.set_ready(pid, true)
	
	# Обновление данных экрана игроков
	var ready_alive_players := player_list.get_alive_ready_count()
	var update_date = {
		'label_state': "К игре готовы: %d / %d
		" % [ready_alive_players, start_player_count],
		'new_accs': player_list.get_accs_list(),
	}
	_server_update_alive_client_screen_data(update_date)
	# Проверка готовности к игре
	if player_list.check_all_alive_ready() and ready_alive_players == start_player_count:
		_server_set_state_aside(REQUESTING)

func _client_update_submit_screen_on_join():
	input_field.editable = false
	input_field.visible = false
	next_button.visible = true
	next_button.disabled = true

@rpc("any_peer", "call_remote", "reliable")
## Меняет информацию содержащиюся на экране
func _client_change_screen_data(update_date: Dictionary) -> void:
	for key in update_date:
		match key:
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

func _client_update_acc_info():
	account.update(my_player_account.get_acc_info(state))

# Меняет отображаемые элеементы на экране 
func _client_change_screen_properties() -> void:
	_client_update_acc_info()
	match state:
		JOIN:
			next_button.disabled = false
			h_slider.visible = false
			next_button.visible = false
			account.visible = false
		REQUESTING:
			clock = wait_time
			next_button.disabled = false
			account.visible = true
			next_button.visible = true
			h_slider.visible = true
			input_field.visible = false
			voting_container.visible = false
		VOTING:
			clock = wait_time
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
		GAMEEND:
			next_button.disabled = true
			next_button.visible = false
			voting_container.visible = true
			voting_container.disable_accs()
			h_slider.visible = false
		_:
			push_warning("[change_screen_properties] Uknown state: %s" % state)

func _server_update_alive_client_screen_data(update_date: Dictionary) -> void:
	for pid in player_list.get_alive_pids():
		_client_change_screen_data.rpc_id(pid, update_date)

func _server_update_all_client_screen_data(update_date: Dictionary) -> void:
	for pid in player_list.get_pids():
		_client_change_screen_data.rpc_id(pid, update_date)
		
func _server_change_state():
	clock = 0
	send_dead_log()
	_server_sync_all_player()
	if state == JOIN:
		_server_setup_all_alive_account()
	
	state = new_state
	var alive_count = player_list.get_alive_count()
	if alive_count <= 1:
		state = GAMEEND
	player_list.set_ready(-1, false)
	match state:
		REQUESTING:
			_server_set_requesting_state()
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
	for pid in player_list.get_alive_pids():
		_client_update_player_state.rpc_id(pid, state)

@rpc("any_peer", "call_remote", "reliable")
func _client_update_player_state(_state):
	if state != _state:
		state = _state
		_client_change_screen_properties()

## Подготавливает информацию обигроках к началу нового раунда
## Отправляет новые данные об экранах универсальную игроков
func _server_set_requesting_state():
	clock = wait_time
	player_list.reset_request_vote()
	player_list.reset_game_data()
	player_list.set_init_budget()
	
	for pid in player_list.get_alive_pids():
		var init_screen_data = player_list.get_state_screen_data(pid, "set_request")
		_client_change_screen_data.rpc_id(pid, init_screen_data)

## Добавляет информацию об запросе игрока на получение баллов
func _server_update_game_on_requesting(pid: int, player_data: Dictionary):
	player_list.set_ready(pid, true)
	player_list.set_request(pid, player_data["h_slider_value"])

	if player_list.check_all_alive_ready():
		player_list.calc_request_result()
		_server_set_state_aside(VOTING)

func _client_update_submit_screen_on_requesting():
	var update_data = {
		'slider_editable': false,
		'next_button': "Вы сделали запрос",
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

func _server_set_voting_state():
	clock = wait_time
	for pid in player_list.get_alive_pids():
		var new_player_date = player_list.get_state_screen_data(pid, "set_voting")
		player_list.reset_request_vote()
		_client_change_screen_data.rpc_id(pid, new_player_date)
	player_list.reset_game_data()

func _server_update_game_on_voting(pid: int, player_data: Dictionary) -> void:
	var vote_pid = player_data['vote_pid'] 
	var vote_value = player_data["h_slider_value"]
	if vote_pid > 0 and vote_value > 0:
		player_list.set_vote(pid, vote_pid, vote_value)
	else:
		player_list.reset_vote(pid)
	player_list.set_ready(pid, true)
	if player_list.check_all_alive_ready():
		player_list.calc_voting_result()
		_server_set_state_aside(ELIMINATING)
		
func _client_update_submit_screen_on_voting():
	var update_data = {
		"next_button": "Вы проголосовали",
		"next_button_disabled": true,
		"slider_editable": false,
	}
	_client_change_screen_data(update_data)

func _on_change_voting(pid:int):
	if state != VOTING:
		return
	if pid > 0 and h_slider.value > 0:
		next_button.text = "Проголосовать"
	else:
		next_button.text = "Пропустить\nголосование"
	
func _server_set_eliminating_state():
	if player_list.vote_winner:
		var label_state_str := "" 
		var message_label_str := "" 
		var voting_vars_array := []
		var alive_count = player_list.get_alive_count() 
		for acc_data in player_list.vote_winner:
			var pid = acc_data['pid']
			player_list.kill(pid, alive_count)
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
		_server_sync_all_player()
		_server_set_state_aside(REQUESTING)
	else:
		push_warning("vote winner didn't calc")
		player_list.calc_voting_result(true)
		_server_set_state_aside(ELIMINATING)

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
	var log_message := '~~~~~~~~~~~~~~~~{0}~~~~~~~~~~~~~~~\n'.format([player_list.get_alive_count()])
	var alive_acc = player_list.get_alive_pids()
	for pid in alive_acc:
		log_message += player_list.get_state_log(pid, state)
	player_list.game_history += log_message
	var update_date = {
		'history_log': player_list.game_history,
		"voting_vars": alive_acc,
	}
	for pid in player_list.get_dead_pids():
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
	var win_pids := [] 
	var win_message = ""
	for pid in player_list.get_alive_pids():
		win_pids.append(pid)
		player_list.set_place(pid, 1)
		win_message += "Выиграл %s: %d\n" % [player_list.get_player_name(pid), player_list.get_player_balance(pid)]
	var last_message = player_list.get_last_message()
	
	var update_data = {
		'message_label': last_message,
		'clear_selaction': true,
		'history_log': player_list.game_history,
	}
	if !win_pids:
		update_data['label_state'] = "Все проиграли"
		update_data['voting_vars'] = []
	else:
		update_data['label_state'] = win_message
		update_data['voting_vars'] = win_pids
		
	_server_update_all_client_screen_data(update_data)

func print_time():
	var time_dict = Time.get_time_dict_from_system()
	print("%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second])

@rpc("any_peer", "call_remote", "reliable")
func _client_sync_clock(server_clock):
	clock = server_clock
	update_clock()
	print('clock updated')
	
func _on_ping_timer_timeout() -> void:
	if multiplayer.is_server():
		print_time()
		for pid in player_list.get_alive_pids():
			_client_sync_clock.rpc_id(pid, clock)
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		keep_alive_dummy.rpc_id(1, multiplayer.get_unique_id()) 

@rpc("any_peer", "reliable")
func keep_alive_dummy(pid) -> void:
	if player_list.is_exist(pid):
		print("[%s]\t%d" % [player_list.get_player_name(pid), pid])
	
