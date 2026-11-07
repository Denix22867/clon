shader_type spatial;
// Обводка «вывернутой оболочкой»: раздутая копия меша, видны только задние грани.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width = 0.022;
uniform vec4 color : source_color = vec4(0.09, 0.06, 0.05, 1.0);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
