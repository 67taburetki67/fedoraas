#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec4 c = texture(tex, v_texcoord);
  float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  g = (g - 0.5) * 0.9 + 0.47;
  float v = distance(v_texcoord, vec2(0.5));
  g *= 1.0 - v * v * 0.7;
  g += (hash(floor(v_texcoord * vec2(1920.0, 1080.0))) - 0.5) * {{GRAIN}};
  vec3 tinted = vec3(g) * vec3({{TINT}});
  fragColor = vec4(mix(tinted, c.rgb, {{SAT}}), c.a);
}
