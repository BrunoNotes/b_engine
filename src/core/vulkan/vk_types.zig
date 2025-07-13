const std = @import("std");
const c = @import("../c.zig");
const math = @import("../math.zig");

pub const QueueFamilyIndex = struct {
    graphics: ?u32 = null,
    compute: ?u32 = null,
    transfer: ?u32 = null,
    present: ?u32 = null,
};

pub const QueueInfo = struct {
    familyIndex: u32 = 0,
    queueIndex: u32 = 0,
    queue: c.VkQueue = undefined,
};

pub const Image = struct {
    handle: c.VkImage = undefined,
    view: c.VkImageView = undefined,
    extent: c.VkExtent2D = undefined,
    vk_allocation: c.VmaAllocation = undefined,
};

pub const RGBAColor = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 1.0,
};

pub const Vertex = struct {
    position: math.Vec3 = undefined,
    texture_coord: math.Vec2 = undefined,
    // color: RGBAColor = undefined,
};

pub fn VK_CHECK(x: c.VkResult) !void {
    if (x != c.VK_SUCCESS) {
        std.log.err("Detected vulkan error: {s}", .{c.string_VkResult(x)});
        return error.VulkanError;
    }
}
