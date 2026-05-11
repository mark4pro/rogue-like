shader_type canvas_item;

uniform bool debug = false;
uniform float border_scale = 2.0;
uniform vec2 shadow_offset = vec2(-10.0, -10.0);
uniform vec4 color : source_color;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float shadow_scale = 1.5;
uniform bool disable_rotating = false;
uniform int blur_kernel_max : hint_range(1, 24) = 8;
uniform bool disable_shadow = false;

varying flat vec4 modulate;
varying flat float sprite_rotation;
varying flat float final_scale;

void vertex() {
	final_scale = max(border_scale, shadow_scale);
	VERTEX.xy *= final_scale;
	modulate = COLOR;
	sprite_rotation = atan(MODEL_MATRIX[0][1], MODEL_MATRIX[0][0]);
}

vec4 sample_texture_safe(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		return vec4(0.0);
	return texture(tex, uv);
}

vec4 apply_gaussian_blur(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		return vec4(0.0);

	vec2 texel = 1.0 / vec2(textureSize(tex, 0)) * blur_amount;
	int kernel_size = min(int(blur_amount * 2.0), blur_kernel_max);
	float inv_sigma = -0.5 / (blur_amount * blur_amount);

	// Precompute symmetric 1D weights — exp() called k+1 times not (2k+1)²
	const int MAX_K = 24;
	float weights[MAX_K + 1];
	for (int i = 0; i <= MAX_K; i++) {
		float f = float(i);
		weights[i] = (i <= kernel_size) ? exp(f * f * inv_sigma) : 0.0;
	}

	vec4 color_blur = vec4(0.0);
	float total_weight = 0.0;
	for (int x = -MAX_K; x <= MAX_K; x++) {
		if (abs(x) > kernel_size) continue;
		float wx = weights[abs(x)];
		for (int y = -MAX_K; y <= MAX_K; y++) {
			if (abs(y) > kernel_size) continue;
			float weight = wx * weights[abs(y)];
			vec2 sample_uv = uv + vec2(float(x), float(y)) * texel;
			total_weight += weight;
			if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 &&
				sample_uv.y >= 0.0 && sample_uv.y <= 1.0)
				color_blur += texture(tex, sample_uv) * weight;
		}
	}

	if (total_weight <= 0.0) return vec4(0.0);
	return clamp(color_blur / total_weight, 0.0, 1.0);
}

vec2 rotate_point(vec2 point, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(point.x * c - point.y * s, point.x * s + point.y * c);
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
}
