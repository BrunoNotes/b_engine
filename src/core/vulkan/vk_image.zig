const std = @import("std");
const c = @import("../c.zig");

const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const vk_buffer = @import("vk_buffer.zig");
const vk_cmd = @import("vk_cmd_buffer.zig");
const vk_utils = @import("vk_utils.zig");
const math = @import("../math.zig");

pub const TextureImage = struct {
    image: vk_types.Image = undefined,
    sampler: c.VkSampler = undefined,
    descriptor_binding: u32 = undefined,

    pub fn init(
        self: *@This(),
        file_path: [*c]const u8,
        vk_allocator: c.VmaAllocator,
        device: c.VkDevice,
        queue: c.VkQueue,
        cmd_pool: c.VkCommandPool,
    ) !void {
        var img_width: i32 = undefined;
        var img_height: i32 = undefined;
        var img_channels: i32 = undefined;

        c.stbi_set_flip_vertically_on_load(1);

        const img_data = c.stbi_load(
            file_path,
            &img_width,
            &img_height,
            &img_channels,
            c.STBI_rgb_alpha,
        );
        defer c.stbi_image_free(img_data);

        if (img_data != null) {
            try self.createTexture(
                vk_allocator,
                device,
                queue,
                cmd_pool,
                @intCast(img_width),
                @intCast(img_height),
                @intCast(img_channels),
                img_data,
            );
        } else {
            std.log.err("Failed to load file: {s}, {s}", .{ file_path, c.stbi_failure_reason() });
            var default_tex = try defaultTexture();

            try self.createTexture(
                vk_allocator,
                device,
                queue,
                cmd_pool,
                @intCast(default_tex.width),
                @intCast(default_tex.height),
                @intCast(default_tex.channels),
                &default_tex.data,
            );
        }
    }

    pub fn deinit(
        self: *@This(),
        vk_allocator: c.VmaAllocator,
        device: c.VkDevice,
    ) void {
        VK_CHECK(c.vkDeviceWaitIdle(device)) catch @panic("Failed to wait device!");
        c.vkDestroySampler(device, self.sampler, null);
        c.vmaDestroyImage(vk_allocator, self.image.handle, self.image.vk_allocation);
        c.vkDestroyImageView(device, self.image.view, null);
    }

    pub fn defaultTexture() !struct {
        width: u32,
        height: u32,
        channels: u32,
        // data: [262144]u8,
        data: [4096]u8,
    } {
        // const tex_dimension = 256;
        const tex_dimension = 32;
        const channels = 4;
        const pixel_count = tex_dimension * tex_dimension;

        var pixels: [pixel_count * channels]u8 = undefined;

        for (&pixels) |*value| {
            value.* = 255;
        }

        for (0..tex_dimension) |row| {
            for (0..tex_dimension) |col| {
                const index = (row * tex_dimension) + col;
                const index_channels = index * channels;

                if (@mod(row, 2) == 1) {
                    if (@mod(col, 2) == 1) {
                        pixels[index_channels * 0] = 0;
                        pixels[index_channels * 1] = 0;
                    }
                } else {
                    if (@mod(col, 2) != 1) {
                        pixels[index_channels * 0] = 0;
                        pixels[index_channels * 1] = 0;
                    }
                }
            }
        }

        return .{
            .width = tex_dimension,
            .height = tex_dimension,
            .channels = channels,
            .data = pixels,
        };
    }

    fn createTexture(
        self: *@This(),
        vk_allocator: c.VmaAllocator,
        device: c.VkDevice,
        queue: c.VkQueue,
        cmd_pool: c.VkCommandPool,
        img_width: u32,
        img_height: u32,
        img_channels: u32,
        img_data: [*c]u8,
    ) !void {
        self.image.extent = c.VkExtent2D{
            .width = img_width,
            .height = img_height,
        };

        const image_info = c.VkImageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = c.VK_IMAGE_TYPE_2D,
            .format = c.VK_FORMAT_R8G8B8A8_UNORM,
            .extent = c.VkExtent3D{
                .width = img_width,
                .height = img_height,
                .depth = 1,
            },
            .mipLevels = 1,
            .arrayLayers = 1,
            .tiling = c.VK_IMAGE_TILING_LINEAR,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .usage = c.VK_IMAGE_USAGE_SAMPLED_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        };

        var vma_alloc_create_info = c.VmaAllocationCreateInfo{
            .usage = c.VMA_MEMORY_USAGE_GPU_ONLY,
        };
        var vma_alloc_info = c.VmaAllocationInfo{};
        try VK_CHECK(c.vmaCreateImage(
            vk_allocator,
            &image_info,
            &vma_alloc_create_info,
            &self.image.handle,
            &self.image.vk_allocation,
            &vma_alloc_info,
        ));

        const channels = if (img_channels < 4) 4 else img_channels;
        const img_size = img_width * img_height * channels;

        var staging_buffer = vk_buffer.Buffer(u8){};
        try staging_buffer.init(
            vk_allocator,
            device,
            // same thins as: @sizeOf(@TypeOf(vk_builder.Buffer)) * vertices.len
            img_size,
            c.VK_BUFFER_USAGE_2_TRANSFER_SRC_BIT_KHR,
            c.VMA_MEMORY_USAGE_CPU_TO_GPU,
            c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT,
        );
        defer staging_buffer.deinit(vk_allocator);

        try staging_buffer.mapMemory(
            vk_allocator,
            img_data[0..img_size],
        );

        const cmd = try vk_cmd.beginSingleTimeCmd(device, cmd_pool);

        vk_utils.transitionImage(
            cmd,
            self.image.handle,
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        );

        var copy_region = [_]c.VkBufferImageCopy{
            c.VkBufferImageCopy{
                .bufferOffset = 0,
                .bufferRowLength = 0,
                .bufferImageHeight = 0,
                .imageSubresource = c.VkImageSubresourceLayers{
                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .mipLevel = 0,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
                .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
                .imageExtent = image_info.extent,
            },
        };

        c.vkCmdCopyBufferToImage(
            cmd,
            staging_buffer.handle,
            self.image.handle,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            @intCast(copy_region.len),
            &copy_region,
        );

        vk_utils.transitionImage(
            cmd,
            self.image.handle,
            c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        );

        try vk_cmd.endSingleTimeCmd(cmd, device, cmd_pool, queue);

        var view_info = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = self.image.handle,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = image_info.format,
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .levelCount = 1,
                .layerCount = 1,
            },
        };
        try VK_CHECK(c.vkCreateImageView(device, &view_info, null, &self.image.view));

        var sampler_info = c.VkSamplerCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            .magFilter = c.VK_FILTER_LINEAR,
            .minFilter = c.VK_FILTER_LINEAR,
            .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
            .anisotropyEnable = c.VK_TRUE,
            .maxAnisotropy = 16,
            .borderColor = c.VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK,
            .unnormalizedCoordinates = c.VK_FALSE,
            .compareEnable = c.VK_TRUE,
            .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
            .mipLodBias = 0.0,
            .minLod = 0.0,
            .maxLod = 0.0,
        };

        try VK_CHECK(c.vkCreateSampler(
            device,
            &sampler_info,
            null,
            &self.sampler,
        ));
    }
};
