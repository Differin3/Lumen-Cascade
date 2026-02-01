shader_type canvas_item;
render_mode unshaded;

uniform float strength = 0.015; // 0..0.05
uniform float speed = 2.0; // скорость волн
uniform float freq = 18.0; // частота волн

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * freq + TIME * speed) * strength;
	uv.y += cos(uv.x * (freq * 0.6) + TIME * (speed * 0.7)) * (strength * 0.4);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
