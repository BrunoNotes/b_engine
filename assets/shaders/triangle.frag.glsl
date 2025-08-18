#version 460 core

layout(location = 0) in vec2 in_uv; // texture coordinates

layout(location = 0) out vec4 out_color;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
} uniform_obj;

layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

void main()
{
    out_color = uniform_obj.diffuse_color * texture(diffuse_sampler, in_uv);
    // out_color = texture(diffuse_sampler, in_uv);
}
