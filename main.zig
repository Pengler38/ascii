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

var window: *c.GLFWwindow = undefined;

pub fn main() u8 {
    init();

    //Begin main loop
    while (c.glfwWindowShouldClose(window) == 0) {
        //Continuously run
        loop();
    }

    cleanup();

    return 0;
}

fn init() void {
    _ = c.glfwSetErrorCallback(errorCallback);

    //Init GLFW
    if (c.glfwInit() == c.GL_FALSE) {
        std.debug.panic("Failed to initialize GLFW\n", .{});
    }

    //Check for Vulkan Support
    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.panic("Vulkan is not supported\n", .{});
    }

    //Create window
    window = c.glfwCreateWindow(640, 480, "Test", null, null) orelse
        std.debug.panic("Failed to create window\n", .{});

    //Add keypress handling function
    _ = c.glfwSetKeyCallback(window, key_callback);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);
}

fn cleanup() void {
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

//params: window, key, scancode, action, mods
export fn key_callback(optional_window: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, _: c_int) void {
    const current_window = optional_window.?;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(current_window, c.GLFW_TRUE);
    }
    return;
}

inline fn loop() void {
    //This struct acts as static variables
    const S = struct {
        var numFrames: u64 = 0;
        var seconds: u64 = 0;
    };

    S.numFrames += 1;
    const time = c.glfwGetTime();

    if (@as(u64, @intFromFloat(time)) > S.seconds) {
        S.seconds += 1;
        std.debug.print("FPS: {d}\n", .{S.numFrames});
        S.numFrames = 0;
    }

    c.glfwSwapBuffers(window);
    c.glfwPollEvents();
}
