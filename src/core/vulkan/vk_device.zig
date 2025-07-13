const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const vk_swapchain = @import("vk_swapchain.zig");
const vk_utils = @import("vk_utils.zig");

pub const PhysicalDevice = struct {
    handle: c.VkPhysicalDevice = undefined,
    properties: c.VkPhysicalDeviceProperties2 = undefined,

    const VulkanPhysicalDeviceRequirements = struct {
        graphics: bool = false,
        present: bool = false,
        compute: bool = false,
        transfer: bool = false,
        discrete_gpu: bool = false,
    };

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        instance: c.VkInstance,
        surface: c.VkSurfaceKHR,
    ) !void {
        std.log.info("PhysicalDevice init", .{});
        var device_count: u32 = undefined;
        try VK_CHECK(c.vkEnumeratePhysicalDevices(instance, &device_count, null));

        assert(device_count > 0);

        const physical_devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
        defer allocator.free(physical_devices);

        try VK_CHECK(c.vkEnumeratePhysicalDevices(instance, &device_count, physical_devices.ptr));

        var properties2 = c.VkPhysicalDeviceProperties2{};
        properties2.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;

        const requirements = VulkanPhysicalDeviceRequirements{
            .graphics = true,
            .present = true,
            .compute = true,
            .transfer = true,
            .discrete_gpu = true,
        };

        var chosen_device: c.VkPhysicalDevice = undefined;
        var found_device: bool = false;

        for (physical_devices) |device| {
            c.vkGetPhysicalDeviceProperties2(device, &properties2);

            if (try physicalDeviceMeetsRequirements(
                allocator,
                device,
                surface,
                properties2.properties,
                requirements,
            )) {
                chosen_device = device;
                found_device = true;
                break;
            }

            // if (properties2.properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            //     chosen_device = device;
            //     break;
            // }
        }

        if (!found_device) {
            return error.VulkanPhysicalDeviceNotFound;
        }

        std.log.info("Selected GPU: {s}", .{properties2.properties.deviceName});
        std.log.info("Driver: {d}.{d}.{d}", .{
            c.VK_VERSION_MAJOR(properties2.properties.driverVersion),
            c.VK_VERSION_MINOR(properties2.properties.driverVersion),
            c.VK_VERSION_PATCH(properties2.properties.driverVersion),
        });

        self.handle = chosen_device;
        self.properties = properties2;
    }

    fn physicalDeviceMeetsRequirements(
        allocator: std.mem.Allocator,
        physical_device: c.VkPhysicalDevice,
        surface: c.VkSurfaceKHR,
        device_properties: c.VkPhysicalDeviceProperties,
        requirements: VulkanPhysicalDeviceRequirements,
    ) !bool {
        if (requirements.discrete_gpu) {
            if (device_properties.deviceType != c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                return false;
            }
        }

        var queue_family_count: u32 = undefined;
        c.vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &queue_family_count, null);
        // const queue_families = try allocator.alloc(c.VkQueueFamilyProperties2, queue_family_count);
        // defer allocator.free(queue_families);
        var queue_families = std.ArrayList(c.VkQueueFamilyProperties2).init(allocator);
        defer queue_families.deinit();
        for (0..queue_family_count) |_| {
            try queue_families.append(c.VkQueueFamilyProperties2{
                .sType = c.VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2,
            });
        }
        c.vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &queue_family_count, queue_families.items.ptr);

        var queue_family_index = vk_types.QueueFamilyIndex{};

        var min_transfer_score: u8 = 255;
        for (0..queue_family_count) |i| {
            var current_transfer_score: u8 = 0;

            // Graphics queue
            if ((queue_families.items[i].queueFamilyProperties.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) > 0) {
                queue_family_index.graphics = @intCast(i);
                current_transfer_score += 1;
            }

            // Compute queue
            if ((queue_families.items[i].queueFamilyProperties.queueFlags & c.VK_QUEUE_COMPUTE_BIT) > 0) {
                queue_family_index.compute = @intCast(i);
                current_transfer_score += 1;
            }

            // Transfer queue
            if ((queue_families.items[i].queueFamilyProperties.queueFlags & c.VK_QUEUE_TRANSFER_BIT) > 0) {
                if (current_transfer_score <= min_transfer_score) {
                    min_transfer_score = current_transfer_score;
                    queue_family_index.transfer = @intCast(i);
                }
            }

            // Present queue
            var support_present: c.VkBool32 = undefined;
            try VK_CHECK(c.vkGetPhysicalDeviceSurfaceSupportKHR(
                physical_device,
                @intCast(i),
                surface,
                &support_present,
            ));

            if (support_present == c.VK_TRUE) {
                queue_family_index.present = @intCast(i);
            }
        }

        if (!requirements.graphics or (requirements.graphics and queue_family_index.graphics != null) and
            !requirements.present or (requirements.present and queue_family_index.present != null) and
            !requirements.compute or (requirements.compute and queue_family_index.compute != null) and
            !requirements.transfer or (requirements.transfer and queue_family_index.transfer != null))
        {
            var swapchain_support = vk_swapchain.SwapChainSupport{};
            try swapchain_support.init(
                physical_device,
                surface,
                allocator,
            );
            defer swapchain_support.deinit(allocator);

            if (swapchain_support.format_count < 1 or swapchain_support.present_mode_count < 1) {
                return false;
            }

            // if everything goes right
            return true;
        }

        return false;
    }
};

pub const LogicDevice = struct {
    handle: c.VkDevice = undefined,
    queues: std.ArrayList(vk_types.QueueInfo) = undefined,
    graphics_queue: vk_types.QueueInfo = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        physical_device: c.VkPhysicalDevice,
    ) !void {
        std.log.info("LogicDevice init", .{});
        self.queues = std.ArrayList(vk_types.QueueInfo).init(allocator);

        try self.queues.append(try getQueue(
            allocator,
            physical_device,
            c.VK_QUEUE_GRAPHICS_BIT,
        ));

        self.graphics_queue = self.queues.items[0];

        const queue_priority: f32 = 1.0;
        var queue_info = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = self.graphics_queue.familyIndex,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        var features11 = c.VkPhysicalDeviceVulkan11Features{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        };
        var features12 = c.VkPhysicalDeviceVulkan12Features{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        };
        features12.bufferDeviceAddress = c.VK_TRUE;
        features12.descriptorIndexing = c.VK_TRUE;
        var features13 = c.VkPhysicalDeviceVulkan13Features{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        };
        features13.dynamicRendering = c.VK_TRUE;
        features13.synchronization2 = c.VK_TRUE;
        // var features14 = c.VkPhysicalDeviceVulkan14Features{ .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_4_FEATURES };

        pNextChainPushFront(c.VkPhysicalDeviceVulkan11Features, c.VkPhysicalDeviceVulkan12Features, &features11, &features12);
        pNextChainPushFront(c.VkPhysicalDeviceVulkan11Features, c.VkPhysicalDeviceVulkan13Features, &features11, &features13);
        // pNextChainPushFront(c.VkPhysicalDeviceVulkan11Features, c.VkPhysicalDeviceVulkan14Features, &features11, &features14);

        // available extensions
        var available_device_extension_count: u32 = 0;
        try VK_CHECK(c.vkEnumerateDeviceExtensionProperties(physical_device, null, &available_device_extension_count, null));

        const device_extensions_available = try allocator.alloc(c.VkExtensionProperties, available_device_extension_count);
        defer allocator.free(device_extensions_available);
        try VK_CHECK(c.vkEnumerateDeviceExtensionProperties(physical_device, null, &available_device_extension_count, device_extensions_available.ptr));

        var device_extensions = std.ArrayList([*c]const u8).init(allocator);
        defer device_extensions.deinit();

        try device_extensions.append(c.VK_KHR_SWAPCHAIN_EXTENSION_NAME); // Needed for display on the screen

        //Check if the device supports the required extensions
        //Because we cannot request a device with extension it is not supporting

        if (vk_utils.extensionIsAvailable(c.VK_KHR_PUSH_DESCRIPTOR_EXTENSION_NAME, device_extensions_available)) {
            try device_extensions.append(c.VK_KHR_PUSH_DESCRIPTOR_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_EXT_EXTENDED_DYNAMIC_STATE_EXTENSION_NAME, device_extensions_available)) {
            var dynamicStateFeatures = c.VkPhysicalDeviceExtendedDynamicStateFeaturesEXT{
                .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT,
            };
            pNextChainPushFront(
                c.VkPhysicalDeviceVulkan11Features,
                c.VkPhysicalDeviceExtendedDynamicStateFeaturesEXT,
                &features11,
                &dynamicStateFeatures,
            );
            try device_extensions.append(c.VK_EXT_EXTENDED_DYNAMIC_STATE_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_EXT_EXTENDED_DYNAMIC_STATE_2_EXTENSION_NAME, device_extensions_available)) {
            var dynamicState2Features = c.VkPhysicalDeviceExtendedDynamicState2FeaturesEXT{
                .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_2_FEATURES_EXT,
            };
            pNextChainPushFront(
                c.VkPhysicalDeviceVulkan11Features,
                c.VkPhysicalDeviceExtendedDynamicState2FeaturesEXT,
                &features11,
                &dynamicState2Features,
            );
            try device_extensions.append(c.VK_EXT_EXTENDED_DYNAMIC_STATE_2_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME, device_extensions_available)) {
            var dynamicState3Features = c.VkPhysicalDeviceExtendedDynamicState3FeaturesEXT{
                .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT,
            };
            pNextChainPushFront(
                c.VkPhysicalDeviceVulkan11Features,
                c.VkPhysicalDeviceExtendedDynamicState3FeaturesEXT,
                &features11,
                &dynamicState3Features,
            );
            try device_extensions.append(c.VK_EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME);
        }
        if (vk_utils.extensionIsAvailable(c.VK_EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME, device_extensions_available)) {
            var swapchainFeatures = c.VkPhysicalDeviceSwapchainMaintenance1FeaturesEXT{
                .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT,
            };
            pNextChainPushFront(
                c.VkPhysicalDeviceVulkan11Features,
                c.VkPhysicalDeviceSwapchainMaintenance1FeaturesEXT,
                &features11,
                &swapchainFeatures,
            );
            try device_extensions.append(c.VK_EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME);
        }

        if (builtin.mode == .Debug) {
            for (device_extensions.items) |ext| {
                std.log.debug("Device extension: {s}", .{ext});
            }
        }

        var device_features = c.VkPhysicalDeviceFeatures2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
        };
        device_features.pNext = &features11;

        c.vkGetPhysicalDeviceFeatures2(physical_device, &device_features);
        assert(features13.dynamicRendering == c.VK_TRUE);
        assert(features13.maintenance4 == c.VK_TRUE);
        // assert(features14.maintenance5 == c.VK_TRUE);
        // assert(features14.maintenance6 == c.VK_TRUE);

        var device_properties = c.VkPhysicalDeviceProperties2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
        };
        var pushDescriptorProperties = c.VkPhysicalDevicePushDescriptorPropertiesKHR{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PUSH_DESCRIPTOR_PROPERTIES_KHR,
        };
        device_properties.pNext = &pushDescriptorProperties;

        c.vkGetPhysicalDeviceProperties2(physical_device, &device_properties);

        var device_info = c.VkDeviceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = &device_features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_info,
            .enabledExtensionCount = @intCast(device_extensions.items.len),
            .ppEnabledExtensionNames = device_extensions.items.ptr,
        };

        try VK_CHECK(c.vkCreateDevice(
            physical_device,
            &device_info,
            null,
            &self.handle,
        ));

        // Get the requested queues
        c.vkGetDeviceQueue(
            self.handle,
            self.graphics_queue.familyIndex,
            self.graphics_queue.queueIndex,
            &self.graphics_queue.queue,
        );
    }

    pub fn deinit(self: *@This()) void {
        self.queues.deinit();
        c.vkDestroyDevice(self.handle, null);
        std.log.info("LogicDevice deinit", .{});
    }

    fn getQueue(
        allocator: std.mem.Allocator,
        physical_device: c.VkPhysicalDevice,
        flags: c.VkQueueFlagBits,
    ) !vk_types.QueueInfo {
        var queue_family_count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties2(physical_device, &queue_family_count, null);

        var queue_families = std.ArrayList(c.VkQueueFamilyProperties2).init(allocator);
        defer queue_families.deinit();

        for (0..queue_family_count) |_| {
            try queue_families.append(c.VkQueueFamilyProperties2{ .sType = c.VK_STRUCTURE_TYPE_QUEUE_FAMILY_PROPERTIES_2 });
        }

        c.vkGetPhysicalDeviceQueueFamilyProperties2(
            physical_device,
            &queue_family_count,
            queue_families.items.ptr,
        );

        var queue_info = vk_types.QueueInfo{};
        for (0..queue_family_count) |i| {
            if ((queue_families.items[i].queueFamilyProperties.queueFlags & flags) == 1) {
                queue_info.familyIndex = @intCast(i);
                queue_info.queueIndex = 0;
            }
        }

        return queue_info;
    }

    fn pNextChainPushFront(main_T: type, new_T: type, main_struct: *main_T, new_struct: *new_T) void {
        // equivalent to -> in C
        new_struct.*.pNext = main_struct.*.pNext;
        main_struct.*.pNext = new_struct;
    }
};
