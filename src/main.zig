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
        if (keyboard_state[core.c.SDL_SCANCODE_W]) {
            std.debug.print("W\n", .{});
        }

        try eng.vk_renderer.beginDraw(allocator);
        try eng.vk_renderer.endDraw(allocator);
    }
}

test "sample test" {
    try std.testing.expectEqual(1, 1);
}
