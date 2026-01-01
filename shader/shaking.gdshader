shader_type canvas_item;
varying vec2 world_pos_xy;
uniform int mode = 0; // 0 - normal 1 - sdelected 2 - deselected

float saw(float x){
	x = (1. - mod(x, 2.));
	return x * x;
}

void vertex() {
	world_pos_xy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 local_pos = VERTEX;
	if (mode==0) {
	    local_pos.y += sin(TIME + world_pos_xy.x-local_pos.x*.5) * 5.;
	}
	else if (mode==1) {
		float mag = (1.+saw(TIME)*.1);
		local_pos = mag*(local_pos -64.)+64.;
	}
	VERTEX = local_pos;
}

void fragment() {
	float b = world_pos_xy.x - world_pos_xy.y;
	float a = 300.;
	b = saw(b/a+TIME*.5) * .1;
	if (mode==0) {
		COLOR = vec4(COLOR.r+b, COLOR.g+1.5*b, COLOR.b, COLOR.a);
	}
	else if (mode == 2){
		float grad = (COLOR.r + COLOR.g + COLOR.b) * .2;  
		COLOR = vec4(vec3(grad), COLOR.a);
	}
}
