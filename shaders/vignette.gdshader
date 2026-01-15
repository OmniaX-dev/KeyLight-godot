shader_type canvas_item;

uniform float top_height : hint_range(0.0, 1.0) = 0.25;
uniform float bottom_height : hint_range(0.0, 1.0) = 0.25;

uniform float top_softness : hint_range(0.0, 1.0) = 0.2;
uniform float bottom_softness : hint_range(0.0, 1.0) = 0.2;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    float y = UV.y;

    // Top gradient: fades from black at y=0 downward
    float top_grad = smoothstep(0.0, top_height, y);
    top_grad = 1.0 - top_grad; // invert so black is at the top
    top_grad = smoothstep(0.0, top_softness, top_grad);

    // Bottom gradient: fades from black at y=1 upward
    float bottom_grad = smoothstep(1.0 - bottom_height, 1.0, y);
    bottom_grad = smoothstep(0.0, bottom_softness, bottom_grad);

    // Combine both gradients
    float vignette = max(top_grad, bottom_grad);

    COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
