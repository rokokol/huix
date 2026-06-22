#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Перевод изображения экрана в оттенки серого (коэффициенты яркости Rec. 709).
void main() {
    vec4 color = texture(tex, v_texcoord);
    float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(gray), color.a);
}
