shader_type canvas_item;

// Goes on the generated world's Ground TileMapLayer (set up from worldgen.gd).
// Blends floor types without hand-made transition tiles: every pixel looks up which
// floor types are around it (ground_mask, 1 texel per tile, filtered so it fades between
// tile centres), wobbles the border with noise, and draws the winning type's tile from the atlas.

uniform sampler2D ground_mask : filter_linear, repeat_disable; // channel i = weight of ground type i (up to 4 types)
uniform vec2 mask_size = vec2(300.0);    // world size in tiles
uniform vec2 tile_px = vec2(32.0);       // tile size in texture pixels
uniform vec2 type_tiles[4];              // atlas coords of each ground type's tile
uniform int type_count = 2;
// TileSetAtlasSource.use_texture_padding: Godot draws tiles from a copy of the atlas with a
// 1px border around every tile, so tile (x, y) starts at (x, y) * (tile + 2) + 1 in TEXTURE.
uniform float atlas_padding = 1.0;

uniform vec2 ground_origin = vec2(0.0);  // global position of the ground layer's origin
uniform vec2 ground_scale = vec2(1.0);   // global scale of the ground layer

uniform sampler2D edge_noise : filter_linear, repeat_enable;
uniform float noise_tex_px = 256.0;      // edge_noise size; sampled 1 texel per pixel (wobble size comes from the noise frequency)
uniform float noise_strength = 0.6;      // 0 = straight tile edges, ~1 = very ragged

varying vec2 world_pos;
varying vec4 tint;

void vertex() {
	// TileMapLayer draws in rendering quadrants, so go through MODEL_MATRIX for the real position
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec2 local_pos = (world_pos - ground_origin) / ground_scale;
	
	// Centre of the texture pixel this fragment is in, so every pixel maps to exactly one texel
	vec2 px = floor(local_pos) + 0.5;
	
	vec4 w = texture(ground_mask, (px / tile_px) / mask_size);
	
	// Strongest type wins after a per-type noise nudge.
	// A tile whose neighbours are all its own type has weight 1 for it everywhere, so it never changes.
	int best = 0;
	float best_v = -1e9;
	for (int i = 0; i < 4; i++) {
		if (i >= type_count) {
			break;
		}
		float n = texture(edge_noise, px / noise_tex_px + vec2(float(i) * 0.37, float(i) * 0.71)).r - 0.5;
		float v = w[i] + n * noise_strength;
		if (v > best_v) {
			best_v = v;
			best = i;
		}
	}
	
	// Same pixel of the winning type's tile, in the real (padded) texture Godot is drawing from
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 stride = tile_px + 2.0 * atlas_padding;
	vec2 in_tile = mod(px, tile_px);
	vec2 atlas_uv = (type_tiles[best] * stride + atlas_padding + in_tile) / tex_size;
	COLOR = texture(TEXTURE, atlas_uv) * tint;
}
