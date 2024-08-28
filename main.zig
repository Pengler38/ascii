//main.zig
//Preston Engler
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
    //@cInclude("cimgui.h");
    //@cInclude("cimgui_impl.h");
});

const std = @import("std");

const WIDTH = 640;
const HEIGHT = 480;

var window: *c.GLFWwindow = undefined;

pub fn main() !u8 {
    initWindow();
    try initVulkan();

    //Begin main loop
    while (c.glfwWindowShouldClose(window) == 0) {
        //Continuously run
        loop();
    }

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
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    window = c.glfwCreateWindow(WIDTH, HEIGHT, "Test", null, null) orelse
        std.debug.panic("Failed to create window\n", .{});

    //Add keypress handling function
    _ = c.glfwSetKeyCallback(window, key_callback);
}

//Hold Vulkan function pointers in vk variable
const VkStruct = struct {
    createInstance: c.PFN_vkCreateInstance = undefined,
    createDevice: c.PFN_vkCreateDevice = undefined,
    destroyInstance: c.PFN_vkDestroyInstance = undefined,
    enumeratePhysicalDevices: c.PFN_vkEnumeratePhysicalDevices = undefined,
};
var vk = VkStruct{};
var instance: c.VkInstance = undefined;
var surface: c.VkSurfaceKHR = undefined;

fn initVulkan() !void {
    //Check for Vulkan Support
    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.panic("Vulkan is not supported\n", .{});
    }

    //Get function pointers
    vk.createInstance = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkCreateInstance"));
    vk.createDevice = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkCreateDevice"));
    vk.destroyInstance = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkDestroyInstance"));
    vk.enumeratePhysicalDevices = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkEnumeratePhysicalDevices"));

    //Create Vulkan instance
    createInstance();

    //TODO: Add debug callback and handle Validation Layers

    //Pick Vulkan device
    try pickPhysicalDevice();

    //Query GLFW for presentation support

    //Create a GLFW surface linked to the window
    //TODO: check what the parameter VkAllocationCallbacks allocator is,
    //currently null (using the default allocator)
    if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create vulkan window surface\n", .{});
    } else {
        std.debug.print("Vulkan surface successfully created\n", .{});
    }
}

//Populates the instance variable
fn createInstance() void {

    //Query required vulkan extensions
    var count: u32 = undefined;
    const vulkanExtensions = c.glfwGetRequiredInstanceExtensions(&count) orelse
        std.debug.panic("Failed to get required Vulkan Extensions\n", .{});

    //Print vulkan extensions
    std.debug.print("{d} Required Vulkan extensions:\n", .{count});
    for (vulkanExtensions[0..count]) |ext| {
        std.debug.print("\t{s}\n", .{ext});
    }

    //Create Vulkan instance
    var instanceCreateInfo: c.VkInstanceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = null,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = count,
        .ppEnabledExtensionNames = vulkanExtensions,
    };
    if (vk.createInstance.?(&instanceCreateInfo, null, &instance) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create Vulkan instance\n", .{});
    }
}

fn pickPhysicalDevice() !void {
    var count: u32 = 0;
    _ = vk.enumeratePhysicalDevices.?(instance, &count, null);
    if (count == 0) {
        std.debug.panic("No GPUs with Vulkan support\n", .{});
    } else {
        std.debug.print("{d} GPU with Vulkan support found\n", .{count});
    }

    const devices = try std.heap.c_allocator.alloc(c.VkPhysicalDevice, count);
    defer std.heap.c_allocator.free(devices);
    _ = vk.enumeratePhysicalDevices.?(instance, &count, @ptrCast(devices));
}

fn cleanup() void {
    vk.destroyInstance.?(instance, null);
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

//params: window, key, scancode, action, mods
export fn key_callback(optional_window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    _ = scancode;
    _ = mods;
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

    c.glfwPollEvents();
}
