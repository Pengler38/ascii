const std = @import("std");

pub fn heapFail() noreturn {
    std.debug.panic("Failed to allocate on the heap\n", .{});
}
