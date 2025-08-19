const std = @import("std");
const c = @import("../../c.zig");

const math = @import("../../math.zig");
const vk_img = @import("../vk_image.zig");
const vk_descriptor = @import("../vk_descriptor.zig");
const vk_buffer = @import("../vk_buffer.zig");
const vk_renderer = @import("../vk_renderer.zig");

pub const TextureUniform = struct {
    diffuse_color: math.Vec4 = undefined,
    // reserved_0: math.Vec4 = undefined,
    // reserved_1: math.Vec4 = undefined,
    // reserved_2: math.Vec4 = undefined,
};

pub const Texture = struct {
    images: []vk_img.TextureImage = undefined,
    descriptor: vk_descriptor.Descriptor = undefined,
    uniform: TextureUniform = undefined,
    buffer: vk_buffer.Buffer(TextureUniform) = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        context: *vk_renderer.VkRenderer,
    ) !void {
        // TODO: create a structure to load texture
        var texture = vk_img.TextureImage{};
        // defer texture.deinit(context.vk_allocator, context.device.handle);
        try texture.init(
            "assets/textures" ++ "/texture_01.png",
            context.vk_allocator,
            context.device.handle,
            context.device.graphics_queue.queue,
            context.swapchain.getCurrentFrame().cmd_pool,
        );

        const textures = [_]vk_img.TextureImage{texture};
        self.images = try allocator.dupe(vk_img.TextureImage, textures[0..]);

        var texture_descriptor_pool_size = [_]c.VkDescriptorPoolSize{
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                // .descriptorCount = @intCast(self.images.items.len),
                .descriptorCount = @intCast(self.images.len),
            },
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                // .descriptorCount = @intCast(self.images.items.len),
                .descriptorCount = @intCast(self.images.len),
            },
        };

        var texture_descriptor_layout_binding = std.ArrayList(c.VkDescriptorSetLayoutBinding).init(allocator);
        defer texture_descriptor_layout_binding.deinit();

        try texture_descriptor_layout_binding.append(c.VkDescriptorSetLayoutBinding{
            .binding = @intCast(texture_descriptor_layout_binding.items.len),
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        });

        for (0..self.images.len) |i| {
            const layout_binding = c.VkDescriptorSetLayoutBinding{
                .binding = @intCast(texture_descriptor_layout_binding.items.len),
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            };

            try texture_descriptor_layout_binding.append(layout_binding);

            self.images[i].descriptor_binding = layout_binding.binding;
        }

        try self.descriptor.init(
            context.device.handle,
            @intCast(self.images.len),
            &texture_descriptor_pool_size,
            texture_descriptor_layout_binding.items,
        );

        self.uniform = TextureUniform{
            .diffuse_color = math.Vec4.init(1.0, 1.0, 1.0, 1.0),
        };

        try self.buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(TextureUniform),
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VMA_MEMORY_USAGE_AUTO,
            null,
        );
    }

    pub fn deinit(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) void {
        for (0..self.images.len) |i| {
            self.images[i].deinit(
                context.vk_allocator,
                context.device.handle,
            );
        }
        self.buffer.deinit(context.vk_allocator);

        self.descriptor.deinit(context.device.handle);
    }

    pub fn render(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) !void {
        try self.buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.uniform,
            @sizeOf(TextureUniform),
            context.device.graphics_queue.queue,
            context.swapchain.getCurrentFrame().cmd_pool,
        );
    }
};
