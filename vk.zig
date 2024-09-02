//vk.zig
//Preston Engler
const c = @import("c.zig");

const std = @import("std");

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

const deviceExtensions = [_][*:0]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

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
}

//Populates the instance variable
fn createInstance() void {
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

    const render_pass_info: c.VkRenderPassCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
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
    const vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
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

pub fn cleanup() void {
    for (swapChainFramebuffers.items) |framebuffer| {
        vkf.p.vkDestroyFramebuffer.?(device, framebuffer, null);
    }
    swapChainFramebuffers.deinit();
    vkf.p.vkDestroyPipeline.?(device, graphicsPipeline, null);
    vkf.p.vkDestroyPipelineLayout.?(device, pipelineLayout, null);
    vkf.p.vkDestroyPipelineLayout.?(device, pipelineLayout, null);
    for (swapChainImageViews.items) |view| {
        vkf.p.vkDestroyImageView.?(device, view, null);
    }
    swapChainImageViews.deinit();
    swapChainImages.deinit();
    vkf.p.vkDestroySwapchainKHR.?(device, swapChain, null);
    vkf.p.vkDestroyDevice.?(device, null);
    vkf.p.vkDestroyInstance.?(instance, null);
}

fn strEql(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: u32 = 0;
    while (a[i] != 0 and b[i] != 0) {
        if (a[i] != b[i]) {
            return false;
        }
        i += 1;
    }
    return true;
}

fn heapFailure() noreturn {
    std.debug.panic("Failed to allocate on the heap\n", .{});
}