shader_type spatial;

uniform sampler2D diffuse_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D back_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_nearest, repeat_disable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

// Cornea/specular
uniform float cornea_radius : hint_range(0.0, 1.0) = 0.35;
uniform float cornea_sharpness : hint_range(1.0, 32.0) = 8.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 1.0;
uniform float specular_shininess : hint_range(1.0, 256.0) = 128.0;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Wetness rim around cornea
uniform float wetness : hint_range(0.0, 1.0) = 0.4;
uniform float wetness_falloff : hint_range(1.0, 16.0) = 4.0;

varying vec3 world_normal;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 sphere_uv(vec3 pos) {
	vec3 n = normalize(pos);
	// Project from front face: just use X and Y of the normal directly
	// This maps the texture as a flat circle on the front of the sphere
	return vec2(n.x, -n.y) * 0.5 + 0.5;
}

void fragment() {
	vec3 n = normalize(local_pos);
	vec2 uv = sphere_uv(local_pos);

	vec4 diff_front = texture(diffuse_texture, uv);
	
	// Back hemisphere uses mirrored X so it doesn't flip
	vec2 back_uv = vec2(-n.x, -n.y) * 0.5 + 0.5;
	vec4 diff_back = texture(back_texture, back_uv);

	// Blend at the equator
	float facing = smoothstep(-0.5, -1, n.z);
	vec4 diff = mix(diff_back, diff_front, facing);

	// Normal map — sample and unpack, then blend by normal_strength
	vec3 nm = texture(normal_map, uv).xyz * 2.0 - 1.0;
	nm.xy *= normal_strength;
	nm = normalize(nm);

	// Tangent frame for planar-front projection
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 bitangent = vec3(0.0, -1.0, 0.0);
	vec3 mapped_normal = normalize(
		nm.x * tangent +
		nm.y * bitangent +
		nm.z * n
	);
	// Transform to view space for Godot's spatial shader
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(mapped_normal, 0.0)).xyz);

	// Cornea mask — based on angular distance from front of sphere
	// local_pos.z assumed to be the forward axis; adjust if your sphere faces differently
	float cornea_dot = dot(normalize(local_pos), vec3(0.0, 0.0, 1.0));
	float cornea_mask = smoothstep(
		cornea_radius - 0.05,
		cornea_radius + 0.05,
		cornea_dot
	);

	// Wetness: subtle specular rim just outside cornea edge
	float wetness_ring = pow(
		smoothstep(cornea_radius - 0.1, cornea_radius, cornea_dot) *
		(1.0 - smoothstep(cornea_radius, cornea_radius + 0.15, cornea_dot)),
		wetness_falloff
	);

	// Specular strength: high on cornea, slight wetness ring outside
	float spec = mix(0.05, specular_strength, cornea_mask);
	spec = max(spec, wetness * wetness_ring);

	// Roughness: cornea is smooth, sclera is slightly rough
	float roughness = mix(0.6, 0.05, cornea_mask);
	
	ALBEDO = diff.rgb;
	NORMAL = view_normal;
	SPECULAR = spec;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
