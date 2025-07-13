const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub const Descriptor = struct {
    pool: c.VkDescriptorPool = undefined,
    set_layout: c.VkDescriptorSetLayout = undefined,
    set: c.VkDescriptorSet = undefined,

    pub fn init(
        self: *@This(),
        device: c.VkDevice,
        max_descriptor_set: u32,
        pool_size: []c.VkDescriptorPoolSize,
        layout_binding: []c.VkDescriptorSetLayoutBinding,
    ) !void {
        std.log.info("Descriptor init", .{});

        var pool_info = c.VkDescriptorPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .flags = c.VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT | //  allows descriptor sets to be updated after they have been bound to a command buffer
                c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT, // individual descriptor sets can be freed from the descriptor pool
            .maxSets = max_descriptor_set,
            .poolSizeCount = @intCast(pool_size.len),
            .pPoolSizes = pool_size.ptr,
        };

        try VK_CHECK(c.vkCreateDescriptorPool(device, &pool_info, null, &self.pool));

        var layout_info = c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .flags = c.VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT, // Allows to update the descriptor set after it has been bound
            .bindingCount = @intCast(layout_binding.len),
            .pBindings = layout_binding.ptr,
        };

        try VK_CHECK(c.vkCreateDescriptorSetLayout(device, &layout_info, null, &self.set_layout));

        var set_layouts = [_]c.VkDescriptorSetLayout{
            self.set_layout,
        };

        var set_alloc_info = c.VkDescriptorSetAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = self.pool,
            .descriptorSetCount = @intCast(set_layouts.len),
            .pSetLayouts = &set_layouts,
        };

        try VK_CHECK(c.vkAllocateDescriptorSets(device, &set_alloc_info, &self.set));
    }

    pub fn deinit(
        self: *@This(),
        device: c.VkDevice,
    ) void {
        c.vkDestroyDescriptorSetLayout(device, self.set_layout, null);
        c.vkDestroyDescriptorPool(device, self.pool, null);

        std.log.info("Descriptor deinit", .{});
    }
};
