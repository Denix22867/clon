// Общий мультяшный шейдер моделей: цвет из вершин, UV.x — сила свечения,
// две ступени освещения, мягкий контровой свет, вспышка при попадании.
#ifdef GHOST
render_mode blend_mix, cull_back, depth_draw_always, specular_disabled;
#else
render_mode blend_mix, cull_back, depth_draw_opaque, specular_disabled;
#endif

uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float rim_strength = 0.45;
uniform float glow_strength = 1.6;

varying float glow;

void vertex() {
	glow = UV.x;
}

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * glow * glow_strength + flash.rgb * flash.a + vec3(1.0, 0.88, 0.7) * rim * rim_strength * (1.0 - glow);
#ifdef GHOST
	ALPHA = tint.a * (0.55 + 0.45 * rim + glow * 0.3);
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.04, 0.04, ndl) * 0.62 + smoothstep(0.42, 0.5, ndl) * 0.38;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
