shader_type canvas_item;
render_mode unshaded;

// Goes on the CanvasGroup that holds all the tree multimeshes.
// The group renders the whole forest first, then this cuts holes in the result,
// so overlapping trees can't stack back up to opaque.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Pixel i = (x, y) world position in R and G. Filled from GDScript every frame.
uniform sampler2D cutout_data : filter_nearest, repeat_disable;
uniform int cutout_count = 0;
uniform float cutout_radius = 48.0;     // world pixels
uniform float cutout_softness = 24.0;   // fade width at the edge of the hole
uniform float cutout_alpha : hint_range(0.0, 1.0) = 0.25; // opacity left in the middle of a hole

varying vec2 world_pos;

void vertex() {
	// The group is a plain node, so MODEL_MATRIX is just its global transform
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float cutout_factor() {
	float f = 1.0;
	int count = min(cutout_count, textureSize(cutout_data, 0).x);
	for (int i = 0; i < count; i++) {
		vec2 p = texelFetch(cutout_data, ivec2(i, 0), 0).rg;
		f = min(f, smoothstep(cutout_radius - cutout_softness, cutout_radius, distance(world_pos, p)));
	}
	return mix(cutout_alpha, 1.0, f);
}

void fragment() {
	// Standard CanvasGroup read-back (the buffer is premultiplied)
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR *= c;
	COLOR.a *= cutout_factor();
}
