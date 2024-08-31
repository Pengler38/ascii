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
    Vk.initVulkan();

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

//Hold vulkan vars and functions in a struct
pub const Vk = struct {
    const QueueFamilyIndices = struct {
        graphics: ?u32 = null,
        presentation: ?u32 = null,
    };

    //Hold Vulkan function pointers in vk variable
    var vkCreateInstance: c.PFN_vkCreateInstance = undefined;
    var vkCreateDevice: c.PFN_vkCreateDevice = undefined;
    var vkDestroyInstance: c.PFN_vkDestroyInstance = undefined;
    var vkEnumeratePhysicalDevices: c.PFN_vkEnumeratePhysicalDevices = undefined;
    var vkGetPhysicalDeviceQueueFamilyProperties: c.PFN_vkGetPhysicalDeviceQueueFamilyProperties = undefined;
    var vkGetPhysicalDeviceProperties: c.PFN_vkGetPhysicalDeviceProperties = undefined;
    var vkGetPhysicalDeviceFeatures: c.PFN_vkGetPhysicalDeviceFeatures = undefined;
    var vkDestroyDevice: c.PFN_vkDestroyDevice = undefined;
    var vkGetDeviceQueue: c.PFN_vkGetDeviceQueue = undefined;
    var vkGetPhysicalDeviceSurfaceSupportKHR: c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR = undefined;

    var instance: c.VkInstance = undefined;
    var surface: c.VkSurfaceKHR = undefined;
    var physicalDevice: c.VkPhysicalDevice = undefined;
    var device: c.VkDevice = undefined;
    var graphicsQueue: c.VkQueue = undefined;
    var presentQueue: c.VkQueue = undefined;

    const deviceExtensions = [_]u8{
        c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };

    fn initVulkan() void {
        //Check for Vulkan Support
        if (c.glfwVulkanSupported() == c.GL_FALSE) {
            std.debug.panic("Vulkan is not supported\n", .{});
        }

        //Get function pointers necessary to create instance
        vkCreateInstance = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkCreateInstance"));

        //Create Vulkan instance
        createInstance();

        //Create a GLFW surface linked to the window
        //TODO: check what the parameter VkAllocationCallbacks allocator is,
        //currently null (using the default allocator)
        if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
            std.debug.panic("Failed to create vulkan window surface\n", .{});
        } else {
            std.debug.print("Vulkan surface successfully created\n", .{});
        }

        //Get the rest of the function pointers
        vkCreateDevice = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkCreateDevice"));
        vkDestroyInstance = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkDestroyInstance"));
        vkEnumeratePhysicalDevices = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkEnumeratePhysicalDevices"));
        vkGetPhysicalDeviceQueueFamilyProperties = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkGetPhysicalDeviceQueueFamilyProperties"));
        vkGetPhysicalDeviceFeatures = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkGetPhysicalDeviceFeatures"));
        vkGetPhysicalDeviceProperties = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkGetPhysicalDeviceProperties"));
        vkDestroyDevice = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkDestroyDevice"));
        vkGetDeviceQueue = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkGetDeviceQueue"));
        vkGetPhysicalDeviceSurfaceSupportKHR = @ptrCast(c.glfwGetInstanceProcAddress(instance, "vkGetPhysicalDeviceSurfaceSupportKHR"));

        //TODO: Add debug callback and handle Validation Layers

        //Pick Vulkan device and find the queue families
        pickPhysicalDevice();
        const indices = findQueueFamilies(physicalDevice);

        //Query GLFW for presentation support
        if (c.glfwGetPhysicalDevicePresentationSupport(instance, physicalDevice, indices.presentation.?) == c.GLFW_FALSE) {
            std.debug.panic("GLFW Presentation not supported\n", .{});
        }

        //Create a logical device
        createLogicalDevice(indices.graphics.?);

        //Create queues
        vkGetDeviceQueue.?(device, indices.graphics.?, 0, &graphicsQueue);
        vkGetDeviceQueue.?(device, indices.presentation.?, 0, &presentQueue);
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
        if (vkCreateInstance.?(&instanceCreateInfo, null, &instance) != c.VK_SUCCESS) {
            std.debug.panic("Failed to create Vulkan instance\n", .{});
        }
    }

    fn pickPhysicalDevice() void {
        var count: u32 = 0;
        _ = vkEnumeratePhysicalDevices.?(instance, &count, null);
        if (count == 0) {
            std.debug.panic("No GPUs with Vulkan support\n", .{});
        } else {
            std.debug.print("{d} GPU with Vulkan support found\n", .{count});
        }

        const devices = std.heap.c_allocator.alloc(c.VkPhysicalDevice, count) catch {
            heapFailure();
        };
        defer std.heap.c_allocator.free(devices);
        _ = vkEnumeratePhysicalDevices.?(instance, &count, @ptrCast(devices));

        for (devices) |d| {
            if (isDeviceSuitable(d) == true) {
                physicalDevice = d;
                return;
            }
        }

        std.debug.panic("No suitable devices found\n", .{});
    }

    fn isDeviceSuitable(d: c.VkPhysicalDevice) bool {
        //TODO check for appropriate PhysicalDeviceProperties and PhysicalDeviceFeatures
        const indices = findQueueFamilies(d);
        if (indices.graphics != null and indices.presentation != null) {
            return true;
        } else {
            return false;
        }
    }

    fn findQueueFamilies(thisDevice: c.VkPhysicalDevice) QueueFamilyIndices {
        var ret: QueueFamilyIndices = .{};

        var queueFamilyCount: u32 = 0;
        vkGetPhysicalDeviceQueueFamilyProperties.?(thisDevice, &queueFamilyCount, null);
        const queueFamilies = std.heap.c_allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch {
            heapFailure();
        };
        defer std.heap.c_allocator.free(queueFamilies);
        vkGetPhysicalDeviceQueueFamilyProperties.?(thisDevice, &queueFamilyCount, @ptrCast(queueFamilies));

        for (queueFamilies, 0..) |queueFamily, i| {
            if (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
                ret.graphics = @intCast(i);
            }
            var presentSupport: c.VkBool32 = undefined;
            _ = vkGetPhysicalDeviceSurfaceSupportKHR.?(thisDevice, @intCast(i), surface, &presentSupport);
            if (presentSupport == c.VK_TRUE) {
                ret.presentation = @intCast(i);
            }

            //Early return if appropriate queuefamilies found
            if (ret.graphics != null and ret.presentation != null) {
                return ret;
            }
        }

        return ret;
    }

    fn createLogicalDevice(queueFamilyIndex: u32) void {
        const queuePriority: f32 = 1.0;
        const queueCreateInfo: c.VkDeviceQueueCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamilyIndex,
            .queueCount = 1,
            .pQueuePriorities = @ptrCast(&queuePriority),
        };
        const deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
        const createInfo: c.VkDeviceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pQueueCreateInfos = &queueCreateInfo,
            .queueCreateInfoCount = 1,
            .pEnabledFeatures = &deviceFeatures,
            .enabledExtensionCount = 0,
            .enabledLayerCount = 0,
        };
        if (vkCreateDevice.?(physicalDevice, &createInfo, null, @ptrCast(&device)) != c.VK_SUCCESS) {
            std.debug.panic("Failed to create logical device\n", .{});
        }
    }
};

fn cleanup() void {
    Vk.vkDestroyDevice.?(Vk.device, null);
    Vk.vkDestroyInstance.?(Vk.instance, null);
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

inline fn heapFailure() noreturn {
    std.debug.panic("Failed to allocate on the heap\n", .{});
}
