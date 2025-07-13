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
    var camera_view = core.math.Vec3.init(0.0, 0.0, -2.0);

    while (eng.running) {
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
        }

        const keyboard_state = core.c.SDL_GetKeyboardState(null);

        const view_value: f32 = 0.01;

        if (keyboard_state[core.c.SDL_SCANCODE_W]) {
            camera_view.z += view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_A]) {
            camera_view.x += view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_S]) {
            camera_view.z -= view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_D]) {
            camera_view.x -= view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_SPACE]) {
            camera_view.y -= view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_LSHIFT]) {
            camera_view.y += view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_RIGHT]) {
            angle += view_value;
        }
        if (keyboard_state[core.c.SDL_SCANCODE_LEFT]) {
            angle -= view_value;
        }

        const rotation = core.math.Quat.fromAxisAngle(core.math.Vec3.FORWARD, angle);
        const model_matrix = core.math.Quat.toRotationMatrix(
            rotation,
            core.math.Vec3.ZERO,
        );

        // rotate the object with a push constant
        eng.vk_renderer.triangle.push_constant.model_matrix = model_matrix;

        eng.vk_renderer.triangle.camera_uniforms.view = core.math.Mat4.translation(camera_view);
        eng.vk_renderer.triangle.camera_uniforms.projection = core.math.Mat4.perspective(
            std.math.degreesToRadians(45),
            @as(f32, @floatFromInt(eng.vk_renderer.window_extent.width)) / @as(f32, @floatFromInt(eng.vk_renderer.window_extent.height)),
            0.1,
            1000.0,
        );

        try eng.vk_renderer.beginDraw(allocator);

        try eng.vk_renderer.endDraw(allocator);
    }
}

test "sample test" {
    try std.testing.expectEqual(1, 1);
}
