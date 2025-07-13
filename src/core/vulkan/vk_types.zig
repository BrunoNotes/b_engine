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

pub const CameraUniform = struct {
    projection: math.Mat4 = undefined, // 64 bytes
    view: math.Mat4 = undefined,
    reserved_0: math.Mat4 = undefined,
    reserved_1: math.Mat4 = undefined,
};

pub const TextureUniform = struct {
    diffuse_color: math.Vec4 = undefined,
    reserved_0: math.Vec4 = undefined,
    reserved_1: math.Vec4 = undefined,
    reserved_2: math.Vec4 = undefined,
};

pub const PushConstant = struct {
    model_matrix: math.Mat4 = undefined,
};
pub fn VK_CHECK(x: c.VkResult) !void {
    if (x != c.VK_SUCCESS) {
        std.log.err("Detected vulkan error: {s}", .{c.string_VkResult(x)});
        return error.VulkanError;
    }
}
