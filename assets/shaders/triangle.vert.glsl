#version 460 core

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_uv; // texture coordinates
layout(location = 2) in vec2 in_color;
layout(location = 3) in vec2 in_normal;

layout(set = 0, binding = 0) uniform uniform_object {
    mat4 projection;
    mat4 view;
} camera_uniform;

layout(push_constant) uniform push_constants {
    mat4 model_matrix;
} m_push_constants;

layout(location = 0) out vec2 out_uv;

void main()
{
    gl_Position = camera_uniform.projection * camera_uniform.view * m_push_constants.model_matrix * vec4(in_position, 1.0);
    out_uv = in_uv;
}
