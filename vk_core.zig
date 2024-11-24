//vk_core.zig
//Preston Engler

const std = @import("std");
const c = @import("c.zig");
const math = @import("math.zig");
const vkf = @import("vk_function_pointers.zig");
const util = @import("util.zig");

//types:
//UniformBuffer
pub const QueueFamilyIndices = struct {
    graphics: ?u32 = null,
    presentation: ?u32 = null,
};

pub const UniformBuffer = struct {
    model: math.mat4,
    view: math.mat4,
    proj: math.mat4,
};

pub const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
    formats: std.ArrayList(c.VkSurfaceFormatKHR) = undefined,
    presentModes: std.ArrayList(c.VkPresentModeKHR) = undefined,

    pub fn init(a: std.mem.Allocator) SwapChainSupportDetails {
        var self = SwapChainSupportDetails{};
        self.formats = std.ArrayList(c.VkSurfaceFormatKHR).init(a);
        self.presentModes = std.ArrayList(c.VkPresentModeKHR).init(a);
        return self;
    }

    pub fn deinit(self: SwapChainSupportDetails) void {
        self.formats.deinit();
        self.presentModes.deinit();
    }
};

//constants:
pub const max_frames_in_flight = 2;

//Allocator
var permanent_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub const permanent_alloc = permanent_arena.allocator();

//Public variables
pub var device: c.VkDevice = undefined;
pub var window: *c.GLFWwindow = undefined;
pub var swapChain: c.VkSwapchainKHR = undefined;
pub var swapChainExtent: c.VkExtent2D = undefined;
pub var renderPass: c.VkRenderPass = undefined;
pub var imageAvailableSemaphores = std.ArrayList(c.VkSemaphore).init(permanent_alloc);
pub var inFlightFences = std.ArrayList(c.VkFence).init(permanent_alloc);
pub var uniformBuffersMapped = [max_frames_in_flight]?*UniformBuffer{ null, null };
pub var commandBuffers = std.ArrayList(c.VkCommandBuffer).init(permanent_alloc);
pub var renderFinishedSemaphores = std.ArrayList(c.VkSemaphore).init(permanent_alloc);
pub var commandPool: c.VkCommandPool = undefined;
pub var pipelineLayout: c.VkPipelineLayout = undefined;

pub var uniformBuffers: [max_frames_in_flight]c.VkBuffer = undefined;
pub var uniformBuffersMemory: [max_frames_in_flight]c.VkDeviceMemory = undefined;

pub var graphicsQueue: c.VkQueue = undefined;
pub var presentQueue: c.VkQueue = undefined;
pub var graphicsPipeline: c.VkPipeline = undefined;

pub var swapChainFramebuffers: std.ArrayList(c.VkFramebuffer) = std.ArrayList(c.VkFramebuffer).init(permanent_alloc);
pub var vertexBuffer: c.VkBuffer = undefined;
pub var vertexBufferMemory: c.VkDeviceMemory = undefined;
pub var indexBuffer: c.VkBuffer = undefined;
pub var indexBufferMemory: c.VkDeviceMemory = undefined;

pub var surface: c.VkSurfaceKHR = undefined;
pub var instance: c.VkInstance = undefined;
pub var swapChainImageFormat: c.VkFormat = undefined;

pub var swapChainSupport: SwapChainSupportDetails = undefined;
pub var queue_family_indices: QueueFamilyIndices = undefined;
pub var descriptorSets: [max_frames_in_flight]c.VkDescriptorSet = undefined;

pub var framebufferResized = false;
pub var swapChainImages = std.ArrayList(c.VkImage).init(permanent_alloc);
pub var swapChainImageViews = std.ArrayList(c.VkImageView).init(permanent_alloc);
pub var descriptorPool: c.VkDescriptorPool = undefined;
pub var descriptorSetLayout: c.VkDescriptorSetLayout = undefined;

pub fn createFramebuffers() void {
    swapChainFramebuffers.resize(swapChainImageViews.items.len) catch {
        util.heapFail();
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

pub fn createImageViews() void {
    const mem = swapChainImageViews.addManyAsSlice(swapChainImages.items.len) catch {
        util.heapFail();
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

pub fn createSwapChain() void {
    const nested = struct {
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
    };

    const surfaceFormat: c.VkSurfaceFormatKHR = nested.chooseSwapSurfaceFormat(&swapChainSupport.formats);
    const presentMode: c.VkPresentModeKHR = nested.chooseSwapPresentMode(&swapChainSupport.presentModes);
    const extent: c.VkExtent2D = nested.chooseSwapExtent(&swapChainSupport.capabilities);

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

    if (queue_family_indices.graphics.? == queue_family_indices.presentation.?) {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        createInfo.queueFamilyIndexCount = 0;
        createInfo.pQueueFamilyIndices = null;
    } else {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &[_]u32{ queue_family_indices.graphics.?, queue_family_indices.presentation.? };
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
        util.heapFail();
    };
    _ = vkf.p.vkGetSwapchainImagesKHR.?(device, swapChain, &imageCount, @ptrCast(newMemory));
}

pub fn waitIdle() void {
    _ = vkf.p.vkDeviceWaitIdle.?(device);
}

pub fn cleanupSwapChain() void {
    for (swapChainFramebuffers.items) |framebuffer| {
        vkf.p.vkDestroyFramebuffer.?(device, framebuffer, null);
    }

    for (swapChainImageViews.items) |view| {
        vkf.p.vkDestroyImageView.?(device, view, null);
    }

    vkf.p.vkDestroySwapchainKHR.?(device, swapChain, null);
}

pub fn cleanup() void {
    for (0..max_frames_in_flight) |i| {
        vkf.p.vkDestroySemaphore.?(device, imageAvailableSemaphores.items[i], null);
        vkf.p.vkDestroySemaphore.?(device, renderFinishedSemaphores.items[i], null);
        vkf.p.vkDestroyFence.?(device, inFlightFences.items[i], null);

        vkf.p.vkDestroyBuffer.?(device, uniformBuffers[i], null);
        vkf.p.vkFreeMemory.?(device, uniformBuffersMemory[i], null);
    }
    vkf.p.vkDestroyCommandPool.?(device, commandPool, null);
    vkf.p.vkDestroyPipeline.?(device, graphicsPipeline, null);
    vkf.p.vkDestroyPipelineLayout.?(device, pipelineLayout, null);

    cleanupSwapChain();

    vkf.p.vkDestroyDescriptorPool.?(device, descriptorPool, null);
    vkf.p.vkDestroyDescriptorSetLayout.?(device, descriptorSetLayout, null);

    vkf.p.vkDestroyBuffer.?(device, vertexBuffer, null);
    vkf.p.vkFreeMemory.?(device, vertexBufferMemory, null);
    vkf.p.vkDestroyBuffer.?(device, indexBuffer, null);
    vkf.p.vkFreeMemory.?(device, indexBufferMemory, null);

    vkf.p.vkDestroyRenderPass.?(device, renderPass, null);

    vkf.p.vkDestroyDevice.?(device, null);

    vkf.p.vkDestroySurfaceKHR.?(instance, surface, null);
    vkf.p.vkDestroyInstance.?(instance, null);

    permanent_arena.deinit();
}
