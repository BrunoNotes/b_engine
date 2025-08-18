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

    // TODO: temp
    var model: core.vulkan.model.Model = undefined;
    try model.init(allocator, &eng.vk_renderer);
    defer model.deinit(&eng.vk_renderer);

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

            model.camera.processSDLEvents(event, delta_seconds);
        }

        const keyboard_state = core.c.SDL_GetKeyboardState(null);

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
        model.camera.uniform.model_matrix = model_matrix;

        model.camera.update(
            eng.vk_renderer.window_extent.width,
            eng.vk_renderer.window_extent.height,
        );
        // model.camera.uniform.view = model.camera.getViewMatrix();
        // model.camera.uniform.projection = core.math.Mat4.perspective(
        //     std.math.degreesToRadians(70),
        //     @as(f32, @floatFromInt(eng.vk_renderer.window_extent.width)) / @as(f32, @floatFromInt(eng.vk_renderer.window_extent.height)),
        //     0.1,
        //     1000.0,
        // );

        try eng.vk_renderer.beginDraw(allocator);

        // --------- triangle ---------
        try model.render(allocator, &eng.vk_renderer);
        // --------- triangle ---------

        try eng.vk_renderer.endDraw(allocator);
    }
}

test "sample test" {
    try std.testing.expectEqual(1, 1);
}
