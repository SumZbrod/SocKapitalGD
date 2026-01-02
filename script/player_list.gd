class_name PlayerListClass

var player_dict := {}
var voting_dict := {}
var vote_winner := []
var subsidia := 0
var init_budget := 0
const PLAYER_COST = 100
var game_history := ""
var start_player_count: int
var ava_id_shift := randi() % 9
var ava_id_step:int = [1, 2, 4, 5, 7, 8].pick_random()

var role_dict = {
	-1: PlayerClass.new(-1, "Ксива", 0),
}

func from_dict(data: Dictionary) -> PlayerClass:
	var new_player = PlayerClass.new(data['pid'], data['player_name'], data['ava_id'])
	new_player.sync(data)
	return new_player
	
func make_player(pid, player_name) -> void:
	var ava_id = (ava_id_shift + ava_id_step*get_alive_count()) % 9
	var new_player = PlayerClass.new(pid, player_name, ava_id)
	start_player_count += 1
	player_dict[pid] = new_player
	
func kill(pid: int, place:=-1) -> void:
	player_dict[pid].kill()
	if place == -1:
		player_dict[pid].place = get_alive_count()
	else:
		player_dict[pid].place = place
	
func make_gost(pid) -> void:
	var new_player = PlayerClass.new(pid, 'Gost', 0)
	new_player.kill()
	player_dict[pid] = new_player

func is_exist(pid: int) -> bool:
	return pid in player_dict

func erase(pid: int) -> void:
	if is_exist(pid):
		player_dict.erase(pid)
	else:
		push_warning("[playerplayer_dict:erase] pid didn't exist: %d" % pid)
		
func get_player(pid: int) -> PlayerClass:
	return player_dict[pid] as PlayerClass

## if pid == -1, value will be set to everyone
func set_ready(pid:int, value: bool) -> void:
	if pid == -1:
		for sub_pid in player_dict:
			player_dict[sub_pid].ready_state = value
	elif is_exist(pid):
		player_dict[pid].ready_state = value
	else:
		push_warning("[player_dict:set_ready] pid didn't exist: %d" % pid)
		
func is_ready(pid: int) -> bool:
	return player_dict[pid].ready_state

func is_alive(pid: int) -> bool:
	return player_dict[pid].alive

func get_pids() -> Array:
	return player_dict.keys()

func get_alive_pids() -> Array:
	var res := []
	for pid in player_dict:
		if player_dict[pid].alive:
			res.append(pid)
	return res

func get_dead_pids() -> Array:
	var res := []
	for pid in player_dict:
		if !player_dict[pid].alive:
			res.append(pid)
	return res

func get_ava_id(pid: int) -> int:
	return player_dict[pid].ava_id

func get_player_name(pid: int) -> String:
	if pid > 0:
		return player_dict[pid].player_name
	for rid in role_dict:
		if rid == pid:
			return role_dict[rid].player_name
	push_error("[PlayerListClass:get_player_name] unknown pid: %d" % pid)
	return ''

func get_player_balance(pid: int) -> int:
	return player_dict[pid].balance

func get_alive_ready_count() -> int:
	var res := 0
	for pid in player_dict:
		if player_dict[pid].alive and player_dict[pid].ready_state:
			res += 1
	return res
	
func get_alive_count() -> int:
	var res := 0
	for pid in player_dict:
		if player_dict[pid].alive:
			res += 1
	return res

func check_all_alive_ready() -> bool:
	for pid in player_dict:
		if !player_dict[pid].ready_state and player_dict[pid].alive:
			return false
	return true

func reset_request_vote(pid:=-1):
	if pid != -1:
		player_dict[pid]['request'] = 0
		player_dict[pid]['request_result'] = 0
		player_dict[pid]['vote'] = {}
	else:
		for sub_pid in player_dict:
			player_dict[sub_pid]['request'] = 0
			player_dict[sub_pid]['request_result'] = 0
			player_dict[sub_pid]['vote'] = {}

func reset_game_data():
	voting_dict = {}
	init_budget = 0
	vote_winner = []

func reset_vote(pid: int) -> void:
	player_dict[pid].vote = {}

func set_request(pid: int, value: int) -> void:
	player_dict[pid].request = value
	
## if pid == -1, return sum of requestings of everyone
func get_request(pid: int, power:=1.) -> float:
	var res := 0.
	if pid == -1:
		for sub_pid in get_alive_pids():
			res += float(player_dict[sub_pid].request) ** power
	elif is_exist(pid):
		res = float(player_dict[pid].request) ** power
	else:
		push_warning("[playerplayer_dict:set_ready] pid didn't exist: %d" % pid)
	return res
	
func set_request_result(shrink_budget, power):
	var power_sum := get_request(-1, power)
	for pid in player_dict:
		if player_dict[pid].rid == -1:
			player_dict[pid].request_result = get_fix_earn()
		elif shrink_budget == init_budget:
			player_dict[pid].request_result = player_dict[pid].request
		else:
			player_dict[pid].request_result = int((float(player_dict[pid].request)**power) / float(power_sum) * shrink_budget)
		player_dict[pid].balance += player_dict[pid].request_result
		
func calc_request_result():
	var inequality_degree := .5 + 2*randf()
	var sum_request := get_request(-1)
	var shrink_budget = min(init_budget, 2*init_budget - sum_request)
	shrink_budget = max(PLAYER_COST, abs(shrink_budget)) * (1 if shrink_budget > 0 else -1)
	set_request_result(shrink_budget, inequality_degree)
	if shrink_budget <= 0:
		subsidia = get_subsidia()
		game_history += "субсидия равна: %d\n" % subsidia
	else:
		subsidia = 0
	for pid in player_dict:
		if player_dict[pid].alive:
			player_dict[pid].balance += subsidia
			player_dict[pid].subsidia = subsidia

func increase_balance(pid:int, value:int) -> void:
	if pid == -1:
		for sub_pid in player_dict:
			player_dict[sub_pid].balance += value
	else:
		player_dict[pid].balance += value

func get_subsidia() -> int:
	var max_minus := 0
	for pid in player_dict:
		if player_dict[pid].alive:
			if max_minus > player_dict[pid].request_result:
				max_minus = player_dict[pid].request_result
	return abs(max_minus)
	
func get_voiting_vars_for(pid:int) -> Array:
	var voting_vars = []
	for sub_pid in player_dict:
		if sub_pid == pid:
			continue 
		if !player_dict[sub_pid].alive:
			continue
		voting_vars.append(sub_pid)
	return voting_vars

func get_max_voting_value(pid: int) -> int:
	return player_dict[pid].balance 
	
func get_balance(pid: int) -> int:
	return player_dict[pid].balance 

func set_init_budget() -> void:
	init_budget = get_alive_count() * PLAYER_COST

func get_role_vars():
	return role_dict.keys()

func get_fix_earn() -> int:
	@warning_ignore("integer_division")
	return PLAYER_COST / get_alive_count()

func get_state_screen_data(pid: int, state:String) -> Dictionary:
	var data: Dictionary
	match state:
		"set_roling":
			data = {
				"label_state": "Аукцион",
				"next_button": "Пропустить",
				"slider_editable": true,
				"h_slider_max": get_max_voting_value(pid),
				"h_slider_value": 0,
				"voting_vars": get_role_vars(),
			} 
		"set_role_result":
			data = {
				'label_state': "Результат Аукциона",
				'next_button': "Дальше",
				'slider_editable': false,
				'message_label': player_dict[pid].get_palyer_role_result_message(),
				"voting_vars": [],
			}
		"set_request":
			if player_dict[pid].rid == -1:
				data = {
					'label_state': "Ваша зарплата: %d" % get_fix_earn(),
					'next_button': "Пропуск",
					'slider_editable': false,
					'message_label': "",
				}
			else:
				data = {
					'label_state': "Бюджет: %d" % init_budget,
					'h_slider_max': init_budget,
					'h_slider_value': PLAYER_COST,
					'next_button': "Запросить",
					'slider_editable': true,
					'message_label': "Ваш запрос: %d" % PLAYER_COST,
				}
		"set_voting":
			if player_dict[pid].rid == -1:
				data = {
					"label_state": "Выберите кого крышивать",
					"next_button": "Пропустить\nголосование",
					"slider_editable": true,
					"h_slider_max": get_max_voting_value(pid),
					"h_slider_value": 0,
					"voting_vars": get_voiting_vars_for(pid),
					'message_label': "Отданные голоса\nпойдут в защиту игрока",
					'clear_selaction': true,
				} 
			else:
				data = {
					"label_state": "Выберите за кого голосовать",
					"next_button": "Пропустить\nголосование",
					"slider_editable": true,
					"h_slider_max": get_max_voting_value(pid),
					"h_slider_value": 0,
					"voting_vars": get_voiting_vars_for(pid),
					'clear_selaction': true,
				} 
	return data

func get_vote_value_sign(pid, _vote_pid) -> int:
	if player_dict[pid].rid == -1:
		return -1
	return 1

func set_vote(pid, vote_pid, value) -> void:
	player_dict[pid].vote = {vote_pid: value}
	player_dict[pid].balance -= value 
	var value_sign := get_vote_value_sign(pid, vote_pid)
	if vote_pid in voting_dict:
		voting_dict[vote_pid] += value * value_sign
	else:
		voting_dict[vote_pid] = value * value_sign

func get_first_most_richer_player() -> int:
	var max_balance := 0
	var max_pid := 0
	for pid in player_dict:
		if player_dict[pid].alive and player_dict[pid].balance > max_balance:
			max_balance = player_dict[pid].balance
			max_pid = pid
	return max_pid

func calc_voting_result(exaption_enable=false):
	var max_vote := -INF
	var max_pid := 0
	var selected_pid := []
	for pid in voting_dict:
		if max_vote < voting_dict[pid]:
			max_pid = pid
			max_vote = voting_dict[pid]
	
	if max_pid > 0:
		for pid in voting_dict:
			if player_dict[pid].alive and voting_dict[pid] >= max_vote:
				selected_pid.append(pid)
	else:
		selected_pid = [get_first_most_richer_player()]
	print("[PlayerList:calc_voting_result] voting_dict ", voting_dict)
	vote_winner = []
	for pid in selected_pid:
		var winner := {
			'pid': pid,
			'balance': player_dict[pid].balance,
			'name': player_dict[pid].player_name,
		}
		vote_winner.append(winner)
	if exaption_enable and vote_winner:
		push_error("I can't make vote winner")

func get_state_log(pid: int, state) -> String:
	var pid_data = player_dict[pid]
	var res = ""
	match state:
		PlayerClass.REQUESTING:
			pid_data = [pid_data.player_name, pid_data.request, pid_data.request_result, pid_data.balance]
			res += "{0} запросил {1} получил {2} баланс равен {3}\n".format(pid_data)
		PlayerClass.ROLING:
			if pid_data.rid:
				var auction_data = [pid_data.player_name, role_dict[pid_data.rid].player_name]
				res += "{0} получил {1}\n".format(auction_data)
			else:
				var auction_data = [pid_data.player_name]
				res += "{0} пропустил аукцион\n".format(auction_data)
		PlayerClass.VOTING:
			var vote_name_ 
			var vote_value_
			for k in pid_data.vote:
				vote_name_ = player_dict[k].player_name
				vote_value_ = pid_data.vote[k]
			if vote_name_:
				pid_data = [pid_data.player_name, int(vote_value_), vote_name_]
				if player_dict[pid].rid == -1:
					res += "{0} поставил -{1} в защиту {2}\n".format(pid_data)
				else:
					res += "{0} поставил {1} против {2}\n".format(pid_data)
			else:
				res += "%s не голосовал\n" % player_dict[pid].player_name
	return res

func set_place(pid:int, place:int):
	player_dict[pid].place = place

func get_last_message() -> String:
	var last_message = ''
	for i in range(1, 1+start_player_count):
		for pid in player_dict:
			if player_dict[pid].place == i:
				last_message += "#%d: %s\n" % [i, player_dict[pid].player_name]
	return last_message

func get_accs_list():
	var new_accs = []
	for pid in player_dict:
		var new_acc = {
			'pid' = pid,
			'ava_id' = player_dict[pid].ava_id,
			'name' = player_dict[pid].player_name,
		}
		new_accs.append(new_acc)
	return new_accs

func _to_string():
	return str(player_dict.keys())
	
func get_dict(pid:int) -> Dictionary:
	return player_dict[pid].to_dict()

func get_role_data_list() -> Array:
	var data_list := []
	for rid in role_dict:
		var new_role = {
			'pid' = rid,
			'ava_id' = role_dict[rid].ava_id,
			'name' = role_dict[rid].player_name,
		}
		data_list.append(new_role)
	return data_list
	
func set_auction(pid, vote_pid, vote_value):
	player_dict[pid].auction = {vote_pid: vote_value}
	player_dict[pid].balance -= int(vote_value)

func reset_auction(pid):
	player_dict[pid].auction = {}

func calc_auction_result():
	var auction_result = {} # {rid: {pid, value}}
	for rid in role_dict:
		for pid in player_dict:
			var auction = player_dict[pid].auction
			if rid in auction:
				if rid not in auction_result:
					auction_result[rid] = {
						'value': auction[rid],
						'pid': pid
					}
				elif auction_result[rid]['value'] < auction[rid]:
					auction_result[rid]['value'] = auction[rid]
					auction_result[rid]['pid'] = pid

	for rid in auction_result:
		player_dict[auction_result[rid]['pid']].rid = rid
		player_dict[auction_result[rid]['pid']].role_name = role_dict[rid].player_name
