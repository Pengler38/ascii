//vk.zig
//Preston Engler

//The in/out file for the rest of the program to interface with the vulkan zig files

const c = @import("c.zig");
const init = @import("vk_init.zig");
const draw_frame = @import("vk_draw_frame.zig");
const core = @import("vk_core.zig");

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
