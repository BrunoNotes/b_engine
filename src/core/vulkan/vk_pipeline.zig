const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c = @import("../c.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;
const vk_utils = @import("vk_utils.zig");
const vk_shader = @import("vk_shader.zig");
const vk_descriptor = @import("vk_descriptor.zig");

pub const Pipeline = struct {
    handle: c.VkPipeline = undefined,
    layout: c.VkPipelineLayout = undefined,

    pub fn init(
        self: *@This(),
        device: c.VkDevice,
        image_format: c.VkFormat,
        is_wireframe: bool,
        shader_stages: vk_shader.ShaderStages,
        push_constants_range: ?[]c.VkPushConstantRange,
        descriptors_set_layout: ?[]c.VkDescriptorSetLayout,
        attribute_descriptions: ?[]c.VkVertexInputAttributeDescription,
    ) !void {
        std.log.info("Pipeline init", .{});

        var layout_info = c.VkPipelineLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        };

        if (push_constants_range) |handle| {
            layout_info.pushConstantRangeCount = @intCast(handle.len);
            layout_info.pPushConstantRanges = handle.ptr;
        }
        if (descriptors_set_layout) |handle| {
            layout_info.setLayoutCount = @intCast(handle.len);
            layout_info.pSetLayouts = handle.ptr;
        }

        try VK_CHECK(c.vkCreatePipelineLayout(device, &layout_info, null, &self.layout));

        var binding_description = c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(vk_types.Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        var vertex_input = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = &binding_description,
        };

        if (attribute_descriptions) |desc| {
            vertex_input.vertexAttributeDescriptionCount = @intCast(desc.len);
            vertex_input.pVertexAttributeDescriptions = desc.ptr;
        }

        var input_assembly = c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = c.VK_FALSE,
        };

        var raster = c.VkPipelineRasterizationStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = c.VK_FALSE,
            .rasterizerDiscardEnable = c.VK_FALSE,
            .polygonMode = if (is_wireframe) c.VK_POLYGON_MODE_LINE else c.VK_POLYGON_MODE_FILL,
            .depthBiasEnable = c.VK_FALSE,
            .lineWidth = 1.0,
        };

        const dynamic_states = [_]c.VkDynamicState{
            c.VK_DYNAMIC_STATE_VIEWPORT,
            c.VK_DYNAMIC_STATE_SCISSOR,
            c.VK_DYNAMIC_STATE_CULL_MODE,
            c.VK_DYNAMIC_STATE_FRONT_FACE,
            c.VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY,
        };

        var blend_attachment = c.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        };

        var blend = c.VkPipelineColorBlendStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &blend_attachment,
        };

        var viewport = c.VkPipelineViewportStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .scissorCount = 1,
        };

        // Disable all depth testing.
        var depth_stencil = c.VkPipelineDepthStencilStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthCompareOp = c.VK_COMPARE_OP_ALWAYS,
        };

        // No multisampling.
        var multisample = c.VkPipelineMultisampleStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        };

        var dynamic_state_info = c.VkPipelineDynamicStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = @intCast(dynamic_states.len),
            .pDynamicStates = &dynamic_states,
        };

        var pipeline_rendering_info = c.VkPipelineRenderingCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &image_format,
        };

        var pipeline_info = c.VkGraphicsPipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .pNext = &pipeline_rendering_info,
            .stageCount = @intCast(shader_stages.stage_infos.items.len),
            .pStages = shader_stages.stage_infos.items.ptr,
            .pVertexInputState = &vertex_input,
            .pInputAssemblyState = &input_assembly,
            .pViewportState = &viewport,
            .pRasterizationState = &raster,
            .pMultisampleState = &multisample,
            .pDepthStencilState = &depth_stencil,
            .pColorBlendState = &blend,
            .pDynamicState = &dynamic_state_info,
            .layout = self.layout, // We need to specify the pipeline layout description up front as well.
            .renderPass = null, // Since we are using dynamic rendering this will set as null
            .subpass = 0,
        };

        try VK_CHECK(c.vkCreateGraphicsPipelines(device, null, 1, &pipeline_info, null, &self.handle));
    }

    pub fn deinit(
        self: *@This(),
        device: c.VkDevice,
    ) void {
        c.vkDestroyPipeline(device, self.handle, null);
        c.vkDestroyPipelineLayout(device, self.layout, null);

        std.log.info("Pipeline deinit", .{});
    }

    pub fn bind(
        self: *@This(),
        cmd: c.VkCommandBuffer,
        bind_point: c.VkPipelineBindPoint,
    ) void {
        c.vkCmdBindPipeline(
            cmd,
            bind_point,
            self.handle,
        );
    }

    pub fn setDynamicUpdates(
        self: *@This(),
        cmd: c.VkCommandBuffer,
        window_extent: c.VkExtent2D,
    ) void {
        _ = self;
        const window_width: f32 = @floatFromInt(window_extent.width);
        const window_height: f32 = @floatFromInt(window_extent.height);

        var viewport = c.VkViewport{
            .x = 0.0,
            .y = window_height,
            .width = window_width,
            .height = -window_height,
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        c.vkCmdSetViewport(cmd, 0, 1, &viewport);

        var scissor = c.VkRect2D{
            .extent = window_extent,
        };

        c.vkCmdSetScissor(cmd, 0, 1, &scissor);

        c.vkCmdSetCullMode(cmd, c.VK_CULL_MODE_NONE);
        // c.vkCmdSetCullMode(cmd, c.VK_CULL_MODE_BACK_BIT);

        c.vkCmdSetFrontFace(cmd, c.VK_FRONT_FACE_COUNTER_CLOCKWISE);

        c.vkCmdSetPrimitiveTopology(cmd, c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
    }
};
