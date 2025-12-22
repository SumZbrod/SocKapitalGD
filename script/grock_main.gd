extends Control

@onready var message_label: Label = $VBox/MessageLabel
@onready var balance_label: Label = $VBox/BalanceLabel
@onready var input_field: LineEdit = $VBox/InputField
@onready var label_state: Label = $LabelState
@onready var next_button: Button = $VBox/NextButton

enum {
	JOIN,
	REQUESTING,
	VOTING,
}
var state := JOIN

const PORT: int = 8080
var SERVER_URL: String = "ws://127.0.0.1:" + str(PORT)

var players_data: Dictionary = {}  # {player_id: {'ready': bool, 'balance': int, 'request': int, 'vote': [{player_id: int}]}}

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
	message_label.text = "Сервер онлайн (ID: 1)"
	balance_label.text = "Баланс сервера: ∞"
	input_field.visible = false
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func start_client() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_client(SERVER_URL)
	if err != OK:
		push_error("Ошибка клиента: " + str(err))
		message_label.text = "Ошибка подключения"
		return
	
	multiplayer.multiplayer_peer = peer
	print("Подключение...")
	message_label.text = "Подключаюсь..."
	balance_label.text = ""
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_player_connected(id: int) -> void:
	# ГЕНЕРИРУЕМ БАЛАНС ПРИ ПОДКЛЮЧЕНИИ!
	if state == JOIN:
		players_data[id] = {'ready': false, 'balance': 0, 'request': 0, 'vote': []}
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
	message_label.text = "Готов к чату! (ID: " + str(my_id) + ")"
	input_field.placeholder_text = "Напиши и Enter (ID: " + str(my_id) + ")"

func _on_connection_failed() -> void:
	message_label.text = "Сервер недоступен"

func _on_next_button_pressed() -> void:
	print('_on_next_button_pressed()')
	input_field.clear()
	#update_game()
	update_game.rpc_id(1, multiplayer.get_unique_id())
	
func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	# Клиент отправляет серверу
	_on_next_button_pressed()
	
@rpc("any_peer", "call_remote", "reliable")
func send_message(player_id: int, message: String) -> void:
	if multiplayer.is_server():
		display_message.rpc(player_id, message)
		for _player_id in players_data:
			update_players_data.rpc_id(_player_id, players_data[_player_id])

@rpc("authority", "call_remote", "reliable")
func display_message(player_id: int, message: String) -> void:
	message_label.text = "Игрок " + str(player_id) + ": " + message

@rpc("authority", "call_remote", "reliable")
func update_players_data(player_date: Dictionary) -> void:
	balance_label.text = "Твой баланс: " + str(player_date['balance'])

@rpc("any_peer", "call_remote", "reliable")
func update_game(pl_id: int) -> void:
	print('players_data ', players_data)
	print('update_game():')
	if multiplayer.is_server():
		match state: 
			JOIN:
				_on_join(pl_id)

func _on_join(pl_id: int):
	if !multiplayer.is_server():
		return
	if pl_id in players_data:
		players_data[pl_id]['ready'] = !players_data[pl_id]['ready']
		var ready_players := 0
		for pl_data in players_data.values():
			if pl_data['ready']:
				ready_players += 1
		var update_date = {}
		var local_update_date = {}
		local_update_date['label_state'] = "К игре готовы: " + str(ready_players) + " / " + str(players_data.size())
		if players_data[pl_id]['ready']:
			update_date['next_button'] = "Готов"
		else:
			update_date['next_button'] = "Не готов"
		update_player_screen.rpc_id(pl_id, local_update_date)
		update_all_player_screen.rpc_id(1, update_date)

@rpc("any_peer", "call_remote", "reliable")
func update_player_screen(update_date: Dictionary) -> void:
	for key in update_date:
		match key:
			"label_state":
				label_state.text = update_date[key]
			"next_button":
				next_button.text = update_date[key]

@rpc("any_peer", "call_remote", "reliable")
func update_all_player_screen(update_date: Dictionary) -> void:
	print("players_data ", players_data)
	for pl_id in players_data:
		print('update_all_player_screen pl_id ', pl_id)
		update_player_screen.rpc_id(pl_id, update_date)
		
