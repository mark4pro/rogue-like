shader_type canvas_item;

uniform bool debug = false;
uniform float border_scale = 2.0;
uniform vec2 shadow_offset = vec2(-10.0, -10.0);
uniform vec4 color : source_color;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float shadow_scale = 1.5;
uniform bool disable_rotating = false;
uniform int blur_kernel_max : hint_range(1, 24) = 8;

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
	if (blur_amount <= 0.0)
		return sample_texture_safe(tex, uv);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		return vec4(0.0);

	vec2 texel = 1.0 / vec2(textureSize(tex, 0)) * blur_amount;
	int kernel_size = min(int(blur_amount * 2.0), blur_kernel_max);
	float inv_sigma = -0.5 / (blur_amount * blur_amount);

	// Precompute 1D weights
	const int MAX_K = 24;
	float weights[MAX_K + 1];
	float weight_sum = 0.0;
	for (int i = 0; i <= MAX_K; i++) {
		if (i > kernel_size) {
			weights[i] = 0.0;
		} else {
			float f = float(i);
			weights[i] = exp(f * f * inv_sigma);
			weight_sum += (i == 0) ? weights[0] : weights[i] * 2.0;
		}
	}

	// Separable blur: horizontal pass
	vec4 h_blur[MAX_K * 2 + 1];
	float h_total = 0.0;
	// center
	vec4 h_center = (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)
		? texture(tex, uv) : vec4(0.0);
	// We'll just do the full separable inline
	// Horizontal accumulation stored per-row implicitly via two-pass approach

	// --- Horizontal pass ---
	vec4 h_result = vec4(0.0);
	float h_weight_total = 0.0;
	for (int x = -MAX_K; x <= MAX_K; x++) {
		if (abs(x) > kernel_size) continue;
		float w = weights[abs(x)];
		vec2 suv = uv + vec2(float(x) * texel.x, 0.0);
		h_weight_total += w;
		if (suv.x >= 0.0 && suv.x <= 1.0)
			h_result += texture(tex, suv) * w;
	}
	if (h_weight_total > 0.0) h_result /= h_weight_total;

	// --- Vertical pass on horizontal result ---
	// True two-pass needs a render target; best we can do in one pass is
	// sample the original tex vertically at each row and combine.
	vec4 color_blur = vec4(0.0);
	float total_weight = 0.0;
	for (int y = -MAX_K; y <= MAX_K; y++) {
		if (abs(y) > kernel_size) continue;
		float wy = weights[abs(y)];
		vec2 suv = uv + vec2(0.0, float(y) * texel.y);
		// Horizontal blur at this row
		vec4 row = vec4(0.0);
		float row_w = 0.0;
		for (int x = -MAX_K; x <= MAX_K; x++) {
			if (abs(x) > kernel_size) continue;
			float wx = weights[abs(x)];
			vec2 s2 = suv + vec2(float(x) * texel.x, 0.0);
			row_w += wx;
			if (s2.x >= 0.0 && s2.x <= 1.0 && s2.y >= 0.0 && s2.y <= 1.0)
				row += texture(tex, s2) * wx;
		}
		if (row_w > 0.0) row /= row_w;
		color_blur += row * wy;
		total_weight += wy;
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

	vec2 adjusted_offset = disable_rotating
		? shadow_offset
		: rotate_point(shadow_offset, -sprite_rotation);

	vec2 shadow_uv = sprite_uv + adjusted_offset * TEXTURE_PIXEL_SIZE;

	vec4 main_texture = sample_texture_safe(TEXTURE, sprite_uv) * modulate;

	vec4 blurred = apply_gaussian_blur(TEXTURE, shadow_uv);
	vec4 shadow = vec4(color.rgb, blurred.a * color.a * modulate.a);

	vec4 res = mix(shadow, main_texture, main_texture.a);
	COLOR = debug ? mix(vec4(1.0, 0.0, 0.0, 0.3), res, res.a) : res;
}
