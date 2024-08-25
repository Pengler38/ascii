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

    //Init GLFW
    if (c.glfwInit() == c.GL_FALSE) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return 1;
    }
    defer c.glfwTerminate();

    //Check for Vulkan Support
    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.print("Vulkan is not supported\n", .{});
        return 1;
    }

    //Create window
    const window: *c.GLFWwindow = c.glfwCreateWindow(640, 480, "Test", null, null) orelse
        std.debug.panic("Failed to create window\n", .{});
    defer c.glfwDestroyWindow(window);

    //Add keypress handling function
    _ = c.glfwSetKeyCallback(window, key_callback);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);

    //Begin main loop
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

var numFrames: u64 = 0;
var seconds: u64 = 0;
inline fn loop(window: *c.GLFWwindow) void {
    numFrames += 1;

    const time = c.glfwGetTime();

    if (@as(u64, @intFromFloat(time)) > seconds) {
        seconds += 1;
        std.debug.print("FPS: {d}\n", .{numFrames});
        numFrames = 0;
    }

    c.glfwSwapBuffers(window);
    c.glfwPollEvents();
}
