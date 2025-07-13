const std = @import("std");
pub const c = @import("c.zig");

pub const Window = @import("window.zig").Window;
pub const vulkan = @import("vulkan/vk_renderer.zig");
pub const math = @import("math.zig");
pub const util = @import("util.zig");

pub const Engine = struct {
    window: Window = undefined,
    running: bool = false,
    vk_renderer: vulkan.VkRenderer = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
    ) !void {
        try self.window.init();
        try self.vk_renderer.init(allocator, &self.window);

        self.running = true;
    }

    pub fn deinit(self: *@This()) void {
        self.vk_renderer.deinit();
        self.window.deinit();
        self.running = false;
    }
};
