#version 460 core

// layout(location = 0) in vec3 in_color;
layout(location = 0) out vec4 out_color;
// layout(push_constant) uniform PushConstants
// {
//     vec4 color;
// } push_constants;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
} uniform_obj;

layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

// data transfer object
layout(location = 0) in struct dto {
    vec2 texture_coord;
} in_dto;

void main()
{
    // out_color = vec4(in_color, 1.0);
    // out_color = push_constants.color;
    out_color = uniform_obj.diffuse_color * texture(diffuse_sampler, in_dto.texture_coord);
}
