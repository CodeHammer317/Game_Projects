shader_type canvas_item;

uniform float ghost_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    // Get the sprite’s texture color
    vec4 tex = texture(TEXTURE, UV);

    // Semi‑transparency control
    tex.a *= ghost_alpha;

    // Add a soft glow by brightening bright areas
    vec3 glow = tex.rgb * glow_strength;
    tex.rgb += glow;

    COLOR = tex;
}