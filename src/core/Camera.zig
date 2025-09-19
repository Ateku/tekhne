const std = @import("std");
const mem = std.mem;
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const math = @import("math.zig");
const vector3 = math.vector3;
const matrix = math.matrix;

const Camera = @This();

position: math.Vector3 = .{ 0, 0, 3 },
rotation: math.Vector3 = .{ 0, 90, 0 },

fov: f32 = 90.0,
near: f32 = 0.1,
far: f32 = 1000.0,

pub const new: Camera = .{};

pub fn getForwardVector(camera: Camera) math.Vector3 {
    const x_rot = math.degreesToRadians(camera.rotation[0]);
    const y_rot = math.degreesToRadians(camera.rotation[1]);

    return vector3.normalize(vector3.scale(.{
        @cos(x_rot) * @cos(y_rot),
        @sin(x_rot),
        @cos(x_rot) * @sin(y_rot),
    }, -1));
}

pub fn pushData(camera: Camera, cmd_buf: gpu.CommandBuffer, aspect: f32) void {
    const target = camera.getForwardVector() + camera.position;

    cmd_buf.pushVertexUniformData(0, mem.asBytes(&.{
        matrix.lookAt(camera.position, target, vector3.up),
        matrix.perspective(camera.fov, aspect, camera.near, camera.far),
    }));

    cmd_buf.pushFragmentUniformData(0, mem.asBytes(&.{camera.position}));
}
