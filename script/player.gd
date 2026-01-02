class_name PlayerClass extends EntityClass
var alive := true 
var ready_state := false 
var balance := 0 
var request := 0 
var request_result := 0 
var vote := {}
var place := 0
var subsidia

enum GAME_STATE {
	JOIN,
	REQUESTING,
	VOTING,
	ELIMINATING,
	GAMEEND,
}

func kill():
	alive = false

func get_ava_rect() -> Rect2:
	var r = 341
	var x = ava_id % 3
	@warning_ignore("integer_division")
	var y = ava_id / 3
	return Rect2(r*x, r*y, r, r)

func sync(player_dict:Dictionary):
	super(player_dict)
	alive = player_dict['alive'] 
	ready_state = player_dict['ready_state'] 
	balance = player_dict['balance'] 
	request = player_dict['request'] 
	request_result = player_dict['request_result'] 
	vote = player_dict['vote'] 
	place = player_dict['place'] 
	subsidia = player_dict['subsidia'] 

func to_dict() -> Dictionary:
	return {
		'pid': pid,
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
	}

func get_request() -> int:
	return request

func get_acc_info(state) -> Dictionary:
	var res := {}
	res['score'] = str(balance)
	match state:
		GAME_STATE.VOTING:
			res['name'] = player_name
			res['message'] = "Запросил: %d\n Получил: %d" % [request, request_result]
			if subsidia:
				res['message'] += '\n Субсидия: %d' % subsidia
	return res
