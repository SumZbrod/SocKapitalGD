shader_type canvas_item;
varying vec2 world_pos_xy;

void vertex() {
	world_pos_xy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 local_pos = VERTEX;
    local_pos.y += sin(TIME + world_pos_xy.x-local_pos.x*.75) * 5.;
    VERTEX = local_pos;
}

float saw(float x){
	x = (1. - mod(x, 2.));
	return x * x;
}

void fragment() {
	float b = world_pos_xy.x - world_pos_xy.y;
	float a = 300.;
	b = saw(b/a+TIME*.5) * .1;
	COLOR = vec4(COLOR.r+b, COLOR.g+1.5*b, COLOR.b, COLOR.a);
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
