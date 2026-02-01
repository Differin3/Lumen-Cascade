shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest; // экран
uniform float aberration_px = 15.0; // смещение RGB в пикселях
uniform float vignette_strength = 0.18; // 0..1
uniform float grain_strength = 0.015; // 0..0.2
uniform float tear_strength = 0.0; // 0..0.05 (разрыв/глитч)
uniform float tear_speed = 6.0; // скорость разрыва
uniform float tear_lines = 220.0; // сколько "строк" по Y
uniform float sharpen_strength = 0.35; // 0..1 (резкость)
uniform float lens_strength = 0.0; // 0..0.12 (рыбий глаз при бусте)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
	vec2 off = px * aberration_px;

	// lens / fisheye (центр экрана)
	vec2 c = uv - vec2(0.5);
	float r2 = dot(c, c);
	uv = uv + c * r2 * lens_strength;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// tear/glitch: горизонтальные смещения по полосам
	float line = floor(uv.y * tear_lines);
	float rnd = hash(vec2(line, floor(TIME * tear_speed)));
	float band = step(0.92, rnd); // редкие полосы
	uv.x += (rnd - 0.5) * tear_strength * band;
	// без "волны", только резкие сдвиги

	vec4 c0 = texture(screen_tex, uv);
	float r = texture(screen_tex, uv + off).r;
	float g = c0.g;
	float b = texture(screen_tex, uv - off).b;
	vec3 col = vec3(r, g, b);

	// sharpen (unsharp mask)
	vec3 sN = texture(screen_tex, uv + vec2(0.0, -px.y)).rgb;
	vec3 sS = texture(screen_tex, uv + vec2(0.0,  px.y)).rgb;
	vec3 sW = texture(screen_tex, uv + vec2(-px.x, 0.0)).rgb;
	vec3 sE = texture(screen_tex, uv + vec2( px.x, 0.0)).rgb;
	vec3 blur = (sN + sS + sW + sE + col) / 5.0;
	col = mix(col, col + (col - blur), sharpen_strength);

	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.85, 0.45, d);
	col *= mix(1.0, vig, vignette_strength);

	float n = hash(uv * vec2(1234.0, 5678.0) + TIME);
	col += (n - 0.5) * grain_strength;

	COLOR = vec4(col, 1.0);
}
