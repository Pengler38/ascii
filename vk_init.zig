//vk_init.zig
//Preston Engler

//Imports
const c = @import("c.zig");

const std = @import("std");
const config = @import("config");

const vkf = @import("vk_function_pointers.zig");
const math = @import("math.zig");
const core = @import("vk_core.zig");
const util = @import("util.zig");
const graphics = @import("graphics.zig");

//Imported variables
const SwapChainSupportDetails = core.SwapChainSupportDetails;
const QueueFamilyIndices = core.QueueFamilyIndices;
const Vertex = graphics.Vertex;

const UniformBuffer = core.UniformBuffer;

const max_frames_in_flight = core.max_frames_in_flight;

const COMMENTED_OUT = struct {
    var device: **c.VkDevice = &core.device;
    var inFlightFences = &core.inFlightFences;
    var window: **c.GLFWwindow = &core.window;
    var swapChain: **c.VkSwapchainKHR = &core.swapChain;
    var swapChainExtent: **c.VkExtent2D = &core.swapChainExtent;
    var renderPass: **c.VkRenderPass = &core.renderPass;
    var imageAvailableSemaphores = &core.imageAvailableSemaphores;
    var uniformBuffersMapped = &core.uniformBuffersMapped;
    var commandBuffers = &core.commandBuffers;
    var renderFinishedSemaphores = &core.renderFinishedSemaphores;
    var swapChainFramebuffers: *std.ArrayList(c.VkFramebuffer) = &core.swapChainFramebuffers;
    var graphicsPipeline: *c.VkPipeline = &core.graphicsPipeline;
    var vertexBuffer: *c.VkBuffer = &core.vertexBuffer;
    var instance = &core.instance;
    var surface = &core.surface;
    var swapChainImageFormat = &core.swapChainImageFormat;
    var descriptorSetLayout = &core.descriptorSetLayout;
    var commandPool = &core.commandPool;
    var descriptorPool = &core.descriptorPool;
    var pipelineLayout = &core.pipelineLayout;
    var vertexBufferMemory = &core.vertexBufferMemory;
    var indexBufferMemory = &core.indexBufferMemory;
    var uniformBuffers = &core.uniformBuffers;
    var uniformBuffersMemory = &core.uniformBuffersMemory;
    var descriptorSets = &core.descriptorSets;
};

const vertices = graphics.vertices;
const indices = graphics.indices;

//Allocator
var init_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const init_alloc = init_arena.allocator();

//Types

//Constants

const enable_validation_layers = config.debug;
const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

const deviceExtensions = [_][*:0]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

//Private variables
var physicalDevice: c.VkPhysicalDevice = undefined;

//var uniformBuffersMapped = [max_frames_in_flight]?*align(@alignOf(math.mat4)) anyopaque{};

pub fn initVulkan(w: *c.GLFWwindow) void {
    core.window = w;
    //Check for Vulkan Support
    if (c.glfwVulkanSupported() == c.GL_FALSE) {
        std.debug.panic("Vulkan is not supported\n", .{});
    }

    //Create Vulkan instance
    createInstance();

    //Create a GLFW surface linked to the window
    if (c.glfwCreateWindowSurface(core.instance, core.window, null, &core.surface) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create vulkan window surface\n", .{});
    } else {
        std.debug.print("Vulkan surface successfully created\n", .{});
    }

    //Get the rest of the function pointers
    vkf.getVkFunctionPointers(core.instance) catch {
        std.debug.panic("Failed to get Vulkan function pointers\n", .{});
    };

    //TODO: Add debug callback and handle Validation Layers

    //Pick Vulkan device and find the queue families
    pickPhysicalDevice();
    const queue_family_indices = findQueueFamilies(physicalDevice);

    //Query GLFW for presentation support
    if (c.glfwGetPhysicalDevicePresentationSupport(core.instance, physicalDevice, queue_family_indices.presentation.?) == c.GLFW_FALSE) {
        std.debug.panic("GLFW Presentation not supported\n", .{});
    }

    createLogicalDevice(queue_family_indices.graphics.?);

    //Create queues
    vkf.p.vkGetDeviceQueue.?(core.device, queue_family_indices.graphics.?, 0, &core.graphicsQueue);
    vkf.p.vkGetDeviceQueue.?(core.device, queue_family_indices.presentation.?, 0, &core.presentQueue);

    core.createSwapChain();
    core.createImageViews();
    createRenderPass();

    createUniformBuffers();
    createVertexBuffer();
    createIndexBuffer();

    createDescriptorSetLayout();
    createDescriptorPool();
    createDescriptorSets();

    createGraphicsPipeline();
    core.createFramebuffers();
    createCommandPool();
    createCommandBuffers();
    createSyncObjects();
}

fn checkValidationLayerSupport() bool {
    const vkEnumerateInstanceLayerProperties: c.PFN_vkEnumerateInstanceLayerProperties = @ptrCast(c.glfwGetInstanceProcAddress(null, "vkEnumerateInstanceLayerProperties"));

    var layer_count: u32 = undefined;
    _ = vkEnumerateInstanceLayerProperties.?(&layer_count, null);

    const available_layers = init_alloc.alloc(c.VkLayerProperties, layer_count) catch util.heapFail();
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
    if (vkCreateInstance.?(&instanceCreateInfo, null, &core.instance) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create Vulkan instance\n", .{});
    }
}

fn pickPhysicalDevice() void {
    var count: u32 = 0;
    _ = vkf.p.vkEnumeratePhysicalDevices.?(core.instance, &count, null);
    if (count == 0) {
        std.debug.panic("No GPUs with Vulkan support\n", .{});
    } else {
        std.debug.print("{d} GPU with Vulkan support found\n", .{count});
    }

    const devices = init_alloc.alloc(c.VkPhysicalDevice, count) catch util.heapFail();
    _ = vkf.p.vkEnumeratePhysicalDevices.?(core.instance, &count, @ptrCast(devices));

    for (devices) |d| {
        if (isDeviceSuitable(d) == true) {
            physicalDevice = d;
            //Load swapchain support info permanently into core.swap
            core.swapChainSupport = querySwapChainSupport(d, core.permanent_alloc);
            return;
        }
    }

    std.debug.panic("No suitable devices found\n", .{});
}

fn isDeviceSuitable(d: c.VkPhysicalDevice) bool {
    //TODO check for appropriate PhysicalDeviceProperties and PhysicalDeviceFeatures
    core.queue_family_indices = findQueueFamilies(d);
    const swap_chain_support = querySwapChainSupport(d, init_alloc);
    const swapChainSupported = swap_chain_support.formats.items.len > 0 and
        swap_chain_support.presentModes.items.len > 0;

    return core.queue_family_indices.graphics != null and core.queue_family_indices.presentation != null and
        checkDeviceExtensionSupport(d) == true and
        swapChainSupported;
}

fn querySwapChainSupport(d: c.VkPhysicalDevice, allocator: std.mem.Allocator) SwapChainSupportDetails {
    var details: SwapChainSupportDetails = SwapChainSupportDetails.init(allocator);
    _ = vkf.p.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(d, core.surface, @ptrCast(&details.capabilities));

    var formatCount: u32 = undefined;
    _ = vkf.p.vkGetPhysicalDeviceSurfaceFormatsKHR.?(d, core.surface, &formatCount, null);
    if (formatCount != 0) {
        const newMemory = details.formats.addManyAsSlice(formatCount) catch {
            util.heapFail();
        };
        _ = vkf.p.vkGetPhysicalDeviceSurfaceFormatsKHR.?(d, core.surface, &formatCount, @ptrCast(newMemory));
    }

    var presentModeCount: u32 = undefined;
    _ = vkf.p.vkGetPhysicalDeviceSurfacePresentModesKHR.?(d, core.surface, &presentModeCount, null);
    if (presentModeCount != 0) {
        const newMemory = details.presentModes.addManyAsSlice(formatCount) catch {
            util.heapFail();
        };
        _ = vkf.p.vkGetPhysicalDeviceSurfacePresentModesKHR.?(d, core.surface, &presentModeCount, @ptrCast(newMemory));
    }

    return details;
}

fn checkDeviceExtensionSupport(d: c.VkPhysicalDevice) bool {
    var extensionCount: u32 = undefined;
    _ = vkf.p.vkEnumerateDeviceExtensionProperties.?(d, null, &extensionCount, null);
    const extensions = init_alloc.alloc(c.VkExtensionProperties, extensionCount) catch util.heapFail();
    _ = vkf.p.vkEnumerateDeviceExtensionProperties.?(d, null, &extensionCount, @ptrCast(extensions));

    var requiredExtensions = std.ArrayList([*:0]const u8).init(init_alloc);
    requiredExtensions.appendSlice(deviceExtensions[0..]) catch {
        util.heapFail();
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
        util.heapFail();
    };
    defer std.heap.c_allocator.free(queueFamilies);
    vkf.p.vkGetPhysicalDeviceQueueFamilyProperties.?(thisDevice, &queueFamilyCount, @ptrCast(queueFamilies));

    for (queueFamilies, 0..) |queueFamily, i| {
        if (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT > 0) {
            ret.graphics = @intCast(i);
        }
        var presentSupport: c.VkBool32 = undefined;
        _ = vkf.p.vkGetPhysicalDeviceSurfaceSupportKHR.?(thisDevice, @intCast(i), core.surface, &presentSupport);
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
        .enabledLayerCount = 0,
        .enabledExtensionCount = deviceExtensions.len,
        .ppEnabledExtensionNames = &deviceExtensions,
    };
    if (vkf.p.vkCreateDevice.?(physicalDevice, &createInfo, null, @ptrCast(&core.device)) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create logical device\n", .{});
    }
}

fn createRenderPass() void {
    const color_attachment: c.VkAttachmentDescription = .{
        .format = core.swapChainImageFormat,
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

    if (vkf.p.vkCreateRenderPass.?(core.device, &render_pass_info, null, &core.renderPass) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create render pass\n", .{});
    }
}

fn createGraphicsPipeline() void {
    const vert_shader_code: [:0]align(4) const u8 = @alignCast(@embedFile("shaders/tri.vert.spv"));
    const frag_shader_code: [:0]align(4) const u8 = @alignCast(@embedFile("shaders/tri.frag.spv"));

    const vert_shader_module = createShaderModule(vert_shader_code);
    defer vkf.p.vkDestroyShaderModule.?(core.device, vert_shader_module, null);
    const frag_shader_module = createShaderModule(frag_shader_code);
    defer vkf.p.vkDestroyShaderModule.?(core.device, frag_shader_module, null);

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
        .width = @floatFromInt(core.swapChainExtent.width),
        .height = @floatFromInt(core.swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor: c.VkRect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = core.swapChainExtent,
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
        .setLayoutCount = 1,
        .pSetLayouts = &core.descriptorSetLayout,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    if (vkf.p.vkCreatePipelineLayout.?(core.device, &pipeline_layout_info, null, &core.pipelineLayout) != c.VK_SUCCESS) {
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

        .layout = core.pipelineLayout,
        .renderPass = core.renderPass,
        .subpass = 0,

        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    if (vkf.p.vkCreateGraphicsPipelines.?(core.device, null, 1, &pipeline_info, null, &core.graphicsPipeline) != c.VK_SUCCESS) {
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
    if (vkf.p.vkCreateShaderModule.?(core.device, &createInfo, null, &shader_module) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create shader module\n", .{});
    }

    return shader_module;
}

fn createCommandPool() void {
    const queue_family_indices: QueueFamilyIndices = findQueueFamilies(physicalDevice);

    const pool_info: c.VkCommandPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queue_family_indices.graphics.?,
    };
    if (vkf.p.vkCreateCommandPool.?(core.device, &pool_info, null, &core.commandPool) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create command pool\n", .{});
    }
}

fn createBuffer(
    size: c.VkDeviceSize,
    usage: c.VkBufferUsageFlags,
    properties: c.VkMemoryPropertyFlags,
    buffer: *c.VkBuffer,
    buffer_memory: *c.VkDeviceMemory,
) void {
    const buffer_info: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    if (vkf.p.vkCreateBuffer.?(core.device, &buffer_info, null, buffer) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create buffer\n", .{});
    }

    var mem_requirements: c.VkMemoryRequirements = undefined;
    vkf.p.vkGetBufferMemoryRequirements.?(core.device, buffer.*, &mem_requirements);

    const alloc_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = findMemoryType(
            mem_requirements.memoryTypeBits,
            properties,
        ),
    };

    if (vkf.p.vkAllocateMemory.?(core.device, &alloc_info, null, buffer_memory) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate buffer memory\n", .{});
    }

    _ = vkf.p.vkBindBufferMemory.?(core.device, buffer.*, buffer_memory.*, 0);
}

fn createVertexBuffer() void {
    const buffer_size = @sizeOf(@TypeOf(vertices));
    createBuffer(
        buffer_size,
        c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &core.vertexBuffer,
        &core.vertexBufferMemory,
    );

    var data: ?[*]Vertex = undefined;
    _ = vkf.p.vkMapMemory.?(core.device, core.vertexBufferMemory, 0, buffer_size, 0, @ptrCast(&data));
    @memcpy(data.?, &vertices);
    vkf.p.vkUnmapMemory.?(core.device, core.vertexBufferMemory);
}

fn createIndexBuffer() void {
    const buffer_size = @sizeOf(@TypeOf(indices));
    createBuffer(
        buffer_size,
        c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &core.indexBuffer,
        &core.indexBufferMemory,
    );

    var data: ?[*]u16 = undefined;
    _ = vkf.p.vkMapMemory.?(core.device, core.indexBufferMemory, 0, buffer_size, 0, @ptrCast(&data));
    @memcpy(data.?, &indices);
    vkf.p.vkUnmapMemory.?(core.device, core.indexBufferMemory);
}

fn createUniformBuffers() void {
    const buffer_size = @sizeOf(UniformBuffer);

    for (0..max_frames_in_flight) |i| {
        createBuffer(
            buffer_size,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &core.uniformBuffers[i],
            &core.uniformBuffersMemory[i],
        );

        _ = vkf.p.vkMapMemory.?(core.device, core.uniformBuffersMemory[i], 0, buffer_size, 0, @ptrCast(&core.uniformBuffersMapped[i]));
    }
}

fn createDescriptorSetLayout() void {
    const ubo_layout_binding = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };

    const layout_info = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &ubo_layout_binding,
    };

    if (vkf.p.vkCreateDescriptorSetLayout.?(core.device, &layout_info, null, &core.descriptorSetLayout) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create descriptor set layout\n", .{});
    }
}

fn createDescriptorPool() void {
    const pool_size = c.VkDescriptorPoolSize{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = max_frames_in_flight,
    };

    const pool_info = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &pool_size,
        .maxSets = max_frames_in_flight,
    };

    if (vkf.p.vkCreateDescriptorPool.?(core.device, &pool_info, null, &core.descriptorPool) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create descriptor pool\n", .{});
    }
}

fn createDescriptorSets() void {
    var layouts = [max_frames_in_flight]c.VkDescriptorSetLayout{ core.descriptorSetLayout, core.descriptorSetLayout };
    const alloc_info = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = core.descriptorPool,
        .descriptorSetCount = max_frames_in_flight,
        .pSetLayouts = &layouts,
    };

    if (vkf.p.vkAllocateDescriptorSets.?(core.device, &alloc_info, &core.descriptorSets) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate descriptor sets\n", .{});
    }

    for (0..max_frames_in_flight) |i| {
        const buffer_info = c.VkDescriptorBufferInfo{
            .buffer = core.uniformBuffers[i],
            .offset = 0,
            .range = @sizeOf(UniformBuffer),
        };
        const descriptor_write = c.VkWriteDescriptorSet{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = core.descriptorSets[i],
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &buffer_info,
            .pImageInfo = null,
            .pTexelBufferView = null,
        };

        vkf.p.vkUpdateDescriptorSets.?(core.device, 1, &descriptor_write, 0, null);
    }
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
    core.commandBuffers.resize(core.max_frames_in_flight) catch {
        util.heapFail();
    };
    const alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = core.commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(core.commandBuffers.items.len),
    };
    if (vkf.p.vkAllocateCommandBuffers.?(core.device, &alloc_info, @ptrCast(core.commandBuffers.items)) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate command buffers\n", .{});
    }
}

fn createSyncObjects() void {
    core.imageAvailableSemaphores.resize(max_frames_in_flight) catch {
        util.heapFail();
    };
    core.renderFinishedSemaphores.resize(max_frames_in_flight) catch {
        util.heapFail();
    };
    core.inFlightFences.resize(max_frames_in_flight) catch {
        util.heapFail();
    };

    const semaphore_info: c.VkSemaphoreCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    const fence_info: c.VkFenceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };
    for (0..max_frames_in_flight) |i| {
        if (vkf.p.vkCreateSemaphore.?(core.device, &semaphore_info, null, &core.imageAvailableSemaphores.items[i]) != c.VK_SUCCESS or
            vkf.p.vkCreateSemaphore.?(core.device, &semaphore_info, null, &core.renderFinishedSemaphores.items[i]) != c.VK_SUCCESS or
            vkf.p.vkCreateFence.?(core.device, &fence_info, null, &core.inFlightFences.items[i]) != c.VK_SUCCESS)
        {
            std.debug.panic("Failed to create semaphores\n", .{});
        }
    }
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
