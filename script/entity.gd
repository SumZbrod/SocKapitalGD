@abstract class_name EntityClass
var ava_id: int
var pid
var player_name: String

func _init(pid_, player_name_, ava_id_):
	pid = pid_
	player_name = player_name_
	ava_id = ava_id_

func get_pid():
	return pid

func sync(player_dict:Dictionary):
	if pid != player_dict['pid']:
		push_warning("Replace player data from %d to %d" % [pid, player_dict['pid']])
	player_name = player_dict['player_name'] 
	ava_id = player_dict['ava_id'] 
	pid = player_dict['pid'] 

func get_player_name():
	return player_name
	
func to_dict() -> Dictionary:
	return {
		'pid': pid,
		'player_name': player_name,
		'ava_id': ava_id,
	}

func _to_string() -> String:
	return str(to_dict())

@abstract
func get_ava_rect() -> Rect2
