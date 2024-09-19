//vk_func.zig
//Preston Engler
//This file holds all vulkan function pointers and gets them using glfwGetInstanceProcAddress

const c = @import("c.zig");

pub const p = struct {
    pub var vkDestroyInstance: c.PFN_vkDestroyInstance = null;
    pub var vkEnumeratePhysicalDevices: c.PFN_vkEnumeratePhysicalDevices = null;
    pub var vkGetPhysicalDeviceQueueFamilyProperties: c.PFN_vkGetPhysicalDeviceQueueFamilyProperties = null;
    pub var vkGetPhysicalDeviceProperties: c.PFN_vkGetPhysicalDeviceProperties = null;
    pub var vkGetPhysicalDeviceFeatures: c.PFN_vkGetPhysicalDeviceFeatures = null;
    pub var vkCreateDevice: c.PFN_vkCreateDevice = null;
    pub var vkDestroyDevice: c.PFN_vkDestroyDevice = null;
    pub var vkGetDeviceQueue: c.PFN_vkGetDeviceQueue = null;
    pub var vkGetPhysicalDeviceSurfaceSupportKHR: c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR = null;
    pub var vkEnumerateDeviceExtensionProperties: c.PFN_vkEnumerateDeviceExtensionProperties = null;
    pub var vkGetPhysicalDeviceSurfaceCapabilitiesKHR: c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR = null;
    pub var vkGetPhysicalDeviceSurfaceFormatsKHR: c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR = null;
    pub var vkGetPhysicalDeviceSurfacePresentModesKHR: c.PFN_vkGetPhysicalDeviceSurfacePresentModesKHR = null;
    pub var vkCreateSwapchainKHR: c.PFN_vkCreateSwapchainKHR = null;
    pub var vkDestroySwapchainKHR: c.PFN_vkDestroySwapchainKHR = null;
    pub var vkGetSwapchainImagesKHR: c.PFN_vkGetSwapchainImagesKHR = null;
    pub var vkCreateImageView: c.PFN_vkCreateImageView = null;
    pub var vkDestroyImageView: c.PFN_vkDestroyImageView = null;
    pub var vkCreateShaderModule: c.PFN_vkCreateShaderModule = null;
    pub var vkDestroyShaderModule: c.PFN_vkDestroyShaderModule = null;
    pub var vkCreatePipelineLayout: c.PFN_vkCreatePipelineLayout = null;
    pub var vkDestroyPipelineLayout: c.PFN_vkDestroyPipelineLayout = null;
    pub var vkCreateRenderPass: c.PFN_vkCreateRenderPass = null;
    pub var vkDestroyRenderPass: c.PFN_vkDestroyRenderPass = null;
    pub var vkCreateGraphicsPipelines: c.PFN_vkCreateGraphicsPipelines = null;
    pub var vkDestroyPipeline: c.PFN_vkDestroyPipeline = null;
    pub var vkCreateFramebuffer: c.PFN_vkCreateFramebuffer = null;
    pub var vkDestroyFramebuffer: c.PFN_vkDestroyFramebuffer = null;
    pub var vkCreateCommandPool: c.PFN_vkCreateCommandPool = null;
    pub var vkDestroyCommandPool: c.PFN_vkDestroyCommandPool = null;
    pub var vkAllocateCommandBuffers: c.PFN_vkAllocateCommandBuffers = null;
    pub var vkBeginCommandBuffer: c.PFN_vkBeginCommandBuffer = null;
    pub var vkCmdBeginRenderPass: c.PFN_vkCmdBeginRenderPass = null;
    pub var vkCmdBindPipeline: c.PFN_vkCmdBindPipeline = null;
    pub var vkCmdSetViewport: c.PFN_vkCmdSetViewport = null;
    pub var vkCmdSetScissor: c.PFN_vkCmdSetScissor = null;
    pub var vkCmdDraw: c.PFN_vkCmdDraw = null;
    pub var vkCreateSemaphore: c.PFN_vkCreateSemaphore = null;
    pub var vkDestroySemaphore: c.PFN_vkDestroySemaphore = null;
    pub var vkCreateFence: c.PFN_vkCreateFence = null;
    pub var vkDestroyFence: c.PFN_vkDestroyFence = null;
    pub var vkWaitForFences: c.PFN_vkWaitForFences = null;
    pub var vkResetFences: c.PFN_vkResetFences = null;
    pub var vkAcquireNextImageKHR: c.PFN_vkAcquireNextImageKHR = null;
    pub var vkResetCommandBuffer: c.PFN_vkResetCommandBuffer = null;
    pub var vkQueueSubmit: c.PFN_vkQueueSubmit = null;
    pub var vkQueuePresentKHR: c.PFN_vkQueuePresentKHR = null;
    pub var vkDeviceWaitIdle: c.PFN_vkDeviceWaitIdle = null;
    pub var vkCmdEndRenderPass: c.PFN_vkCmdEndRenderPass = null;
    pub var vkEndCommandBuffer: c.PFN_vkEndCommandBuffer = null;
    pub var vkCreateBuffer: c.PFN_vkCreateBuffer = null;
    pub var vkDestroyBuffer: c.PFN_vkDestroyBuffer = null;
    pub var vkGetBufferMemoryRequirements: c.PFN_vkGetBufferMemoryRequirements = null;
    pub var vkGetPhysicalDeviceMemoryProperties: c.PFN_vkGetPhysicalDeviceMemoryProperties = null;
    pub var vkAllocateMemory: c.PFN_vkAllocateMemory = null;
    pub var vkBindBufferMemory: c.PFN_vkBindBufferMemory = null;
    pub var vkFreeMemory: c.PFN_vkFreeMemory = null;
    pub var vkMapMemory: c.PFN_vkMapMemory = null;
    pub var vkUnmapMemory: c.PFN_vkUnmapMemory = null;
    pub var vkCmdBindVertexBuffers: c.PFN_vkCmdBindVertexBuffers = null;
    pub var vkDestroySurfaceKHR: c.PFN_vkDestroySurfaceKHR = null;
    pub var vkCreateDescriptorSetLayout: c.PFN_vkCreateDescriptorSetLayout = null;
    pub var vkDestroyDescriptorSetLayout: c.PFN_vkDestroyDescriptorSetLayout = null;
    pub var vkCreateDescriptorPool: c.PFN_vkCreateDescriptorPool = null;
    pub var vkDestroyDescriptorPool: c.PFN_vkDestroyDescriptorPool = null;
    pub var vkCmdBindDescriptorSets: c.PFN_vkCmdBindDescriptorSets = null;
    pub var vkAllocateDescriptorSets: c.PFN_vkAllocateDescriptorSets = null;
    pub var vkUpdateDescriptorSets: c.PFN_vkUpdateDescriptorSets = null;
    pub var vkCmdBindIndexBuffer: c.PFN_vkCmdBindIndexBuffer = null;
    pub var vkCmdDrawIndexed: c.PFN_vkCmdDrawIndexed = null;
};

pub fn getVkFunctionPointers(instance: c.VkInstance) !void {
    inline for (@typeInfo(p).Struct.decls) |decl| {
        @field(p, decl.name) = @ptrCast(c.glfwGetInstanceProcAddress(instance, decl.name));
        if (@field(p, decl.name) == null) {
            return error.FunctionNotFound;
        }
    }
}
