const std = @import("std");

pub fn readFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.log.err("Error opening {s}", .{path});
                return err;
            },
            else => return err,
        }
    };
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var buf_reader = buffered.reader();

    const file_stat = try file.stat();
    const buffer = try buf_reader.readAllAlloc(allocator, file_stat.size);
    return buffer;
}
