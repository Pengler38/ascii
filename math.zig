//math.zig
//Preston Engler
//
//Let's see if I can do the glm library functions on my own with Zig vectors

const math = @import("std").math;

pub const mat4 = extern struct {
    rows: [4]@Vector(4, f32),

    pub fn init(x: f32) mat4 {
        return .{
            .rows = .{
                .{ x, 0, 0, 0 },
                .{ 0, x, 0, 0 },
                .{ 0, 0, x, 0 },
                .{ 0, 0, 0, x },
            },
        };
    }

    ///Gets a copy of the matrix's specified row
    pub fn row(mat: mat4, i: u32) @Vector(4, f32) {
        return mat.rows[i];
    }

    ///Gets a copy of the matrix's specified column
    pub fn col(mat: mat4, i: u32) @Vector(4, f32) {
        return .{ mat.row[0][i], mat.row[1][i], mat.row[2][i], mat.row[3][i] };
    }

    ///Multiplies matrices A * B
    pub fn mult(A: mat4, B: mat4) mat4 {
        var ret: mat4 = undefined;

        for (0..4) |i| {
            for (0..4) |j| {
                ret.rows[i][j] =
                    A.rows[i][0] * B.rows[0][j] +
                    A.rows[i][1] * B.rows[1][j] +
                    A.rows[i][2] * B.rows[2][j] +
                    A.rows[i][3] * B.rows[3][j];
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

        return .{
            .rows = .{
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
            },
        };
    }

    ///Rotate around a given angle and a unit vector axis
    ///Uses the function `rotationMatrix`
    pub fn rotate(mat: mat4, angle: f32, axis: vec3) mat4 {
        return mat.mult(rotationMatrix(angle, axis));
    }
};

pub const vec3 = @Vector(3, f32);

pub const radians = math.degreesToRadians;
