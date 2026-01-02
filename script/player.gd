class_name PlayerClass
var alive := true 
var ready_state := false 
var player_name: String
var ava_id: int
var balance := 0 
var request := 0 
var request_result := 0 
var vote := {}
var place := 0
var pid: int
var subsidia: int
var auction := {}
var rid := 0
var role_name: String

enum {
	JOIN,
	ROLING,
	REQUESTING,
	VOTING,
	ELIMINATING,
	GAMEEND,
}

func _init(pid_, player_name_, ava_id_):
	pid = pid_
	player_name = player_name_
	ava_id = ava_id_

func kill():
	alive = false

func get_ava_rect() -> Rect2:
	if pid > 0:
		var r = 341
		var x = ava_id % 3
		@warning_ignore("integer_division")
		var y = ava_id / 3
		return Rect2(r*x, r*y, r, r)
	else:
		var r = 512
		var x = ava_id % 2
		@warning_ignore("integer_division")
		var y = ava_id / 2
		return Rect2(1024+r*x, r*y, r, r)
		
func get_pid():
	return pid

func sync(player_dict:Dictionary):
	if pid != player_dict['pid']:
		push_warning("Replace player data from %d to %d" % [pid, player_dict['pid']])
	alive = player_dict['alive'] 
	ready_state = player_dict['ready_state'] 
	player_name = player_dict['player_name'] 
	ava_id = player_dict['ava_id'] 
	balance = player_dict['balance'] 
	request = player_dict['request'] 
	request_result = player_dict['request_result'] 
	vote = player_dict['vote'] 
	place = player_dict['place'] 
	pid = player_dict['pid'] 
	subsidia = player_dict['subsidia'] 
	rid = player_dict['rid'] 
	role_name = player_dict['role_name'] 
	

func get_player_name():
	return player_name
	
func to_dict() -> Dictionary:
	return {
		'pid': pid,
		'rid': rid,
		'alive': alive,
		'ready_state': ready_state,
		'player_name': player_name,
		'ava_id': ava_id,
		'balance': balance,
		'request': request,
		'request_result': request_result,
		'vote': vote,
		'place': place,
		'subsidia': subsidia,
		'role_name': role_name,
	}

func get_request() -> int:
	return request

func get_acc_info(state) -> Dictionary:
	var res := {}
	res['score'] = str(balance)
	match state:
		VOTING, ROLING:
			res['name'] = player_name
			res['message'] = "Запросил: %d\n Получил: %d" % [request, request_result]
			if subsidia:
				res['message'] += '\n Субсидия: %d' % subsidia
	if rid != 0:
		res['role'] = role_name
	return res

func _to_string() -> String:
	return str(to_dict())
