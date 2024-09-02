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
};

pub fn getVkFunctionPointers(instance: c.VkInstance) !void {
    inline for (@typeInfo(p).Struct.decls) |decl| {
        @field(p, decl.name) = @ptrCast(c.glfwGetInstanceProcAddress(instance, decl.name));
        if (@field(p, decl.name) == null) {
            return error.FunctionNotFound;
        }
    }
}
