shader_type canvas_item;

uniform vec4 fill_color : source_color;
uniform vec4 outline_color : source_color;
uniform float radius = 8.0;
uniform float outline_width = 2.0;
uniform vec2 rect_size;

void fragment() {
    // Convert UV (0..1) to pixel coordinates
    vec2 p = UV * rect_size;

    // Distance to nearest edge
    vec2 q = min(p, rect_size - p);
    float dist = min(q.x, q.y);

    float inner = radius;
    float outer = radius + outline_width;

    if (dist > outer) {
        discard;
    } else if (dist > inner) {
        COLOR = outline_color;
    } else {
        COLOR = fill_color;
    }
	COLOR = vec4(1.0, 0.0, 0.0, 1.0);
}
