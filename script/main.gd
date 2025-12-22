extends Control

var round_id: int
var current_player_count: int
@export var single_score := 100
@export var start_player_count := 5
@onready var label_state: Label = $LabelState
@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var next_button: Button = $NextButton

const PlayerScene = preload("uid://bcmreqckndjor")
@onready var bank_score: Label = $BankScore
var init_bank: int

enum {
	START,
	EARNING,
	ELIMINATION,
}
var state := EARNING
var votes = {}

#func _ready() -> void:
	#var shift_n = randi() % start_player_count
	#for n in range(start_player_count):
		#var player = PlayerScene.instantiate()
		#h_box_container.add_child(player)
		#player.setup((n + shift_n) % start_player_count)
		#round_id = start_player_count
		#current_player_count = start_player_count

func next():
	match state:
		START:
			bank_score.text = ""
			label_state.text = " Welcome "
			next_button.text = " Start "
			state = EARNING
		EARNING:
			init_bank = current_player_count * single_score
			bank_score.text = " Capital: %d " % init_bank
			label_state.text = " Distribution of points "
			next_button.text = " Next "
			state = ELIMINATION
		ELIMINATION:
			bank_score.text = ""
			label_state.text = " Voting for Elimination "
			next_button.text = " Next "
			state = EARNING

func _on_button_pressed() -> void:
	next()
