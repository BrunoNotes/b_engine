const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const c = @import("c.zig");

pub const Window = struct {
    width: u32 = 800,
    height: u32 = 600,
    name: []const u8 = "Ink",
    handle: ?*c.SDL_Window = undefined,

    pub fn init(
        self: *@This(),
    ) !void {
        const props = c.SDL_CreateProperties();

        _ = c.SDL_SetStringProperty(props, c.SDL_PROP_WINDOW_CREATE_TITLE_STRING, self.name.ptr);
        _ = c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_RESIZABLE_BOOLEAN, true);
        _ = c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_BORDERLESS_BOOLEAN, false);
        _ = c.SDL_SetNumberProperty(props, c.SDL_PROP_WINDOW_CREATE_WIDTH_NUMBER, self.width);
        _ = c.SDL_SetNumberProperty(props, c.SDL_PROP_WINDOW_CREATE_HEIGHT_NUMBER, self.height);

        _ = c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_VULKAN_BOOLEAN, true);

        // if (builtin.os.tag == .linux) {
        //     _ = c.SDL_SetBooleanProperty(props, c.SDL_PROP_WINDOW_CREATE_WAYLAND_SURFACE_ROLE_CUSTOM_BOOLEAN, true);
        // }

        self.handle = c.SDL_CreateWindowWithProperties(props) orelse {
            std.log.err("SDL: Error creating window, {s}", .{c.SDL_GetError()});
            return error.SDLInitError;
        };

        std.log.info("Window init", .{});
    }

    pub fn deinit(self: *@This()) void {
        c.SDL_DestroyWindow(self.handle);
        std.log.info("Window deinit", .{});
    }

    pub fn resize(self: *@This()) void {
        var width: i32 = undefined;
        var height: i32 = undefined;
        _ = c.SDL_GetWindowSize(
            self.handle,
            &width,
            &height,
        );

        self.width = @intCast(width);
        self.height = @intCast(height);
    }

    pub fn getVkExtensions(self: *@This()) struct {
        count: u32,
        ext: [*c]const [*c]const u8,
    } {
        _ = self;
        var ext_count: u32 = undefined;
        const ext = c.SDL_Vulkan_GetInstanceExtensions(&ext_count);

        return .{
            .count = ext_count,
            .ext = ext,
        };
    }

    pub fn getVkSurface(
        self: *@This(),
        instance: c.VkInstance,
    ) !c.VkSurfaceKHR {
        var surface: c.VkSurfaceKHR = undefined;
        if (!c.SDL_Vulkan_CreateSurface(
            self.handle,
            instance,
            null,
            &surface,
        )) {
            std.log.err("Vulkan: failed to create surface!", .{});
            return error.VulkanError;
        }

        return surface;
    }

    pub fn getVkSurfaceExtent(
        self: *@This(),
    ) c.VkExtent2D {
        return c.VkExtent2D{
            .height = self.height,
            .width = self.width,
        };
    }
};
