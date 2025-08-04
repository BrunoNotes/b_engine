const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const util = @import("../util.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const vk_renderer = @import("vk_renderer.zig");
const vk_pipeline = @import("vk_pipeline.zig");
const vk_descriptor = @import("vk_descriptor.zig");
const vk_buffer = @import("vk_buffer.zig");
const vk_img = @import("vk_image.zig");
const vk_shader = @import("vk_shader.zig");
const math = @import("../math.zig");

// TODO: temp
pub const CameraUniform = struct {
    projection: math.Mat4 = undefined, // 64 bytes
    view: math.Mat4 = undefined,
    model_matrix: math.Mat4 = undefined,
    // reserved_1: math.Mat4 = undefined,
};

pub const Camera = struct {
    velocity: math.Vec3 = math.Vec3.ZERO,
    position: math.Vec3 = math.Vec3.ZERO,
    pitch: f32 = 0, // vertical rotation
    yaw: f32 = 0, // horizontal rotation

    pub fn update(self: *@This()) void {
        const r = self.getRotationMatrix();
        const p = math.Vec4.init(
            self.position.x,
            self.position.y,
            self.position.z,
            0,
        );

        const result = math.Vec4.init(
            (r.data[0] * p.x) + (r.data[1] * p.y) + (r.data[2] * p.z) + (r.data[3] * p.w),
            (r.data[4] * p.x) + (r.data[5] * p.y) + (r.data[6] * p.z) + (r.data[7] * p.w),
            (r.data[8] * p.x) + (r.data[9] * p.y) + (r.data[10] * p.z) + (r.data[11] * p.w),
            (r.data[12] * p.x) + (r.data[13] * p.y) + (r.data[14] * p.z) + (r.data[15] * p.w),
        );
        _ = result;

        // self.position = math.Vec3.add(self.position, math.Vec3.init(result.x, result.y, result.z));

        // std.debug.print("{any}\n", .{self.position});
    }

    pub fn getRotationMatrix(self: *@This()) math.Mat4 {
        // TODO: use quaternions
        // const pitch = math.Quat.toRotationMatrix(
        //     math.Quat.fromAxisAngle(math.Vec3.RIGHT, self.pitch),
        //     math.Vec3.ZERO,
        // );
        // const yaw = math.Quat.toRotationMatrix(
        //     math.Quat.fromAxisAngle(math.Vec3.UP, self.yaw),
        //     math.Vec3.ZERO,
        // );
        // return math.Mat4.mult(pitch, yaw);

        // prevents gimble lock
        const limit = std.math.degreesToRadians(89);
        self.pitch = std.math.clamp(self.pitch, -limit, limit);

        return math.Mat4.eulerXYZ(self.pitch, self.yaw, 0);
    }

    pub fn getViewMatrix(self: *@This()) math.Mat4 {
        // _ = self;
        const rotation = self.getRotationMatrix();
        const translation = math.Mat4.translation(self.position);
        // std.debug.print("{any}\n", .{rotation});

        return math.Mat4.inverse(math.Mat4.mult(translation, rotation));
        // return math.Mat4.inverse(translation);
    }
};

// TODO: temp
pub const TextureUniform = struct {
    diffuse_color: math.Vec4 = undefined,
    // reserved_0: math.Vec4 = undefined,
    // reserved_1: math.Vec4 = undefined,
    // reserved_2: math.Vec4 = undefined,
};

// TODO: temp
pub const PushConstant = struct {
    model_matrix: math.Mat4 = undefined,
};

// TODO: temp
pub const VkTriangle = struct {
    pipeline: vk_pipeline.Pipeline = undefined,
    shader_stages: vk_shader.ShaderStages = undefined,
    vertex_descriptor: vk_descriptor.Descriptor = undefined,
    vertices: []vk_types.Vertex = undefined,
    vertex_buffer: vk_buffer.Buffer(vk_types.Vertex) = undefined,
    indices: []u32 = undefined,
    index_buffer: vk_buffer.Buffer(u32) = undefined,

    texture_images: []vk_img.TextureImage = undefined,
    texture_descriptor: vk_descriptor.Descriptor = undefined,
    texture_uniform: TextureUniform = undefined,
    texture_uniform_buffer: vk_buffer.Buffer(TextureUniform) = undefined,

    push_constant: PushConstant = undefined,

    camera: Camera,
    camera_uniforms: CameraUniform = undefined,
    camera_uniform_buffer: vk_buffer.Buffer(CameraUniform) = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        context: *vk_renderer.VkRenderer,
    ) !void {
        std.log.info("VkTriangle init", .{});

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
        self.texture_images = try allocator.dupe(vk_img.TextureImage, textures[0..]);

        var fragment_descriptor_pool_size = [_]c.VkDescriptorPoolSize{
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                // .descriptorCount = @intCast(self.images.items.len),
                .descriptorCount = @intCast(self.texture_images.len),
            },
            c.VkDescriptorPoolSize{
                .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                // .descriptorCount = @intCast(self.images.items.len),
                .descriptorCount = @intCast(self.texture_images.len),
            },
        };

        var fragment_descriptor_layout_binding = std.ArrayList(c.VkDescriptorSetLayoutBinding).init(allocator);
        defer fragment_descriptor_layout_binding.deinit();

        try fragment_descriptor_layout_binding.append(c.VkDescriptorSetLayoutBinding{
            .binding = @intCast(fragment_descriptor_layout_binding.items.len),
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        });

        for (0..self.texture_images.len) |i| {
            const layout_binding = c.VkDescriptorSetLayoutBinding{
                .binding = @intCast(fragment_descriptor_layout_binding.items.len),
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            };

            try fragment_descriptor_layout_binding.append(layout_binding);

            self.texture_images[i].descriptor_binding = layout_binding.binding;
        }

        try self.texture_descriptor.init(
            context.device.handle,
            @intCast(self.texture_images.len),
            &fragment_descriptor_pool_size,
            fragment_descriptor_layout_binding.items,
        );

        var descritor_set_layout = [_]c.VkDescriptorSetLayout{
            self.vertex_descriptor.set_layout,
            self.texture_descriptor.set_layout,
        };

        // var push_constant_range = [_]c.VkPushConstantRange{
        //     c.VkPushConstantRange{
        //         .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        //         .offset = @sizeOf(math.Mat4) * 0,
        //         .size = @sizeOf(math.Mat4) * 2,
        //     },
        // };

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
                .offset = @offsetOf(vk_types.Vertex, "texture_coord"),
            },
        };

        try self.pipeline.init(
            context.device.handle,
            context.swapchain.image_format,
            false, // TODO: make this configurable
            self.shader_stages,
            // &push_constant_range,
            null,
            &descritor_set_layout,
            &attribute_descriptions,
        );

        var vertices: [4]vk_types.Vertex = undefined;
        vertices[0].position = .{ .x = -0.5, .y = -0.5, .z = 0.0 };
        vertices[0].texture_coord = .{ .x = 0.0, .y = 0.0 };
        vertices[1].position = .{ .x = 0.5, .y = 0.5, .z = 0.0 };
        vertices[1].texture_coord = .{ .x = 1.0, .y = 1.0 };
        vertices[2].position = .{ .x = -0.5, .y = 0.5, .z = 0.0 };
        vertices[2].texture_coord = .{ .x = 0.0, .y = 1.0 };
        vertices[3].position = .{ .x = 0.5, .y = -0.5, .z = 0.0 };
        vertices[3].texture_coord = .{ .x = 1.0, .y = 0.0 };
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

        self.texture_uniform = TextureUniform{
            .diffuse_color = math.Vec4.init(1.0, 1.0, 1.0, 1.0),
        };

        try self.texture_uniform_buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(TextureUniform),
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VMA_MEMORY_USAGE_AUTO,
            null,
        );

        // self.push_constant = PushConstant{
        //     .model_matrix = math.Mat4.translation(math.Vec3.ZERO),
        // };

        self.camera.position = math.Vec3.init(0, 0, 2);

        self.camera_uniforms = CameraUniform{
            .projection = math.Mat4.perspective(
                std.math.degreesToRadians(70),
                @as(f32, @floatFromInt(context.window_extent.width)) / @as(f32, @floatFromInt(context.window_extent.height)),
                0.1,
                1000.0,
            ),
            // .view = math.Mat4.translation(math.Vec3.init(0.0, 0.0, -2.0)),
            .view = self.camera.getViewMatrix(),
            .model_matrix = math.Mat4.translation(math.Vec3.ZERO),
        };

        try self.camera_uniform_buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(CameraUniform),
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VMA_MEMORY_USAGE_AUTO,
            null,
        );
    }

    pub fn deinit(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) void {
        for (0..self.texture_images.len) |i| {
            self.texture_images[i].deinit(
                context.vk_allocator,
                context.device.handle,
            );
        }
        self.camera_uniform_buffer.deinit(context.vk_allocator);
        self.texture_uniform_buffer.deinit(context.vk_allocator);
        self.index_buffer.deinit(context.vk_allocator);
        self.vertex_buffer.deinit(context.vk_allocator);

        self.pipeline.deinit(context.device.handle);
        self.shader_stages.deinit(context.device.handle);
        self.texture_descriptor.deinit(context.device.handle);
        self.vertex_descriptor.deinit(context.device.handle);

        std.log.info("VkTriangle deinit", .{});
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

        try self.texture_uniform_buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.texture_uniform,
            @sizeOf(TextureUniform),
            queue,
            cmd_pool,
        );

        try self.camera_uniform_buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.camera_uniforms,
            @sizeOf(CameraUniform),
            queue,
            cmd_pool,
        );

        // TODO: check if it needs to update
        var descritor_write = std.ArrayList(c.VkWriteDescriptorSet).init(allocator);
        defer descritor_write.deinit();

        var vertex_buffer_info = c.VkDescriptorBufferInfo{
            .buffer = self.camera_uniform_buffer.handle,
            .offset = 0,
            .range = @sizeOf(@TypeOf(self.camera_uniforms)),
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

        var fragment_buffer_info = c.VkDescriptorBufferInfo{
            .buffer = self.texture_uniform_buffer.handle,
            .offset = 0,
            .range = @sizeOf(@TypeOf(self.texture_uniform)),
        };
        try descritor_write.append(c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = self.texture_descriptor.set,
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &fragment_buffer_info,
        });

        for (self.texture_images) |tex| {
            const image_info = c.VkDescriptorImageInfo{
                .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                .imageView = tex.image.view,
                .sampler = tex.sampler,
            };

            try descritor_write.append(c.VkWriteDescriptorSet{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = self.texture_descriptor.set,
                .dstBinding = tex.descriptor_binding,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .pImageInfo = &image_info,
            });
        }

        var descriptors_sets = [_]c.VkDescriptorSet{
            self.vertex_descriptor.set,
            self.texture_descriptor.set,
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

        // c.vkCmdPushConstants(
        //     cmd,
        //     self.pipeline.layout,
        //     c.VK_SHADER_STAGE_VERTEX_BIT,
        //     0,
        //     @sizeOf(PushConstant),
        //     &self.push_constant,
        // );

        c.vkCmdDrawIndexed(cmd, @intCast(self.indices.len), 1, 0, 0, 0);
    }
};
