shader_type canvas_item;

uniform float scroll_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 scrolled_uv = UV;
	scrolled_uv.x -= TIME * scroll_speed;
	COLOR = texture(TEXTURE, scrolled_uv);
}