const std = @import("std");
const c = @import("../c.zig");

const Window = @import("../window.zig").Window;
pub const vk_instance = @import("vk_instance.zig");
pub const vk_device = @import("vk_device.zig");
pub const vk_swapchain = @import("vk_swapchain.zig");
pub const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
pub const vk_utils = @import("vk_utils.zig");

pub const VkRenderer = struct {
    instance: vk_instance.Instance = undefined,
    surface: c.VkSurfaceKHR = undefined,
    window_extent: c.VkExtent2D = undefined,
    physical_device: vk_device.PhysicalDevice = undefined,
    device: vk_device.LogicDevice = undefined,
    swapchain: vk_swapchain.SwapChain = undefined,
    vk_allocator: c.VmaAllocator = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        window: *Window,
    ) !void {
        std.log.info("VkRenderer init", .{});
        try self.instance.init(allocator, window);

        self.surface = try window.getVkSurface(self.instance.handle);
        self.window_extent = window.getVkSurfaceExtent();

        try self.physical_device.init(allocator, self.instance.handle, self.surface);

        try self.device.init(
            allocator,
            self.physical_device.handle,
        );

        try self.swapchain.init(
            allocator,
            true, // TODO: make this configurable
            self.surface,
            self.window_extent,
            self.physical_device.handle,
            self.device.handle,
            self.device.graphics_queue,
        );

        std.log.info("VmaAllocator create", .{});
        var vkallocator_info = c.VmaAllocatorCreateInfo{
            .physicalDevice = self.physical_device.handle,
            .device = self.device.handle,
            .instance = self.instance.handle,
            .vulkanApiVersion = self.instance.api_version,
        };

        try VK_CHECK(c.vmaCreateAllocator(&vkallocator_info, &self.vk_allocator));
    }

    pub fn deinit(self: *@This()) void {
        VK_CHECK(c.vkDeviceWaitIdle(self.device.handle)) catch @panic("failed to wait device");

        c.vmaDestroyAllocator(self.vk_allocator);
        std.log.info("VmaAllocator deastroy", .{});

        self.swapchain.deinit(
            self.device.handle,
        );

        self.device.deinit();

        self.instance.deinit();

        std.log.info("VkRenderer deinit", .{});
    }

    pub fn resize(
        self: *@This(),
        window_extent: c.VkExtent2D,
    ) void {
        self.window_extent = window_extent;
        self.swapchain.needs_rebuild = true;
    }

    pub fn beginDraw(
        self: *@This(),
        allocator: std.mem.Allocator,
    ) !void {
        // rebuilds the swapchain if needed
        if (self.swapchain.needs_rebuild) {
            try self.swapchain.rebuild(
                allocator,
                true, // TODO: make this configurable
                self.device.handle,
                self.device.graphics_queue,
                self.surface,
                self.window_extent,
                self.physical_device.handle,
            );
        }

        const frame_data = self.swapchain.getCurrentFrame();

        // Wait until GPU has finished processing the frame that was using these resources previously
        try VK_CHECK(c.vkWaitForFences(
            self.device.handle,
            1,
            &frame_data.render_finished_fence,
            c.VK_TRUE,
            std.math.maxInt(u64),
        ));
        try VK_CHECK(c.vkResetFences(
            self.device.handle,
            1,
            &frame_data.render_finished_fence,
        ));

        // Reset the command pool to reuse the command buffer for recording
        try VK_CHECK(c.vkResetCommandPool(self.device.handle, frame_data.cmd_pool, 0));

        const cmd = frame_data.cmd_buffer;

        // Begin the command buffer recording for the frame
        var begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };
        try VK_CHECK(c.vkBeginCommandBuffer(cmd, &begin_info));

        try self.swapchain.acquireNextImage(self.device.handle);

        const image = self.swapchain.getNextImage();

        vk_utils.transitionImage(
            cmd,
            image.handle,
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        );

        const clear_value = c.VkClearValue{
            .color = c.VkClearColorValue{
                .float32 = [4]f32{ 0.392, 0.584, 0.929, 1.0 },
            },
        };

        var color_attachment = [_]c.VkRenderingAttachmentInfo{
            c.VkRenderingAttachmentInfo{
                .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
                .imageView = image.view,
                .imageLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
                .clearValue = clear_value,
            },
        };

        var rendering_info = c.VkRenderingInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
            .renderArea = c.VkRect2D{ // Initialize the nested `VkRect2D` structure
                .offset = c.VkOffset2D{ .x = 0, .y = 0 }, // Initialize the `VkOffset2D` inside `renderArea`
                .extent = self.window_extent,
            },
            .layerCount = 1,
            .colorAttachmentCount = color_attachment.len,
            .pColorAttachments = &color_attachment,
        };

        c.vkCmdBeginRendering(cmd, &rendering_info);
    }

    pub fn endDraw(
        self: *@This(),
        allocator: std.mem.Allocator,
    ) !void {
        const cmd = self.swapchain.getCurrentFrame().cmd_buffer;
        c.vkCmdEndRendering(cmd);

        vk_utils.transitionImage(
            cmd,
            self.swapchain.getNextImage().handle,
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        );

        try VK_CHECK(c.vkEndCommandBuffer(cmd));

        var wait_semaphore = std.ArrayList(c.VkSemaphoreSubmitInfo).init(allocator);
        defer wait_semaphore.deinit();
        var signal_semaphore = std.ArrayList(c.VkSemaphoreSubmitInfo).init(allocator);
        defer signal_semaphore.deinit();

        const frame = self.swapchain.getCurrentFrame();

        try wait_semaphore.append(c.VkSemaphoreSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
            .semaphore = frame.img_available_semaphore,
            .stageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        });

        try signal_semaphore.append(c.VkSemaphoreSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
            .semaphore = frame.render_finished_semaphore,
            .stageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        });

        // const signal_frame_value = frame.frame_number + self._swapchain.max_frames_inflight;
        // frame.frame_number = signal_frame_value;
        // try signal_semaphore.append(c.VkSemaphoreSubmitInfo{
        //     .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
        //     .semaphore = self._swapchain.frame_timeline_semaphore,
        //     .value = signal_frame_value,
        //     .stageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        // });

        var cmd_buffer_info = std.ArrayList(c.VkCommandBufferSubmitInfo).init(allocator);
        defer cmd_buffer_info.deinit();

        try cmd_buffer_info.append(c.VkCommandBufferSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
            .commandBuffer = cmd,
        });

        var submit_info = std.ArrayList(c.VkSubmitInfo2).init(allocator);
        defer submit_info.deinit();
        try submit_info.append(c.VkSubmitInfo2{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
            .waitSemaphoreInfoCount = @intCast(wait_semaphore.items.len),
            .pWaitSemaphoreInfos = wait_semaphore.items.ptr, // Wait for the image to be available
            .commandBufferInfoCount = @intCast(cmd_buffer_info.items.len), //
            .pCommandBufferInfos = cmd_buffer_info.items.ptr, // Command buffer to submit
            .signalSemaphoreInfoCount = @intCast(signal_semaphore.items.len), //
            .pSignalSemaphoreInfos = signal_semaphore.items.ptr, // Signal when rendering is finished
        });

        // Submit the command buffer to the GPU and signal when it's done
        try VK_CHECK(c.vkQueueSubmit2(
            self.device.graphics_queue.queue,
            @intCast(submit_info.items.len),
            submit_info.items.ptr,
            frame.render_finished_fence,
        ));

        try self.swapchain.presentFrame(self.device.graphics_queue.queue);
    }
};
