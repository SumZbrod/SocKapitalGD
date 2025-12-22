extends Control

@onready var button: Button = $Button
@onready var multiplayer: MultiplayerAPI = get_multiplayer()

const PORT: int = 8080
const SERVER_URL: String = "ws://127.0.0.1:" + str(PORT)

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	
	# Автоматическое определение режима
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
		start_server()
	else:
		start_client()  # Для HTML5 и desktop-клиентов

func start_server() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT)
	if err != OK:
		push_error("Ошибка создания сервера: " + str(err))
		return
	
	multiplayer.multiplayer_peer = peer
	print("Сервер запущен на порту " + str(PORT))
	button.text = "Сервер (ID: 1)"
	button.disabled = true  # Сервер не нажимает кнопку
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func start_client() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_client(SERVER_URL)
	if err != OK:
		push_error("Ошибка подключения: " + str(err))
		button.text = "Ошибка подключения"
		return
	
	multiplayer.multiplayer_peer = peer
	print("Подключение к серверу...")
	button.text = "Подключаюсь..."
	
	# Сигналы для клиента
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_player_connected(id: int) -> void:
	print("Игрок подключился: ID " + str(id))
	# Автоматическое "создание аккаунта" - ID присваивается автоматически

func _on_player_disconnected(id: int) -> void:
	print("Игрок отключился: ID " + str(id))

func _on_connected_to_server() -> void:
	print("Подключен к серверу! Твой ID: " + str(multiplayer.get_unique_id()))
	button.text = "Нажми! (ID: " + str(multiplayer.get_unique_id()) + ")"

func _on_connection_failed() -> void:
	print("Ошибка подключения")
	button.text = "Сервер недоступен"

func _on_button_pressed() -> void:
	if multiplayer.is_server():
		return  # Сервер не отправляет нажатия
	
	# Клиент отправляет свой ID серверу (только по нажатию!)
	button_press.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_remote", "reliable")
func button_press(player_id: int) -> void:
	if multiplayer.is_server():
		# Сервер рассылает обновление ВСЕМ клиентам (и себе)
		update_button_text.rpc(player_id)

@rpc("authority", "call_remote", "reliable")
func update_button_text(player_id: int) -> void:
	# У всех меняется текст на ID нажавшего
	button.text = "Нажал: " + str(player_id)
