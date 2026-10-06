// Shared by mutation.gdshader and mutation_shadow.gdshader (see mutation.gd).
// Recolours with a palette built from one colour, keeping the original shading: shadows go to a
// deep, slightly cooler shade, mid tones to the colour, highlights to a pale warmer tint, so any
// colour still reads like a real material. A soft sheen sweeps across. Prismatic cycles the rainbow.

uniform vec4 base_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform bool prismatic = false;
uniform float sheen : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;

vec3 mut_rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 mut_hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 mutate(vec3 col, vec2 uv) {
	// Most weapon sprites are fairly dark, so lift the tones a little before mapping
	float l = pow(clamp(dot(col, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.75);
	vec3 base = base_color.rgb;
	if (prismatic) {
		base = mut_hsv2rgb(vec3(fract(TIME * 0.15 + uv.x * 0.6 + uv.y * 0.3 + seed), 0.75, 1.0));
	}
	vec3 bh = mut_rgb2hsv(base);
	vec3 dark = mut_hsv2rgb(vec3(fract(bh.x - 0.04), min(bh.y * 1.1, 1.0), 0.18));
	vec3 light = mut_hsv2rgb(vec3(fract(bh.x + 0.03), bh.y * 0.3, 1.0));
	const float PIVOT = 0.4;
	vec3 mapped = l < PIVOT ? mix(dark, base, l / PIVOT) : mix(base, light, (l - PIVOT) / (1.0 - PIVOT));
	vec3 result = mix(col, mapped, strength);
	float band = smoothstep(0.07, 0.0, abs(fract(uv.x + uv.y - TIME * 0.35 + seed) - 0.5));
	return result + band * sheen;
}
