#version 460 core

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec2 in_texture_coord;

// layout(location = 0) out vec3 out_color;
// vec3 triangle_colors[4] = vec3[](
//         vec3(1.0, 0.0, 0.0),
//         vec3(0.0, 1.0, 0.0),
//         vec3(0.0, 0.0, 1.0),
//         vec3(1.0, 0.0, 1.0)
//     );

layout(push_constant) uniform push_constants {
    mat4 model_matrix;
} u_push_constants;

layout(set = 0, binding = 0) uniform uniform_object {
    mat4 projection;
    mat4 view;
} camera_uniform;

layout(location = 0) out struct dto {
    vec2 texture_coord;
} out_dto;

void main()
{
    // gl_Position = vec4(in_position, 1.0);
    // out_color = triangle_colors[gl_VertexIndex % 4];
    gl_Position = camera_uniform.projection * camera_uniform.view * u_push_constants.model_matrix * vec4(in_position, 1.0);
    out_dto.texture_coord = in_texture_coord;
}
