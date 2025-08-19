const std = @import("std");
const c = @import("../../c.zig");
const math = @import("../../math.zig");
const vk_buffer = @import("../vk_buffer.zig");
const vk_renderer = @import("../vk_renderer.zig");

// TODO: temp
pub const CameraUniform = struct {
    projection: math.Mat4 = undefined, // 64 bytes
    view: math.Mat4 = undefined,
    // reserved_0: math.Mat4 = undefined,
    // reserved_1: math.Mat4 = undefined,
};

pub const Camera = struct {
    velocity: math.Vec3 = math.Vec3.ZERO,
    position: math.Vec3 = math.Vec3.ZERO,
    pitch: f32 = 0, // vertical rotation
    yaw: f32 = 0, // horizontal rotation
    FOV: f32 = 70,
    uniform: CameraUniform = undefined,
    buffer: vk_buffer.Buffer(CameraUniform) = undefined,

    pub fn init(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) !void {
        self.uniform = CameraUniform{
            .projection = math.Mat4.perspective(
                std.math.degreesToRadians(70),
                @as(f32, @floatFromInt(context.window_extent.width)) / @as(f32, @floatFromInt(context.window_extent.height)),
                0.1,
                1000.0,
            ),
            // .view = math.Mat4.translation(math.Vec3.init(0.0, 0.0, -2.0)),
            .view = self.getViewMatrix(),
        };

        try self.buffer.init(
            context.vk_allocator,
            context.device.handle,
            @sizeOf(CameraUniform),
            c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VMA_MEMORY_USAGE_AUTO,
            null,
        );
    }

    pub fn deinit(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) void {
        self.buffer.deinit(context.vk_allocator);
    }

    pub fn render(
        self: *@This(),
        context: *vk_renderer.VkRenderer,
    ) !void {
        try self.buffer.loadBufferData(
            context.vk_allocator,
            context.device.handle,
            self.uniform,
            @sizeOf(CameraUniform),
            context.device.graphics_queue.queue,
            context.swapchain.getCurrentFrame().cmd_pool,
        );
    }

    pub fn update(
        self: *@This(),
        width: u32,
        height: u32,
    ) void {
        // TODO: rotate in local space
        const velocity = math.Vec3.multScalar(self.velocity, 0.5);
        const v = math.Vec4.init(velocity.x, velocity.y, velocity.z, 0);
        const r = self.getRotationMatrix();

        const result = math.Vec4.multMatrix(r, v);
        self.position = math.Vec3.add(
            self.position,
            math.Vec3.init(result.x, result.y, result.z),
        );

        self.uniform.view = self.getViewMatrix();
        self.uniform.projection = self.getProjectionMatrix(width, height);
    }

    pub fn getRotationMatrix(self: *@This()) math.Mat4 {
        const pitch = math.Quat.fromAxisAngle(math.Vec3.LEFT, self.pitch);
        const yaw = math.Quat.fromAxisAngle(math.Vec3.UP, self.yaw);
        return math.Mat4.mult(math.Quat.toMat4(pitch), math.Quat.toMat4(yaw));
    }

    pub fn getViewMatrix(self: *@This()) math.Mat4 {
        // _ = self;
        const rotation = self.getRotationMatrix();
        const translation = math.Mat4.translation(self.position);
        // std.debug.print("{any}\n", .{rotation});

        return math.Mat4.inverse(math.Mat4.mult(translation, rotation));
        // return math.Mat4.inverse(translation);
    }

    pub fn getProjectionMatrix(
        self: *@This(),
        width: u32,
        height: u32,
    ) math.Mat4 {
        // TODO: make others projections
        return math.Mat4.perspective(
            std.math.degreesToRadians(self.FOV),
            @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
            0.1,
            1000.0,
        );
    }

    pub fn processSDLEvents(
        self: *@This(),
        e: c.SDL_Event,
        delta_seconds: f32,
    ) void {
        const mod: i32 = 2;
        if (e.type == c.SDL_EVENT_KEY_DOWN) {
            if (e.key.key == c.SDLK_W) {
                self.velocity.z = -mod * delta_seconds;
            }
            if (e.key.key == c.SDLK_S) {
                self.velocity.z = mod * delta_seconds;
            }
            if (e.key.key == c.SDLK_A) {
                self.velocity.x = -mod * delta_seconds;
            }
            if (e.key.key == c.SDLK_D) {
                self.velocity.x = mod * delta_seconds;
            }
        }

        if (e.type == c.SDL_EVENT_KEY_UP) {
            if (e.key.key == c.SDLK_W) {
                self.velocity.z = 0;
            }
            if (e.key.key == c.SDLK_S) {
                self.velocity.z = 0;
            }
            if (e.key.key == c.SDLK_A) {
                self.velocity.x = 0;
            }
            if (e.key.key == c.SDLK_D) {
                self.velocity.x = 0;
            }
        }

        var x: f32 = undefined;
        var y: f32 = undefined;
        const buttons = c.SDL_GetMouseState(&x, &y);
        // if (buttons & c.SDL_BUTTON_LMASK > 0) {
        //     // Left mouse button is being held
        // }

        if (buttons & c.SDL_BUTTON_RMASK > 0) {
            // Right mouse button is being held
            if (e.type == c.SDL_EVENT_MOUSE_MOTION) {
                self.yaw += e.motion.xrel / 200;
                self.pitch -= e.motion.yrel / 200;
            }
        }

        // if (buttons & c.SDL_BUTTON_MMASK > 0) {
        //     // Middle mouse button is being held
        // }
    }
};
