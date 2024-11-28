//vk_init.zig
//Preston Engler

//Imports
const c = @import("../c.zig");

const std = @import("std");
const config = @import("config");

const vkf = @import("function_pointers.zig");
const gp = @import("graphics_pipeline.zig");
const math = @import("../math.zig");
const core = @import("core.zig");
const util = @import("../util.zig");
const graphics = @import("../graphics.zig");

//Imported Types
const SwapChainSupportDetails = core.SwapChainSupportDetails;
const QueueFamilyIndices = core.QueueFamilyIndices;
const Vertex = graphics.Vertex;
const UniformBuffer = core.UniformBuffer;

//Allocator
var init_arena = std.heap.ArenaAllocator.init(core.gpa_alloc);
const init_alloc = init_arena.allocator();

//Constants
const enable_validation_layers = config.debug;
const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

const deviceExtensions = [_][*:0]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

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

    //Query GLFW for presentation support
    if (c.glfwGetPhysicalDevicePresentationSupport(core.instance, core.physicalDevice, core.queue_family_indices.presentation.?) == c.GLFW_FALSE) {
        std.debug.panic("GLFW Presentation not supported\n", .{});
    }

    createLogicalDevice(core.queue_family_indices.graphics.?);

    //Create queues
    vkf.p.vkGetDeviceQueue.?(core.device, core.queue_family_indices.graphics.?, 0, &core.graphicsQueue);
    vkf.p.vkGetDeviceQueue.?(core.device, core.queue_family_indices.presentation.?, 0, &core.presentQueue);

    core.createSwapChain();
    core.createImageViews();
    createRenderPass();

    createUniformBuffers();
    createVertexBuffer();
    createIndexBuffer();

    createDescriptorSetLayout();
    createDescriptorPool();
    createDescriptorSets();

    gp.createDefaultGraphicsPipeline();
    core.createFramebuffers();
    createCommandPool();
    createCommandBuffers();
    createSyncObjects();

    init_arena.deinit();
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
            core.physicalDevice = d;
            //Load swapchain support info permanently into core.swap
            core.swapChainSupport = core.querySwapChainSupport(d, null);
            return;
        }
    }

    std.debug.panic("No suitable devices found\n", .{});
}

fn isDeviceSuitable(d: c.VkPhysicalDevice) bool {
    //TODO check for appropriate PhysicalDeviceProperties and PhysicalDeviceFeatures
    core.queue_family_indices = findQueueFamilies(d);
    const swap_chain_support = core.querySwapChainSupport(d, init_alloc);
    const swapChainSupported = swap_chain_support.formats.items.len > 0 and
        swap_chain_support.presentModes.items.len > 0;

    return core.queue_family_indices.graphics != null and core.queue_family_indices.presentation != null and
        checkDeviceExtensionSupport(d) == true and
        swapChainSupported;
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
    const queueFamilies = init_alloc.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch {
        util.heapFail();
    };
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
    if (vkf.p.vkCreateDevice.?(core.physicalDevice, &createInfo, null, @ptrCast(&core.device)) != c.VK_SUCCESS) {
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

fn createCommandPool() void {
    const pool_info: c.VkCommandPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = core.queue_family_indices.graphics.?,
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
    const buffer_size = @sizeOf(@TypeOf(graphics.vertices));
    createBuffer(
        buffer_size,
        c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &core.vertexBuffer,
        &core.vertexBufferMemory,
    );

    var data: ?[*]Vertex = undefined;
    _ = vkf.p.vkMapMemory.?(core.device, core.vertexBufferMemory, 0, buffer_size, 0, @ptrCast(&data));
    @memcpy(data.?, &graphics.vertices);
    vkf.p.vkUnmapMemory.?(core.device, core.vertexBufferMemory);
}

fn createIndexBuffer() void {
    const buffer_size = @sizeOf(@TypeOf(graphics.indices));
    createBuffer(
        buffer_size,
        c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &core.indexBuffer,
        &core.indexBufferMemory,
    );

    var data: ?[*]u16 = undefined;
    _ = vkf.p.vkMapMemory.?(core.device, core.indexBufferMemory, 0, buffer_size, 0, @ptrCast(&data));
    @memcpy(data.?, &graphics.indices);
    vkf.p.vkUnmapMemory.?(core.device, core.indexBufferMemory);
}

fn createUniformBuffers() void {
    const buffer_size = @sizeOf(UniformBuffer);

    for (0..core.max_frames_in_flight) |i| {
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
        .descriptorCount = core.max_frames_in_flight,
    };

    const pool_info = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &pool_size,
        .maxSets = core.max_frames_in_flight,
    };

    if (vkf.p.vkCreateDescriptorPool.?(core.device, &pool_info, null, &core.descriptorPool) != c.VK_SUCCESS) {
        std.debug.panic("Failed to create descriptor pool\n", .{});
    }
}

fn createDescriptorSets() void {
    var layouts = [core.max_frames_in_flight]c.VkDescriptorSetLayout{ core.descriptorSetLayout, core.descriptorSetLayout };
    const alloc_info = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = core.descriptorPool,
        .descriptorSetCount = core.max_frames_in_flight,
        .pSetLayouts = &layouts,
    };

    if (vkf.p.vkAllocateDescriptorSets.?(core.device, &alloc_info, &core.descriptorSets) != c.VK_SUCCESS) {
        std.debug.panic("Failed to allocate descriptor sets\n", .{});
    }

    for (0..core.max_frames_in_flight) |i| {
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
    vkf.p.vkGetPhysicalDeviceMemoryProperties.?(core.physicalDevice, &mem_properties);

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
    core.imageAvailableSemaphores.resize(core.max_frames_in_flight) catch {
        util.heapFail();
    };
    core.renderFinishedSemaphores.resize(core.max_frames_in_flight) catch {
        util.heapFail();
    };
    core.inFlightFences.resize(core.max_frames_in_flight) catch {
        util.heapFail();
    };

    const semaphore_info: c.VkSemaphoreCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    const fence_info: c.VkFenceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };
    for (0..core.max_frames_in_flight) |i| {
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
