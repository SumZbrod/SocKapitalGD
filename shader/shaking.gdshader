shader_type canvas_item;

void vertex() {
	float world_pos_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
	vec2 local_pos = VERTEX;
    local_pos.y += sin(TIME * 2. + world_pos_x) * 5.;
    VERTEX = local_pos;
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
