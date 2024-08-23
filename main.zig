//main.zig
//Preston Engler
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
    //@cInclude("cimgui.h");
    //@cInclude("cimgui_impl.h");
});

const std = @import("std");

var window: *c.GLFWwindow = undefined;

export fn errorCallback(_: c_int, description: [*c]const u8) void {
    std.debug.panic("Error: {s}\n", .{description});
}

pub fn main() u8 {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == c.GL_FALSE) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return 1;
    }

    std.debug.print("Success!\n", .{});

    return 0;
}
