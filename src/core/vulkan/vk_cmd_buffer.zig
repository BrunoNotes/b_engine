const std = @import("std");
const c = @import("../c.zig");

const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub fn beginSingleTimeCmd(
    device: c.VkDevice,
    cmd_pool: c.VkCommandPool,
) !c.VkCommandBuffer {
    var alloc_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = cmd_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    var cmd: c.VkCommandBuffer = undefined;
    try VK_CHECK(c.vkAllocateCommandBuffers(device, &alloc_info, &cmd));

    var begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    try VK_CHECK(c.vkBeginCommandBuffer(cmd, &begin_info));

    return cmd;
}

pub fn endSingleTimeCmd(
    cmd: c.VkCommandBuffer,
    device: c.VkDevice,
    cmd_pool: c.VkCommandPool,
    queue: c.VkQueue,
) !void {
    try VK_CHECK(c.vkEndCommandBuffer(cmd));

    var fence_info = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    };

    var fence: c.VkFence = undefined;

    try VK_CHECK(c.vkCreateFence(device, &fence_info, null, &fence));

    var cmd_buffer_info = c.VkCommandBufferSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
        .commandBuffer = cmd,
    };
    var submit_info = [_]c.VkSubmitInfo2{
        c.VkSubmitInfo2{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2,
            .commandBufferInfoCount = 1,
            .pCommandBufferInfos = &cmd_buffer_info,
        },
    };

    try VK_CHECK(c.vkQueueSubmit2(
        queue,
        @intCast(submit_info.len),
        &submit_info,
        fence,
    ));

    try VK_CHECK(c.vkWaitForFences(
        device,
        1,
        &fence,
        c.VK_TRUE,
        std.math.maxInt(u64),
    ));

    c.vkDestroyFence(device, fence, null);
    c.vkFreeCommandBuffers(device, cmd_pool, 1, &cmd);
}
