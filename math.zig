//math.zig
//Preston Engler
//
//Let's see if I can do the glm library functions on my own with Zig vectors

pub const mat4 = extern struct {
    a: @Vector(4, f32),
    b: @Vector(4, f32),
    c: @Vector(4, f32),
    d: @Vector(4, f32),

    const This = @This();

    pub fn cos(mat: mat4) mat4 {
        return .{
            .a = @cos(mat.a),
            .b = @cos(mat.b),
            .c = @cos(mat.c),
            .d = @cos(mat.d),
        };
    }
};

pub fn make_f32_mat4(x: f32) mat4 {
    return .{
        .a = .{ x, 0, 0, 0 },
        .b = .{ 0, x, 0, 0 },
        .c = .{ 0, 0, x, 0 },
        .d = .{ 0, 0, 0, x },
    };
}
