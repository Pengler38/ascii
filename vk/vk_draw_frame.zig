//vk_draw_frame.zig
//Preston Engler

//Imports
const c = @import("../c.zig");

const std = @import("std");
const config = @import("config");

const vkf = @import("vk_function_pointers.zig");
const math = @import("../math.zig");
const core = @import("vk_core.zig");
const graphics = @import("../graphics.zig");

var current_frame: u32 = 0;

pub fn drawFrame() void {
    _ = vkf.p.vkWaitForFences.?(core.device, 1, &core.inFlightFences.items[current_frame], c.VK_TRUE, std.math.maxInt(u64));

    var image_index: u32 = undefined;
    const acquire_result = vkf.p.vkAcquireNextImageKHR.?(core.device, core.swapChain, std.math.maxInt(u64), core.imageAvailableSemaphores.items[current_frame], null, &image_index);
    if (acquire_result == c.VK_ERROR_OUT_OF_DATE_KHR) {
        recreateSwapChain();
        return;
    } else if (acquire_result != c.VK_SUCCESS and acquire_result != c.VK_SUBOPTIMAL_KHR) {
        std.debug.panic("Failed to acquire swap chain image\n", .{});
    }

    //Only reset the fences if we are submitting work (we pass the early erturn from VK_ERROR_OUT_OF_DATE_KHR)
    _ = vkf.p.vkResetFences.?(core.device, 1, &core.inFlightFences.items[current_frame]);

    _ = vkf.p.vkResetCommandBuffer.?(core.commandBuffers.items[current_frame], 0);

    recordCommandBuffer(core.commandBuffers.items[current_frame], image_index);

    updateUniformBuffer(current_frame);

    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]c.VkSemaphore{core.imageAvailableSemaphores.items[current_frame]},
        .pWaitDstStageMask = &[_]u32{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},

        .commandBufferCount = 1,
        .pCommandBuffers = &core.commandBuffers.items[current_frame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &[_]c.VkSemaphore{core.renderFinishedSemaphores.items[current_frame]},
    };

    if (vkf.p.vkQueueSubmit.?(core.graphicsQueue, 1, &submit_info, core.inFlightFences.items[current_frame]) != c.VK_SUCCESS) {
        std.debug.panic("Failed to submit draw command buffer\n", .{});
    }

    const present_info: c.VkPresentInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &[_]c.VkSemaphore{core.renderFinishedSemaphores.items[current_frame]},
        .swapchainCount = 1,
        .pSwapchains = &[_]c.VkSwapchainKHR{core.swapChain},
        .pImageIndices = &image_index,
        .pResults = null,
    };

    const present_result = vkf.p.vkQueuePresentKHR.?(core.presentQueue, &present_info);
    if (present_result == c.VK_ERROR_OUT_OF_DATE_KHR or present_result == c.VK_SUBOPTIMAL_KHR or core.framebufferResized == true) {
        core.framebufferResized = false;
        recreateSwapChain();
    } else if (present_result != c.VK_SUCCESS) {
        std.debug.panic("Failed to present swap chain image\n", .{});
    }

    //Switch to next frame
    current_frame = (current_frame + 1) % core.max_frames_in_flight;
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
        .renderPass = core.renderPass,
        .framebuffer = core.swapChainFramebuffers.items[image_index],
        .renderArea = .{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = core.swapChainExtent,
        },
        .clearValueCount = 1,
        .pClearValues = &c.VkClearValue{
            .color = .{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        },
    };

    vkf.p.vkCmdBeginRenderPass.?(local_command_buffer, &render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);
    vkf.p.vkCmdBindPipeline.?(local_command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, core.graphicsPipeline);

    const viewport: c.VkViewport = .{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(core.swapChainExtent.width),
        .height = @floatFromInt(core.swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    vkf.p.vkCmdSetViewport.?(local_command_buffer, 0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = core.swapChainExtent,
    };
    vkf.p.vkCmdSetScissor.?(local_command_buffer, 0, 1, &scissor);

    const vertexBuffers = [_]c.VkBuffer{core.vertexBuffer};
    const offsets = [_]c.VkDeviceSize{0};
    vkf.p.vkCmdBindVertexBuffers.?(local_command_buffer, 0, 1, &vertexBuffers, &offsets);
    vkf.p.vkCmdBindIndexBuffer.?(local_command_buffer, core.indexBuffer, 0, c.VK_INDEX_TYPE_UINT16);

    vkf.p.vkCmdBindDescriptorSets.?(
        local_command_buffer,
        c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        core.pipelineLayout,
        0,
        1,
        &core.descriptorSets[current_frame],
        0,
        null,
    );

    //vkf.p.vkCmdDraw.?(local_command_buffer, @intCast(vertices.len), 1, 0, 0);
    vkf.p.vkCmdDrawIndexed.?(local_command_buffer, @intCast(graphics.indices.len), 1, 0, 0, 0);

    vkf.p.vkCmdEndRenderPass.?(local_command_buffer);
    if (vkf.p.vkEndCommandBuffer.?(local_command_buffer) != c.VK_SUCCESS) {
        std.debug.panic("Failed to record command buffer\n", .{});
    }
}

fn updateUniformBuffer(frame: u32) void {
    const current_time: f32 = @floatCast(c.glfwGetTime());

    const aspect_ratio = @as(f32, @floatFromInt(core.swapChainExtent.width)) / @as(f32, @floatFromInt(core.swapChainExtent.height));

    core.uniformBuffersMapped[frame].?.* = core.UniformBuffer{
        .model = math.mat4.rotationMatrix(
            current_time * math.radians(5),
            .{ 0, 0, 1 },
        ).translate(
            .{ 0, 0, 0.5 },
        ).rotate(current_time * math.radians(20), math.normalize(.{ 0.5, 0.70710678, 0.5 })),
        .view = math.mat4.init(1.0),
        .proj = math.mat4.orthographicProjection(0 + aspect_ratio * -1.0, 0 + aspect_ratio * 1.0, -1, 1, 100, -100),
    };
}

fn recreateSwapChain() void {
    var width: c_int = 0;
    var height: c_int = 0;
    c.glfwGetFramebufferSize(core.window, &width, &height);
    while (width == 0 or height == 0) {
        c.glfwGetFramebufferSize(core.window, &width, &height);
        c.glfwWaitEvents();
    }
    _ = vkf.p.vkDeviceWaitIdle.?(core.device);

    core.cleanupSwapChain();

    core.createSwapChain();
    core.createImageViews();
    core.createFramebuffers();
}
