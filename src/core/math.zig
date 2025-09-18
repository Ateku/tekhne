pub const degreesToRadians = @import("std").math.degreesToRadians;

pub const Vector3 = @Vector(3, f32);
pub const vector3 = struct {
    pub const zero: Vector3 = .{ 0, 0, 0 };
    pub const one: Vector3 = .{ 1, 1, 1 };
    pub const right: Vector3 = .{ 1, 0, 0 };
    pub const left: Vector3 = .{ -1, 0, 0 };
    pub const up: Vector3 = .{ 0, 1, 0 };
    pub const down: Vector3 = .{ 0, -1, 0 };
    pub const forward: Vector3 = .{ 0, 0, 1 };
    pub const backward: Vector3 = .{ 0, 0, -1 };

    pub fn fromVector4(v: Vector4) Vector3 {
        return .{ v[0], v[1], v[2] };
    }

    pub fn splat(s: f32) Vector3 {
        return @splat(s);
    }

    pub fn scale(v: Vector3, s: f32) Vector3 {
        return v * splat(s);
    }

    pub fn dot(a: Vector3, b: Vector3) f32 {
        return @reduce(.Add, a * b);
    }

    pub fn magnitude(v: Vector3) f32 {
        return @sqrt(dot(v, v));
    }

    pub fn magnitudeSquared(v: Vector3) f32 {
        return dot(v, v);
    }

    pub fn normalize(v: Vector3) Vector3 {
        const length = magnitudeSquared(v);

        return if (length == 0) v else v / splat(length);
    }

    pub fn cross(a: Vector3, b: Vector3) Vector3 {
        return .{
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
        };
    }
};

pub const Vector4 = @Vector(4, f32);
pub const vector4 = struct {
    pub fn fromVector3(v: Vector3, w: f32) Vector4 {
        return .{ v[0], v[1], v[2], w };
    }
};

pub const Matrix = [4]Vector4;
pub const matrix = struct {
    pub const identity: Matrix = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };

    pub fn mul(a: Matrix, b: Matrix) Matrix {
        const bt = transpose(b);
        var result: Matrix = undefined;

        inline for (0..4) |i| {
            result[i] = .{
                @reduce(.Add, a[i] * bt[0]),
                @reduce(.Add, a[i] * bt[1]),
                @reduce(.Add, a[i] * bt[2]),
                @reduce(.Add, a[i] * bt[3]),
            };
        }

        return result;
    }

    pub fn mulVec(a: Matrix, b: Vector4) Vector4 {
        return .{
            @reduce(.Add, a[0] * b),
            @reduce(.Add, a[1] * b),
            @reduce(.Add, a[2] * b),
            @reduce(.Add, a[3] * b),
        };
    }

    pub fn lookAt(eye: Vector3, target: Vector3, up: Vector3) Matrix {
        const f = vector3.normalize(eye - target);
        const s = vector3.normalize(vector3.cross(up, f));
        const u = vector3.cross(f, s);

        return .{
            vector4.fromVector3(s, -vector3.dot(s, eye)),
            vector4.fromVector3(u, -vector3.dot(u, eye)),
            vector4.fromVector3(-f, vector3.dot(f, eye)),
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Matrix {
        const t = 1 / @tan(fov * 0.5);
        const f = far / (far - near);

        return transpose(.{
            .{ t, 0, 0, 0 },
            .{ 0, t / aspect, 0, 0 },
            .{ 0, 0, f, 1 },
            .{ 0, 0, -near * f, 0 },
        });
    }

    pub fn transpose(m: Matrix) Matrix {
        const t1 = @shuffle(f32, m[0], m[1], [4]i32{ 0, 1, -1, -2 });
        const t3 = @shuffle(f32, m[0], m[1], [4]i32{ 2, 3, -3, -4 });
        const t2 = @shuffle(f32, m[2], m[3], [4]i32{ 0, 1, -1, -2 });
        const t4 = @shuffle(f32, m[2], m[3], [4]i32{ 2, 3, -3, -4 });

        return .{
            @shuffle(f32, t1, t2, [4]i32{ 0, 2, -1, -3 }),
            @shuffle(f32, t1, t2, [4]i32{ 1, 3, -2, -4 }),
            @shuffle(f32, t3, t4, [4]i32{ 0, 2, -1, -3 }),
            @shuffle(f32, t3, t4, [4]i32{ 1, 3, -2, -4 }),
        };
    }

    pub fn translate(v: Vector3) Matrix {
        return .{
            .{ 1, 0, 0, v[0] },
            .{ 0, 1, 0, v[1] },
            .{ 0, 0, 1, v[2] },
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn rotateX(v: f32) Matrix {
        const rad = degreesToRadians(v);
        const c = @cos(rad);
        const s = @sin(rad);

        return .{
            .{ 1, 0, 0, 0 },
            .{ 0, c, -s, 0 },
            .{ 0, s, c, 0 },
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn rotateY(v: f32) Matrix {
        const rad = degreesToRadians(v);
        const c = @cos(rad);
        const s = @sin(rad);

        return .{
            .{ c, 0, s, 0 },
            .{ 0, 1, 0, 0 },
            .{ -s, 0, c, 0 },
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn rotateZ(v: f32) Matrix {
        const rad = degreesToRadians(v);
        const c = @cos(rad);
        const s = @sin(rad);

        return .{
            .{ c, -s, 0, 0 },
            .{ s, c, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn rotate(v: Vector3) Matrix {
        const x = rotateX(v[0]);
        const y = rotateY(v[1]);
        const z = rotateZ(v[2]);

        return mul(z, mul(y, x));
    }

    pub fn scale(v: Vector3) Matrix {
        return .{
            .{ v[0], 0, 0, 0 },
            .{ 0, v[1], 0, 0 },
            .{ 0, 0, v[2], 0 },
            .{ 0, 0, 0, 1 },
        };
    }

    pub fn recompose(position: Vector3, rotation: Vector3, scalar: Vector3) Matrix {
        return mul(translate(position), mul(rotate(rotation), scale(scalar)));
    }
};
