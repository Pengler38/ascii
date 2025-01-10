//main.zig
//Preston Engler

const c = @import("c.zig");

const std = @import("std");
const vk = @import("vk/vk.zig");

const WIDTH = 640;
const HEIGHT = 480;

var window: *c.GLFWwindow = undefined;

pub fn main() !u8 {
    initWindow();
    vk.initVulkan(window);

    //Begin main loop
    while (c.glfwWindowShouldClose(window) == 0) {
        //Continuously run
        loop();
    }

    vk.waitIdle();
    cleanup();

    return 0;
}

export fn errorCallback(_: c_int, description: [*c]const u8) void {
    std.debug.panic("Error: {s}\n", .{description});
}

fn initWindow() void {
    _ = c.glfwSetErrorCallback(errorCallback);

    //Init GLFW
    if (c.glfwInit() == c.GL_FALSE) {
        std.debug.panic("Failed to initialize GLFW\n", .{});
    }

    //Create window
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    //c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    window = c.glfwCreateWindow(WIDTH, HEIGHT, "Test", null, null) orelse
        std.debug.panic("Failed to create window\n", .{});
    _ = c.glfwSetFramebufferSizeCallback(window, framebufferResizeCallback);

    //Add keypress handling function
    _ = c.glfwSetKeyCallback(window, key_callback);
}

fn cleanup() void {
    vk.cleanup();
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

export fn framebufferResizeCallback(w: ?*c.GLFWwindow, width: c_int, height: c_int) void {
    _ = width;
    _ = height;
    _ = w;
    vk.framebufferResized.* = true;
}

//params: window, key, scancode, action, mods
export fn key_callback(optional_window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    _ = scancode;
    _ = mods;
    const current_window = optional_window.?;
    if (action == c.GLFW_PRESS) {
        switch (key) {
            c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(current_window, c.GLFW_TRUE),
            c.GLFW_KEY_1...c.GLFW_KEY_9 => vk.switchGraphics(key - 48),
            else => {},
        }
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

    c.glfwPollEvents();
    vk.drawFrame();
}
