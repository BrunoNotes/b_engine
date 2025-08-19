const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../../c.zig");
const util = @import("../../util.zig");
const vk_types = @import("../vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const vk_renderer = @import("../vk_renderer.zig");
const vk_pipeline = @import("../vk_pipeline.zig");
const vk_descriptor = @import("../vk_descriptor.zig");
const vk_buffer = @import("../vk_buffer.zig");
const vk_img = @import("../vk_image.zig");
const vk_shader = @import("../vk_shader.zig");
const math = @import("../../math.zig");

const cam = @import("camera.zig");
const tex = @import("texture.zig");

// TODO: temp
pub const PushConstant = struct {
    model_matrix: math.Mat4 = undefined,
};

// TODO: temp
pub const Model = struct {
    pipeline: vk_pipeline.Pipeline = undefined,
    shader_stages: vk_shader.ShaderStages = undefined,
    vertex_descriptor: vk_descriptor.Descriptor = undefined,
    vertices: []vk_types.Vertex = undefined,
    vertex_buffer: vk_buffer.Buffer(vk_types.Vertex) = undefined,
    indices: []u32 = undefined,
    index_buffer: vk_buffer.Buffer(u32) = undefined,

    texture: tex.Texture = undefined,

    push_constant: PushConstant = undefined,

    camera: cam.Camera,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        context: *vk_renderer.VkRenderer,
    ) !void {
        std.log.info("Model init", .{});

        const shader_folder = "assets/shaders/bin";

        var shader_stage_type = [_]vk_shader.ShaderStageType{
            .{
                .path = shader_folder ++ "/triangle.vert.spv",
                .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                .type = vk_shader.ShaderType.vert,
            },
            .{
                .path = shader_folder ++ "/triangle.frag.spv",
                .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .type = vk_shader.ShaderType.frag,
            },
        };

        try self.shader_stages.init(
            allocator,
            context.device.handle,
            &shader_stage_type,
        );

        var vertex_descriptor_pool_size = [_]c.VkDescriptorPoolSize{
            .{
                .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = @intCast(context.swapchain.images.len),
            },
        };

        var vertex_descriptor_layout_binding = [_]c.VkDescriptorSetLayoutBinding{
            c.VkDescriptorSetLayoutBinding{
                .binding = 0,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
                .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
            },
        };

        try self.vertex_descriptor.init(
            context.device.handle,
            @intCast(context.swapchain.images.len),
            &vertex_descriptor_pool_size,
            &vertex_descriptor_layout_binding,
        );

        try self.texture.init(allocator, context);

        var descritor_set_layout = [_]c.VkDescriptorSetLayout{
            self.vertex_descriptor.set_layout,
            self.texture.descriptor.set_layout,
        };

        var push_constant_range = [_]c.VkPushConstantRange{
            c.VkPushConstantRange{
                .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                .offset = @sizeOf(math.Mat4) * 0,
                .size = @sizeOf(math.Mat4) * 2,
            },
        };

        var attribute_descriptions = [_]c.VkVertexInputAttributeDescription{
            c.VkVertexInputAttributeDescription{
                .location = 0,
                .binding = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(vk_types.Vertex, "position"),
            },
            c.VkVertexInputAttributeDescription{
                .location = 1,
                .binding = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(vk_types.Vertex, "uv"),
            },
            c.VkVertexInputAttributeDescription{
                .location = 2,
                .binding = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(vk_types.Vertex, "color"),
            },
            c.VkVertexInputAttributeDescription{
                .location = 3,
                .binding = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(vk_types.Vertex, "normal"),
            },
        };

        try self.pipeline.init(
            context.device.handle,
            context.swapchain.image_format,
            false, // TODO: make this configurable
            self.shader_stages,
            &push_constant_range,
            &descritor_set_layout,
            &attribute_descriptions,
        );

        var vertices: [4]vk_types.Vertex = undefined;
        vertices[0].position = .{ .x = -0.5, .y = -0.5, .z = 0.0 };
        vertices[0].uv = .{ .x = 0.0, .y = 0.0 };
        vertices[1].position = .{ .x = 0.5, .y = 0.5, .z = 0.0 };
        vertices[1].uv = .{ .x = 1.0, .y = 1.0 };
        vertices[2].position = .{ .x = -0.5, .y = 0.5, .z = 0.0 };
        vertices[2].uv = .{ .x = 0.0, .y = 1.0 };
        vertices[3].position = .{ .x = 0.5, .y = -0.5, .z = 0.0 };
        vertices[3].uv = .{ .x = 1.0, .y = 0.0 };
        // self.vertices = &vertices;
        // for slices the caller must own the memory
        self.vertices = try allocator.dupe(vk_types.Vertex, vertices[0..]);

        try self.vertex_buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(vk_types.Vertex) * self.vertices.len,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VMA_MEMORY_USAGE_GPU_ONLY,
            null,
        );

        const indices = [_]u32{ 0, 1, 2, 0, 3, 1 };
        self.indices = try allocator.dupe(u32, indices[0..]);

        try self.index_buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(u32) * self.indices.len,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            c.VMA_MEMORY_USAGE_GPU_ONLY,
            null,
        );

        self.camera.position = math.Vec3.init(0, 0, 2);
        self.camera.FOV = 70;
        try self.camera.init(context);
    }

    pub fn deinit(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) void {
        self.camera.deinit(context);
        self.texture.deinit(context);
        self.index_buffer.deinit(context.vk_allocator);
        self.vertex_buffer.deinit(context.vk_allocator);

        self.pipeline.deinit(context.device.handle);
        self.shader_stages.deinit(context.device.handle);
        self.vertex_descriptor.deinit(context.device.handle);

        std.log.info("Model deinit", .{});
    }

    pub fn render(
        self: *@This(),
        allocator: std.mem.Allocator,
        context: *vk_renderer.VkRenderer,
    ) !void {
        const cmd = context.swapchain.getCurrentFrame().cmd_buffer;
        const cmd_pool = context.swapchain.getCurrentFrame().cmd_pool;
        const queue = context.device.graphics_queue.queue;

        // dymanic state updates ----------------------
        self.pipeline.setDynamicUpdates(cmd, context.window_extent);
        self.pipeline.bind(cmd, c.VK_PIPELINE_BIND_POINT_GRAPHICS);

        try self.vertex_buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.vertices.ptr[0..self.vertices.len],
            @sizeOf(vk_types.Vertex) * self.vertices.len,
            queue,
            cmd_pool,
        );

        try self.index_buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.indices,
            @sizeOf(u32) * self.indices.len,
            queue,
            cmd_pool,
        );

        try self.texture.render(context);

        try self.camera.render(context);

        // TODO: check if it needs to update
        var descritor_write = std.ArrayList(c.VkWriteDescriptorSet).init(allocator);
        defer descritor_write.deinit();

        // ----- Vertex -----
        var vertex_buffer_info = c.VkDescriptorBufferInfo{
            .buffer = self.camera.buffer.handle,
            .offset = 0,
            .range = @sizeOf(@TypeOf(self.camera.uniform)),
        };
        try descritor_write.append(c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = self.vertex_descriptor.set,
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &vertex_buffer_info,
        });
        // ----- Vertex -----

        // ----- Texture -----
        // TODO: move this to the Texture struct
        var texture_buffer_info = c.VkDescriptorBufferInfo{
            .buffer = self.texture.buffer.handle,
            .offset = 0,
            .range = @sizeOf(@TypeOf(self.texture.uniform)),
        };
        try descritor_write.append(c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = self.texture.descriptor.set,
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &texture_buffer_info,
        });

        for (self.texture.images) |img| {
            const image_info = c.VkDescriptorImageInfo{
                .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                .imageView = img.image.view,
                .sampler = img.sampler,
            };

            try descritor_write.append(c.VkWriteDescriptorSet{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = self.texture.descriptor.set,
                .dstBinding = img.descriptor_binding,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .pImageInfo = &image_info,
            });
        }
        // ----- Texture -----

        var descriptors_sets = [_]c.VkDescriptorSet{
            self.vertex_descriptor.set,
            self.texture.descriptor.set,
        };

        c.vkUpdateDescriptorSets(
            context.device.handle,
            @intCast(descritor_write.items.len),
            descritor_write.items.ptr,
            0,
            0,
        );

        c.vkCmdBindDescriptorSets(
            cmd,
            c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            self.pipeline.layout,
            0,
            @intCast(descriptors_sets.len),
            &descriptors_sets,
            0,
            0,
        );

        var offset: c.VkDeviceSize = 0;
        c.vkCmdBindVertexBuffers(cmd, 0, 1, &self.vertex_buffer.handle, &offset);

        c.vkCmdBindIndexBuffer(cmd, self.index_buffer.handle, offset, c.VK_INDEX_TYPE_UINT32);

        c.vkCmdPushConstants(
            cmd,
            self.pipeline.layout,
            c.VK_SHADER_STAGE_VERTEX_BIT,
            0,
            @sizeOf(PushConstant),
            &self.push_constant,
        );

        c.vkCmdDrawIndexed(cmd, @intCast(self.indices.len), 1, 0, 0, 0);
    }
};
