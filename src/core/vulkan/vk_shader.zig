const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const util = @import("../util.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub const ShaderType = enum { vert, frag, tesc, tese, geom, comp };

pub const ShaderStageType = struct {
    path: []const u8,
    stage: c.VkShaderStageFlagBits,
    type: ShaderType,
};

pub const ShaderStages = struct {
    modules: std.ArrayList(c.VkShaderModule) = undefined,
    stage_infos: std.ArrayList(c.VkPipelineShaderStageCreateInfo) = undefined,
    module_infos: std.ArrayList(c.VkShaderModuleCreateInfo) = undefined,

    pub fn init(
        self: *@This(),
        allocator: std.mem.Allocator,
        device: c.VkDevice,
        shader_stage_type: []ShaderStageType,
    ) !void {
        std.log.info("ShaderStages init", .{});
        self.modules = std.ArrayList(c.VkShaderModule).init(allocator);
        self.stage_infos = std.ArrayList(c.VkPipelineShaderStageCreateInfo).init(allocator);
        self.module_infos = std.ArrayList(c.VkShaderModuleCreateInfo).init(allocator);

        for (shader_stage_type) |shader| {
            const shader_buffer = try util.readFile(allocator, shader.path);

            var module_info = c.VkShaderModuleCreateInfo{};
            module_info.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
            module_info.pNext = null;
            module_info.codeSize = shader_buffer.len;
            module_info.pCode = @alignCast(@ptrCast(shader_buffer.ptr));

            var module: c.VkShaderModule = undefined;
            try VK_CHECK(c.vkCreateShaderModule(
                device,
                &module_info,
                null,
                &module,
            ));

            const stage_info = c.VkPipelineShaderStageCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = shader.stage,
                .module = module,
                .pName = "main",
            };

            try self.modules.append(module);
            try self.stage_infos.append(stage_info);
            try self.module_infos.append(module_info);

            // std.debug.print("stage: {s}\n", .{c.string_VkShaderStageFlagBits(shader.stage)});
            // std.debug.print("stage_info: {s}\n", .{c.string_VkShaderStageFlagBits(stage_info.stage)});
        }
    }
    pub fn deinit(
        self: *@This(),
        device: c.VkDevice,
    ) void {
        for (self.modules.items) |module| {
            c.vkDestroyShaderModule(device, module, null);
        }
        self.modules.deinit();
        self.stage_infos.deinit();
        self.module_infos.deinit();
        std.log.info("ShaderStages deinit", .{});
    }
};
