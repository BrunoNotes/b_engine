const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub const ZERO = init(0.0, 0.0);
    pub const UP = init(0.0, 1.0);
    pub const DOWN = init(0.0, -1.0);
    pub const LEFT = init(-1.0, 0.0);
    pub const RIGHT = init(1.0, 0.0);

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(vector_0: Vec2, vector_1: Vec2) Vec2 {
        return Vec2{
            .x = vector_0.x + vector_1.x,
            .y = vector_0.y + vector_1.y,
        };
    }

    pub fn sub(vector_0: Vec2, vector_1: Vec2) Vec2 {
        return Vec2{
            .x = vector_0.x - vector_1.x,
            .y = vector_0.y - vector_1.y,
        };
    }

    pub fn mult(vector_0: Vec2, vector_1: Vec2) Vec2 {
        return Vec2{
            .x = vector_0.x * vector_1.x,
            .y = vector_0.y * vector_1.y,
        };
    }

    pub fn div(vector_0: Vec2, vector_1: Vec2) Vec2 {
        return Vec2{
            .x = vector_0.x / vector_1.x,
            .y = vector_0.y / vector_1.y,
        };
    }

    pub fn lengthSquared(vector: Vec2) f32 {
        return vector.x * vector.x + vector.y * vector.y;
    }

    pub fn length(vector: Vec2) f32 {
        return std.math.sqrt(Vec2.lengthSquared(vector));
    }

    pub fn normalize(self: *@This()) void {
        const vec_length = Vec2.length(self);
        self.x /= vec_length;
        self.y /= vec_length;
    }

    // the distance between 2 vectors
    pub fn distance(vector_0: Vec2, vector_1: Vec2) f32 {
        const d = Vec2.sub(vector_0, vector_1);
        return Vec2.length(d);
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const ZERO = init(0.0, 0.0, 0.0);
    pub const UP = init(0.0, 1.0, 0.0);
    pub const DOWN = init(0.0, -1.0, 0.0);
    pub const LEFT = init(-1.0, 0.0, 0.0);
    pub const RIGHT = init(1.0, 0.0, 0.0);
    pub const FORWARD = init(0.0, 0.0, 1.0);
    pub const BACK = init(0.0, 0.0, -1.0);

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(vector_0: Vec3, vector_1: Vec3) Vec3 {
        return Vec3{
            .x = vector_0.x + vector_1.x,
            .y = vector_0.y + vector_1.y,
            .z = vector_0.z + vector_1.z,
        };
    }

    pub fn sub(vector_0: Vec3, vector_1: Vec3) Vec3 {
        return Vec3{
            .x = vector_0.x - vector_1.x,
            .y = vector_0.y - vector_1.y,
            .z = vector_0.z - vector_1.z,
        };
    }

    pub fn mult(vector_0: Vec3, vector_1: Vec3) Vec3 {
        return Vec3{
            .x = vector_0.x * vector_1.x,
            .y = vector_0.y * vector_1.y,
            .z = vector_0.z * vector_1.z,
        };
    }

    pub fn div(vector_0: Vec3, vector_1: Vec3) Vec3 {
        return Vec3{
            .x = vector_0.x / vector_1.x,
            .y = vector_0.y / vector_1.y,
            .z = vector_0.z / vector_1.z,
        };
    }

    pub fn multScalar(vector: Vec3, scalar: f32) Vec3 {
        return Vec3{
            .x = vector.x * scalar,
            .y = vector.y * scalar,
            .z = vector.z * scalar,
        };
    }

    pub fn lengthSquared(vector: Vec3) f32 {
        return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z;
    }

    pub fn length(vector: Vec3) f32 {
        return std.math.sqrt(Vec3.lengthSquared(vector));
    }

    // dot product
    pub fn dot(vector_0: Vec3, vector_1: Vec3) f32 {
        var p: f32 = 0;
        p += vector_0.x * vector_1.x;
        p += vector_0.y * vector_1.y;
        p += vector_0.z * vector_1.z;
        return p;
    }

    // cross multiply
    pub fn cross(vector_0: Vec3, vector_1: Vec3) Vec3 {
        return Vec3{
            .x = vector_0.y * vector_1.z - vector_0.z * vector_1.y,
            .y = vector_0.z * vector_1.x - vector_0.x * vector_1.z,
            .z = vector_0.x * vector_1.y - vector_0.y * vector_1.x,
        };
    }

    pub fn normalize(self: *@This()) void {
        const vec_length = Vec3.length(self.*);
        self.x /= vec_length;
        self.y /= vec_length;
        self.z /= vec_length;
    }

    // the distance between 2 vectors
    pub fn distance(vector_0: Vec3, vector_1: Vec3) f32 {
        const d = Vec3.sub(vector_0, vector_1);
        return Vec3.length(d);
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const ZERO = init(0.0, 0.0, 0.0, 0.0);

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn add(vector_0: Vec4, vector_1: Vec4) Vec4 {
        return Vec4{
            .x = vector_0.x + vector_1.x,
            .y = vector_0.y + vector_1.y,
            .z = vector_0.z + vector_1.z,
            .w = vector_0.w + vector_1.w,
        };
    }

    pub fn sub(vector_0: Vec4, vector_1: Vec4) Vec4 {
        return Vec4{
            .x = vector_0.x - vector_1.x,
            .y = vector_0.y - vector_1.y,
            .z = vector_0.z - vector_1.z,
            .w = vector_0.w - vector_1.w,
        };
    }

    pub fn mult(vector_0: Vec4, vector_1: Vec4) Vec4 {
        return Vec4{
            .x = vector_0.x * vector_1.x,
            .y = vector_0.y * vector_1.y,
            .z = vector_0.z * vector_1.z,
            .w = vector_0.w * vector_1.w,
        };
    }

    pub fn div(vector_0: Vec4, vector_1: Vec4) Vec4 {
        return Vec4{
            .x = vector_0.x / vector_1.x,
            .y = vector_0.y / vector_1.y,
            .z = vector_0.z / vector_1.z,
            .w = vector_0.w / vector_1.w,
        };
    }

    pub fn lengthSquared(vector: Vec4) f32 {
        return vector.x * vector.x + vector.y * vector.y + vector.z * vector.z + vector.w * vector.w;
    }

    pub fn length(vector: Vec4) f32 {
        return std.math.sqrt(Vec4.lengthSquared(vector));
    }

    pub fn normalize(self: *@This()) void {
        const vec_length = Vec4.length(self);
        self.x /= vec_length;
        self.y /= vec_length;
        self.z /= vec_length;
        self.w /= vec_length;
    }
};

pub const Mat4 = struct {
    data: [16]f32,

    pub const ZERO = Mat4{
        .data = [16]f32{
            0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0,
        },
    };

    pub const IDENTITY = Mat4{
        .data = [16]f32{
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        },
    };

    pub fn mult(matrix_0: Mat4, matrix_1: Mat4) Mat4 {
        var result = Mat4.ZERO;

        for (&result.data, 0..result.data.len) |*data, i| {
            const row = i / 4;
            const col = i % 4;

            for (matrix_0.data[row * 4 .. row * 4 + 4], 0..4) |data_0, j| {
                data.* += data_0 * matrix_1.data[j * 4 + col];
            }
        }

        return result;
    }

    // ortographic projection matrix
    pub fn ortographic(
        left_dir: f32,
        right_dir: f32,
        bottom_dir: f32,
        top_dir: f32,
        near_clip: f32,
        far_clip: f32,
    ) Mat4 {
        var result = Mat4.IDENTITY;

        const lr = 1.0 / (left_dir - right_dir);
        const bt = 1.0 / (bottom_dir - top_dir);
        const nf = 1.0 / (near_clip - far_clip);

        result.data[0] = -2.0 * lr;
        result.data[5] = -2.0 * bt;
        result.data[10] = -2.0 * nf;

        result.data[12] = (left_dir + right_dir) * lr;
        result.data[13] = (top_dir + bottom_dir) * bt;
        result.data[14] = (far_clip + near_clip) * nf;

        return result;
    }

    // perspective projection matrix
    pub fn perspective(
        fov_radians: f32,
        aspect_ratio: f32,
        near_clip: f32,
        far_clip: f32,
    ) Mat4 {
        var result = Mat4.ZERO;

        const half_tan_fov: f32 = std.math.tan(fov_radians * 0.5);

        result.data[0] = 1.0 / (aspect_ratio * half_tan_fov);
        result.data[5] = 1.0 / half_tan_fov;
        result.data[10] = -((far_clip + near_clip) / (far_clip - near_clip));
        result.data[11] = -1.0;
        result.data[14] = -((2.0 * far_clip * near_clip) / (far_clip - near_clip));

        return result;
    }

    pub fn lookAt(
        position: Vec3,
        target: Vec3,
        up_vec: Vec3,
    ) Mat4 {
        var result = Mat4.ZERO;
        var z_axis = Vec3.sub(target, position);
        z_axis.normalize();
        var x_axis = Vec3.cross(z_axis, up_vec);
        x_axis.normalize();
        const y_axis = Vec3.cross(x_axis, z_axis);

        result.data[0] = x_axis.x;
        result.data[1] = y_axis.x;
        result.data[2] = -z_axis.x;
        result.data[3] = 0;
        result.data[4] = x_axis.y;
        result.data[5] = y_axis.y;
        result.data[6] = -z_axis.y;
        result.data[7] = 0;
        result.data[8] = x_axis.z;
        result.data[9] = y_axis.z;
        result.data[10] = -z_axis.z;
        result.data[11] = 0;
        result.data[12] = -Vec3.dot(x_axis, position);
        result.data[13] = -Vec3.dot(y_axis, position);
        result.data[14] = Vec3.dot(z_axis, position);
        result.data[15] = 1.0;

        return result;
    }

    pub fn transposed(matrix: Mat4) Mat4 {
        var result = Mat4.ZERO;
        result.data[0] = matrix.data[0];
        result.data[1] = matrix.data[4];
        result.data[2] = matrix.data[8];
        result.data[3] = matrix.data[12];
        result.data[4] = matrix.data[1];
        result.data[5] = matrix.data[5];
        result.data[6] = matrix.data[9];
        result.data[7] = matrix.data[13];
        result.data[8] = matrix.data[2];
        result.data[9] = matrix.data[6];
        result.data[10] = matrix.data[10];
        result.data[11] = matrix.data[14];
        result.data[12] = matrix.data[3];
        result.data[13] = matrix.data[7];
        result.data[14] = matrix.data[11];
        result.data[15] = matrix.data[15];
        return result;
    }

    pub fn inverse(matrix: Mat4) Mat4 {
        const m = matrix.data;

        const t0 = m[10] * m[15];
        const t1 = m[14] * m[11];
        const t2 = m[6] * m[15];
        const t3 = m[14] * m[7];
        const t4 = m[6] * m[11];
        const t5 = m[10] * m[7];
        const t6 = m[2] * m[15];
        const t7 = m[14] * m[3];
        const t8 = m[2] * m[11];
        const t9 = m[10] * m[3];
        const t10 = m[2] * m[7];
        const t11 = m[6] * m[3];
        const t12 = m[8] * m[13];
        const t13 = m[12] * m[9];
        const t14 = m[4] * m[13];
        const t15 = m[12] * m[5];
        const t16 = m[4] * m[9];
        const t17 = m[8] * m[5];
        const t18 = m[0] * m[13];
        const t19 = m[12] * m[1];
        const t20 = m[0] * m[9];
        const t21 = m[8] * m[1];
        const t22 = m[0] * m[5];
        const t23 = m[4] * m[1];

        var result = Mat4.ZERO;

        result.data[0] = (t0 * m[5] + t3 * m[9] + t4 * m[13]) -
            (t1 * m[5] + t2 * m[9] + t5 * m[13]);
        result.data[1] = (t1 * m[1] + t6 * m[9] + t9 * m[13]) -
            (t0 * m[1] + t7 * m[9] + t8 * m[13]);
        result.data[2] = (t2 * m[1] + t7 * m[5] + t10 * m[13]) -
            (t3 * m[1] + t6 * m[5] + t11 * m[13]);
        result.data[3] = (t5 * m[1] + t8 * m[5] + t11 * m[9]) -
            (t4 * m[1] + t9 * m[5] + t10 * m[9]);

        const d = 1.0 / (m[0] * result.data[0] + m[4] * result.data[1] + m[8] * result.data[2] + m[12] * result.data[3]);

        // Check for singular matrix (determinant near zero)
        if (@abs(d) < 1e-6) {
            // Return identity matrix if the determinant is close to zero (singular matrix)
            return Mat4.IDENTITY;
        }

        result.data[0] = d * result.data[0];
        result.data[1] = d * result.data[1];
        result.data[2] = d * result.data[2];
        result.data[3] = d * result.data[3];
        result.data[4] = d * ((t1 * m[4] + t2 * m[8] + t5 * m[12]) -
            (t0 * m[4] + t3 * m[8] + t4 * m[12]));
        result.data[5] = d * ((t0 * m[0] + t7 * m[8] + t8 * m[12]) -
            (t1 * m[0] + t6 * m[8] + t9 * m[12]));
        result.data[6] = d * ((t3 * m[0] + t6 * m[4] + t11 * m[12]) -
            (t2 * m[0] + t7 * m[4] + t10 * m[12]));
        result.data[7] = d * ((t4 * m[0] + t9 * m[4] + t10 * m[8]) -
            (t5 * m[0] + t8 * m[4] + t11 * m[8]));
        result.data[8] = d * ((t12 * m[7] + t15 * m[11] + t16 * m[15]) -
            (t13 * m[7] + t14 * m[11] + t17 * m[15]));
        result.data[9] = d * ((t13 * m[3] + t18 * m[11] + t21 * m[15]) -
            (t12 * m[3] + t19 * m[11] + t20 * m[15]));
        result.data[10] = d * ((t14 * m[3] + t19 * m[7] + t22 * m[15]) -
            (t15 * m[3] + t18 * m[7] + t23 * m[15]));
        result.data[11] = d * ((t17 * m[3] + t20 * m[7] + t23 * m[11]) -
            (t16 * m[3] + t21 * m[7] + t22 * m[11]));
        result.data[12] = d * ((t14 * m[10] + t17 * m[14] + t13 * m[6]) -
            (t16 * m[14] + t12 * m[6] + t15 * m[10]));
        result.data[13] = d * ((t20 * m[14] + t12 * m[2] + t19 * m[10]) -
            (t18 * m[10] + t21 * m[14] + t13 * m[2]));
        result.data[14] = d * ((t18 * m[6] + t23 * m[14] + t15 * m[2]) -
            (t22 * m[14] + t14 * m[2] + t19 * m[6]));
        result.data[15] = d * ((t22 * m[10] + t16 * m[2] + t21 * m[6]) -
            (t20 * m[6] + t23 * m[10] + t17 * m[2]));

        return result;
    }

    pub fn translation(position: Vec3) Mat4 {
        var result = Mat4.IDENTITY;
        result.data[12] = position.x;
        result.data[13] = position.y;
        result.data[14] = position.z;
        return result;
    }

    pub fn scale(value: Vec3) Mat4 {
        var result = Mat4.IDENTITY;
        result.data[0] = value.x;
        result.data[5] = value.y;
        result.data[10] = value.z;
        return result;
    }

    pub fn eulerX(angle_radians: f32) Mat4 {
        var result = Mat4.IDENTITY;
        const c: f32 = std.math.cos(angle_radians);
        const s: f32 = std.math.sin(angle_radians);

        result.data[5] = c;
        result.data[6] = s;
        result.data[9] = -s;
        result.data[10] = c;
        return result;
    }

    pub fn eulerY(angle_radians: f32) Mat4 {
        var result = Mat4.IDENTITY;
        const c: f32 = std.math.cos(angle_radians);
        const s: f32 = std.math.sin(angle_radians);

        result.data[0] = c;
        result.data[2] = -s;
        result.data[8] = s;
        result.data[10] = c;
        return result;
    }

    pub fn eulerZ(angle_radians: f32) Mat4 {
        var result = Mat4.IDENTITY;
        const c: f32 = std.math.cos(angle_radians);
        const s: f32 = std.math.sin(angle_radians);

        result.data[0] = c;
        result.data[1] = s;
        result.data[4] = -s;
        result.data[5] = c;
        return result;
    }

    pub fn eulerXYZ(
        x_radians: f32,
        y_radians: f32,
        z_radians: f32,
    ) Mat4 {
        const rx = Mat4.eulerX(x_radians);
        const ry = Mat4.eulerY(y_radians);
        const rz = Mat4.eulerZ(z_radians);
        var result = Mat4.mult(rx, ry);
        result = Mat4.mult(result, rz);
        return result;
    }

    pub fn forward(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = -matrix.data[8];
        vector.y = -matrix.data[9];
        vector.z = -matrix.data[10];
        vector.normalize();
        return vector;
    }

    pub fn backward(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = matrix.data[8];
        vector.y = matrix.data[9];
        vector.z = matrix.data[10];
        vector.normalize();
        return vector;
    }

    pub fn up(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = matrix.data[1];
        vector.y = matrix.data[5];
        vector.z = matrix.data[9];
        vector.normalize();
        return vector;
    }

    pub fn down(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = -matrix.data[1];
        vector.y = -matrix.data[5];
        vector.z = -matrix.data[9];
        vector.normalize();
        return vector;
    }

    pub fn left(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = -matrix.data[0];
        vector.y = -matrix.data[1];
        vector.z = -matrix.data[2];
        vector.normalize();
        return vector;
    }

    pub fn right(matrix: Mat4) Vec3 {
        var vector = Vec3.ZERO;
        vector.x = matrix.data[0];
        vector.y = matrix.data[1];
        vector.z = matrix.data[2];
        vector.normalize();
        return vector;
    }
};

// quaternion
pub const Quat = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const ZERO = init(0.0, 0.0, 0.0, 0.0);
    pub const IDENTITY = init(0.0, 0.0, 0.0, 1.0);

    pub fn init(x: f32, y: f32, z: f32, w: f32) Quat {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn normal(q: Quat) f32 {
        return std.math.sqrt(q.x * q.x +
            q.y * q.y +
            q.z * q.z +
            q.w * q.w);
    }

    pub fn normalize(self: *@This()) void {
        const normal_value = Quat.normal(self);
        self.x = self.x / normal_value;
        self.y = self.y / normal_value;
        self.z = self.z / normal_value;
        self.w = self.w / normal_value;
    }

    pub fn conjugate(q: Quat) Quat {
        return Quat{
            .x = -q.x,
            .y = -q.y,
            .z = -q.z,
            .w = q.w,
        };
    }

    pub fn inverse(q: Quat) Quat {
        var result = Quat.conjugate(q);
        return result.normalize();
    }

    pub fn mult(q_0: Quat, q_1: Quat) Quat {
        var result = Quat.ZERO;

        result.x =
            q_0.x * q_1.w + q_0.y * q_1.z - q_0.z * q_1.y + q_0.w * q_1.x;

        result.y =
            -q_0.x * q_1.z + q_0.y * q_1.w + q_0.z * q_1.x + q_0.w * q_1.y;

        result.z =
            q_0.x * q_1.y - q_0.y * q_1.x + q_0.z * q_1.w + q_0.w * q_1.z;

        result.w =
            -q_0.x * q_1.x - q_0.y * q_1.y - q_0.z * q_1.z + q_0.w * q_1.w;

        return result;
    }

    pub fn dot(q_0: Quat, q_1: Quat) f32 {
        return q_0.x * q_1.x + q_0.y * q_1.y + q_0.z * q_1.z + q_0.w * q_1.w;
    }

    pub fn toMat4(q: Quat) Mat4 {
        var result = Mat4.identity();

        // https://stackoverflow.com/questions/1556260/convert-quaternion-rotation-to-rotation-matrix

        const n = q.normalize();

        result.data[0] = 1.0 - 2.0 * n.y * n.y - 2.0 * n.z * n.z;
        result.data[1] = 2.0 * n.x * n.y - 2.0 * n.z * n.w;
        result.data[2] = 2.0 * n.x * n.z + 2.0 * n.y * n.w;

        result.data[4] = 2.0 * n.x * n.y + 2.0 * n.z * n.w;
        result.data[5] = 1.0 - 2.0 * n.x * n.x - 2.0 * n.z * n.z;
        result.data[6] = 2.0 * n.y * n.z - 2.0 * n.x * n.w;

        result.data[8] = 2.0 * n.x * n.z - 2.0 * n.y * n.w;
        result.data[9] = 2.0 * n.y * n.z + 2.0 * n.x * n.w;
        result.data[10] = 1.0 - 2.0 * n.x * n.x - 2.0 * n.y * n.y;

        return result;
    }

    pub fn toRotationMatrix(q: Quat, center: Vec3) Mat4 {
        var result = Mat4.ZERO;

        result.data[0] = (q.x * q.x) - (q.y * q.y) - (q.z * q.z) + (q.w * q.w);
        result.data[1] = 2.0 * ((q.x * q.y) + (q.z * q.w));
        result.data[2] = 2.0 * ((q.x * q.z) - (q.y * q.w));
        result.data[3] = center.x - center.x * result.data[0] - center.y * result.data[1] - center.z * result.data[2];

        result.data[4] = 2.0 * ((q.x * q.y) - (q.z * q.w));
        result.data[5] = -(q.x * q.x) + (q.y * q.y) - (q.z * q.z) + (q.w * q.w);
        result.data[6] = 2.0 * ((q.y * q.z) + (q.x * q.w));
        result.data[7] = center.y - center.x * result.data[4] - center.y * result.data[5] - center.z * result.data[6];

        result.data[8] = 2.0 * ((q.x * q.z) + (q.y * q.w));
        result.data[9] = 2.0 * ((q.y * q.z) - (q.x * q.w));
        result.data[10] = -(q.x * q.x) - (q.y * q.y) + (q.z * q.z) + (q.w * q.w);
        result.data[11] = center.z - center.x * result.data[8] - center.y * result.data[9] - center.z * result.data[10];

        result.data[12] = 0.0;
        result.data[13] = 0.0;
        result.data[14] = 0.0;
        result.data[15] = 1.0;
        return result;
    }

    pub fn fromAxisAngle(
        axis: Vec3,
        angle: f32,
    ) Quat {
        const half_angle = 0.5 * angle;
        const s = std.math.sin(half_angle);
        const c = std.math.cos(half_angle);

        return Quat.init(s * axis.x, s * axis.y, s * axis.z, c);
    }

    pub fn slerp(q_0: Quat, q_1: Quat, percentage: f32) Quat {
        var result = Quat.ZERO;
        // Source: https://en.wikipedia.org/wiki/Slerp
        // Only unit quaternions are valid rotations.
        // Normalize to avoid undefined behavior.
        const v0 = q_0.normalize();
        const v1 = q_1.normalize();

        // Compute the cosine of the angle between the two vectors.
        var q_dot = Quat.dot(v0, v1);

        // If the dot product is negative, slerp won't take
        // the shorter path. Note that v1 and -v1 are equivalent when
        // the negation is applied to all four components. Fix by
        // reversing one quaternion.
        if (q_dot < 0.0) {
            v1.x = -v1.x;
            v1.y = -v1.y;
            v1.z = -v1.z;
            v1.w = -v1.w;
            q_dot = -q_dot;
        }

        const DOT_THRESHOLD: f32 = 0.9995;
        if (q_dot > DOT_THRESHOLD) {
            // If the inputs are too close for comfort, linearly interpolate
            // and normalize the result.
            result = Quat.init(
                v0.x + ((v1.x - v0.x) * percentage),
                v0.y + ((v1.y - v0.y) * percentage),
                v0.z + ((v1.z - v0.z) * percentage),
                v0.w + ((v1.w - v0.w) * percentage),
            );

            return result.normalize();
        }

        // Since dot is in range [0, DOT_THRESHOLD], acos is safe
        const theta_0 = std.math.acos(q_dot); // theta_0 = angle between input vectors
        const theta = theta_0 * percentage; // theta = angle between v0 and result
        const sin_theta = std.math.sin(theta); // compute this value only once
        const sin_theta_0 = std.math.sin(theta_0); // compute this value only once

        const s0 =
            std.math.cos(theta) -
            q_dot * sin_theta / sin_theta_0; // == sin(theta_0 - theta) / sin(theta_0)
        const s1 = sin_theta / sin_theta_0;

        return Quat.init(
            (v0.x * s0) + (v1.x * s1),
            (v0.y * s0) + (v1.y * s1),
            (v0.z * s0) + (v1.z * s1),
            (v0.w * s0) + (v1.w * s1),
        );
    }
};
