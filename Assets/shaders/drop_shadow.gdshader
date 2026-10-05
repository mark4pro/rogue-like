shader_type canvas_item;

uniform bool debug = false;
uniform float border_scale = 2.0;
uniform vec2 shadow_offset = vec2(-10.0, -10.0);
uniform vec4 color : source_color;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float shadow_scale = 1.5;
uniform bool disable_rotating = false;
uniform bool disable_shadow = false;

// Cutouts (filled from GDScript every frame).
// Positions live in a 1-pixel-tall float texture: pixel i = (x, y) in R and G.
uniform sampler2D cutout_data : filter_nearest, repeat_disable;
uniform int cutout_count = 0;
uniform float cutout_radius = 48.0;     // world pixels
uniform float cutout_softness = 24.0;   // fade width at the edge of the hole
uniform float cutout_alpha : hint_range(0.0, 1.0) = 0.25; // how see-through the middle gets (0 = fully gone)

varying flat vec4 modulate;
varying flat float sprite_rotation;
varying flat float final_scale;
varying vec2 world_pos;

void vertex() {
	final_scale = max(border_scale, shadow_scale);
	VERTEX.xy *= final_scale;
	modulate = COLOR;
	sprite_rotation = atan(MODEL_MATRIX[0][1], MODEL_MATRIX[0][0]);
	// Same space as Node2D.global_position (includes the multimesh instance transform)
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec4 sample_texture_safe(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		return vec4(0.0);
	return texture(tex, uv);
}

vec4 apply_gaussian_blur(sampler2D tex, vec2 uv) {
	if (blur_amount <= 0.0)
		return sample_texture_safe(tex, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		return vec4(0.0);

	vec2 texel = 1.0 / vec2(textureSize(tex, 0)) * blur_amount;

	vec4 c = vec4(0.0);
	float tw = 0.0;

	// center
	c += texture(tex, uv) * 0.2270;
	tw += 0.2270;

	vec2 o1 = vec2(texel.x, 0.0);
	vec2 o2 = vec2(0.0, texel.y);
	c += (sample_texture_safe(tex, uv + o1) + sample_texture_safe(tex, uv - o1)) * 0.1945;
	c += (sample_texture_safe(tex, uv + o2) + sample_texture_safe(tex, uv - o2)) * 0.1945;
	tw += 0.1945 * 4.0;

	vec2 o3 = vec2(texel.x * 2.0, 0.0);
	vec2 o4 = vec2(0.0, texel.y * 2.0);
	c += (sample_texture_safe(tex, uv + o3) + sample_texture_safe(tex, uv - o3)) * 0.1210;
	c += (sample_texture_safe(tex, uv + o4) + sample_texture_safe(tex, uv - o4)) * 0.1210;
	tw += 0.1210 * 4.0;

	vec2 d1 = vec2( texel.x,  texel.y);
	vec2 d2 = vec2(-texel.x,  texel.y);
	c += (sample_texture_safe(tex, uv + d1) + sample_texture_safe(tex, uv - d1)) * 0.0833;
	c += (sample_texture_safe(tex, uv + d2) + sample_texture_safe(tex, uv - d2)) * 0.0833;
	tw += 0.0833 * 4.0;

	return clamp(c / tw, 0.0, 1.0);
}

vec2 rotate_point(vec2 point, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(point.x * c - point.y * s, point.x * s + point.y * c);
}

// 1.0 = untouched, cutout_alpha = in the middle of a hole
float cutout_factor() {
	float f = 1.0;
	int count = min(cutout_count, textureSize(cutout_data, 0).x);
	for (int i = 0; i < count; i++) {
		vec2 p = texelFetch(cutout_data, ivec2(i, 0), 0).rg;
		float d = distance(world_pos, p);
		f = min(f, smoothstep(cutout_radius - cutout_softness, cutout_radius, d));
	}
	return mix(cutout_alpha, 1.0, f);
}

void fragment() {
	vec2 sprite_uv = (UV - 0.5) * final_scale + 0.5;
	vec4 main_texture = sample_texture_safe(TEXTURE, sprite_uv) * modulate;

	if (disable_shadow) {
		COLOR = main_texture;
	} else {
		vec2 adjusted_offset = disable_rotating
			? shadow_offset
			: rotate_point(shadow_offset, -sprite_rotation);
		vec2 shadow_uv = sprite_uv + adjusted_offset * TEXTURE_PIXEL_SIZE;

		vec4 blurred = blur_amount > 0.0
			? apply_gaussian_blur(TEXTURE, shadow_uv)
			: sample_texture_safe(TEXTURE, shadow_uv);
		vec4 shadow = vec4(color.rgb, blurred.a * color.a * modulate.a);

		vec4 res = mix(shadow, main_texture, main_texture.a);
		COLOR = debug ? mix(vec4(1.0, 0.0, 0.0, 0.3), res, res.a) : res;
	}

	// Fade canopy and its shadow together so the hole doesn't reveal a dark blob
	COLOR.a *= cutout_factor();
}
