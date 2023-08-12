varying vec4 worldSpace;
uniform float fogStartRadius;
uniform float fogEndRadius;

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    worldSpace = vertex_position;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
    vec4 pixel = color * Texel(texture, tc);
    // Currently assumes the center of the fog is at (0, 0, 0)
    float l = length(worldSpace);
    if(l >= fogStartRadius) {
        pixel.a = pixel.a * map(l, fogStartRadius, fogEndRadius, 1, 0);
    }
    return pixel;
}
#endif