const std = @import("std");
const core = @import("Core");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var eng = core.Engine{
        .window = core.Window{
            .name = "B engine test",
            .width = 800,
            .height = 600,
        },
    };

    try eng.init(allocator);
    defer eng.deinit();

    var angle: f32 = 0.0;
    // var camera_view = core.math.Vec3.init(0, 0, -2);

    // TODO: temp
    var triangle: core.vulkan.vk_triangle.VkTriangle = undefined;
    try triangle.init(allocator, &eng.vk_renderer);
    defer triangle.deinit(&eng.vk_renderer);

    var timer = try std.time.Timer.start();
    var last_time = timer.read();

    while (eng.running) {
        const current_time = timer.read();
        const delta_time = current_time - last_time;
        last_time = current_time;
        const delta_seconds = @as(f32, @floatFromInt(delta_time)) / 1_000_000_000.0;

        // TODO: create an event system
        var event: core.c.SDL_Event = undefined;

        while (core.c.SDL_PollEvent(&event)) {
            // close the window when user alt-f4s or clicks the X button
            if (event.type == core.c.SDL_EVENT_QUIT) {
                eng.running = false;
            }

            if (event.window.type == core.c.SDL_EVENT_WINDOW_RESIZED) {
                eng.window.resize();
                eng.vk_renderer.resize(eng.window.getVkSurfaceExtent());
            }

            if (event.type == core.c.SDL_EVENT_MOUSE_MOTION) {
                triangle.camera.yaw = event.motion.xrel / 200;
                triangle.camera.pitch = event.motion.yrel / 200;
            }
        }

        const keyboard_state = core.c.SDL_GetKeyboardState(null);
        // var camera_translation = core.math.Vec3.ZERO;
        //
        // if (keyboard_state[core.c.SDL_SCANCODE_W]) {
        //     camera_translation = core.math.Vec3.FORWARD;
        // }
        // if (keyboard_state[core.c.SDL_SCANCODE_A]) {
        //     camera_translation = core.math.Vec3.LEFT;
        // }
        // if (keyboard_state[core.c.SDL_SCANCODE_S]) {
        //     camera_translation = core.math.Vec3.BACK;
        // }
        // if (keyboard_state[core.c.SDL_SCANCODE_D]) {
        //     camera_translation = core.math.Vec3.RIGHT;
        // }
        // if (keyboard_state[core.c.SDL_SCANCODE_SPACE]) {
        //     camera_translation = core.math.Vec3.UP;
        // }
        // if (keyboard_state[core.c.SDL_SCANCODE_LSHIFT]) {
        //     camera_translation = core.math.Vec3.DOWN;
        // }
        if (keyboard_state[core.c.SDL_SCANCODE_RIGHT]) {
            angle += 1 * delta_seconds;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_LEFT]) {
            angle -= 1 * delta_seconds;
        }

        const rotation = core.math.Quat.fromAxisAngle(core.math.Vec3.UP, angle);
        const model_matrix = core.math.Quat.toRotationMatrix(
            rotation,
            core.math.Vec3.ZERO,
        );

        // rotate the object with a push constant
        // triangle.push_constant.model_matrix = model_matrix;
        triangle.camera_uniforms.model_matrix = model_matrix;

        triangle.camera.update();
        triangle.camera_uniforms.view = triangle.camera.getViewMatrix();
        std.debug.print("{any}\n", .{triangle.camera_uniforms.view});

        // camera_translation.y = camera_translation.y * -1;
        // camera_translation.x = camera_translation.x * -1;
        // camera_translation = core.math.Vec3.multScalar(camera_translation, delta_seconds);
        // camera_view = core.math.Vec3.add(camera_view, camera_translation);
        // triangle.camera_uniforms.view = core.math.Mat4.translation(camera_view);
        // triangle.camera_uniforms.projection = core.math.Mat4.perspective(
        //     std.math.degreesToRadians(70),
        //     @as(f32, @floatFromInt(eng.vk_renderer.window_extent.width)) / @as(f32, @floatFromInt(eng.vk_renderer.window_extent.height)),
        //     0.1,
        //     1000.0,
        // );

        try eng.vk_renderer.beginDraw(allocator);

        // --------- triangle ---------
        try triangle.render(allocator, &eng.vk_renderer);
        // --------- triangle ---------

        try eng.vk_renderer.endDraw(allocator);
    }
}

test "sample test" {
    try std.testing.expectEqual(1, 1);
}
