const std = @import("std");

const c = @import("../c.zig");
const vk_cmd = @import("vk_cmd_buffer.zig");
const vk_types = @import("vk_types.zig");
const VK_CHECK = vk_types.VK_CHECK;

pub fn Buffer(comptime T: type) type {
    return struct {
        handle: c.VkBuffer = undefined,
        allocation: c.VmaAllocation = undefined,

        pub fn init(
            self: *@This(),
            vk_allocator: c.VmaAllocator,
            device: c.VkDevice,
            size: c.VkDeviceSize,
            usage: c.VkBufferUsageFlags,
            memory_usage: ?c.VmaMemoryUsage,
            flags: ?c.VmaAllocationCreateFlags,
        ) !void {
            const mem_usage: c.VmaMemoryUsage = if (memory_usage != null) memory_usage.? else c.VMA_MEMORY_USAGE_AUTO;
            const alloc_flags: c.VmaAllocationCreateFlags = if (flags != null) flags.? else 0;

            var buffer_info = c.VkBufferCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                .size = size,
                .usage = usage,
                .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE, // Only one queue family will access i
            };

            var alloc_info = c.VmaAllocationCreateInfo{
                .flags = alloc_flags,
                .usage = mem_usage,
            };

            const dedicated_mem_min_size: c.VkDeviceSize = 64 * 1024; // 64kb
            if (size > dedicated_mem_min_size) {
                alloc_info.flags |= c.VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT; // Use dedicated memory for large buffers
            }

            var out_alloc_info: c.VmaAllocationInfo = undefined;

            try VK_CHECK(c.vmaCreateBuffer(
                vk_allocator,
                &buffer_info,
                &alloc_info,
                &self.handle,
                &self.allocation,
                &out_alloc_info,
            ));

            // TODO: check Warning: VUID-VkBufferDeviceAddressInfo-buffer-02601
            _ = device;
            // var address_info = c.VkBufferDeviceAddressInfo{
            //     .sType = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
            //     .buffer = buffer,
            // };
            // const b_address = c.vkGetBufferDeviceAddress(device, &address_info);
        }

        pub fn deinit(
            self: *@This(),
            vk_allocator: c.VmaAllocator,
        ) void {
            // c.vkDestroyBuffer(device, self.handle, null);
            c.vmaDestroyBuffer(vk_allocator, self.handle, self.allocation);
        }

        pub fn initStaging(
            self: *@This(),
            vk_allocator: c.VmaAllocator,
            device: c.VkDevice,
        ) !void {
            try self.init(
                vk_allocator,
                device,
                // same thins as: @sizeOf(@TypeOf(vk_builder.Buffer)) * vertices.len
                @sizeOf(T),
                c.VK_BUFFER_USAGE_2_TRANSFER_SRC_BIT_KHR,
                c.VMA_MEMORY_USAGE_CPU_TO_GPU,
                c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT,
            );
        }

        // map items to buffer memory
        pub fn mapMemory(
            self: *@This(),
            VkAllocator: c.VmaAllocator,
            items: anytype,
        ) !void {
            var data: ?*anyopaque = undefined;
            try VK_CHECK(c.vmaMapMemory(
                VkAllocator,
                self.allocation,
                &data,
            ));

            if (@TypeOf(items) != []T) {
                var items_slice = [_]T{
                    items,
                };

                @memcpy(
                    @as([*]T, @ptrCast(@alignCast(data)))[0..items_slice.len],
                    @as([]T, &items_slice),
                );
            } else {
                @memcpy(
                    @as([*]T, @ptrCast(@alignCast(data)))[0..items.len],
                    @as([]T, items),
                );
            }

            c.vmaUnmapMemory(VkAllocator, self.allocation);
        }

        pub fn copyTo(
            self: *@This(),
            queue: c.VkQueue,
            device: c.VkDevice,
            cmd_pool: c.VkCommandPool,
            dst_buffer: c.VkBuffer,
            src_offset: u64,
            dst_offset: u64,
            size: u64,
        ) !void {
            try VK_CHECK(c.vkQueueWaitIdle(queue));

            const temp_cmd = try vk_cmd.beginSingleTimeCmd(device, cmd_pool);

            var copy_region = c.VkBufferCopy{};
            copy_region.srcOffset = src_offset;
            copy_region.dstOffset = dst_offset;
            copy_region.size = size;

            c.vkCmdCopyBuffer(temp_cmd, self.handle, dst_buffer, 1, &copy_region);

            try vk_cmd.endSingleTimeCmd(temp_cmd, device, cmd_pool, queue);
        }

        pub fn loadBufferData(
            self: *@This(),
            vk_allocator: c.VmaAllocator,
            device: c.VkDevice,
            items: anytype,
            queue: c.VkQueue,
            cmd_pool: c.VkCommandPool,
        ) !void {
            var staging_buffer = Buffer(T){};
            try staging_buffer.initStaging(
                vk_allocator,
                device,
            );
            defer staging_buffer.deinit(vk_allocator);

            try staging_buffer.mapMemory(
                vk_allocator,
                items,
            );

            try staging_buffer.copyTo(
                queue,
                device,
                cmd_pool,
                self.handle,
                0,
                0,
                @sizeOf(T),
            );
        }
    };
}
