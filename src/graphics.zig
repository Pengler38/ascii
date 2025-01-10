//graphics.zig
//Preston Engler

const c = @import("c.zig");

pub const Vertex = extern struct {
    pos: @Vector(3, f32),
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
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
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

pub const vertices = [_]Vertex{
    .{ .pos = .{ 0.0, -0.5, 0 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .pos = .{ 0.5, 0.5, 0 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .pos = .{ -0.5, 0.5, 0 }, .color = .{ 0.0, 0.0, 1.0 } },
    .{ .pos = .{ 0, 0.1, 0.5 }, .color = .{ 0.0, 0.0, 0.0 } },
};

pub const indices = [_]u16{ 0, 2, 1, 3, 0, 1, 3, 1, 2, 3, 2, 0 };
