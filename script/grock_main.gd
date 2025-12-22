extends Control

@export var start_player_count := 2
@export var player_cost := 100
@onready var message_label: Label = $VBox/MessageLabel
@onready var balance_label: Label = $VBox/BalanceLabel
@onready var input_field: LineEdit = $VBox/InputField
@onready var label_state: Label = $LabelState
@onready var next_button: Button = $VBox/NextButton
@onready var h_slider: HSlider = $VBox/HSlider

enum {
	JOIN,
	REQUESTING,
	VOTING,
	GAMEEND,
}
var state := JOIN

const PORT: int = 8080
var SERVER_URL: String = "ws://127.0.0.1:" + str(PORT)

var players_data: Dictionary = {}  # {player_id: {'alive': bool 'ready': bool, 'balance': int, 'request': int, 'vote': [{player_id: int}]}}
var game_data: Dictionary = {'init_budget': 0}

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
	balance_label.text = "Баланс сервера: ∞"
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
	balance_label.text = ""
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_player_connected(id: int) -> void:
	# ГЕНЕРИРУЕМ БАЛАНС ПРИ ПОДКЛЮЧЕНИИ!
	if state == JOIN:
		players_data[id] = {'alive': true, 'ready': false, 'balance': 0, 'request': 0, 'vote': []}
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
	input_field.placeholder_text = "Напиши и Enter (ID: " + str(my_id) + ")"

func _on_connection_failed() -> void:
	message_label.text = "Сервер недоступен"

func _on_next_button_pressed() -> void:
	input_field.clear()
	update_game.rpc_id(1, multiplayer.get_unique_id())
	
func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	# Клиент отправляет серверу
	_on_next_button_pressed()
	
@rpc("authority", "call_remote", "reliable")
func update_players_data(player_date: Dictionary) -> void:
	balance_label.text = "Твой баланс: " + str(player_date['balance'])

@rpc("any_peer", "call_remote", "reliable")
func update_game(pl_id: int) -> void:
	if multiplayer.is_server():
		match state: 
			JOIN:
				_on_join(pl_id)
			REQUESTING:
				_on_requesting(pl_id)
			_:
				push_error("Uknown state: %s" % state)

func _on_join(pl_id: int):
	if pl_id in players_data:
		players_data[pl_id]['ready'] = !players_data[pl_id]['ready']
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
		update_player_screen.rpc_id(pl_id, state, local_update_date)
		update_all_player_screen(update_date)
		if check_all_alive_ready():
			change_state(REQUESTING)


@rpc("any_peer", "call_remote", "reliable")
func update_player_screen(_state, update_date: Dictionary) -> void:
	for key in update_date:
		match key:
			"label_state":
				label_state.text = update_date[key]
			"next_button":
				next_button.text = update_date[key]
			"h_slider":
				h_slider.max_value = update_date[key]
			"message_label":
				message_label.text = update_date[key]
			"slider_editable":
				h_slider.editable = update_date[key]
			_:
				push_error("Uknown key: %s" % key)
	match _state:
		JOIN:
			h_slider.visible = false
		REQUESTING:
			h_slider.visible = true
		"":
			return
		_:
			push_error("Uknown state: %s" % _state)
			
func check_all_alive_ready() -> bool:
	for pl_id in players_data:
		if !players_data[pl_id]['ready'] and players_data[pl_id]['alive']:
			return false
	return true

func update_all_player_screen(update_date: Dictionary) -> void:
	for pl_id in players_data:
		update_player_screen.rpc_id(pl_id, state, update_date)

func change_state(new_state):
	state = new_state
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

func _set_requesting(alive_count: int):
	var update_date = {}
	var budget := alive_count * player_cost
	game_data['init_budget'] = budget
	update_date['label_state'] = "Бюджет: %d" % budget
	update_date['h_slider'] = budget
	update_date['next_button'] = "Запросить"
	update_date['slider_editable'] = true
	update_all_player_screen(update_date)
	

func _on_requesting(pl_id: int):
	if !multiplayer.is_server():
		return
	if pl_id in players_data:
		if players_data[pl_id]['ready']:
			return
		var update_player_date = {}
		players_data[pl_id]['ready'] = true
		update_player_date['slider_editable'] = false
		update_player_date['next_button'] = "Ваш запрос: %d" % h_slider.value
		
		update_player_screen.rpc(pl_id, update_player_date)

func _on_h_slider_value_changed(value: float) -> void:
	var update_date = {}
	update_date['message_label'] = "Ваш запрос: %d" % int(value)
	update_player_screen("", update_date)
