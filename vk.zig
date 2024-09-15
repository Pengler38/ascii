//vk.zig
//Preston Engler
const c = @import("c.zig");

const std = @import("std");
const config = @import("config");

const vkf = @import("vk_function_pointers.zig");

const QueueFamilyIndices = struct {
    graphics: ?u32 = null,
    presentation: ?u32 = null,
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: std.ArrayList(c.VkSurfaceFormatKHR) = undefined,
    presentModes: std.ArrayList(c.VkPresentModeKHR) = undefined,

    pub fn init() SwapChainSupportDetails {
        var self = SwapChainSupportDetails{};
        self.formats = std.ArrayList(c.VkSurfaceFormatKHR).init(std.heap.c_allocator);
        self.presentModes = std.ArrayList(c.VkPresentModeKHR).init(std.heap.c_allocator);
        return self;
    }

    pub fn deinit(self: SwapChainSupportDetails) void {
        self.formats.deinit();
        self.presentModes.deinit();
    }
};

const Vertex = extern struct {
    pos: @Vector(2, f32),
    color: @Vector(3, f32),

    pub fn getBindingDescription() c.VkVertexInputBindingDescription {
        const bindingDescription: c.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return bindingDescription;
    }

    pub fn getAttributeDescriptions() [2]c.VkVertexInputAttributeDescription {
        return [2]c.VkVertexInputAttributeDescription{
            .{
                .binding = 0,
                .location = 0,
                .format = c.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(Vertex, "pos"),
            },
            .{
                .binding = 0,
                .location = 1,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "color"),
            },
        };
    }
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0.0, -0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
};

const enable_validation_layers = config.debug;
const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var window: *c.GLFWwindow = undefined;

var instance: c.VkInstance = undefined;
var surface: c.VkSurfaceKHR = undefined;
var physicalDevice: c.VkPhysicalDevice = undefined;
var device: c.VkDevice = undefined;
var graphicsQueue: c.VkQueue = undefined;
var presentQueue: c.VkQueue = undefined;

var swapChain: c.VkSwapchainKHR = undefined;
var swapChainImages: std.ArrayList(c.VkImage) = undefined;
var swapChainImageFormat: c.VkFormat = undefined;
var swapChainExtent: c.VkExtent2D = undefined;

var swapChainImageViews: std.ArrayList(c.VkImageView) = undefined;

var renderPass: c.VkRenderPass = undefined;
var pipelineLayout: c.VkPipelineLayout = undefined;

var graphicsPipeline: c.VkPipeline = undefined;
var swapChainFramebuffers: std.ArrayList(c.VkFramebuffer) = undefined;

var commandPool: c.VkCommandPool = undefined;
var commandBuffers = std.ArrayList(c.VkCommandBuffer).init(std.heap.c_allocator);

var vertexBuffer: c.VkBuffer = undefined;
var vertexBufferMemory: c.VkDeviceMemory = undefined;

var imageAvailableSemaphores = std.ArrayList(c.VkSemaphore).init(std.heap.c_allocator);
var renderFinishedSemaphores = std.ArrayList(c.VkSemaphore).init(std.heap.c_allocator);
var inFlightFences = std.ArrayList(c.VkFence).init(std.heap.c_allocator);

pub var framebufferResized = false;

const deviceExtensions = [_][*:0]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

const max_frames_in_flight = 2;
var current_frame: u32 = 0;

pub fn initVulkan(w: *c.GLFWwindow) void {
    window = w;
    //Check for Vulkan Support
    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.panic("Vulkan is not supported\n", .{});
    }

    //Create Vulkan instance
    createInstance();

    //Create a GLFW surface linked to the window
    if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create vulkan window surface\n", .{});
    } else {
        std.debug.print("Vulkan surface successfully created\n", .{});
    }

    //Get the rest of the function pointers
    vkf.getVkFunctionPointers(instance) catch {
        std.debug.panic("Failed to get Vulkan function pointers\n", .{});
    };

    //TODO: Add debug callback and handle Validation Layers

    //Pick Vulkan device and find the queue families
    pickPhysicalDevice();
    const indices = findQueueFamilies(physicalDevice);

    //Query GLFW for presentation support
    if (c.glfwGetPhysicalDevicePresentationSupport(instance, physicalDevice, indices.presentation.?) == c.GLFW_FALSE) {
        std.debug.panic("GLFW Presentation not supported\n", .{});
    }

    createLogicalDevice(indices.graphics.?);

    //Create queues
    vkf.p.vkGetDeviceQueue.?(device, indices.graphics.?, 0, &graphicsQueue);
    vkf.p.vkGetDeviceQueue.?(device, indices.presentation.?, 0, &presentQueue);

    createSwapChain();
    createImageViews();
    createRenderPass();
    createGraphicsPipeline();
    createFramebuffers();
    createCommandPool();
    createVertexBuffer();
    createCommandBuffers();
    createSyncObjects();
}

fn checkValidationLayerSupport() bool {
    const vkEnumerateInstanceLayerProperties: c.PFN_vkEnumerateInstanceLayerProperties = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkEnumerateInstanceLayerProperties"));

    var layer_count: u32 = undefined;
    _ = vkEnumerateInstanceLayerProperties.?(&layer_count, null);

    const available_layers = std.heap.c_allocator.alloc(c.VkLayerProperties, layer_count) catch heapFailure();
    defer std.heap.c_allocator.free(available_layers);
    _ = vkEnumerateInstanceLayerProperties.?(&layer_count, @ptrCast(available_layers));

    return for (validation_layers) |layer| {
        const layer_found = for (available_layers) |available_layer| {
            if (strEql(layer, available_layer.layerName ++ "")) break true;
        } else false;

        if (!layer_found) break false;
    } else true;
}

//Populates the instance variable
fn createInstance() void {
    if (enable_validation_layers and !checkValidationLayerSupport()) {
        std.debug.panic("Validation layers requested in debug build, but not available\n", .{});
    }

    //Get CreateInstance function pointer
    const vkCreateInstance: c.PFN_vkCreateInstance = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkCreateInstance"));

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
        .enabledLayerCount = if (enable_validation_layers) validation_layers.len else 0,
        .ppEnabledLayerNames = if (enable_validation_layers) &validation_layers else null,
        .enabledExtensionCount = count,
        .ppEnabledExtensionNames = vulkanExtensions,
    };
    if (vkCreateInstance.?(&instanceCreateInfo, null, &instance) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create Vulkan instance\n", .{});
    }
}

fn pickPhysicalDevice() void {
    var count: u32 = 0;
    _ = vkf.p.vkEnumeratePhysicalDevices.?(instance, &count, null);
    if (count == 0) {
        std.debug.panic("No GPUs with Vulkan support\n", .{});
    } else {
        std.debug.print("{d} GPU with Vulkan support found\n", .{count});
    }

    const devices = std.heap.c_allocator.alloc(c.VkPhysicalDevice, count) catch {
        heapFailure();
    };
    defer std.heap.c_allocator.free(devices);
    _ = vkf.p.vkEnumeratePhysicalDevices.?(instance, &count, @ptrCast(devices));

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
    const swapChainSupport = querySwapChainSupport(d);
    defer swapChainSupport.deinit();
    const swapChainSupported = swapChainSupport.formats.items.len > 0 and
        swapChainSupport.presentModes.items.len > 0;

    return indices.graphics != null and indices.presentation != null and
        checkDeviceExtensionSupport(d) == true and
        swapChainSupported;
}

fn checkDeviceExtensionSupport(d: c.VkPhysicalDevice) bool {
    var extensionCount: u32 = undefined;
    _ = vkf.p.vkEnumerateDeviceExtensionProperties.?(d, null, &extensionCount, null);
    const extensions = std.heap.c_allocator.alloc(c.VkExtensionProperties, extensionCount) catch {
        heapFailure();
    };
    defer std.heap.c_allocator.free(extensions);
    _ = vkf.p.vkEnumerateDeviceExtensionProperties.?(d, null, &extensionCount, @ptrCast(extensions));

    var requiredExtensions = std.ArrayList([*:0]const u8).init(std.heap.c_allocator);
    defer requiredExtensions.deinit();
    requiredExtensions.appendSlice(deviceExtensions[0..]) catch {
        heapFailure();
    };

    for (extensions) |extension| {
        for (requiredExtensions.items, 0..) |reqExt, i| {
            if (strEql(reqExt, extension.extensionName ++ "")) {
                _ = requiredExtensions.orderedRemove(i);
                break;
            }
        }
    }
    const ret = requiredExtensions.items.len == 0;

    return ret;
}

fn findQueueFamilies(thisDevice: c.VkPhysicalDevice) QueueFamilyIndices {
    var ret: QueueFamilyIndices = .{};

    var queueFamilyCount: u32 = 0;
    vkf.p.vkGetPhysicalDeviceQueueFamilyProperties.?(thisDevice, &queueFamilyCount, null);
    const queueFamilies = std.heap.c_allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch {
        heapFailure();
    };
    defer std.heap.c_allocator.free(queueFamilies);
    vkf.p.vkGetPhysicalDeviceQueueFamilyProperties.?(thisDevice, &queueFamilyCount, @ptrCast(queueFamilies));

    for (queueFamilies, 0..) |queueFamily, i| {
        if (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
            ret.graphics = @intCast(i);
        }
        var presentSupport: c.VkBool32 = undefined;
        _ = vkf.p.vkGetPhysicalDeviceSurfaceSupportKHR.?(thisDevice, @intCast(i), surface, &presentSupport);
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

fn querySwapChainSupport(d: c.VkPhysicalDevice) SwapChainSupportDetails {
    var details: SwapChainSupportDetails = SwapChainSupportDetails.init();
    _ = vkf.p.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(d, surface, @ptrCast(&details.capabilities));

    var formatCount: u32 = undefined;
    _ = vkf.p.vkGetPhysicalDeviceSurfaceFormatsKHR.?(d, surface, &formatCount, null);
    if (formatCount != 0) {
        const newMemory = details.formats.addManyAsSlice(formatCount) catch {
            heapFailure();
        };
        _ = vkf.p.vkGetPhysicalDeviceSurfaceFormatsKHR.?(d, surface, &formatCount, @ptrCast(newMemory));
    }

    var presentModeCount: u32 = undefined;
    _ = vkf.p.vkGetPhysicalDeviceSurfacePresentModesKHR.?(d, surface, &presentModeCount, null);
    if (presentModeCount != 0) {
        const newMemory = details.presentModes.addManyAsSlice(formatCount) catch {
            heapFailure();
        };
        _ = vkf.p.vkGetPhysicalDeviceSurfacePresentModesKHR.?(d, surface, &presentModeCount, @ptrCast(newMemory));
    }

    return details;
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
        .enabledLayerCount = 0,
        .enabledExtensionCount = deviceExtensions.len,
        .ppEnabledExtensionNames = &deviceExtensions,
    };
    if (vkf.p.vkCreateDevice.?(physicalDevice, &createInfo, null, @ptrCast(&device)) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create logical device\n", .{});
    }
}

fn createSwapChain() void {
    const swapChainSupport: SwapChainSupportDetails = querySwapChainSupport(physicalDevice);
    defer swapChainSupport.deinit();

    const surfaceFormat: c.VkSurfaceFormatKHR = chooseSwapSurfaceFormat(&swapChainSupport.formats);
    const presentMode: c.VkPresentModeKHR = chooseSwapPresentMode(&swapChainSupport.presentModes);
    const extent: c.VkExtent2D = chooseSwapExtent(&swapChainSupport.capabilities);

    var imageCount: u32 = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 and
        imageCount > swapChainSupport.capabilities.maxImageCount)
    {
        imageCount = swapChainSupport.capabilities.maxImageCount;
    }

    var createInfo: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = imageCount,
        .imageFormat = surfaceFormat.format,
        .imageColorSpace = surfaceFormat.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

        .preTransform = swapChainSupport.capabilities.currentTransform,

        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,

        .presentMode = presentMode,
        .clipped = c.VK_TRUE,

        .oldSwapchain = null,
    };

    const indices = findQueueFamilies(physicalDevice);
    if (indices.graphics.? == indices.presentation.?) {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        createInfo.queueFamilyIndexCount = 0;
        createInfo.pQueueFamilyIndices = null;
    } else {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &[_]u32{ indices.graphics.?, indices.presentation.? };
    }

    if (vkf.p.vkCreateSwapchainKHR.?(device, &createInfo, null, &swapChain) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create swap chain\n", .{});
    }

    //Save swapChainImageFormat and swapChainExtent to the Vk struct vars
    swapChainImageFormat = surfaceFormat.format;
    swapChainExtent = extent;

    //Save the handles of the swapchain images
    swapChainImages = std.ArrayList(c.VkImage).init(std.heap.c_allocator);
    _ = vkf.p.vkGetSwapchainImagesKHR.?(device, swapChain, &imageCount, null);
    const newMemory = swapChainImages.addManyAsSlice(imageCount) catch {
        heapFailure();
    };
    _ = vkf.p.vkGetSwapchainImagesKHR.?(device, swapChain, &imageCount, @ptrCast(newMemory));
}

fn chooseSwapSurfaceFormat(
    availableFormats: *const std.ArrayList(c.VkSurfaceFormatKHR),
) c.VkSurfaceFormatKHR {
    for (availableFormats.*.items) |f| {
        if (f.format == c.VK_FORMAT_B8G8R8A8_SRGB and
            f.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return f;
        }
    }
    return availableFormats.*.items[0];
}

fn chooseSwapPresentMode(
    availablePresentModes: *const std.ArrayList(c.VkPresentModeKHR),
) c.VkPresentModeKHR {
    //Choose the VSYNC mode
    _ = availablePresentModes;
    return c.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(capabilities: *const c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(window, &width, &height);

        return .{
            .width = std.math.clamp(@as(u32, @intCast(width)), capabilities.minImageExtent.width, capabilities.maxImageExtent.width),
            .height = std.math.clamp(@as(u32, @intCast(height)), capabilities.minImageExtent.height, capabilities.maxImageExtent.width),
        };
    }
}

fn createImageViews() void {
    swapChainImageViews = std.ArrayList(c.VkImageView).init(std.heap.c_allocator);
    const mem = swapChainImageViews.addManyAsSlice(swapChainImages.items.len) catch {
        heapFailure();
    };

    for (mem, 0..) |*element, i| {
        const createInfo: c.VkImageViewCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = swapChainImages.items[i],
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = swapChainImageFormat,

            .components = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },

            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        if (vkf.p.vkCreateImageView.?(device, &createInfo, null, element) != c.VK_SUCCESS) {
            std.debug.panic("Failed to create image view {d}\n", .{i});
        }
    }
}

fn createRenderPass() void {
    const color_attachment: c.VkAttachmentDescription = .{
        .format = swapChainImageFormat,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    const color_attachment_ref: c.VkAttachmentReference = .{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass: c.VkSubpassDescription = .{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
    };

    const dependency: c.VkSubpassDependency = .{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    };

    const render_pass_info: c.VkRenderPassCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    if (vkf.p.vkCreateRenderPass.?(device, &render_pass_info, null, &renderPass) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create render pass\n", .{});
    }
}

fn createGraphicsPipeline() void {
    const vert_shader_code: [:0]align(4) const u8 = @alignCast(@embedFile("shaders/vert.spv"));
    const frag_shader_code: [:0]align(4) const u8 = @alignCast(@embedFile("shaders/frag.spv"));

    const vert_shader_module = createShaderModule(vert_shader_code);
    defer vkf.p.vkDestroyShaderModule.?(device, vert_shader_module, null);
    const frag_shader_module = createShaderModule(frag_shader_code);
    defer vkf.p.vkDestroyShaderModule.?(device, frag_shader_module, null);

    const vert_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vert_shader_module,
        .pName = "main",
    };

    const frag_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = frag_shader_module,
        .pName = "main",
    };

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{
        vert_shader_stage_info,
        frag_shader_stage_info,
    };

    //Config dynamic viewport state
    const dynamic_states = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamic_state: c.VkPipelineDynamicStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamic_states.len,
        .pDynamicStates = @ptrCast(&dynamic_states),
    };

    //vertext input setup
    const binding_description = Vertex.getBindingDescription();
    const attribute_descriptions = Vertex.getAttributeDescriptions();
    const vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &binding_description,
        .vertexAttributeDescriptionCount = @intCast(attribute_descriptions.len),
        .pVertexAttributeDescriptions = &attribute_descriptions,
    };

    //input assembly setup
    const input_assembly: c.VkPipelineInputAssemblyStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    //viewport setup
    const viewport: c.VkViewport = .{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(swapChainExtent.width),
        .height = @floatFromInt(swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor: c.VkRect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = swapChainExtent,
    };

    const viewport_state: c.VkPipelineViewportStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    //Rasterizer setup
    const rasterizer: c.VkPipelineRasterizationStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,

        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
    };

    //Multisampling
    const multisampling: c.VkPipelineMultisampleStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
    };

    //This is where I would put my depth and stencil tests...
    //If I had them!!!

    //Color blending, first struct is no color blending, second struct does blend
    const no_color_blend_attachment: c.VkPipelineColorBlendAttachmentState = .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };
    _ = no_color_blend_attachment;

    const color_blend_attachment: c.VkPipelineColorBlendAttachmentState = .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_TRUE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const color_blending: c.VkPipelineColorBlendStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
    };

    //Pipeline layout
    const pipeline_layout_info: c.VkPipelineLayoutCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0,
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    if (vkf.p.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipelineLayout) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create pipeline layout\n", .{});
    }

    const pipeline_info: c.VkGraphicsPipelineCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = @ptrCast(&shader_stages),

        .pVertexInputState = &vertex_input_info,
        .pInputAssemblyState = &input_assembly,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pDepthStencilState = null,
        .pColorBlendState = &color_blending,
        .pDynamicState = &dynamic_state,

        .layout = pipelineLayout,
        .renderPass = renderPass,
        .subpass = 0,

        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    if (vkf.p.vkCreateGraphicsPipelines.?(device, null, 1, &pipeline_info, null, &graphicsPipeline) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create graphics pipeline\n", .{});
    }
}

fn createShaderModule(code: [:0]align(4) const u8) c.VkShaderModule {
    const createInfo: c.VkShaderModuleCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @ptrCast(code),
    };

    var shader_module: c.VkShaderModule = undefined;
    if (vkf.p.vkCreateShaderModule.?(device, &createInfo, null, &shader_module) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create shader module\n", .{});
    }

    return shader_module;
}

fn createFramebuffers() void {
    swapChainFramebuffers = std.ArrayList(c.VkFramebuffer).init(std.heap.c_allocator);
    swapChainFramebuffers.resize(swapChainImageViews.items.len) catch {
        heapFailure();
    };

    for (swapChainImageViews.items, swapChainFramebuffers.items) |image_view, *framebuffer| {
        const attachments = [_]c.VkImageView{
            image_view,
        };
        const framebuffer_info: c.VkFramebufferCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = renderPass,
            .attachmentCount = 1,
            .pAttachments = &attachments,
            .width = swapChainExtent.width,
            .height = swapChainExtent.height,
            .layers = 1,
        };

        if (vkf.p.vkCreateFramebuffer.?(device, &framebuffer_info, null, framebuffer) != c.VK_SUCCESS) {
            std.debug.panic("Failed to create framebuffer\n", .{});
        }
    }
}

fn createCommandPool() void {
    const queue_family_indices: QueueFamilyIndices = findQueueFamilies(physicalDevice);

    const pool_info: c.VkCommandPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queue_family_indices.graphics.?,
    };
    if (vkf.p.vkCreateCommandPool.?(device, &pool_info, null, &commandPool) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create command pool\n", .{});
    }
}

fn createVertexBuffer() void {
    const buffer_info: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    if (vkf.p.vkCreateBuffer.?(device, &buffer_info, null, &vertexBuffer) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create vertex buffer\n", .{});
    }

    var mem_requirements: c.VkMemoryRequirements = undefined;
    vkf.p.vkGetBufferMemoryRequirements.?(device, vertexBuffer, &mem_requirements);

    const alloc_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = findMemoryType(
            mem_requirements.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        ),
    };

    if (vkf.p.vkAllocateMemory.?(device, &alloc_info, null, &vertexBufferMemory) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate vertex buffer memory\n", .{});
    }

    _ = vkf.p.vkBindBufferMemory.?(device, vertexBuffer, vertexBufferMemory, 0);

    var data: ?*align(@alignOf(Vertex)) anyopaque = undefined;
    _ = vkf.p.vkMapMemory.?(device, vertexBufferMemory, 0, buffer_info.size, 0, &data);
    @memcpy(@as([*]Vertex, @ptrCast(data.?)), &vertices);
    vkf.p.vkUnmapMemory.?(device, vertexBufferMemory);
}

fn findMemoryType(type_filter: u32, properties: c.VkMemoryPropertyFlags) u32 {
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    vkf.p.vkGetPhysicalDeviceMemoryProperties.?(physicalDevice, &mem_properties);

    for (0..mem_properties.memoryTypeCount) |i| {
        if ((type_filter & (@as(u32, 1) << @as(u5, @intCast(i))) > 0) and
            mem_properties.memoryTypes[i].propertyFlags & properties == properties)
        {
            return @intCast(i);
        }
    }

    std.debug.panic("Failed to find suitable memory type\n", .{});
}

fn createCommandBuffers() void {
    commandBuffers.resize(max_frames_in_flight) catch {
        heapFailure();
    };
    const alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(commandBuffers.items.len),
    };
    if (vkf.p.vkAllocateCommandBuffers.?(device, &alloc_info, @ptrCast(commandBuffers.items)) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate command buffers\n", .{});
    }
}

fn recordCommandBuffer(local_command_buffer: c.VkCommandBuffer, image_index: u32) void {
    const begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    if (vkf.p.vkBeginCommandBuffer.?(local_command_buffer, &begin_info) != c.VK_SUCCESS) {
        std.debug.panic("Failed to begin recording command buffer\n", .{});
    }

    const render_pass_info: c.VkRenderPassBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = renderPass,
        .framebuffer = swapChainFramebuffers.items[image_index],
        .renderArea = .{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = swapChainExtent,
        },
        .clearValueCount = 1,
        .pClearValues = &c.VkClearValue{
            .color = .{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        },
    };

    vkf.p.vkCmdBeginRenderPass.?(local_command_buffer, &render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);
    vkf.p.vkCmdBindPipeline.?(local_command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

    const viewport: c.VkViewport = .{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(swapChainExtent.width),
        .height = @floatFromInt(swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    vkf.p.vkCmdSetViewport.?(local_command_buffer, 0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapChainExtent,
    };
    vkf.p.vkCmdSetScissor.?(local_command_buffer, 0, 1, &scissor);

    const vertexBuffers = [_]c.VkBuffer{vertexBuffer};
    const offsets = [_]c.VkDeviceSize{0};
    vkf.p.vkCmdBindVertexBuffers.?(local_command_buffer, 0, 1, &vertexBuffers, &offsets);

    vkf.p.vkCmdDraw.?(local_command_buffer, @intCast(vertices.len), 1, 0, 0);

    vkf.p.vkCmdEndRenderPass.?(local_command_buffer);
    if (vkf.p.vkEndCommandBuffer.?(local_command_buffer) != c.VK_SUCCESS) {
        std.debug.panic("Failed to record command buffer\n", .{});
    }
}

fn createSyncObjects() void {
    imageAvailableSemaphores.resize(max_frames_in_flight) catch {
        heapFailure();
    };
    renderFinishedSemaphores.resize(max_frames_in_flight) catch {
        heapFailure();
    };
    inFlightFences.resize(max_frames_in_flight) catch {
        heapFailure();
    };

    const semaphore_info: c.VkSemaphoreCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    const fence_info: c.VkFenceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };
    for (0..max_frames_in_flight) |i| {
        if (vkf.p.vkCreateSemaphore.?(device, &semaphore_info, null, &imageAvailableSemaphores.items[i]) != c.VK_SUCCESS or
            vkf.p.vkCreateSemaphore.?(device, &semaphore_info, null, &renderFinishedSemaphores.items[i]) != c.VK_SUCCESS or
            vkf.p.vkCreateFence.?(device, &fence_info, null, &inFlightFences.items[i]) != c.VK_SUCCESS)
        {
            std.debug.panic("Failed to create semaphores\n", .{});
        }
    }
}

pub fn drawFrame() void {
    _ = vkf.p.vkWaitForFences.?(device, 1, &inFlightFences.items[current_frame], c.VK_TRUE, std.math.maxInt(u64));

    var image_index: u32 = undefined;
    const acquire_result = vkf.p.vkAcquireNextImageKHR.?(device, swapChain, std.math.maxInt(u64), imageAvailableSemaphores.items[current_frame], null, &image_index);
    if (acquire_result == c.VK_ERROR_OUT_OF_DATE_KHR) {
        recreateSwapChain();
        return;
    } else if (acquire_result != c.VK_SUCCESS and acquire_result != c.VK_SUBOPTIMAL_KHR) {
        std.debug.panic("Failed to acquire swap chain image\n", .{});
    }

    //Only reset the fences if we are submitting work (we pass the early erturn from VK_ERROR_OUT_OF_DATE_KHR)
    _ = vkf.p.vkResetFences.?(device, 1, &inFlightFences.items[current_frame]);

    _ = vkf.p.vkResetCommandBuffer.?(commandBuffers.items[current_frame], 0);

    recordCommandBuffer(commandBuffers.items[current_frame], image_index);

    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]c.VkSemaphore{imageAvailableSemaphores.items[current_frame]},
        .pWaitDstStageMask = &[_]u32{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},

        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffers.items[current_frame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &[_]c.VkSemaphore{renderFinishedSemaphores.items[current_frame]},
    };

    if (vkf.p.vkQueueSubmit.?(graphicsQueue, 1, &submit_info, inFlightFences.items[current_frame]) != c.VK_SUCCESS) {
        std.debug.panic("Failed to submit draw command buffer\n", .{});
    }

    const present_info: c.VkPresentInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]c.VkSemaphore{renderFinishedSemaphores.items[current_frame]},
        .swapchainCount = 1,
        .pSwapchains = &[_]c.VkSwapchainKHR{swapChain},
        .pImageIndices = &image_index,
        .pResults = null,
    };

    const present_result = vkf.p.vkQueuePresentKHR.?(presentQueue, &present_info);
    if (present_result == c.VK_ERROR_OUT_OF_DATE_KHR or present_result == c.VK_SUBOPTIMAL_KHR or framebufferResized == true) {
        framebufferResized = false;
        recreateSwapChain();
    } else if (present_result != c.VK_SUCCESS) {
        std.debug.panic("Failed to present swap chain image\n", .{});
    }

    //Switch to next frame
    current_frame = (current_frame + 1) % max_frames_in_flight;
}

fn recreateSwapChain() void {
    var width: c_int = 0;
    var height: c_int = 0;
    c.glfwGetFramebufferSize(window, &width, &height);
    while (width == 0 or height == 0) {
        c.glfwGetFramebufferSize(window, &width, &height);
        c.glfwWaitEvents();
    }
    _ = vkf.p.vkDeviceWaitIdle.?(device);

    cleanupSwapChain();

    createSwapChain();
    createImageViews();
    createFramebuffers();
}

pub fn waitIdle() void {
    _ = vkf.p.vkDeviceWaitIdle.?(device);
}

pub fn cleanup() void {
    for (0..max_frames_in_flight) |i| {
        vkf.p.vkDestroySemaphore.?(device, imageAvailableSemaphores.items[i], null);
        vkf.p.vkDestroySemaphore.?(device, renderFinishedSemaphores.items[i], null);
        vkf.p.vkDestroyFence.?(device, inFlightFences.items[i], null);
    }
    vkf.p.vkDestroyCommandPool.?(device, commandPool, null);
    vkf.p.vkDestroyPipeline.?(device, graphicsPipeline, null);
    vkf.p.vkDestroyPipelineLayout.?(device, pipelineLayout, null);

    cleanupSwapChain();
    swapChainFramebuffers.deinit();
    swapChainImageViews.deinit();
    swapChainImages.deinit();

    vkf.p.vkDestroyBuffer.?(device, vertexBuffer, null);
    vkf.p.vkFreeMemory.?(device, vertexBufferMemory, null);

    vkf.p.vkDestroyDevice.?(device, null);
    vkf.p.vkDestroyInstance.?(instance, null);
}

fn cleanupSwapChain() void {
    for (swapChainFramebuffers.items) |framebuffer| {
        vkf.p.vkDestroyFramebuffer.?(device, framebuffer, null);
    }

    for (swapChainImageViews.items) |view| {
        vkf.p.vkDestroyImageView.?(device, view, null);
    }

    vkf.p.vkDestroySwapchainKHR.?(device, swapChain, null);
}

//Utility function to check the equality of two null terminated sentinel strings
fn strEql(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: u32 = 0;
    while (a[i] != 0 and b[i] != 0) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

fn heapFailure() noreturn {
    std.debug.panic("Failed to allocate on the heap\n", .{});
}
