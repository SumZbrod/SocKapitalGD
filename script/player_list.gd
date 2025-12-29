class_name PlayerListClass extends Node

var player_dict: Dictionary = {}

func make_player(pid, player_name, ava_id) -> void:
	var new_player = PlayerClass.new(player_name, ava_id)
	player_dict[pid] = new_player
	
func make_gost(pid) -> void:
	var new_player = PlayerClass.new('Gost', 0)
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
	return player_dict[pid]

## if pid == -1, value will be set to everyone
func set_ready(pid:int, value: bool) -> void:
	if pid == -1:
		for sub_pid in player_dict:
			player_dict[sub_pid].ready_state = value
	elif is_exist(pid):
		player_dict[pid].ready_state = value
	else:
		push_warning("[playerplayer_dict:set_ready] pid didn't exist: %d" % pid)
		
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

func get_ava_id(pid: int) -> int:
	return player_dict[pid].ava_id

func get_player_name(pid: int) -> String:
	return player_dict[pid].player_name
	
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

func set_request(pid: int, value: int) -> void:
	player_dict[pid].request = value
	
## if pid == -1, return sum of requestings of everyone
func get_request(pid: int, power:=1) -> int:
	var res := 0 
	if pid == -1:
		for sub_pid in get_alive_pids():
			res += player_dict[sub_pid].request ** power
	elif is_exist(pid):
		res = player_dict[pid].request ** power
	else:
		push_warning("[playerplayer_dict:set_ready] pid didn't exist: %d" % pid)
	return res
	
func set_request_result(shrink_budget, init_budget, power):
	var power_sum := get_request(-1, power)
	for pid in player_dict:
		if shrink_budget == init_budget:
			player_dict[pid].request_result = player_dict[pid].request
		else:
			player_dict[pid].request_result = round((player_dict[pid].request**power) / power_sum * shrink_budget)
		player_dict[pid].balance += player_dict[pid].request_result

func increase_balance(pid:int, value:int) -> void:
	if pid == -1:
		for sub_pid in player_dict:
			player_dict[sub_pid].balance += value
	else:
		player_dict[pid].balance += value

func get_abs_max_minus() -> int:
	var max_minus := 0
	for pid in player_dict:
		if player_dict[pid].alive:
			if max_minus > player_dict[pid].request_result:
				max_minus = player_dict[pid].request_result
	return max_minus
	
	
func get_voiting_vars_for(pid:int) -> Array:
	var voting_vars = []
	for sub_pid in player_dict:
		if sub_pid == pid:
			continue 
		if !player_dict.alive:
			continue
		voting_vars.append(sub_pid)
	return voting_vars

func get_max_voting_value(pid: int) -> int:
	return player_dict[pid].balance 
	
func get_balance(pid: int) -> int:
	return player_dict[pid].balance 
	
func set_vote(pid, vote_pid, value) -> void:
	player_dict[pid].vote = {player_dict[pid].player_name: value}
	player_dict[pid].balance -= value 
	
	
func reset_vote(pid: int) -> void:
	player_dict[pid].vote = {}
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
