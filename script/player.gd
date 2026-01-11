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
var auction := {} # {vote_pid: vote_value}
var rid := 0
var role_name: String
var probiv_pid: int
var bettor_pid: int
var stavka_pid: int
var stavka_name: String
var has_immunitet := false

enum {
	JOIN,
	ROLING,
	ROLE_RESULT,
	REQUESTING,
	VOTING,
	ELIMINATING,
	URAVNILOVKA,
	GAMEEND,
}

func _init(pid_, player_name_, ava_id_):
	pid = pid_
	player_name = player_name_
	ava_id = ava_id_

func kill():
	alive = false

func get_ava_rect() -> Rect2:
	var r = 341
	var x = ava_id % 3
	@warning_ignore("integer_division")
	var y = ava_id / 3
	var res: Rect2
	if pid > 0:
		res = Rect2(r*x, r*y, r, r)
	else:
		res = Rect2(1024+r*x, r*y, r, r)
	return res

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
	probiv_pid = player_dict['probiv_pid']
	bettor_pid = player_dict['bettor_pid']
	stavka_pid = player_dict['stavka_pid']
	stavka_name = player_dict['stavka_name']
	has_immunitet = player_dict['has_immunitet']
	

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
		'probiv_pid': probiv_pid,
		'bettor_pid': bettor_pid,
		'stavka_pid': stavka_pid,
		'stavka_name': stavka_name,
		'has_immunitet': has_immunitet,
	}

func get_request() -> int:
	return request

func get_acc_info(state) -> Dictionary:
	var res := {}
	res['score'] = str(balance)
	match state:
		VOTING, ROLING:
			res['name'] = player_name
			if request:
				res['message'] = "Запросил: %d\n Получил: %d" % [request, request_result]
			else:
				res['message'] = "Получил: %d" % request_result
			if subsidia:
				res['message'] += '\n Субсидия: %d' % subsidia
		ROLE_RESULT:
			res['role'] = role_name
		REQUESTING:
			if rid == -3:
				res['role'] = "Поставили на %s" % stavka_name
		URAVNILOVKA:
			if request_result > 0:
				res['message'] = "Пособие: %d" % request_result
			elif request_result < 0:
				res['message'] = "Налог: %d" % request_result
	if has_immunitet:
		if 'message' in res:
			res['message'] += "\nИММУНИТЕТ"
		else:
			res['message'] = "\nИММУНИТЕТ"
	return res

func _to_string() -> String:
	return str(to_dict())

func get_palyer_role_result_message() -> String:
	if rid == 0:
		return "Вы ни чего не получили"
	else:
		return 'Вы получили «%s»' % role_name

func get_probiv() -> String:
	var res_format = [player_name, balance, request, request_result]
	if rid == 0:
		res_format.append("Отсуствует")
	else:
		res_format.append(role_name)
	var res := '[{0}] Баланс: {1} Запрос: {2} Получил: {3} Роль: {4}'.format(res_format)
	return res

func is_can_make_request() -> bool:
	if rid in [-1, -4]:
		return false
	return true
