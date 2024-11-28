//vk.zig
//Preston Engler

//The in/out file for the rest of the program to interface with the vulkan zig files

const c = @import("../c.zig");
const init = @import("init.zig");
const draw_frame = @import("draw_frame.zig");
const core = @import("core.zig");
const gp = @import("graphics_pipeline.zig");

pub var framebufferResized: *bool = &core.framebufferResized;

pub fn initVulkan(w: *c.GLFWwindow) void {
    init.initVulkan(w);
}

pub fn waitIdle() void {
    core.waitIdle();
}

pub fn cleanup() void {
    core.cleanup();
}

pub fn drawFrame() void {
    draw_frame.drawFrame();
}

pub fn switchGraphics(n: i32) void {
    gp.switchGraphics(n);
}
