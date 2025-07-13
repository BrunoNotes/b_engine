const std = @import("std");

pub fn main() !void {
    std.debug.print("hello\n", .{});
}

test "sample test" {
    try std.testing.expectEqual(1, 1);
}
