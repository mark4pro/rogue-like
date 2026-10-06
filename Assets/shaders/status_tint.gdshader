shader_type canvas_item;

// Status effect tint (StatusVisuals): blends the sprite toward a colour while keeping its shading,
// so a green goo can still look properly orange when it burns (a plain multiply can't do that).
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint_color.rgb * (0.35 + luma * 0.9);
	c.rgb = mix(c.rgb, tinted, tint_amount);
	COLOR = c;
}
