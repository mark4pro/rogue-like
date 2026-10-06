shader_type canvas_item;

// Mutated weapons on plain sprites and icons (see mutation.gd / mutation.gdshaderinc)
#include "res://Assets/shaders/mutation.gdshaderinc"

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mutate(c.rgb, UV);
	COLOR = c;
}
