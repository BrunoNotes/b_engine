const std = @import("std");

const c = @import("../c.zig");
const util = @import("../util.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub fn extensionIsAvailable(name: [*c]const u8, extensions: []c.VkExtensionProperties) bool {
    for (extensions) |ext| {
        const ext_name: [*c]const u8 = @ptrCast(ext.extensionName[0..]);
        if (std.mem.eql(
            u8,
            std.mem.span(ext_name),
            std.mem.span(name),
        )) {
            return true;
        }
    }

    return false;
}

pub fn transitionImage(
    cmd: c.VkCommandBuffer,
    image: c.VkImage,
    oldLayout: c.VkImageLayout,
    newLayout: c.VkImageLayout,
) void {
    const src_stage_access = getPipelineStageAccess(oldLayout);
    const dst_stage_access = getPipelineStageAccess(newLayout);

    var sub_resource_range = c.VkImageSubresourceRange{};
    sub_resource_range.aspectMask = if (newLayout == c.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL) c.VK_IMAGE_ASPECT_DEPTH_BIT else c.VK_IMAGE_ASPECT_COLOR_BIT;
    sub_resource_range.baseMipLevel = 0;
    sub_resource_range.levelCount = c.VK_REMAINING_MIP_LEVELS;
    sub_resource_range.baseArrayLayer = 0;
    sub_resource_range.layerCount = c.VK_REMAINING_ARRAY_LAYERS;

    var barrier = c.VkImageMemoryBarrier2{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .srcStageMask = src_stage_access.state,
        .srcAccessMask = src_stage_access.access,
        .dstStageMask = dst_stage_access.state,
        .dstAccessMask = dst_stage_access.access,
        .oldLayout = oldLayout,
        .newLayout = newLayout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = sub_resource_range,
    };

    var dep_info = c.VkDependencyInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = &barrier,
    };

    c.vkCmdPipelineBarrier2(cmd, &dep_info);
}

fn getPipelineStageAccess(
    state: c.VkImageLayout,
) struct {
    state: c.VkPipelineStageFlags2,
    access: c.VkAccessFlags2,
} {
    switch (state) {
        c.VK_IMAGE_LAYOUT_UNDEFINED => return .{
            .state = c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            .access = c.VK_ACCESS_2_NONE,
        },
        c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL => return .{
            .state = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            .access = c.VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT | c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
        },
        c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL => return .{
            .state = c.VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT | c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT | c.VK_PIPELINE_STAGE_2_PRE_RASTERIZATION_SHADERS_BIT,
            .access = c.VK_ACCESS_2_SHADER_READ_BIT,
        },
        c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL => return .{
            .state = c.VK_PIPELINE_STAGE_2_TRANSFER_BIT,
            .access = c.VK_ACCESS_2_TRANSFER_WRITE_BIT,
        },
        c.VK_IMAGE_LAYOUT_GENERAL => return .{
            .state = c.VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT | c.VK_PIPELINE_STAGE_2_TRANSFER_BIT,
            .access = c.VK_ACCESS_2_MEMORY_READ_BIT | c.VK_ACCESS_2_MEMORY_WRITE_BIT | c.VK_ACCESS_2_TRANSFER_WRITE_BIT,
        },
        c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR => return .{
            .state = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            .access = c.VK_ACCESS_2_NONE,
        },
        else => return .{
            .state = c.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
            .access = c.VK_ACCESS_2_MEMORY_READ_BIT | c.VK_ACCESS_2_MEMORY_WRITE_BIT,
        },
    }
}
