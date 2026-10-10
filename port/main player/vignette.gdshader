shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float brightness : hint_range(-1, 1) = 0;
uniform float contrast : hint_range(0, 3) = 1.0;
uniform float saturation : hint_range(0, 3) = 1.0;
uniform bool preserve_shell_colors = false;

uniform float redVal : hint_range(0, 1) = 1.0;
uniform float greenVal : hint_range(0, 1) = 1.0;
uniform float blueVal : hint_range(0, 1) = 1.0;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_effect_factor : hint_range(0, 1) = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

//———————————————
//CONTRAST
//———————————————
mat4 contrastMatrix(float _contrast) {
    float t = (1.0 - _contrast) / 2.0;
    return mat4(
        vec4(_contrast, 0, 0, 0),
        vec4(0, _contrast, 0, 0),
        vec4(0, 0, _contrast, 0),
        vec4(t, t, t, 1)
    );
}
//———————————————
//BRIGHTNESS
//———————————————
mat4 brightnessMatrix(float _brightness) {
    return mat4(
        vec4(1, 0, 0, 0),
        vec4(0, 1, 0, 0),
        vec4(0, 0, 1, 0),
        vec4(_brightness, _brightness, _brightness, 1)
    );
}
//———————————————
//SATURATION
//———————————————
mat4 saturationMatrix(float _saturation) {
    vec3 luminance = vec3(0.3086, 0.6094, 0.0820);
    float oneMinusSat = 1.0 - _saturation;
    
    vec3 red = vec3(luminance.x * oneMinusSat);
    red += vec3(_saturation, 0, 0) * redVal;
    vec3 green = vec3(luminance.y * oneMinusSat);
    green += vec3(0, _saturation, 0) * greenVal;
    vec3 blue = vec3(luminance.z * oneMinusSat);
    blue += vec3(0, 0, _saturation) * blueVal;
    
    return mat4(vec4(red, 0), vec4(green, 0), vec4(blue, 0), vec4(0, 0, 0, 1));
}

//———————————————
//fragment
//———————————————
void fragment() {
    vec4 c = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec4 c2 = c * tint_color;
    float local_saturation = saturation;
    if (preserve_shell_colors) {
        bool red_casing = c.r - max(c.g, c.b) > 0.10;
        bool blue_casing = c.b - max(c.r, c.g) > 0.08;
        if (red_casing || blue_casing) {
            local_saturation = max(saturation, 0.95);
        }
    }
    vec4 source = mix(c, c2, tint_effect_factor);
    float output_brightness = brightness;
    if (preserve_shell_colors) {
        // Compatibility already renders a brighter scene; avoid adding grey to black.
        source.rgb *= local_saturation > saturation ? 1.0 : 0.70;
        output_brightness = brightness - 0.15;
    }
    COLOR = brightnessMatrix(output_brightness) * contrastMatrix(contrast) * saturationMatrix(local_saturation) * source;
}
