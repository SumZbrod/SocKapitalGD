class_name PlayerClass extends Control

var player_id : int
@onready var label_name: Label = $VBoxContainer/Name

var players_name = ['Vladislav', "Sasha", "Maria", "Nikolos", "Rob", "Sakura"]
var is_setup = false

func setup(n: int) -> void:
	player_id = n
	label_name.text = players_name[n]
@onready var button: Button = $VBoxContainer/Button
var ws := WebSocketMultiplayerPeer.new()

func _ready():
	ws.create_client("ws://127.0.0.1:8080")
	multiplayer.multiplayer_peer = ws

	button.text = "Никто не нажимал"
	button.pressed.connect(_on_pressed)

func _process(_delta):
	ws.poll()

func _on_pressed():
	rpc("press_button")

@rpc("authority")
func update_button(text):
	button.text = "Последний: " + text
