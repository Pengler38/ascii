//graphics_pipeline.zig
//Preston Engler

const c = @import("../c.zig");

const std = @import("std");

const core = @import("core.zig");
const vkf = @import("function_pointers.zig");
const graphics = @import("../graphics.zig");

const ShaderCode = [:0]align(4) const u8;

const tri_vert: ShaderCode = @alignCast(@embedFile("../shaders/tri.vert.spv"));
const tri_frag: ShaderCode = @alignCast(@embedFile("../shaders/tri.frag.spv"));
const blur_frag: ShaderCode = @alignCast(@embedFile("../shaders/blur.frag.spv"));

var old_pipeline: ?c.VkPipeline = null;
var old_layout: ?c.VkPipelineLayout = null;

pub fn cleanup() void {
    if (old_pipeline != null) {
        vkf.p.vkDestroyPipeline.?(core.device, old_pipeline.?, null);
    }
    if (old_layout != null) {
        vkf.p.vkDestroyPipelineLayout.?(core.device, old_layout.?, null);
    }
}

pub fn createDefaultGraphicsPipeline() void {
    createGraphicsPipeline(&tri_vert, &tri_frag);
}

//Causes an error if used twice in a single frame
pub fn switchGraphics(n: i32) void {
    //The current pipeline is still in use, move it to the old_pipeline var
    if (old_pipeline != null) {
        vkf.p.vkDestroyPipeline.?(core.device, old_pipeline.?, null);
    }
    if (old_layout != null) {
        vkf.p.vkDestroyPipelineLayout.?(core.device, old_layout.?, null);
    }
    old_layout = core.pipelineLayout;
    old_pipeline = core.graphicsPipeline;

    switch (n) {
        //1 falls under the else condition
        2 => createGraphicsPipeline(&tri_vert, &blur_frag),
        else => createDefaultGraphicsPipeline(),
    }
}

fn createGraphicsPipeline(vert_shader_code: *const ShaderCode, frag_shader_code: *const ShaderCode) void {
    const vert_shader_module = createShaderModule(vert_shader_code.*);
    defer vkf.p.vkDestroyShaderModule.?(core.device, vert_shader_module, null);
    const frag_shader_module = createShaderModule(frag_shader_code.*);
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
    const binding_description = graphics.Vertex.getBindingDescription();
    const attribute_descriptions = graphics.Vertex.getAttributeDescriptions();
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

fn createShaderModule(code: ShaderCode) c.VkShaderModule {
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
