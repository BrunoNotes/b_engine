const std = @import("std");
const assert = std.debug.assert;

const c = @import("../c.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub const FrameData = struct {
    cmd_pool: c.VkCommandPool = undefined,
    cmd_buffer: c.VkCommandBuffer = undefined,
    frame_number: u64 = undefined,

    img_available_semaphore: c.VkSemaphore = undefined,
    render_finished_semaphore: c.VkSemaphore = undefined,
    render_finished_fence: c.VkFence = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        swapchain: *SwapChain,
        device: c.VkDevice,
        queue: vk_types.QueueInfo,
        image_format: c.VkFormat,
    ) !struct {
        data: []FrameData,
        images: []vk_types.Image,
    } {
        var frame_data = try allocator.alloc(FrameData, swapchain.max_frames_inflight);
        // defer self.allocator.free(self._frame_data);

        // TODO: study timeline semaphore

        var cmd_poll_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = queue.familyIndex,
        };

        var image_count: u32 = undefined;
        try VK_CHECK(c.vkGetSwapchainImagesKHR(device, swapchain.handle, &image_count, null));
        assert(swapchain.max_frames_inflight == image_count);

        const swapchain_images = try allocator.alloc(c.VkImage, image_count);
        defer allocator.free(swapchain_images);
        try VK_CHECK(c.vkGetSwapchainImagesKHR(device, swapchain.handle, &image_count, swapchain_images.ptr));

        var images = try allocator.alloc(vk_types.Image, image_count);
        // defer self.allocator.free(next_images);

        var imageview_info = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = image_format,
            .components = c.VkComponentMapping{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        var fence_info = c.VkFenceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        };
        var semaphore_info = c.VkSemaphoreCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };

        for (0..swapchain.max_frames_inflight) |i| {
            images[i].handle = swapchain_images[i];
            imageview_info.image = images[i].handle;

            try VK_CHECK(c.vkCreateImageView(
                device,
                &imageview_info,
                null,
                &images[i].view,
            ));

            try VK_CHECK(c.vkCreateFence(
                device,
                &fence_info,
                null,
                &frame_data[i].render_finished_fence,
            ));

            try VK_CHECK(c.vkCreateSemaphore(
                device,
                &semaphore_info,
                null,
                &frame_data[i].img_available_semaphore,
            ));

            try VK_CHECK(c.vkCreateSemaphore(
                device,
                &semaphore_info,
                null,
                &frame_data[i].render_finished_semaphore,
            ));

            // self.frame_data[i].frame_number = i;

            try VK_CHECK(c.vkCreateCommandPool(
                device,
                &cmd_poll_info,
                null,
                &frame_data[i].cmd_pool,
            ));

            var cmd_buffer_alloc_info = c.VkCommandBufferAllocateInfo{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = frame_data[i].cmd_pool,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = 1,
            };

            try VK_CHECK(c.vkAllocateCommandBuffers(
                device,
                &cmd_buffer_alloc_info,
                &frame_data[i].cmd_buffer,
            ));
        }

        return .{
            .data = frame_data,
            .images = images,
        };
    }

    pub fn deinit(
        self: *@This(),
        device: c.VkDevice,
    ) void {
        c.vkDestroyFence(device, self.render_finished_fence, null);

        c.vkDestroySemaphore(device, self.img_available_semaphore, null);
        c.vkDestroySemaphore(device, self.render_finished_semaphore, null);
    }
};

pub const SwapChain = struct {
    max_frames_inflight: u32 = undefined,
    image_format: c.VkFormat = undefined,
    handle: c.VkSwapchainKHR = undefined,
    images: []vk_types.Image = undefined,
    needs_rebuild: bool = false,

    frame_data: []FrameData = undefined,
    current_frame: u32 = 0,
    next_img_index: u32 = 0,
    // frame_timeline_semaphore: c.VkSemaphore = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        vSync: bool,
        surface: c.VkSurfaceKHR,
        window_size: c.VkExtent2D,
        physical_device: c.VkPhysicalDevice,
        device: c.VkDevice,
        queue_info: vk_types.QueueInfo,
    ) !void {
        std.log.info("SwapChain init", .{});
        var swapchain_support = SwapChainSupport{};
        try swapchain_support.init(
            physical_device,
            surface,
            allocator,
        );
        defer swapchain_support.deinit(allocator);

        const surface_format2 = selectSwapChainSurfaceFormat(swapchain_support.formats.items);

        const present_mode = selectSwapChainPresentMode(swapchain_support.present_modes, vSync);

        assert(window_size.height <= swapchain_support.capabilities.surfaceCapabilities.maxImageExtent.height);
        assert(window_size.width <= swapchain_support.capabilities.surfaceCapabilities.maxImageExtent.width);

        const min_image_count = swapchain_support.capabilities.surfaceCapabilities.minImageCount;
        const preferred_image_count = @max(3, min_image_count);

        const max_image_count = if (swapchain_support.capabilities.surfaceCapabilities.maxImageCount == 0) preferred_image_count else swapchain_support.capabilities.surfaceCapabilities.maxImageCount;

        self.max_frames_inflight = std.math.clamp(preferred_image_count, min_image_count, max_image_count);

        self.image_format = surface_format2.surfaceFormat.format;

        var swapchain_info = c.VkSwapchainCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = self.max_frames_inflight,
            .imageFormat = surface_format2.surfaceFormat.format,
            .imageColorSpace = surface_format2.surfaceFormat.colorSpace,
            .imageExtent = window_size,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | c.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform = swapchain_support.capabilities.surfaceCapabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = c.VK_TRUE,
        };

        try VK_CHECK(c.vkCreateSwapchainKHR(device, &swapchain_info, null, &self.handle));

        const frame_data = try FrameData.init(
            allocator,
            self,
            device,
            queue_info,
            self.image_format,
        );

        self.frame_data = frame_data.data;
        self.images = frame_data.images;
    }

    pub fn deinit(
        self: *@This(),
        device: c.VkDevice,
    ) void {
        VK_CHECK(c.vkDeviceWaitIdle(device)) catch @panic("Failed to wait device!");

        for (0..self.frame_data.len) |i| {
            c.vkFreeCommandBuffers(
                device,
                self.frame_data[i].cmd_pool,
                1,
                &self.frame_data[i].cmd_buffer,
            );
            c.vkDestroyCommandPool(
                device,
                self.frame_data[i].cmd_pool,
                null,
            );

            self.frame_data[i].deinit(device);
        }

        for (self.images) |img| {
            c.vkDestroyImageView(device, img.view, null);
        }

        // c.vkDestroySemaphore(device, self.frame_timeline_semaphore, null);

        c.vkDestroySwapchainKHR(device, self.handle, null);

        std.log.info("SwapChain deinit", .{});
    }

    pub fn rebuild(
        self: *@This(),
        allocator: std.mem.Allocator,
        vSync: bool,
        device: c.VkDevice,
        queue_info: vk_types.QueueInfo,
        surface: c.VkSurfaceKHR,
        window_size: c.VkExtent2D,
        physical_device: c.VkPhysicalDevice,
    ) !void {
        try VK_CHECK(c.vkQueueWaitIdle(queue_info.queue));

        self.current_frame = 0;
        self.needs_rebuild = false;

        self.deinit(device);

        try self.init(
            allocator,
            vSync,
            surface,
            window_size,
            physical_device,
            device,
            queue_info,
        );
    }
    pub fn acquireNextImage(
        self: *@This(),
        device: c.VkDevice,
    ) !void {
        const frame = self.frame_data[self.current_frame];

        const result = c.vkAcquireNextImageKHR(
            device,
            self.handle,
            std.math.maxInt(u64),
            frame.img_available_semaphore,
            null,
            &self.next_img_index,
        );

        if (result == c.VK_ERROR_OUT_OF_DATE_KHR) {
            self.needs_rebuild = true; // Swapchain must be rebuilt on the next frame
        } else if (result == c.VK_SUBOPTIMAL_KHR) {
            self.needs_rebuild = true; // Swapchain must be rebuilt on the next frame
        } else {
            // assert(result == c.VK_SUCCESS or result == c.VK_SUBOPTIMAL_KHR);
            assert(result == c.VK_SUCCESS);
        }
    }

    pub fn presentFrame(
        self: *@This(),
        queue: c.VkQueue,
    ) !void {
        const frame = self.frame_data[self.current_frame];

        var presentInfo = c.VkPresentInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1, // Wait for rendering to finish
            .pWaitSemaphores = &frame.render_finished_semaphore, // Synchronize presentation
            .swapchainCount = 1, // Swapchain to present the image
            .pSwapchains = &self.handle, // Pointer to the swapchain
            .pImageIndices = &self.next_img_index, // Index of the image to present
        };

        const result = c.vkQueuePresentKHR(queue, &presentInfo);

        if (result == c.VK_ERROR_OUT_OF_DATE_KHR) {
            self.needs_rebuild = true;
        } else {
            assert(result == c.VK_SUCCESS or result == c.VK_SUBOPTIMAL_KHR);
        }

        self.current_frame = @intCast(@mod(self.current_frame + 1, self.max_frames_inflight));
    }

    pub fn getCurrentFrame(self: *@This()) FrameData {
        return self.frame_data[self.current_frame];
    }

    pub fn getNextImage(self: *@This()) vk_types.Image {
        return self.images[self.current_frame];
    }

    fn selectSwapChainSurfaceFormat(
        available_formats: []c.VkSurfaceFormat2KHR,
    ) c.VkSurfaceFormat2KHR {
        const preferred_formats = [_]c.VkSurfaceFormat2KHR{
            c.VkSurfaceFormat2KHR{
                .sType = c.VK_STRUCTURE_TYPE_SURFACE_FORMAT_2_KHR,
                .surfaceFormat = c.VkSurfaceFormatKHR{
                    .format = c.VK_FORMAT_B8G8R8A8_UNORM,
                    .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
                },
            },
        };

        // if there is only one return a default
        if (available_formats.len == 1 and available_formats[0].surfaceFormat.format == c.VK_FORMAT_UNDEFINED) {
            return preferred_formats[0];
        }

        for (preferred_formats) |pref_format| {
            for (available_formats) |avl_format| {
                if (avl_format.surfaceFormat.format == pref_format.surfaceFormat.format and
                    avl_format.surfaceFormat.colorSpace == pref_format.surfaceFormat.colorSpace)
                {
                    return avl_format; // Return the first matching preferred format.
                }
            }
        }
        // If none of the preferred formats are available, return the first available format.
        return available_formats[0];
    }

    fn selectSwapChainPresentMode(
        available_present_modes: []c.VkPresentModeKHR,
        vSync: bool,
    ) c.VkPresentModeKHR {
        if (vSync) {
            return c.VK_PRESENT_MODE_FIFO_KHR;
        }

        for (available_present_modes) |mode| {
            if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                return c.VK_PRESENT_MODE_MAILBOX_KHR;
            } else if (mode == c.VK_PRESENT_MODE_IMMEDIATE_KHR) {
                return c.VK_PRESENT_MODE_IMMEDIATE_KHR;
            }
        }

        return c.VK_PRESENT_MODE_FIFO_KHR;
    }
};

pub const SwapChainSupport = struct {
    capabilities: c.VkSurfaceCapabilities2KHR = undefined,
    format_count: u32 = undefined,
    formats: std.ArrayList(c.VkSurfaceFormat2KHR) = undefined,
    present_mode_count: u32 = undefined,
    present_modes: []c.VkPresentModeKHR = undefined,

    pub fn init(
        self: *@This(),
        physical_device: c.VkPhysicalDevice,
        surface: c.VkSurfaceKHR,
        allocator: std.mem.Allocator,
    ) !void {
        var surface_info2 = c.VkPhysicalDeviceSurfaceInfo2KHR{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SURFACE_INFO_2_KHR,
            .surface = surface,
        };

        self.capabilities = c.VkSurfaceCapabilities2KHR{
            .sType = c.VK_STRUCTURE_TYPE_SURFACE_CAPABILITIES_2_KHR,
        };

        try VK_CHECK(c.vkGetPhysicalDeviceSurfaceCapabilities2KHR(
            physical_device,
            &surface_info2,
            &self.capabilities,
        ));

        try VK_CHECK(c.vkGetPhysicalDeviceSurfaceFormats2KHR(
            physical_device,
            &surface_info2,
            &self.format_count,
            null,
        ));

        self.formats = std.ArrayList(c.VkSurfaceFormat2KHR).init(allocator);
        for (0..self.format_count) |_| {
            try self.formats.append(c.VkSurfaceFormat2KHR{
                .sType = c.VK_STRUCTURE_TYPE_SURFACE_FORMAT_2_KHR,
            });
        }

        try VK_CHECK(c.vkGetPhysicalDeviceSurfaceFormats2KHR(
            physical_device,
            &surface_info2,
            &self.format_count,
            self.formats.items.ptr,
        ));

        try VK_CHECK(c.vkGetPhysicalDeviceSurfacePresentModesKHR(
            physical_device,
            surface,
            &self.present_mode_count,
            null,
        ));

        self.present_modes = try allocator.alloc(c.VkPresentModeKHR, self.present_mode_count);
        try VK_CHECK(c.vkGetPhysicalDeviceSurfacePresentModesKHR(
            physical_device,
            surface,
            &self.present_mode_count,
            self.present_modes.ptr,
        ));
    }

    pub fn deinit(
        self: *@This(),
        allocator: std.mem.Allocator,
    ) void {
        self.formats.deinit();
        allocator.free(self.present_modes);
    }
};
