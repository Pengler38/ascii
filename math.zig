//math.zig
//Preston Engler
//
//Let's see if I can do the glm library functions on my own with Zig vectors

const math = @import("std").math;

pub const mat4 = extern struct {
    cols: [4]@Vector(4, f32),

    pub fn init(x: f32) mat4 {
        return .{
            .cols = .{
                .{ x, 0, 0, 0 },
                .{ 0, x, 0, 0 },
                .{ 0, 0, x, 0 },
                .{ 0, 0, 0, x },
            },
        };
    }

    pub fn initRows(rows: [4]@Vector(4, f32)) mat4 {
        var ret = mat4{ .cols = undefined };
        for (0..4) |i| {
            for (0..4) |j| {
                ret.cols[j][i] = rows[i][j];
            }
        }
        return ret;
    }

    pub fn equals(m1: mat4, m2: mat4) bool {
        for (0..4) |i| {
            if (@reduce(.Or, m1.cols[i] != m2.cols[i])) return false;
        }
        return true;
    }

    ///Gets a copy of the matrix's specified row
    pub fn row(mat: mat4, i: u32) @Vector(4, f32) {
        return .{ mat.cols[0][i], mat.cols[1][i], mat.cols[2][i], mat.cols[3][i] };
    }

    ///Gets a copy of the matrix's specified column
    pub fn col(mat: mat4, i: u32) @Vector(4, f32) {
        return mat.cols[i];
    }

    ///Multiplies matrices A * B
    pub fn mult(A: mat4, B: mat4) mat4 {
        var ret: mat4 = undefined;

        for (0..4) |i| {
            for (0..4) |j| {
                ret.cols[j][i] =
                    A.cols[0][i] * B.cols[j][0] +
                    A.cols[1][i] * B.cols[j][1] +
                    A.cols[2][i] * B.cols[j][2] +
                    A.cols[3][i] * B.cols[j][3];
            }
        }

        return ret;
    }

    ///Rotate around a given angle and a unit vector axis
    ///See: https://en.wikipedia.org/wiki/Rotation_matrix
    pub fn rotationMatrix(angle: f32, axis: vec3) mat4 {
        const sin_theta = @sin(angle);
        const cos_theta = @cos(angle);
        const one_sub_c = 1 - cos_theta;

        const ux = axis[0];
        const uy = axis[1];
        const uz = axis[2];

        return initRows(.{
            .{
                ux * ux * one_sub_c + cos_theta,
                ux * uy * one_sub_c - uz * sin_theta,
                ux * uz * one_sub_c + uy * sin_theta,
                0,
            },
            .{
                ux * uy * one_sub_c + uz * sin_theta,
                uy * uy * one_sub_c + cos_theta,
                uy * uz * one_sub_c - ux * sin_theta,
                0,
            },
            .{
                ux * uz * one_sub_c - uy * sin_theta,
                uy * uz * one_sub_c + ux * sin_theta,
                uz * uz * one_sub_c + cos_theta,
                0,
            },
            .{ 0, 0, 0, 1 },
        });
    }

    ///Rotate around a given angle and a unit vector axis
    ///Uses the function `rotationMatrix`
    pub fn rotate(mat: mat4, angle: f32, axis: vec3) mat4 {
        return rotationMatrix(angle, axis).mult(mat);
    }

    pub fn translationMatrix(vec: vec3) mat4 {
        var ret = mat4.init(1.0);
        ret.cols[3][0] = vec[0];
        ret.cols[3][1] = vec[1];
        ret.cols[3][2] = vec[2];
        return ret;
    }

    pub fn translate(mat: mat4, vec: vec3) mat4 {
        return translationMatrix(vec).mult(mat);
    }

    pub fn scaleMatrix(vec: vec3) mat4 {
        var ret = init(1.0);
        ret.cols[0][0] = vec[0];
        ret.cols[1][1] = vec[1];
        ret.cols[2][2] = vec[2];
        return ret;
    }

    pub fn scale(mat: mat4, vec: vec3) mat4 {
        return scaleMatrix(vec).mult(mat);
    }

    pub fn viewLookAt() mat4 {
        return mat4.init(1.0);
    }

    //Temporary simple projection matrix TODO improve projection matrix generation
    pub fn projection() mat4 {
        return mat4.init(1.0).translate(.{ 0, 0, 50 }).scale(.{ 1, 1, 0.01 });
    }

    pub fn orthographicProjection(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) mat4 {
        return initRows(.{
            .{ 2 / (right - left), 0, 0, -1 * (right + left) / (right - left) },
            .{ 0, 2 / (top - bottom), 0, -1 * (top + bottom) / (top - bottom) },
            .{ 0, 0, -1 / (far - near), -1 * (near) / (far - near) },
            .{ 0, 0, 0, 1 },
        });
    }
};

pub const vec3 = @Vector(3, f32);

pub fn normalize(vec: vec3) vec3 {
    const magnitude =
        @sqrt(vec[0] * vec[0] +
        vec[1] * vec[1] +
        vec[2] * vec[2]);

    return vec / @Vector(3, f32){ magnitude, magnitude, magnitude };
}

pub const radians = math.degreesToRadians;

//TESTS:
const std = @import("std");
test "Basic mult test" {
    const m1 = mat4.initRows(.{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    });

    const m2 = mat4.initRows(.{
        .{ 100, 101, 102, 103 },
        .{ 104, 105, 106, 107 },
        .{ 108, 109, 110, 111 },
        .{ 112, 113, 114, 115 },
    });

    const result = mat4.initRows(.{
        .{ 1080, 1090, 1100, 1110 },
        .{ 2776, 2802, 2828, 2854 },
        .{ 4472, 4514, 4556, 4598 },
        .{ 6168, 6226, 6284, 6342 },
    });
    try std.testing.expect(m1.mult(m2).equals(result));
}

test "Basic Translation test" {
    const m1 = mat4.initRows(.{
        .{ 1, 2, 3, 0 },
        .{ 4, 5, 6, 0 },
        .{ 7, 8, 9, 0 },
        .{ 0, 0, 0, 1 },
    });

    const result = mat4.initRows(.{
        .{ 1, 2, 3, 1 },
        .{ 4, 5, 6, 5 },
        .{ 7, 8, 9, 10 },
        .{ 0, 0, 0, 1 },
    });

    const m2 = mat4.initRows(.{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    });

    const result2 = mat4.initRows(.{
        .{ 14, 16, 18, 20 },
        .{ 44, 48, 52, 56 },
        .{ 100, 108, 116, 124 },
        .{ 13, 14, 15, 16 },
    });
    try std.testing.expect(m1.translate(.{ 1, 5, 10 }).equals(result));
    try std.testing.expect(m2.translate(.{ 1, 3, 7 }).equals(result2));
}
