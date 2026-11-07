shader_type spatial;
// Мягкая тень под персонажем (на прозрачном фоне настоящая тень не видна).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.45;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.03, 0.02, 0.04);
	ALPHA = strength * (1.0 - smoothstep(0.35, 1.0, d));
}
