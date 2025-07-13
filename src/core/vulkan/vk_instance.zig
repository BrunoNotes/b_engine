const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const vk_utils = @import("vk_utils.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const Window = @import("../window.zig").Window;

pub const Instance = struct {
    handle: c.VkInstance = undefined,
    debug_messenger: c.VkDebugUtilsMessengerEXT = undefined,
    api_version: u32 = undefined,
    enable_validation_layers: bool = builtin.mode == .Debug,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        window: *Window,
    ) !void {
        std.log.info("VkInstance init", .{});

        try VK_CHECK(c.vkEnumerateInstanceVersion(&self.api_version));

        std.log.info("Vulkan API {d}.{d}", .{
            c.VK_VERSION_MAJOR(self.api_version),
            c.VK_VERSION_MINOR(self.api_version),
        });

        assert(self.api_version >= c.VK_MAKE_API_VERSION(0, 1, 3, 0)); // minimum version

        var instance_ext = std.ArrayList([*c]const u8).init(allocator);
        defer instance_ext.deinit();

        const window_ext = window.getVkExtensions();
        for (0..window_ext.count) |i| {
            try instance_ext.append(window_ext.ext[i]);
        }

        // get available extensions
        var ext_count: u32 = undefined;
        try VK_CHECK(c.vkEnumerateInstanceExtensionProperties(null, &ext_count, null));

        const available_instance_ext = try allocator.alloc(c.VkExtensionProperties, ext_count);
        defer allocator.free(available_instance_ext);
        try VK_CHECK(c.vkEnumerateInstanceExtensionProperties(null, &ext_count, available_instance_ext.ptr));

        // check if extension is available and add
        if (vk_utils.extensionIsAvailable(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME, available_instance_ext)) {
            try instance_ext.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME); // allow debug utils
        }
        if (vk_utils.extensionIsAvailable(c.VK_KHR_SURFACE_EXTENSION_NAME, available_instance_ext)) {
            try instance_ext.append(c.VK_KHR_SURFACE_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME, available_instance_ext)) {
            try instance_ext.append(c.VK_KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME, available_instance_ext)) {
            try instance_ext.append(c.VK_EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME);
        }

        if (builtin.mode == .Debug) {
            for (instance_ext.items) |ext| {
                std.log.debug("Loaded Vulkan extension: {s}", .{ext});
            }
        }

        // validation layers
        var instance_validation_layers = std.ArrayList([*c]const u8).init(allocator);
        defer instance_validation_layers.deinit();

        if (self.enable_validation_layers) {
            try instance_validation_layers.append("VK_LAYER_KHRONOS_validation");
        }

        if (builtin.mode == .Debug) {
            for (instance_validation_layers.items) |layer| {
                std.log.debug("Loaded Vulkan validation layers: {s}", .{layer});
            }
        }

        var app_info = c.VkApplicationInfo{
            .pApplicationName = "app",
            .applicationVersion = 1,
            .pEngineName = "engine",
            .engineVersion = 1,
            .apiVersion = self.api_version,
        };

        var instance_info = c.VkInstanceCreateInfo{};
        instance_info.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        instance_info.pApplicationInfo = &app_info;
        instance_info.enabledLayerCount = @intCast(instance_validation_layers.items.len);
        instance_info.ppEnabledLayerNames = instance_validation_layers.items.ptr;
        instance_info.enabledExtensionCount = @intCast(instance_ext.items.len);
        instance_info.ppEnabledExtensionNames = instance_ext.items.ptr;

        var debug_utils_info = c.VkDebugUtilsMessengerCreateInfoEXT{};
        if (self.enable_validation_layers) {
            debug_utils_info.sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
            debug_utils_info.messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;
            debug_utils_info.messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT;
            debug_utils_info.pfnUserCallback = &debugCallback;

            instance_info.pNext = &debug_utils_info;
        }

        try VK_CHECK(c.vkCreateInstance(&instance_info, null, &self.handle));

        if (self.enable_validation_layers) {
            try VK_CHECK(createDebugUtilMessengerExt(
                self.handle,
                &debug_utils_info,
                null,
                &self.debug_messenger,
            ));
        }
    }

    pub fn deinit(self: *@This()) void {
        if (self.enable_validation_layers) {
            destroyDebugUtilMessenger(
                self.handle,
                self.debug_messenger,
                null,
            );
        }

        c.vkDestroyInstance(self.handle, null);
        std.log.info("VkInstance deinit", .{});
    }

    fn debugCallback(
        message_severity: c.VkDebugUtilsMessageSeverityFlagsEXT,
        message_type: c.VkDebugUtilsMessageTypeFlagsEXT,
        callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
        user_data: ?*anyopaque,
    ) callconv(.C) c_uint {
        _ = user_data;
        // if (user_data) {
        //     user_data();
        // }

        if ((message_severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) == 0) {
            std.log.err("{d} Validation Layer: Error: {s}: {s}", .{
                callback_data.?.messageIdNumber,
                callback_data.?.pMessageIdName,
                callback_data.?.pMessage,
            });
        } else if ((message_severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) == 0) {
            std.log.warn("{d} Validation Layer: Warning: {s}: {s}", .{
                callback_data.?.messageIdNumber,
                callback_data.?.pMessageIdName,
                callback_data.?.pMessage,
            });
        } else if ((message_type & c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT) == 0) {
            std.log.warn("{d} Validation Layer: Performance warning: {s}: {s}", .{
                callback_data.?.messageIdNumber,
                callback_data.?.pMessageIdName,
                callback_data.?.pMessage,
            });
        } else {
            std.log.info("{d} Validation Layer: Information: {s}: {s}", .{
                callback_data.?.messageIdNumber,
                callback_data.?.pMessageIdName,
                callback_data.?.pMessage,
            });
        }

        return c.VK_FALSE;
    }

    fn destroyDebugUtilMessenger(
        instance: c.VkInstance,
        debug_messenger: c.VkDebugUtilsMessengerEXT,
        p_allocator: ?*c.VkAllocationCallbacks,
    ) void {
        const get_func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
            instance,
            "vkDestroyDebugUtilsMessengerEXT",
        ));
        if (get_func) |func| {
            func(instance, debug_messenger, p_allocator);
        }
    }

    fn createDebugUtilMessengerExt(
        instance: c.VkInstance,
        p_create_info: *c.VkDebugUtilsMessengerCreateInfoEXT,
        p_allocator: ?*c.VkAllocationCallbacks,
        p_debug_messenger: *c.VkDebugUtilsMessengerEXT,
    ) c.VkResult {
        const get_func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
            instance,
            "vkCreateDebugUtilsMessengerEXT",
        ));
        if (get_func) |func| {
            return func(instance, p_create_info, p_allocator, p_debug_messenger);
        } else {
            return c.VK_ERROR_EXTENSION_NOT_PRESENT;
        }
    }
};
