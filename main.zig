//main.zig
//Preston Engler
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
    //@cInclude("cimgui.h");
    //@cInclude("cimgui_impl.h");
});

const std = @import("std");

export fn errorCallback(_: c_int, description: [*c]const u8) void {
    std.debug.panic("Error: {s}\n", .{description});
}

pub fn main() u8 {
    _ = c.glfwSetErrorCallback(errorCallback);

    if (c.glfwInit() == c.GL_FALSE) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return 1;
    }
    defer c.glfwTerminate();

    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.print("Vulkan is not supported\n", .{});
        return 1;
    }

    const window: *c.GLFWwindow = c.glfwCreateWindow(640, 480, "Test", null, null) orelse
        std.debug.panic("Failed to create window\n", .{});
    defer c.glfwDestroyWindow(window);

    _ = c.glfwSetKeyCallback(window, key_callback);

    while (c.glfwWindowShouldClose(window) == 0) {
        //Continuously run
        loop(window);
    }

    return 0;
}

//params: window, key, scancode, action, mods
export fn key_callback(optional_window: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, _: c_int) void {
    const window = optional_window.?;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
    }
    return;
}

inline fn loop(window: *c.GLFWwindow) void {
    c.glfwSwapBuffers(window);
    c.glfwPollEvents();
}
