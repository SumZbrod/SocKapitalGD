class_name RoleClass extends EntityClass

func get_ava_rect() -> Rect2:
	var r = 512
	var x = ava_id % 2
	@warning_ignore("integer_division")
	var y = ava_id % 2
	return Rect2(r*x+1024, r*y, r, r)
	
func _init(role_type:String):
	match role_type:
		"ksiva":
			super(-1, "Ksiva", 0)
